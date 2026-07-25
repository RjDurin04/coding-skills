[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRecord,
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    $Root = [System.IO.Path]::GetDirectoryName($scriptDirectory)
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$findings = New-Object 'System.Collections.Generic.List[string]'

function Add-Finding {
    param([string] $Message)
    $findings.Add($Message)
}

function Test-JsonNumber {
    param($Value)
    $isNumeric = (
        ($Value -is [byte]) -or
        ($Value -is [int16]) -or
        ($Value -is [int32]) -or
        ($Value -is [int64]) -or
        ($Value -is [single]) -or
        ($Value -is [double]) -or
        ($Value -is [decimal])
    )
    if (-not $isNumeric) {
        return $false
    }
    if (($Value -is [single]) -or ($Value -is [double])) {
        $number = [double] $Value
        return (-not [double]::IsNaN($number)) -and
            (-not [double]::IsInfinity($number))
    }
    return $true
}

function Test-JsonInteger {
    param($Value)
    return (
        ($Value -is [byte]) -or
        ($Value -is [int16]) -or
        ($Value -is [int32]) -or
        ($Value -is [int64])
    )
}

function Test-NonblankString {
    param($Value)
    return (($Value -is [string]) -and (-not [string]::IsNullOrWhiteSpace($Value)))
}

function Test-MeasuredString {
    param($Value)
    if (-not (Test-NonblankString $Value)) { return $false }
    return ([string] $Value -notmatch '^(?i:replace[-_]with(?:[-_]|$))')
}

function ConvertFrom-JsonDocument {
    param([string] $Json)

    $command = Get-Command ConvertFrom-Json -CommandType Cmdlet
    if ($command.Parameters.ContainsKey('DateKind')) {
        return ConvertFrom-Json -InputObject $Json -DateKind String
    }
    return ConvertFrom-Json -InputObject $Json
}

function Test-JsonTimestamp {
    param($Value)

    if (($Value -is [datetime]) -or ($Value -is [datetimeoffset])) {
        return $true
    }
    if (($Value -isnot [string]) -or [string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    $parsed = [datetimeoffset]::MinValue
    return [datetimeoffset]::TryParse([string] $Value, [ref] $parsed)
}

function Assert-ObjectShape {
    param(
        $Value,
        [string[]] $Required,
        [string[]] $Allowed,
        [string] $Context
    )

    if ($Value -isnot [pscustomobject]) {
        Add-Finding "$Context must be an object."
        return $false
    }
    $names = @($Value.PSObject.Properties.Name)
    foreach ($name in $Required) {
        if ($names -notcontains $name) {
            Add-Finding "$Context is missing property '$name'."
        }
    }
    foreach ($name in $names) {
        if ($Allowed -notcontains $name) {
            Add-Finding "$Context contains unknown property '$name'."
        }
    }
    return (@($Required | Where-Object { $names -notcontains $_ }).Count -eq 0)
}

function Write-InvalidResult {
    $result = [ordered]@{
        status = 'INVALID'
        findings = @($findings)
    }
    Write-Output ($result | ConvertTo-Json -Depth 10)
}

function Test-PathEquals {
    param(
        [string] $Left,
        [string] $Right
    )
    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    return [string]::Equals($Left, $Right, $comparison)
}

$manifestPath = Join-Path $rootPath 'governance-manifest.json'
try {
    $manifest = ConvertFrom-JsonDocument (
        Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath
    )
    $catalogPath = Join-Path $rootPath (
        [string] $manifest.capability_evaluations.catalog -replace '/', [System.IO.Path]::DirectorySeparatorChar
    )
    $catalog = ConvertFrom-JsonDocument (
        Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath
    )
}
catch {
    Add-Finding "Unable to load governance manifest or capability catalog: $($_.Exception.Message)"
    Write-InvalidResult
    exit 2
}

try {
    foreach ($thresholdName in @('pass_score', 'critical_pass_score')) {
        $thresholdValue = $catalog.rubric.$thresholdName
        if ((-not (Test-JsonNumber $thresholdValue)) -or
            ([double] $thresholdValue -lt 1) -or
            ([double] $thresholdValue -gt 100)) {
            Add-Finding "Capability catalog $thresholdName must be a finite number from 1 to 100."
        }
    }
    $catalogWeightTotal = 0.0
    foreach ($dimension in @($catalog.rubric.dimensions)) {
        if (-not (Test-JsonNumber $dimension.weight)) {
            Add-Finding "Capability catalog dimension '$($dimension.name)' weight must be finite."
        }
        else {
            $catalogWeightTotal += [double] $dimension.weight
        }
        foreach ($riskName in @('trivial', 'standard', 'structural', 'critical')) {
            $minimumValue = $dimension.minimum_scores.$riskName
            if ((-not (Test-JsonNumber $minimumValue)) -or
                ([double] $minimumValue -lt 0) -or
                ([double] $minimumValue -gt 100)) {
                Add-Finding (
                    "Capability catalog dimension '$($dimension.name)' minimum " +
                    "'$riskName' must be a finite number from 0 to 100."
                )
            }
        }
    }
    if ([math]::Abs($catalogWeightTotal - 100.0) -gt 0.000001) {
        Add-Finding "Capability catalog dimension weights must total 100."
    }
}
catch {
    Add-Finding "Capability catalog numeric policy could not be validated: $($_.Exception.Message)"
}
if ($findings.Count -gt 0) {
    Write-InvalidResult
    exit 2
}

try {
    $recordPath = [System.IO.Path]::GetFullPath($RunRecord)
    if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
        throw "Run record does not exist: $RunRecord"
    }
    $record = ConvertFrom-JsonDocument (
        Get-Content -Raw -Encoding UTF8 -LiteralPath $recordPath
    )
    if ($record -isnot [pscustomobject]) {
        throw 'Run record root must be a JSON object.'
    }
}
catch {
    Add-Finding "Unable to load capability run record: $($_.Exception.Message)"
    Write-InvalidResult
    exit 2
}

$topFields = @(
    '$schema',
    'schema_version',
    'case_id',
    'rules_pack_version',
    'model',
    'execution',
    'runner',
    'reviewer',
    'artifacts',
    'dimension_scores',
    'criterion_results',
    'automatic_failure_reason_ids',
    'notes'
)
$topUsable = Assert-ObjectShape $record $topFields $topFields 'Capability run record'
if ($topUsable) {
    if ([string] $record.'$schema' -ne '../schemas/capability-evaluation-run.schema.json') {
        Add-Finding "Run record `$schema must be '../schemas/capability-evaluation-run.schema.json'."
    }
    if ((-not (Test-JsonInteger $record.schema_version)) -or (([int] $record.schema_version) -ne 2)) {
        Add-Finding 'Run record schema_version must be integer 2.'
    }
    if (-not (Test-MeasuredString $record.case_id)) {
        Add-Finding 'Run record case_id must contain a catalog case id.'
    }
    if (-not (Test-MeasuredString $record.rules_pack_version)) {
        Add-Finding 'Run record rules_pack_version must contain measured metadata.'
    }
    if ($record.notes -isnot [string]) {
        Add-Finding 'Run record notes must be a string.'
    }
}

$modelFields = @('provider', 'name', 'version', 'agent_surface')
if (($record.PSObject.Properties.Name -contains 'model') -and
    (Assert-ObjectShape $record.model $modelFields $modelFields 'Run record model')) {
    foreach ($field in $modelFields) {
        if (-not (Test-MeasuredString $record.model.$field)) {
            Add-Finding "Run record model '$field' must contain measured metadata."
        }
    }
}

$executionFields = @('repository', 'revision', 'started_at', 'duration_seconds', 'token_measure')
if (($record.PSObject.Properties.Name -contains 'execution') -and
    (Assert-ObjectShape $record.execution $executionFields $executionFields 'Run record execution')) {
    foreach ($field in @('repository', 'revision')) {
        if (-not (Test-MeasuredString $record.execution.$field)) {
            Add-Finding "Run record execution '$field' must contain measured metadata."
        }
    }
    if (-not (Test-JsonTimestamp $record.execution.started_at)) {
        Add-Finding 'Run record execution started_at must be a valid timestamp.'
    }
    if ((-not (Test-JsonNumber $record.execution.duration_seconds)) -or
        (([double] $record.execution.duration_seconds) -lt 0)) {
        Add-Finding 'Run record execution duration_seconds must be a nonnegative number.'
    }
    $tokenFields = @('unit', 'value')
    if (Assert-ObjectShape $record.execution.token_measure $tokenFields $tokenFields 'Run record token_measure') {
        if (@('tokens', 'usd', 'other') -notcontains [string] $record.execution.token_measure.unit) {
            Add-Finding 'Run record token_measure unit must be tokens, usd, or other.'
        }
        if ((-not (Test-JsonNumber $record.execution.token_measure.value)) -or
            (([double] $record.execution.token_measure.value) -lt 0)) {
            Add-Finding 'Run record token_measure value must be a nonnegative number.'
        }
    }
}

$identityFields = @('id', 'type', 'organization')
$identityUsable = @{}
foreach ($identityName in @('runner', 'reviewer')) {
    $identityUsable[$identityName] = $false
    if (($record.PSObject.Properties.Name -contains $identityName) -and
        (Assert-ObjectShape $record.$identityName $identityFields $identityFields "Run record $identityName")) {
        $identityUsable[$identityName] = $true
        foreach ($field in @('id', 'organization')) {
            if (-not (Test-MeasuredString $record.$identityName.$field)) {
                Add-Finding "Run record $identityName '$field' must contain measured metadata."
            }
        }
        if (@('human', 'agent', 'automation') -notcontains [string] $record.$identityName.type) {
            Add-Finding "Run record $identityName type must be human, agent, or automation."
        }
    }
}
if ($identityUsable.runner -and $identityUsable.reviewer -and
    (Test-NonblankString $record.runner.id) -and
    (Test-NonblankString $record.reviewer.id) -and
    [string]::Equals(
        ([string] $record.runner.id).Trim(),
        ([string] $record.reviewer.id).Trim(),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    Add-Finding 'Run record runner.id and reviewer.id must identify independent actors.'
}

$knownArtifactIds = @()
$resolvedArtifacts = @()
if (($record.PSObject.Properties.Name -contains 'artifacts') -and
    ($record.artifacts -is [System.Array])) {
    $artifacts = @($record.artifacts)
    if ($artifacts.Count -lt 1) {
        Add-Finding 'Run record artifacts must contain at least one artifact.'
    }
    $artifactIndex = 0
    foreach ($artifact in $artifacts) {
        $artifactIndex++
        $context = "Run record artifact #$artifactIndex"
        $artifactFields = @('id', 'path', 'sha256', 'media_type', 'description')
        if (-not (Assert-ObjectShape $artifact $artifactFields $artifactFields $context)) { continue }

        $artifactId = [string] $artifact.id
        if ((-not (Test-NonblankString $artifact.id)) -or
            ($artifactId -notmatch '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')) {
            Add-Finding "$context id must use snake_case."
        }
        elseif ($knownArtifactIds -contains $artifactId) {
            Add-Finding "Run record contains duplicate artifact id '$artifactId'."
        }
        else {
            $knownArtifactIds += $artifactId
        }

        if (-not (Test-MeasuredString $artifact.path)) {
            Add-Finding "$context path must identify measured evidence."
        }
        else {
            try {
                $recordDirectory = [System.IO.Path]::GetDirectoryName($recordPath)
                $resolvedPath = if ([System.IO.Path]::IsPathRooted([string] $artifact.path)) {
                    [System.IO.Path]::GetFullPath([string] $artifact.path)
                }
                else {
                    [System.IO.Path]::GetFullPath((Join-Path $recordDirectory ([string] $artifact.path)))
                }

                foreach ($resolvedArtifact in $resolvedArtifacts) {
                    if (Test-PathEquals $resolvedPath ([string] $resolvedArtifact.Path)) {
                        Add-Finding (
                            "Artifact '$artifactId' aliases the same resolved path as artifact " +
                            "'$($resolvedArtifact.Id)'."
                        )
                    }
                }
                $resolvedArtifacts += [pscustomobject]@{ Id = $artifactId; Path = $resolvedPath }

                if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
                    Add-Finding "Artifact '$artifactId' does not exist at '$($artifact.path)'."
                }
                else {
                    $declaredHash = ([string] $artifact.sha256).ToLowerInvariant()
                    if (($declaredHash -notmatch '^[a-f0-9]{64}$') -or
                        ($declaredHash -eq ('0' * 64))) {
                        Add-Finding "Artifact '$artifactId' sha256 must be a non-placeholder lowercase SHA-256 digest."
                    }
                    else {
                        $actualHash = (
                            Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256
                        ).Hash.ToLowerInvariant()
                        if ($declaredHash -ne $actualHash) {
                            Add-Finding "Artifact '$artifactId' sha256 does not match the file content."
                        }
                    }
                }
            }
            catch {
                Add-Finding "Artifact '$artifactId' path or digest could not be validated: $($_.Exception.Message)"
            }
        }

        if ((-not (Test-NonblankString $artifact.sha256)) -or
            ([string] $artifact.sha256 -notmatch '^[a-f0-9]{64}$')) {
            Add-Finding "$context sha256 must be 64 lowercase hexadecimal characters."
        }
        if ((-not (Test-NonblankString $artifact.media_type)) -or
            ([string] $artifact.media_type -notmatch '^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$')) {
            Add-Finding "$context media_type must be a lowercase media type."
        }
        if (-not (Test-MeasuredString $artifact.description)) {
            Add-Finding "$context description must describe the measured evidence."
        }
    }
}
elseif ($record.PSObject.Properties.Name -contains 'artifacts') {
    Add-Finding 'Run record artifacts must be an array.'
}

$matchingCases = @()
if (($record.PSObject.Properties.Name -contains 'case_id') -and
    (Test-NonblankString $record.case_id)) {
    $matchingCases = @($catalog.cases | Where-Object { [string] $_.id -eq [string] $record.case_id })
    if ($matchingCases.Count -ne 1) {
        Add-Finding "Run record case_id must match exactly one catalog case: $($record.case_id)"
    }
}

if (($record.PSObject.Properties.Name -contains 'rules_pack_version') -and
    ([string] $record.rules_pack_version -ne [string] $manifest.pack_version)) {
    Add-Finding (
        "Run record rules_pack_version '$($record.rules_pack_version)' does not match " +
        "'$($manifest.pack_version)'."
    )
}

$expectedDimensionNames = @($catalog.rubric.dimensions | ForEach-Object { [string] $_.name })
$dimensionScoreValues = @{}
$weightedTotal = 0.0
if (($record.PSObject.Properties.Name -contains 'dimension_scores') -and
    ($record.dimension_scores -is [pscustomobject])) {
    $actualDimensionNames = @($record.dimension_scores.PSObject.Properties.Name)
    foreach ($unknownDimension in @($actualDimensionNames | Where-Object { $expectedDimensionNames -notcontains $_ })) {
        Add-Finding "Run record contains unknown dimension score '$unknownDimension'."
    }
    foreach ($dimension in @($catalog.rubric.dimensions)) {
        $name = [string] $dimension.name
        if ($actualDimensionNames -notcontains $name) {
            Add-Finding "Run record is missing dimension score '$name'."
            continue
        }
        $score = $record.dimension_scores.$name
        if ((-not (Test-JsonNumber $score)) -or
            (([double] $score) -lt 0) -or
            (([double] $score) -gt 100)) {
            Add-Finding "Dimension '$name' must be a number from 0 to 100."
            continue
        }
        $dimensionScoreValues[$name] = [double] $score
        $weightedTotal += ([double] $score * [double] $dimension.weight) / 100.0
    }
}
elseif ($record.PSObject.Properties.Name -contains 'dimension_scores') {
    Add-Finding 'Run record dimension_scores must be an object.'
}

$expectedCriteria = @()
if ($matchingCases.Count -eq 1) {
    $caseForCriteria = $matchingCases[0]
    foreach ($groupName in @('must_demonstrate', 'must_avoid', 'required_evidence')) {
        foreach ($criterion in @($caseForCriteria.$groupName)) {
            $expectedCriteria += [pscustomobject]@{
                Id = [string] $criterion.id
                Group = $groupName
            }
        }
    }
}
$expectedCriterionIds = @($expectedCriteria | ForEach-Object { $_.Id })
$seenCriterionIds = @()
$criterionStatuses = @{}
if (($record.PSObject.Properties.Name -contains 'criterion_results') -and
    ($record.criterion_results -is [System.Array])) {
    $criterionResults = @($record.criterion_results)
    if ($criterionResults.Count -lt 1) {
        Add-Finding 'Run record criterion_results must contain every case criterion.'
    }
    $criterionIndex = 0
    foreach ($criterionResult in $criterionResults) {
        $criterionIndex++
        $context = "Run record criterion result #$criterionIndex"
        $fields = @('criterion_id', 'status', 'evidence_artifact_ids', 'review_notes')
        if (-not (Assert-ObjectShape $criterionResult $fields $fields $context)) { continue }

        $criterionId = [string] $criterionResult.criterion_id
        if (-not (Test-NonblankString $criterionResult.criterion_id)) {
            Add-Finding "$context criterion_id cannot be blank."
        }
        elseif ($seenCriterionIds -contains $criterionId) {
            Add-Finding "Run record contains duplicate criterion result '$criterionId'."
        }
        else {
            $seenCriterionIds += $criterionId
            if (($expectedCriterionIds.Count -gt 0) -and ($expectedCriterionIds -notcontains $criterionId)) {
                Add-Finding "Run record contains unknown criterion result '$criterionId'."
            }
        }

        $status = [string] $criterionResult.status
        if (@('satisfied', 'violated', 'unverified') -notcontains $status) {
            Add-Finding "$context status must be satisfied, violated, or unverified."
        }
        elseif (Test-NonblankString $criterionResult.criterion_id) {
            $criterionStatuses[$criterionId] = $status
        }

        if ($criterionResult.evidence_artifact_ids -isnot [System.Array]) {
            Add-Finding "$context evidence_artifact_ids must be an array."
        }
        else {
            $evidenceIds = @($criterionResult.evidence_artifact_ids)
            if ($evidenceIds.Count -lt 1) {
                Add-Finding "$context must reference at least one evidence artifact."
            }
            $normalizedEvidenceIds = @()
            foreach ($evidenceIdValue in $evidenceIds) {
                if (-not (Test-NonblankString $evidenceIdValue)) {
                    Add-Finding "$context evidence artifact ids cannot be blank."
                    continue
                }
                $evidenceId = [string] $evidenceIdValue
                $normalizedEvidenceIds += $evidenceId
                if ($knownArtifactIds -notcontains $evidenceId) {
                    Add-Finding "$context references unknown artifact '$evidenceId'."
                }
            }
            foreach ($duplicateEvidence in @(
                $normalizedEvidenceIds | Group-Object | Where-Object Count -gt 1
            )) {
                Add-Finding "$context repeats evidence artifact '$($duplicateEvidence.Name)'."
            }
        }
        if (-not (Test-MeasuredString $criterionResult.review_notes)) {
            Add-Finding "$context review_notes must contain an evidence-grounded assessment."
        }
    }
}
elseif ($record.PSObject.Properties.Name -contains 'criterion_results') {
    Add-Finding 'Run record criterion_results must be an array.'
}
if ($expectedCriterionIds.Count -gt 0) {
    foreach ($criterionId in $expectedCriterionIds) {
        if ($seenCriterionIds -notcontains $criterionId) {
            Add-Finding "Run record is missing criterion result '$criterionId'."
        }
    }
    if ($seenCriterionIds.Count -ne $expectedCriterionIds.Count) {
        Add-Finding (
            "Run record criterion result count must exactly match the case criteria " +
            "($($expectedCriterionIds.Count)); found $($seenCriterionIds.Count)."
        )
    }
}

$knownAutomaticReasonIds = @(
    $catalog.rubric.automatic_failure_reasons | ForEach-Object { [string] $_.id }
)
$automaticReasonIds = @()
if (($record.PSObject.Properties.Name -contains 'automatic_failure_reason_ids') -and
    ($record.automatic_failure_reason_ids -is [System.Array])) {
    foreach ($reasonIdValue in @($record.automatic_failure_reason_ids)) {
        if (-not (Test-NonblankString $reasonIdValue)) {
            Add-Finding 'Run record automatic_failure_reason_ids cannot contain blank values.'
            continue
        }
        $reasonId = [string] $reasonIdValue
        if ($automaticReasonIds -contains $reasonId) {
            Add-Finding "Run record repeats automatic failure reason '$reasonId'."
        }
        else {
            $automaticReasonIds += $reasonId
        }
        if ($knownAutomaticReasonIds -notcontains $reasonId) {
            Add-Finding "Run record contains unknown automatic failure reason '$reasonId'."
        }
    }
}
elseif ($record.PSObject.Properties.Name -contains 'automatic_failure_reason_ids') {
    Add-Finding 'Run record automatic_failure_reason_ids must be an array.'
}

if ($findings.Count -gt 0) {
    Write-InvalidResult
    exit 2
}

$case = $matchingCases[0]
$threshold = [double] $catalog.rubric.pass_score
if ([string] $case.risk -eq 'critical') {
    $threshold = [double] $catalog.rubric.critical_pass_score
}
$weightedScore = [math]::Round($weightedTotal, 2)

$floorFailures = @()
foreach ($dimension in @($catalog.rubric.dimensions)) {
    $name = [string] $dimension.name
    $minimum = [double] $dimension.minimum_scores.([string] $case.risk)
    $score = [double] $dimensionScoreValues[$name]
    if ($score -lt $minimum) {
        $floorFailures += [ordered]@{
            dimension = $name
            score = $score
            minimum = $minimum
        }
    }
}

$violatedCriteria = @(
    $expectedCriteria |
        Where-Object { [string] $criterionStatuses[$_.Id] -eq 'violated' } |
        ForEach-Object {
            [ordered]@{
                criterion_id = $_.Id
                criterion_group = $_.Group
            }
        }
)
$unverifiedCriteria = @(
    $expectedCriteria |
        Where-Object { [string] $criterionStatuses[$_.Id] -eq 'unverified' } |
        ForEach-Object {
            [ordered]@{
                criterion_id = $_.Id
                criterion_group = $_.Group
            }
        }
)

$status = 'PASS'
if (($weightedScore -lt $threshold) -or
    ($floorFailures.Count -gt 0) -or
    ($violatedCriteria.Count -gt 0) -or
    ($unverifiedCriteria.Count -gt 0) -or
    ($automaticReasonIds.Count -gt 0)) {
    $status = 'FAIL'
}

$result = [ordered]@{
    case_id = [string] $record.case_id
    category = [string] $case.category
    risk = [string] $case.risk
    primary_skill = [string] $case.primary_skill
    assurance = 'reviewer_attested'
    reviewer_identity_verification = 'not_verified_by_scorer'
    evidence_relevance_verification = 'reviewer_attested'
    artifact_integrity = 'sha256_verified_at_scoring'
    weighted_score = $weightedScore
    threshold = $threshold
    floor_failures = @($floorFailures)
    violated_criteria = @($violatedCriteria)
    unverified_criteria = @($unverifiedCriteria)
    automatic_failure_reason_ids = @($automaticReasonIds)
    status = $status
}
Write-Output ($result | ConvertTo-Json -Depth 10)

if ($status -eq 'FAIL') { exit 1 }
exit 0

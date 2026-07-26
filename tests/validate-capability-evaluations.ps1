[CmdletBinding()]
param(
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    $Root = [System.IO.Path]::GetDirectoryName($scriptDirectory)
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)
    $failures.Add($Message)
}

function Read-JsonObject {
    param(
        [string] $Path,
        [string] $Label
    )

    try {
        $value = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
        if ($value -isnot [pscustomobject]) {
            Add-Failure "$Label must be a JSON object."
            return $null
        }
        return $value
    }
    catch {
        Add-Failure "$Label is not valid JSON: $($_.Exception.Message)"
        return $null
    }
}

function Assert-ObjectShape {
    param(
        $Value,
        [string[]] $Required,
        [string[]] $Allowed,
        [string] $Context
    )

    if ($Value -isnot [pscustomobject]) {
        Add-Failure "$Context must be an object."
        return $false
    }

    $names = @($Value.PSObject.Properties.Name)
    foreach ($name in $Required) {
        if ($names -notcontains $name) {
            Add-Failure "$Context is missing property '$name'."
        }
    }
    foreach ($name in $names) {
        if ($Allowed -notcontains $name) {
            Add-Failure "$Context contains unknown property '$name'."
        }
    }
    return (@($Required | Where-Object { $names -notcontains $_ }).Count -eq 0)
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

function Assert-UniqueStrings {
    param(
        [string[]] $Values,
        [string] $Context
    )

    foreach ($duplicate in @($Values | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$Context contains duplicate '$($duplicate.Name)'."
    }
}

$canonicalCapabilityThresholdTargets = @(
    'rubric.pass_score',
    'rubric.critical_pass_score',
    'rubric.dimensions.*.weight',
    'rubric.dimensions.*.minimum_scores.trivial',
    'rubric.dimensions.*.minimum_scores.standard',
    'rubric.dimensions.*.minimum_scores.structural',
    'rubric.dimensions.*.minimum_scores.critical',
    'rubric.automatic_failure_reasons.*.id',
    'manifest.capability_evaluations.minimum_cases',
    'manifest.capability_evaluations.minimum_cases_per_routable_skill',
    'skill_coverage.*.minimum_cases',
    'coverage_requirements.maximum_cases',
    'coverage_requirements.minimum_categories',
    'coverage_requirements.minimum_cases_by_risk.trivial',
    'coverage_requirements.minimum_cases_by_risk.standard',
    'coverage_requirements.minimum_cases_by_risk.structural',
    'coverage_requirements.minimum_cases_by_risk.critical',
    'coverage_requirements.minimum_low_risk_ratio.numerator',
    'coverage_requirements.minimum_low_risk_ratio.denominator',
    'coverage_requirements.minimum_criteria_per_case.must_demonstrate',
    'coverage_requirements.minimum_criteria_per_case.must_avoid',
    'coverage_requirements.minimum_criteria_per_case.required_evidence'
)

function Assert-ThresholdPolicies {
    param($Policies)

    if (($Policies -isnot [System.Array]) -or ($Policies -is [string])) {
        Add-Failure 'Capability threshold_policies must be an array.'
        return
    }
    $ids = @()
    $targets = @()
    foreach ($policy in @($Policies)) {
        $fields = @(
            'id',
            'classification',
            'status',
            'owner',
            'basis',
            'evidence_refs',
            'reviewed_on',
            'review_by',
            'targets'
        )
        if (-not (Assert-ObjectShape $policy $fields $fields 'Capability threshold policy')) {
            continue
        }
        $ids += [string] $policy.id
        if (@('derived', 'safety_policy', 'empirical', 'implementation_limit') -notcontains [string] $policy.classification) {
            Add-Failure "Threshold policy '$($policy.id)' has invalid classification."
        }
        if (@('candidate', 'accepted') -notcontains [string] $policy.status) {
            Add-Failure "Threshold policy '$($policy.id)' has invalid status."
        }
        foreach ($propertyName in @('owner', 'basis')) {
            if (-not (Test-NonblankString $policy.$propertyName)) {
                Add-Failure "Threshold policy '$($policy.id)' $propertyName must be nonblank."
            }
        }
        if ($policy.evidence_refs -isnot [System.Array]) {
            Add-Failure "Threshold policy '$($policy.id)' evidence_refs must be an array."
        }
        elseif (([string] $policy.classification -eq 'empirical') -and (@($policy.evidence_refs).Count -eq 0)) {
            Add-Failure "Empirical threshold policy '$($policy.id)' requires evidence_refs."
        }
        foreach ($dateProperty in @('reviewed_on', 'review_by')) {
            $parsedDate = [datetime]::MinValue
            if (($policy.$dateProperty -isnot [string]) -or
                (-not [datetime]::TryParseExact(
                    [string] $policy.$dateProperty,
                    'yyyy-MM-dd',
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::None,
                    [ref] $parsedDate
                ))) {
                Add-Failure "Threshold policy '$($policy.id)' $dateProperty must be YYYY-MM-DD."
            }
            elseif (($dateProperty -eq 'review_by') -and ($parsedDate.Date -lt [datetime]::UtcNow.Date)) {
                Add-Failure "Threshold policy '$($policy.id)' review_by is expired."
            }
        }
        if (($policy.targets -isnot [System.Array]) -or (@($policy.targets).Count -eq 0)) {
            Add-Failure "Threshold policy '$($policy.id)' targets must be a nonempty array."
        }
        else {
            foreach ($target in @($policy.targets)) {
                if (-not (Test-NonblankString $target)) {
                    Add-Failure "Threshold policy '$($policy.id)' contains a blank or non-string target."
                    continue
                }
                $targets += [string] $target
            }
        }
    }
    Assert-UniqueStrings $ids 'Capability threshold policies'
    Assert-UniqueStrings $targets 'Capability threshold targets'
    foreach ($target in @($targets | Sort-Object -Unique)) {
        if ($canonicalCapabilityThresholdTargets -notcontains $target) {
            Add-Failure "Capability threshold target is unknown or non-leaf: $target"
        }
    }
    foreach ($target in $canonicalCapabilityThresholdTargets) {
        $ownerCount = @($targets | Where-Object { $_ -eq $target }).Count
        if ($ownerCount -ne 1) {
            Add-Failure "Capability threshold target '$target' must have exactly one owner; found $ownerCount."
        }
    }
    $uniqueTargets = @($targets | Sort-Object -Unique)
    for ($leftIndex = 0; $leftIndex -lt $uniqueTargets.Count; $leftIndex++) {
        for ($rightIndex = $leftIndex + 1; $rightIndex -lt $uniqueTargets.Count; $rightIndex++) {
            $left = [string] $uniqueTargets[$leftIndex]
            $right = [string] $uniqueTargets[$rightIndex]
            if ($left.StartsWith($right + '.', [System.StringComparison]::Ordinal) -or
                $right.StartsWith($left + '.', [System.StringComparison]::Ordinal)) {
                Add-Failure "Capability threshold targets overlap at parent/child paths: '$left' and '$right'."
            }
        }
    }
}

$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$manifest = Read-JsonObject $manifestPath 'Governance manifest'
if ($null -eq $manifest) {
    Write-Host "Capability evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "- $failure" -ForegroundColor Red }
    exit 1
}

if (($manifest.PSObject.Properties.Name -notcontains 'capability_evaluations') -or
    ($manifest.capability_evaluations -isnot [pscustomobject])) {
    Add-Failure 'Governance manifest capability_evaluations must be an object.'
}
if (($manifest.PSObject.Properties.Name -notcontains 'routing_signals') -or
    ($manifest.routing_signals -isnot [pscustomobject])) {
    Add-Failure 'Governance manifest routing_signals must be an object.'
}
if (($manifest.PSObject.Properties.Name -notcontains 'skills') -or
    ($manifest.skills -isnot [System.Array])) {
    Add-Failure 'Governance manifest skills must be an array.'
}
if ($failures.Count -gt 0) {
    Write-Host "Capability evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "- $failure" -ForegroundColor Red }
    exit 1
}

$catalogRelative = [string] $manifest.capability_evaluations.catalog
$templateRelative = [string] $manifest.capability_evaluations.run_template
$catalogPath = Join-Path $rootPath ($catalogRelative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$templatePath = Join-Path $rootPath ($templateRelative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Read-JsonObject $catalogPath 'Capability catalog'
$runTemplate = Read-JsonObject $templatePath 'Capability run template'
if (($null -eq $catalog) -or ($null -eq $runTemplate)) {
    Write-Host "Capability evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "- $failure" -ForegroundColor Red }
    exit 1
}

$catalogFields = @(
    '$schema',
    'schema_version',
    'threshold_policies',
    'coverage_requirements',
    'rubric',
    'skill_coverage',
    'cases'
)
[void](Assert-ObjectShape $catalog $catalogFields $catalogFields 'Capability catalog')
if (($catalog.PSObject.Properties.Name -contains '$schema') -and
    ([string] $catalog.'$schema' -ne '../schemas/capability-evaluations.schema.json')) {
    Add-Failure "Capability catalog `$schema must be '../schemas/capability-evaluations.schema.json'."
}
if (($catalog.PSObject.Properties.Name -contains 'schema_version') -and
    ((-not (Test-JsonInteger $catalog.schema_version)) -or (([int] $catalog.schema_version) -ne 3))) {
    Add-Failure 'Capability catalog schema_version must be integer 3.'
}
Assert-ThresholdPolicies $catalog.threshold_policies
$coverageFields = @(
    'maximum_cases',
    'minimum_categories',
    'minimum_cases_by_risk',
    'minimum_low_risk_ratio',
    'minimum_criteria_per_case'
)
$coverageUsable = Assert-ObjectShape $catalog.coverage_requirements $coverageFields $coverageFields 'Capability coverage_requirements'
if ($coverageUsable) {
    [void](Assert-ObjectShape $catalog.coverage_requirements.minimum_cases_by_risk @(
        'trivial',
        'standard',
        'structural',
        'critical'
    ) @('trivial', 'standard', 'structural', 'critical') 'Capability minimum_cases_by_risk')
    [void](Assert-ObjectShape $catalog.coverage_requirements.minimum_low_risk_ratio @(
        'numerator',
        'denominator'
    ) @('numerator', 'denominator') 'Capability minimum_low_risk_ratio')
    [void](Assert-ObjectShape $catalog.coverage_requirements.minimum_criteria_per_case @(
        'must_demonstrate',
        'must_avoid',
        'required_evidence'
    ) @('must_demonstrate', 'must_avoid', 'required_evidence') 'Capability minimum_criteria_per_case')
}
if (($catalog.PSObject.Properties.Name -contains 'skill_coverage') -and
    ($catalog.skill_coverage -isnot [System.Array])) {
    Add-Failure 'Capability catalog skill_coverage must be an array.'
}
if (($catalog.PSObject.Properties.Name -contains 'cases') -and
    ($catalog.cases -isnot [System.Array])) {
    Add-Failure 'Capability catalog cases must be an array.'
}

$risks = @($manifest.risk_order | ForEach-Object { [string] $_ })
$expectedRisks = @('trivial', 'standard', 'structural', 'critical')
if (($risks.Count -ne $expectedRisks.Count) -or
    (@(Compare-Object -ReferenceObject $expectedRisks -DifferenceObject $risks -SyncWindow 0).Count -gt 0)) {
    Add-Failure "Manifest risk_order must be exactly: $($expectedRisks -join ', ')."
}

$rubricFields = @('dimensions', 'pass_score', 'critical_pass_score', 'automatic_failure_reasons')
$rubricUsable = $false
if (($catalog.PSObject.Properties.Name -contains 'rubric') -and
    (Assert-ObjectShape $catalog.rubric $rubricFields $rubricFields 'Capability rubric')) {
    $rubricUsable = $true
}

$dimensionNames = @()
$dimensionWeightTotal = 0.0
if ($rubricUsable) {
    if ($catalog.rubric.dimensions -isnot [System.Array]) {
        Add-Failure 'Capability rubric dimensions must be an array.'
    }
    else {
        $dimensionIndex = 0
        foreach ($dimension in @($catalog.rubric.dimensions)) {
            $dimensionIndex++
            $context = "Rubric dimension #$dimensionIndex"
            $fields = @('name', 'weight', 'question', 'minimum_scores')
            if (-not (Assert-ObjectShape $dimension $fields $fields $context)) { continue }

            $name = [string] $dimension.name
            if ((-not (Test-NonblankString $dimension.name)) -or
                ($name -notmatch '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')) {
                Add-Failure "$context name must use snake_case."
            }
            else {
                $dimensionNames += $name
            }
            if ((-not (Test-JsonNumber $dimension.weight)) -or
                (([double] $dimension.weight) -le 0) -or
                (([double] $dimension.weight) -gt 100)) {
                Add-Failure "$context weight must be a number greater than 0 and no greater than 100."
            }
            else {
                $dimensionWeightTotal += [double] $dimension.weight
            }
            if ((-not (Test-NonblankString $dimension.question)) -or
                ([string] $dimension.question).Length -lt 20) {
                Add-Failure "$context question must be a concrete string of at least 20 characters."
            }
            if ($dimension.minimum_scores -isnot [pscustomobject]) {
                Add-Failure "$context minimum_scores must be an object."
            }
            else {
                [void](Assert-ObjectShape $dimension.minimum_scores $risks $risks "$context minimum_scores")
                foreach ($risk in $risks) {
                    if ($dimension.minimum_scores.PSObject.Properties.Name -contains $risk) {
                        $minimum = $dimension.minimum_scores.$risk
                        if ((-not (Test-JsonNumber $minimum)) -or
                            (([double] $minimum) -lt 0) -or
                            (([double] $minimum) -gt 100)) {
                            Add-Failure "$context minimum score '$risk' must be a number from 0 to 100."
                        }
                    }
                }
            }
        }
    }
    Assert-UniqueStrings $dimensionNames 'Rubric dimensions'
    if ([math]::Abs($dimensionWeightTotal - 100.0) -gt 0.000001) {
        Add-Failure "Rubric weights must total 100, found $dimensionWeightTotal."
    }

    if ((-not (Test-JsonNumber $catalog.rubric.pass_score)) -or
        (([double] $catalog.rubric.pass_score) -lt 1) -or
        (([double] $catalog.rubric.pass_score) -gt 100)) {
        Add-Failure 'Rubric pass_score must be a number from 1 to 100.'
    }
    if ((-not (Test-JsonNumber $catalog.rubric.critical_pass_score)) -or
        (([double] $catalog.rubric.critical_pass_score) -lt 1) -or
        (([double] $catalog.rubric.critical_pass_score) -gt 100)) {
        Add-Failure 'Rubric critical_pass_score must be a number from 1 to 100.'
    }
    elseif ((Test-JsonNumber $catalog.rubric.pass_score) -and
        (([double] $catalog.rubric.critical_pass_score) -lt ([double] $catalog.rubric.pass_score))) {
        Add-Failure 'Rubric critical_pass_score cannot be below pass_score.'
    }
}

$automaticReasonIds = @()
if ($rubricUsable) {
    if ($catalog.rubric.automatic_failure_reasons -isnot [System.Array]) {
        Add-Failure 'Capability rubric automatic_failure_reasons must be an array.'
    }
    else {
        $reasonIndex = 0
        foreach ($reason in @($catalog.rubric.automatic_failure_reasons)) {
            $reasonIndex++
            $context = "Automatic failure reason #$reasonIndex"
            $fields = @('id', 'description')
            if (-not (Assert-ObjectShape $reason $fields $fields $context)) { continue }
            $id = [string] $reason.id
            if ((-not (Test-NonblankString $reason.id)) -or
                ($id -notmatch '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')) {
                Add-Failure "$context id must use snake_case."
            }
            else {
                $automaticReasonIds += $id
            }
            if ((-not (Test-NonblankString $reason.description)) -or
                ([string] $reason.description).Length -lt 20) {
                Add-Failure "$context description must be at least 20 characters."
            }
        }
    }
}
Assert-UniqueStrings $automaticReasonIds 'Automatic failure reasons'
$requiredAutomaticReasons = @(
    'fabricated_evidence',
    'unauthorized_action',
    'critical_boundary_missed',
    'unsupported_release_claim',
    'unsafe_durable_shortcut'
)
foreach ($reasonId in $requiredAutomaticReasons) {
    if ($automaticReasonIds -notcontains $reasonId) {
        Add-Failure "Capability rubric is missing required automatic failure reason '$reasonId'."
    }
}

$skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })
Assert-UniqueStrings $skillNames 'Manifest skills'
$leadSkillNames = @(
    $manifest.routing_signals.PSObject.Properties |
        ForEach-Object { $_.Value } |
        Where-Object { $null -ne $_.lead_skill } |
        ForEach-Object { [string] $_.lead_skill } |
        Sort-Object -Unique
)
$supportSkillNames = @(
    $manifest.routing_signals.PSObject.Properties |
        ForEach-Object { $_.Value } |
        ForEach-Object { @($_.supporting_skills) } |
        ForEach-Object { [string] $_ } |
        Sort-Object -Unique
)

$coverageBySkill = @{}
$coverageEntries = if ($catalog.skill_coverage -is [System.Array]) { @($catalog.skill_coverage) } else { @() }
$coverageIndex = 0
foreach ($coverage in $coverageEntries) {
    $coverageIndex++
    $context = "Skill coverage #$coverageIndex"
    $fields = @('skill', 'role', 'minimum_cases', 'reason')
    if (-not (Assert-ObjectShape $coverage $fields $fields $context)) { continue }
    $skill = [string] $coverage.skill
    if (-not (Test-NonblankString $coverage.skill)) {
        Add-Failure "$context skill cannot be blank."
        continue
    }
    if ($coverageBySkill.ContainsKey($skill)) {
        Add-Failure "Skill coverage contains duplicate '$skill'."
    }
    else {
        $coverageBySkill[$skill] = $coverage
    }
    if ($skillNames -notcontains $skill) {
        Add-Failure "$context references unknown skill '$skill'."
    }
    if (@('primary', 'support_only') -notcontains [string] $coverage.role) {
        Add-Failure "$context role must be primary or support_only."
    }
    if ((-not (Test-JsonInteger $coverage.minimum_cases)) -or (([int] $coverage.minimum_cases) -lt 0)) {
        Add-Failure "$context minimum_cases must be a nonnegative integer."
    }
    if (-not (Test-NonblankString $coverage.reason)) {
        Add-Failure "$context reason cannot be blank."
    }
}
foreach ($skillName in $skillNames) {
    if (-not $coverageBySkill.ContainsKey($skillName)) {
        Add-Failure "Skill coverage is missing manifest skill '$skillName'."
    }
}
if ($coverageBySkill.Count -ne $skillNames.Count) {
    Add-Failure "Skill coverage must contain exactly one entry for each manifest skill ($($skillNames.Count)); found $($coverageBySkill.Count)."
}

$cases = if ($catalog.cases -is [System.Array]) { @($catalog.cases) } else { @() }
$minimumCases = [int] $manifest.capability_evaluations.minimum_cases
$maximumCases = [int] $catalog.coverage_requirements.maximum_cases
if (($cases.Count -lt $minimumCases) -or ($cases.Count -gt $maximumCases)) {
    Add-Failure "Capability catalog must contain $minimumCases-$maximumCases cases; found $($cases.Count)."
}

$caseIds = @()
$categoryNames = @()
$caseCountsByRisk = @{}
foreach ($risk in $risks) { $caseCountsByRisk[$risk] = 0 }
$caseCountsBySkill = @{}
foreach ($skillName in $skillNames) { $caseCountsBySkill[$skillName] = 0 }

$caseIndex = 0
foreach ($case in $cases) {
    $caseIndex++
    $context = "Capability case #$caseIndex"
    $fields = @(
        'id',
        'category',
        'risk',
        'primary_skill',
        'prompt',
        'must_demonstrate',
        'must_avoid',
        'required_evidence'
    )
    if (-not (Assert-ObjectShape $case $fields $fields $context)) { continue }

    $caseId = [string] $case.id
    if ((-not (Test-NonblankString $case.id)) -or
        ($caseId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$')) {
        Add-Failure "$context id must use kebab-case."
        $caseId = "<case-$caseIndex>"
    }
    else {
        $caseIds += $caseId
    }
    $context = "Capability case '$caseId'"

    $category = [string] $case.category
    if ((-not (Test-NonblankString $case.category)) -or
        ($category -notmatch '^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')) {
        Add-Failure "$context category must use kebab-case."
    }
    else {
        $categoryNames += $category
    }

    $risk = [string] $case.risk
    if ($risks -notcontains $risk) {
        Add-Failure "$context has unknown risk '$risk'."
    }
    else {
        $caseCountsByRisk[$risk] = [int] $caseCountsByRisk[$risk] + 1
    }

    $primarySkill = [string] $case.primary_skill
    if ($leadSkillNames -notcontains $primarySkill) {
        Add-Failure "$context primary_skill '$primarySkill' is not a routable lead skill."
    }
    if ($caseCountsBySkill.ContainsKey($primarySkill)) {
        $caseCountsBySkill[$primarySkill] = [int] $caseCountsBySkill[$primarySkill] + 1
    }

    if ((-not (Test-NonblankString $case.prompt)) -or ([string] $case.prompt).Length -lt 40) {
        Add-Failure "$context prompt must be a concrete string of at least 40 characters."
    }

    $criterionIds = @()
    foreach ($criterionGroup in @(
        [pscustomobject]@{ Name = 'must_demonstrate'; Minimum = [int] $catalog.coverage_requirements.minimum_criteria_per_case.must_demonstrate },
        [pscustomobject]@{ Name = 'must_avoid'; Minimum = [int] $catalog.coverage_requirements.minimum_criteria_per_case.must_avoid },
        [pscustomobject]@{ Name = 'required_evidence'; Minimum = [int] $catalog.coverage_requirements.minimum_criteria_per_case.required_evidence }
    )) {
        $groupName = [string] $criterionGroup.Name
        $groupValue = $case.$groupName
        if ($groupValue -isnot [System.Array]) {
            Add-Failure "$context $groupName must be an array."
            continue
        }
        $criteria = @($groupValue)
        if ($criteria.Count -lt [int] $criterionGroup.Minimum) {
            Add-Failure "$context $groupName needs at least $($criterionGroup.Minimum) criterion/criteria."
        }
        $criterionIndex = 0
        foreach ($criterion in $criteria) {
            $criterionIndex++
            $criterionContext = "$context $groupName criterion #$criterionIndex"
            $criterionFields = @('id', 'description')
            if (-not (Assert-ObjectShape $criterion $criterionFields $criterionFields $criterionContext)) { continue }
            $criterionId = [string] $criterion.id
            if ((-not (Test-NonblankString $criterion.id)) -or
                ($criterionId -notmatch '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')) {
                Add-Failure "$criterionContext id must use snake_case."
            }
            else {
                $criterionIds += $criterionId
            }
            if (-not (Test-NonblankString $criterion.description)) {
                Add-Failure "$criterionContext description cannot be blank."
            }
        }
    }
    foreach ($duplicate in @($criterionIds | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$context reuses criterion id '$($duplicate.Name)' across criterion groups."
    }
}

Assert-UniqueStrings $caseIds 'Capability cases'
$categories = @($categoryNames | Sort-Object -Unique)
if ($categories.Count -lt [int] $catalog.coverage_requirements.minimum_categories) {
    Add-Failure "Capability catalog needs at least $($catalog.coverage_requirements.minimum_categories) categories; found $($categories.Count)."
}

foreach ($risk in $risks) {
    $riskFloor = [int] $catalog.coverage_requirements.minimum_cases_by_risk.$risk
    if (([int] $caseCountsByRisk[$risk]) -lt $riskFloor) {
        Add-Failure "Capability catalog needs at least $riskFloor '$risk' cases; found $($caseCountsByRisk[$risk])."
    }
}
$lowRiskCount = [int] $caseCountsByRisk.trivial + [int] $caseCountsByRisk.standard
$ratioNumerator = [double] $catalog.coverage_requirements.minimum_low_risk_ratio.numerator
$ratioDenominator = [double] $catalog.coverage_requirements.minimum_low_risk_ratio.denominator
$minimumLowRiskCount = [int] [math]::Ceiling($cases.Count * $ratioNumerator / $ratioDenominator)
if ($lowRiskCount -lt $minimumLowRiskCount) {
    Add-Failure "Trivial plus standard cases do not meet the catalog ratio floor ($minimumLowRiskCount); found $lowRiskCount."
}

$requiredCaseIds = @(
    'implementation-plan-only',
    'review-must-remain-read-only',
    'readiness-local-only-evidence',
    'debugging-labeled-fabrication',
    'bounded-task-policy-refusal',
    'docs-punctuation-only',
    'docs-local-link-fix',
    'docs-code-fence-language',
    'docs-static-heading',
    'docs-whitespace-format',
    'docs-comment-typo'
)
foreach ($requiredCaseId in $requiredCaseIds) {
    if ($caseIds -notcontains $requiredCaseId) {
        Add-Failure "Capability catalog is missing required anti-bypass or anti-ceremony case '$requiredCaseId'."
    }
}

$minimumPerLead = [int] $manifest.capability_evaluations.minimum_cases_per_routable_skill
foreach ($skillName in $skillNames) {
    if (-not $coverageBySkill.ContainsKey($skillName)) { continue }
    $coverage = $coverageBySkill[$skillName]
    $actualCount = [int] $caseCountsBySkill[$skillName]
    if ($leadSkillNames -contains $skillName) {
        if ([string] $coverage.role -ne 'primary') {
            Add-Failure "Routable lead skill '$skillName' must have coverage role primary."
        }
        if ((Test-JsonInteger $coverage.minimum_cases) -and
            (([int] $coverage.minimum_cases) -lt $minimumPerLead)) {
            Add-Failure "Routable lead skill '$skillName' minimum_cases must be at least $minimumPerLead."
        }
        if ((Test-JsonInteger $coverage.minimum_cases) -and
            ($actualCount -lt [int] $coverage.minimum_cases)) {
            Add-Failure "Routable lead skill '$skillName' declares $($coverage.minimum_cases) cases but has $actualCount."
        }
        if ($actualCount -lt $minimumPerLead) {
            Add-Failure "Routable lead skill '$skillName' needs at least $minimumPerLead primary cases; found $actualCount."
        }
    }
    else {
        if ([string] $coverage.role -ne 'support_only') {
            Add-Failure "Non-lead skill '$skillName' must have coverage role support_only."
        }
        if ((Test-JsonInteger $coverage.minimum_cases) -and (([int] $coverage.minimum_cases) -ne 0)) {
            Add-Failure "Support-only skill '$skillName' minimum_cases must be 0."
        }
        if ($actualCount -ne 0) {
            Add-Failure "Support-only skill '$skillName' cannot be a case primary_skill; found $actualCount case(s)."
        }
        if ($supportSkillNames -notcontains $skillName) {
            Add-Failure "Non-lead skill '$skillName' is neither a manifest supporting skill nor a routable lead."
        }
    }
}

$templateFields = @(
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
$templateUsable = Assert-ObjectShape $runTemplate $templateFields $templateFields 'Capability run template'
if ($templateUsable) {
    if ([string] $runTemplate.'$schema' -ne '../schemas/capability-evaluation-run.schema.json') {
        Add-Failure "Capability run template `$schema must be '../schemas/capability-evaluation-run.schema.json'."
    }
    if ((-not (Test-JsonInteger $runTemplate.schema_version)) -or (([int] $runTemplate.schema_version) -ne 2)) {
        Add-Failure 'Capability run template schema_version must be integer 2.'
    }
    foreach ($objectSpec in @(
        [pscustomobject]@{
            Name = 'model'
            Fields = @('provider', 'name', 'version', 'agent_surface')
        },
        [pscustomobject]@{
            Name = 'runner'
            Fields = @('id', 'type', 'organization')
        },
        [pscustomobject]@{
            Name = 'reviewer'
            Fields = @('id', 'type', 'organization')
        }
    )) {
        [void](Assert-ObjectShape $runTemplate.($objectSpec.Name) $objectSpec.Fields $objectSpec.Fields "Capability run template $($objectSpec.Name)")
    }
    $executionFields = @('repository', 'revision', 'started_at', 'duration_seconds', 'token_measure')
    if (Assert-ObjectShape $runTemplate.execution $executionFields $executionFields 'Capability run template execution') {
        $tokenFields = @('unit', 'value')
        [void](Assert-ObjectShape $runTemplate.execution.token_measure $tokenFields $tokenFields 'Capability run template token_measure')
    }
    if ($runTemplate.artifacts -isnot [System.Array]) {
        Add-Failure 'Capability run template artifacts must be an array.'
    }
    elseif (@($runTemplate.artifacts).Count -lt 1) {
        Add-Failure 'Capability run template artifacts cannot be empty.'
    }
    else {
        $artifactFields = @('id', 'path', 'sha256', 'media_type', 'description')
        foreach ($artifact in @($runTemplate.artifacts)) {
            [void](Assert-ObjectShape $artifact $artifactFields $artifactFields 'Capability run template artifact')
        }
    }
    if ($runTemplate.dimension_scores -isnot [pscustomobject]) {
        Add-Failure 'Capability run template dimension_scores must be an object.'
    }
    else {
        [void](Assert-ObjectShape $runTemplate.dimension_scores $dimensionNames $dimensionNames 'Capability run template dimension_scores')
    }
    if ($runTemplate.criterion_results -isnot [System.Array]) {
        Add-Failure 'Capability run template criterion_results must be an array.'
    }
    else {
        $criterionResultFields = @('criterion_id', 'status', 'evidence_artifact_ids', 'review_notes')
        foreach ($criterionResult in @($runTemplate.criterion_results)) {
            if (Assert-ObjectShape $criterionResult $criterionResultFields $criterionResultFields 'Capability run template criterion result') {
                if (@('satisfied', 'violated', 'unverified') -notcontains [string] $criterionResult.status) {
                    Add-Failure 'Capability run template criterion result status must be satisfied, violated, or unverified.'
                }
            }
        }
    }
    if ($runTemplate.automatic_failure_reason_ids -isnot [System.Array]) {
        Add-Failure 'Capability run template automatic_failure_reason_ids must be an array.'
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Capability evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

$summary = (
    "Capability evaluation validation PASS: {0} cases; risks={1}; categories={2}; " +
    "lead coverage={3}; dimensions={4}; weights={5}."
) -f @(
    $cases.Count,
    (($risks | ForEach-Object { "$_=$($caseCountsByRisk[$_])" }) -join ','),
    $categories.Count,
    $leadSkillNames.Count,
    $dimensionNames.Count,
    $dimensionWeightTotal
)
Write-Host $summary -ForegroundColor Green
exit 0

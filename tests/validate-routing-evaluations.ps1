[CmdletBinding()]
param(
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = Split-Path -Parent $scriptDirectory
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)

    $failures.Add($Message)
}

function Read-Json {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure "$Label does not exist: $Path"
        return $null
    }
    try {
        return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    }
    catch {
        Add-Failure "$Label is not valid JSON: $($_.Exception.Message)"
        return $null
    }
}

function Assert-ObjectShape {
    param(
        [AllowNull()] [object] $Object,
        [string[]] $Required,
        [string[]] $Optional,
        [string] $Label
    )

    if (($null -eq $Object) -or ($Object -isnot [pscustomobject])) {
        Add-Failure "$Label must be an object."
        return $false
    }
    $properties = @($Object.PSObject.Properties.Name)
    foreach ($property in $Required) {
        if ($properties -notcontains $property) {
            Add-Failure "$Label is missing property: $property"
        }
    }
    foreach ($property in $properties) {
        if (($Required -notcontains $property) -and ($Optional -notcontains $property)) {
            Add-Failure "$Label contains unknown property: $property"
        }
    }
    return @($Required | Where-Object { $properties -notcontains $_ }).Count -eq 0
}

function Get-StringArray {
    param(
        [AllowNull()] [object] $Value,
        [string] $Label,
        [switch] $AllowEmpty
    )

    if (($null -eq $Value) -or ($Value -is [string]) -or ($Value -isnot [System.Array])) {
        Add-Failure "$Label must be an array of strings."
        return @()
    }
    $values = @()
    foreach ($item in @($Value)) {
        if (($item -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $item)) {
            Add-Failure "$Label contains a blank or non-string value."
            continue
        }
        $values += [string] $item
    }
    if ((-not $AllowEmpty) -and ($values.Count -eq 0)) {
        Add-Failure "$Label cannot be empty."
    }
    foreach ($duplicate in @($values | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$Label contains duplicate value: $($duplicate.Name)"
    }
    return $values
}

function Test-Number {
    param([AllowNull()] [object] $Value)

    $isNumeric = ($Value -is [byte]) -or
        ($Value -is [sbyte]) -or
        ($Value -is [int16]) -or
        ($Value -is [uint16]) -or
        ($Value -is [int32]) -or
        ($Value -is [uint32]) -or
        ($Value -is [int64]) -or
        ($Value -is [uint64]) -or
        ($Value -is [single]) -or
        ($Value -is [double]) -or
        ($Value -is [decimal])
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

function Assert-SameSet {
    param(
        [string[]] $Expected,
        [string[]] $Actual,
        [string] $Label
    )

    $difference = @(Compare-Object -ReferenceObject @($Expected | Sort-Object -Unique) -DifferenceObject @($Actual | Sort-Object -Unique))
    if ($difference.Count -gt 0) {
        Add-Failure "$Label expected [$($Expected -join ', ')] but found [$($Actual -join ', ')]."
        return $false
    }
    return $true
}

$canonicalRoutingThresholdTargets = @(
    'scoring.pass_score',
    'scoring.penalties.wrong_mode',
    'scoring.penalties.missing_signal',
    'scoring.penalties.unnecessary_signal',
    'scoring.penalties.risk_underroute_per_level',
    'scoring.penalties.risk_overroute_per_level',
    'scoring.penalties.confirmation_underroute_per_level',
    'scoring.penalties.confirmation_overroute_per_level',
    'scoring.penalties.wrong_lead_skill',
    'scoring.penalties.missing_supporting_skill',
    'scoring.penalties.unnecessary_supporting_skill',
    'scoring.penalties.critical_underroute',
    'manifest.routing_evaluations.minimum_cases',
    'coverage_requirements.maximum_cases',
    'coverage_requirements.minimum_cases_per_signal',
    'coverage_requirements.minimum_cases_per_mode',
    'coverage_requirements.minimum_minimal_route_cases'
)

function Assert-ThresholdPolicies {
    param(
        [AllowNull()] [object] $Policies,
        [string] $Label
    )

    if (($null -eq $Policies) -or ($Policies -is [string]) -or ($Policies -isnot [System.Array])) {
        Add-Failure "$Label must be an array."
        return
    }
    $ids = @()
    $targets = @()
    $policiesByTarget = @{}
    foreach ($policy in @($Policies)) {
        if (-not (Assert-ObjectShape $policy @(
            'id',
            'classification',
            'status',
            'owner',
            'basis',
            'evidence_refs',
            'reviewed_on',
            'review_by',
            'targets'
        ) @() "$Label policy")) {
            continue
        }
        $ids += [string] $policy.id
        if (@('derived', 'safety_policy', 'empirical', 'implementation_limit') -notcontains [string] $policy.classification) {
            Add-Failure "$Label policy '$($policy.id)' has invalid classification."
        }
        if (@('candidate', 'accepted') -notcontains [string] $policy.status) {
            Add-Failure "$Label policy '$($policy.id)' has invalid status."
        }
        foreach ($propertyName in @('owner', 'basis')) {
            if (($policy.$propertyName -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $policy.$propertyName)) {
                Add-Failure "$Label policy '$($policy.id)' $propertyName must be nonblank."
            }
        }
        $evidenceRefs = @(Get-StringArray $policy.evidence_refs "$Label policy '$($policy.id)' evidence_refs" -AllowEmpty)
        if (([string] $policy.classification -eq 'empirical') -and ($evidenceRefs.Count -eq 0)) {
            Add-Failure "$Label empirical policy '$($policy.id)' requires evidence_refs."
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
                Add-Failure "$Label policy '$($policy.id)' $dateProperty must be YYYY-MM-DD."
            }
            elseif (($dateProperty -eq 'review_by') -and ($parsedDate.Date -lt [datetime]::UtcNow.Date)) {
                Add-Failure "$Label policy '$($policy.id)' review_by is expired."
            }
        }
        foreach ($target in @(Get-StringArray $policy.targets "$Label policy '$($policy.id)' targets")) {
            $targets += $target
            if (-not $policiesByTarget.ContainsKey($target)) {
                $policiesByTarget[$target] = @()
            }
            $policiesByTarget[$target] += $policy
        }
    }
    foreach ($duplicate in @($ids | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$Label contains duplicate policy id: $($duplicate.Name)"
    }
    foreach ($duplicate in @($targets | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$Label target has multiple owners: $($duplicate.Name)"
    }
    foreach ($target in @($targets | Sort-Object -Unique)) {
        if ($canonicalRoutingThresholdTargets -notcontains $target) {
            Add-Failure "$Label target is unknown or non-leaf: $target"
        }
    }
    foreach ($target in $canonicalRoutingThresholdTargets) {
        $ownerCount = @($targets | Where-Object { $_ -eq $target }).Count
        if ($ownerCount -ne 1) {
            Add-Failure "$Label target '$target' must have exactly one owner; found $ownerCount."
        }
    }
    $uniqueTargets = @($targets | Sort-Object -Unique)
    for ($leftIndex = 0; $leftIndex -lt $uniqueTargets.Count; $leftIndex++) {
        for ($rightIndex = $leftIndex + 1; $rightIndex -lt $uniqueTargets.Count; $rightIndex++) {
            $left = [string] $uniqueTargets[$leftIndex]
            $right = [string] $uniqueTargets[$rightIndex]
            if ($left.StartsWith($right + '.', [System.StringComparison]::Ordinal) -or
                $right.StartsWith($left + '.', [System.StringComparison]::Ordinal)) {
                Add-Failure "$Label targets overlap at parent/child paths: '$left' and '$right'."
            }
        }
    }
    $criticalTarget = 'scoring.penalties.critical_underroute'
    if ($policiesByTarget.ContainsKey($criticalTarget)) {
        $criticalOwners = @($policiesByTarget[$criticalTarget])
        if (($criticalOwners.Count -ne 1) -or
            ([string] $criticalOwners[0].classification -ne 'derived')) {
            Add-Failure "$Label target '$criticalTarget' must be owned only by one derived policy."
        }
    }
}

function Get-ComposedRoute {
    param(
        [object] $Manifest,
        [string[]] $Signals,
        [hashtable] $RiskRank,
        [hashtable] $ConfirmationRank
    )

    $risk = 0
    $confirmation = 0
    $lead = $null
    $supports = @()
    foreach ($signalName in $Signals) {
        $signal = $Manifest.routing_signals.$signalName
        $risk = [math]::Max($risk, $RiskRank[[string] $signal.minimum_risk])
        $confirmation = [math]::Max($confirmation, $ConfirmationRank[[string] $signal.confirmation])
        if ($null -ne $signal.lead_skill) {
            $candidate = [string] $signal.lead_skill
            if ($null -eq $lead) {
                $lead = $candidate
            }
            elseif ($candidate -ne $lead) {
                $supports += $candidate
            }
        }
        $supports += @($signal.supporting_skills | ForEach-Object { [string] $_ })
    }
    foreach ($overlay in @($Manifest.risk_overlays)) {
        if ($risk -ge $RiskRank[[string] $overlay.minimum_risk]) {
            $supports += @($overlay.supporting_skills | ForEach-Object { [string] $_ })
        }
    }
    return [pscustomobject]@{
        Risk = [string] $Manifest.risk_order[$risk]
        Confirmation = [string] $Manifest.confirmation_order[$confirmation]
        Lead = $lead
        Supports = @($supports | Where-Object { $_ -ne $lead } | Sort-Object -Unique)
    }
}

$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$manifest = Read-Json $manifestPath 'Governance manifest'
if ($null -eq $manifest) {
    Write-Host "Routing evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}
foreach ($property in @('schema_version', 'pack_version', 'risk_order', 'confirmation_order', 'task_modes', 'routing_signals', 'risk_overlays', 'routing_evaluations', 'schemas')) {
    if ($manifest.PSObject.Properties.Name -notcontains $property) {
        Add-Failure "Governance manifest is missing routing evaluation property: $property"
    }
}
if ($failures.Count -gt 0) {
    Write-Host "Routing evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}
if ([int] $manifest.schema_version -ne 3) {
    Add-Failure 'Routing evaluations require manifest schema_version 3.'
}

$catalogPath = Join-Path $rootPath (([string] $manifest.routing_evaluations.catalog) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$templatePath = Join-Path $rootPath (([string] $manifest.routing_evaluations.run_template) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$scenarioPath = Join-Path $rootPath (([string] $manifest.routing_evaluations.scenario_catalog) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Read-Json $catalogPath 'Routing evaluation catalog'
$template = Read-Json $templatePath 'Routing evaluation run template'
$scenarioDocument = Read-Json $scenarioPath 'Governance scenario catalog'
if (($null -eq $catalog) -or ($null -eq $template) -or ($null -eq $scenarioDocument)) {
    Write-Host "Routing evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

if (Assert-ObjectShape $catalog @(
    '$schema',
    'schema_version',
    'oracle',
    'threshold_policies',
    'coverage_requirements',
    'scoring',
    'cases'
) @() 'Routing evaluation catalog') {
    if ([string] $catalog.'$schema' -ne '../schemas/routing-evaluations.schema.json') {
        Add-Failure "Routing evaluation catalog `$schema must be '../schemas/routing-evaluations.schema.json'."
    }
    if ((($catalog.schema_version -isnot [int]) -and ($catalog.schema_version -isnot [long])) -or ([int] $catalog.schema_version -ne 2)) {
        Add-Failure 'Routing evaluation catalog schema_version must be integer 2.'
    }
}
if (Assert-ObjectShape $catalog.oracle @('kind', 'owner', 'basis', 'reviewed_on', 'pack_version') @() 'Routing semantic oracle') {
    if ([string] $catalog.oracle.kind -ne 'human_semantic') {
        Add-Failure "Routing semantic oracle kind must be 'human_semantic'."
    }
    if ([string] $catalog.oracle.pack_version -ne [string] $manifest.pack_version) {
        Add-Failure 'Routing semantic oracle pack_version must match the manifest.'
    }
}
Assert-ThresholdPolicies $catalog.threshold_policies 'Routing threshold_policies'
if (-not (Assert-ObjectShape $catalog.coverage_requirements @(
    'maximum_cases',
    'minimum_cases_per_signal',
    'minimum_cases_per_mode',
    'minimum_minimal_route_cases'
) @() 'Routing coverage_requirements')) {
    $catalog.coverage_requirements = [pscustomobject]@{
        maximum_cases = 0
        minimum_cases_per_signal = 0
        minimum_cases_per_mode = 0
        minimum_minimal_route_cases = 0
    }
}

$penaltyNames = @(
    'wrong_mode',
    'missing_signal',
    'unnecessary_signal',
    'risk_underroute_per_level',
    'risk_overroute_per_level',
    'confirmation_underroute_per_level',
    'confirmation_overroute_per_level',
    'wrong_lead_skill',
    'missing_supporting_skill',
    'unnecessary_supporting_skill',
    'critical_underroute'
)
if (Assert-ObjectShape $catalog.scoring @('pass_score', 'penalties') @() 'Routing scoring') {
    if ((-not (Test-Number $catalog.scoring.pass_score)) -or ([double] $catalog.scoring.pass_score -lt 1) -or ([double] $catalog.scoring.pass_score -gt 100)) {
        Add-Failure 'Routing scoring pass_score must be numeric in the range 1-100.'
    }
    if (Assert-ObjectShape $catalog.scoring.penalties $penaltyNames @() 'Routing scoring penalties') {
        foreach ($penaltyName in $penaltyNames) {
            $value = $catalog.scoring.penalties.$penaltyName
            if ((-not (Test-Number $value)) -or ([double] $value -lt 0) -or ([double] $value -gt 100)) {
                Add-Failure "Routing penalty '$penaltyName' must be numeric in the range 0-100."
            }
        }
        if ((Test-Number $catalog.scoring.penalties.critical_underroute) -and ([double] $catalog.scoring.penalties.critical_underroute -lt 100)) {
            Add-Failure 'Routing critical_underroute penalty must be 100 to make critical under-routing non-compensatory.'
        }
        if ((Test-Number $catalog.scoring.penalties.unnecessary_signal) -and ([double] $catalog.scoring.penalties.unnecessary_signal -le 0)) {
            Add-Failure 'Routing unnecessary_signal penalty must be greater than zero.'
        }
        if ((Test-Number $catalog.scoring.penalties.missing_signal) -and
            (Test-Number $catalog.scoring.pass_score) -and
            ([double] $catalog.scoring.penalties.missing_signal -le (100 - [double] $catalog.scoring.pass_score))) {
            Add-Failure 'Routing missing_signal penalty must make one omitted expected signal fail the pass threshold.'
        }
        if ((Test-Number $catalog.scoring.penalties.wrong_mode) -and
            (Test-Number $catalog.scoring.pass_score) -and
            ([double] $catalog.scoring.penalties.wrong_mode -le (100 - [double] $catalog.scoring.pass_score))) {
            Add-Failure 'Routing wrong_mode penalty must make any incorrect task mode fail the pass threshold.'
        }
    }
}

$cases = @()
if (($catalog.cases -is [System.Array]) -and ($catalog.cases -isnot [string])) {
    $cases = @($catalog.cases)
}
else {
    Add-Failure 'Routing evaluation cases must be an array.'
}
$minimumCases = [int] $manifest.routing_evaluations.minimum_cases
$maximumCases = [int] $catalog.coverage_requirements.maximum_cases
if (($cases.Count -lt $minimumCases) -or ($cases.Count -gt $maximumCases)) {
    Add-Failure "Expected $minimumCases-$maximumCases routing evaluation cases, found $($cases.Count)."
}
foreach ($duplicate in @($cases | Group-Object -Property id | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate routing evaluation id: $($duplicate.Name)"
}

$riskRank = @{}
for ($index = 0; $index -lt $manifest.risk_order.Count; $index++) {
    $riskRank[[string] $manifest.risk_order[$index]] = $index
}
$confirmationRank = @{}
for ($index = 0; $index -lt $manifest.confirmation_order.Count; $index++) {
    $confirmationRank[[string] $manifest.confirmation_order[$index]] = $index
}
$riskValues = @($manifest.risk_order | ForEach-Object { [string] $_ })
$confirmationValues = @($manifest.confirmation_order | ForEach-Object { [string] $_ })
$modeNames = @($manifest.task_modes.PSObject.Properties.Name)
$signalNames = @($manifest.routing_signals.PSObject.Properties.Name)
$skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })
$signalCoverage = @{}
foreach ($signalName in $signalNames) {
    $signalCoverage[$signalName] = 0
}
$modeCoverage = @{}
foreach ($modeName in $modeNames) {
    $modeCoverage[$modeName] = 0
}
$minimalRouteCases = 0
$variantIds = @()

foreach ($case in $cases) {
    if (-not (Assert-ObjectShape $case @('id', 'request', 'rationale', 'expected') @('variants') 'Routing evaluation case')) {
        continue
    }
    $caseId = if (($case.id -is [string]) -and (-not [string]::IsNullOrWhiteSpace([string] $case.id))) { [string] $case.id } else { '<missing-id>' }
    if ($caseId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        Add-Failure "Routing case '$caseId' id must use lowercase kebab-case."
    }
    if (($case.request -isnot [string]) -or ([string] $case.request).Trim().Length -lt 20) {
        Add-Failure "Routing case '$caseId' request must be at least 20 nonblank characters."
    }
    if (($case.rationale -isnot [string]) -or ([string] $case.rationale).Trim().Length -lt 20) {
        Add-Failure "Routing case '$caseId' rationale must be at least 20 nonblank characters."
    }
    if ($case.PSObject.Properties.Name -contains 'variants') {
        if (($case.variants -is [string]) -or ($case.variants -isnot [System.Array])) {
            Add-Failure "Routing case '$caseId' variants must be an array."
        }
        else {
            foreach ($variant in @($case.variants)) {
                if (-not (Assert-ObjectShape $variant @('id', 'request') @() "Routing case '$caseId' variant")) {
                    continue
                }
                $variantId = [string] $variant.id
                if ($variantId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
                    Add-Failure "Routing case '$caseId' variant id must use lowercase kebab-case."
                }
                else {
                    $variantIds += $variantId
                }
                if (($variant.request -isnot [string]) -or ([string] $variant.request).Trim().Length -lt 20) {
                    Add-Failure "Routing variant '$variantId' request must be at least 20 nonblank characters."
                }
            }
        }
    }
    if (-not (Assert-ObjectShape $case.expected @('mode', 'signals', 'risk', 'confirmation', 'lead_skill', 'supporting_skills') @() "Routing case '$caseId' expected decision")) {
        continue
    }
    $mode = [string] $case.expected.mode
    if ($modeNames -notcontains $mode) {
        Add-Failure "Routing case '$caseId' references unknown mode: $mode"
    }
    else {
        $modeCoverage[$mode]++
    }
    $signals = @(Get-StringArray $case.expected.signals "Routing case '$caseId' expected signals")
    foreach ($signalName in $signals) {
        if ($signalNames -notcontains $signalName) {
            Add-Failure "Routing case '$caseId' references unknown signal: $signalName"
        }
        else {
            $signalCoverage[$signalName]++
        }
    }
    if ($modeNames -contains $mode) {
        $requiredSignals = @($manifest.task_modes.$mode.required_signals | ForEach-Object { [string] $_ })
        foreach ($requiredSignal in $requiredSignals) {
            if ($signals -notcontains $requiredSignal) {
                Add-Failure "Routing case '$caseId' mode '$mode' is missing required signal: $requiredSignal"
            }
        }
        if ((@($signals | Sort-Object -Unique) -join '|') -eq (@($requiredSignals | Sort-Object -Unique) -join '|')) {
            $minimalRouteCases++
        }
    }
    if ($riskValues -notcontains [string] $case.expected.risk) {
        Add-Failure "Routing case '$caseId' has invalid risk: $($case.expected.risk)"
    }
    if ($confirmationValues -notcontains [string] $case.expected.confirmation) {
        Add-Failure "Routing case '$caseId' has invalid confirmation: $($case.expected.confirmation)"
    }
    if (($null -ne $case.expected.lead_skill) -and
        (($case.expected.lead_skill -isnot [string]) -or ($skillNames -notcontains [string] $case.expected.lead_skill))) {
        Add-Failure "Routing case '$caseId' expected lead_skill must be a known skill or null."
    }
    $supports = @(Get-StringArray $case.expected.supporting_skills "Routing case '$caseId' expected supporting_skills" -AllowEmpty)
    foreach ($skillName in $supports) {
        if ($skillNames -notcontains $skillName) {
            Add-Failure "Routing case '$caseId' references unknown supporting skill: $skillName"
        }
    }

    $knownSignals = @($signals | Where-Object { $signalNames -contains $_ })
    if ($knownSignals.Count -eq $signals.Count) {
        $computed = Get-ComposedRoute $manifest $signals $riskRank $confirmationRank
        if ($computed.Risk -ne [string] $case.expected.risk) {
            Add-Failure "Routing case '$caseId' risk does not match manifest composition: expected '$($case.expected.risk)', computed '$($computed.Risk)'."
        }
        if ($computed.Confirmation -ne [string] $case.expected.confirmation) {
            Add-Failure "Routing case '$caseId' confirmation does not match manifest composition: expected '$($case.expected.confirmation)', computed '$($computed.Confirmation)'."
        }
        if (-not [object]::Equals($computed.Lead, $case.expected.lead_skill)) {
            Add-Failure "Routing case '$caseId' lead_skill does not match manifest composition: expected '$($case.expected.lead_skill)', computed '$($computed.Lead)'."
        }
        [void](Assert-SameSet $computed.Supports $supports "Routing case '$caseId' supporting_skills")
    }
}
foreach ($duplicate in @($variantIds | Group-Object | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate routing variant id: $($duplicate.Name)"
}
foreach ($variantId in $variantIds) {
    if (@($cases.id) -contains $variantId) {
        Add-Failure "Routing variant id duplicates a base case id: $variantId"
    }
}

foreach ($signalName in $signalNames) {
    if ($signalCoverage[$signalName] -lt [int] $catalog.coverage_requirements.minimum_cases_per_signal) {
        Add-Failure "Routing signal '$signalName' does not meet the raw-request coverage floor."
    }
}
foreach ($modeName in $modeNames) {
    if ($modeCoverage[$modeName] -lt [int] $catalog.coverage_requirements.minimum_cases_per_mode) {
        Add-Failure "Task mode '$modeName' does not meet the raw-request coverage floor."
    }
}
if ($minimalRouteCases -lt [int] $catalog.coverage_requirements.minimum_minimal_route_cases) {
    Add-Failure "Routing catalog does not meet its minimal-route anti-ceremony floor; found $minimalRouteCases."
}

$oracleCompositionDiscrepancies = New-Object 'System.Collections.Generic.List[string]'
$scenariosById = @{}
foreach ($scenario in @($scenarioDocument.scenarios)) {
    $scenariosById[[string] $scenario.id] = $scenario
}
foreach ($case in $cases) {
    $caseId = [string] $case.id
    if (-not $scenariosById.ContainsKey($caseId)) {
        continue
    }
    $scenario = $scenariosById[$caseId]
    if ([string] $case.request -ne [string] $scenario.request) {
        $oracleCompositionDiscrepancies.Add("case '$caseId' request text differs")
    }
    if ([string] $case.expected.mode -ne [string] $scenario.expected_mode) {
        $oracleCompositionDiscrepancies.Add("case '$caseId' mode differs")
    }
    $signalDifference = @(Compare-Object -ReferenceObject @($scenario.signals | Sort-Object -Unique) -DifferenceObject @($case.expected.signals | Sort-Object -Unique))
    if ($signalDifference.Count -gt 0) {
        $oracleCompositionDiscrepancies.Add("case '$caseId' signal selection differs")
    }
    if (([string] $case.expected.risk -ne [string] $scenario.expected_risk) -or
        ([string] $case.expected.confirmation -ne [string] $scenario.expected_confirmation) -or
        (-not [object]::Equals($case.expected.lead_skill, $scenario.expected_lead_skill))) {
        $oracleCompositionDiscrepancies.Add("case '$caseId' composed route differs")
    }
    $supportDifference = @(Compare-Object -ReferenceObject @($scenario.expected_supporting_skills | Sort-Object -Unique) -DifferenceObject @($case.expected.supporting_skills | Sort-Object -Unique))
    if ($supportDifference.Count -gt 0) {
        $oracleCompositionDiscrepancies.Add("case '$caseId' supporting skills differ")
    }
}

if (Assert-ObjectShape $template @('$schema', 'schema_version', 'case_id', 'rules_pack_version', 'model', 'runner', 'started_at', 'duration_seconds', 'decision', 'notes') @() 'Routing run template') {
    if ([string] $template.'$schema' -ne '../schemas/routing-evaluation-run.schema.json') {
        Add-Failure "Routing run template `$schema must be '../schemas/routing-evaluation-run.schema.json'."
    }
    if ((($template.schema_version -isnot [int]) -and ($template.schema_version -isnot [long])) -or ([int] $template.schema_version -ne 1)) {
        Add-Failure 'Routing run template schema_version must be integer 1.'
    }
    [void](Assert-ObjectShape $template.model @('provider', 'name', 'version', 'agent_surface') @() 'Routing run template model')
    [void](Assert-ObjectShape $template.runner @('id', 'type', 'organization') @() 'Routing run template runner')
    [void](Assert-ObjectShape $template.decision @('mode', 'signals', 'risk', 'confirmation', 'lead_skill', 'supporting_skills') @() 'Routing run template decision')
}

if ($failures.Count -gt 0) {
    Write-Host "Routing evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

foreach ($discrepancy in $oracleCompositionDiscrepancies) {
    Write-Host "Semantic oracle/composition discrepancy: $discrepancy" -ForegroundColor Yellow
}
Write-Host "Routing semantic-oracle validation PASS: $($cases.Count) raw requests, $($signalNames.Count) signal routes, $minimalRouteCases minimal anti-ceremony cases, $($oracleCompositionDiscrepancies.Count) surfaced composition discrepancy item(s)." -ForegroundColor Green
exit 0

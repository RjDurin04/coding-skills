[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRecord,
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = Split-Path -Parent $scriptDirectory
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$recordPath = [System.IO.Path]::GetFullPath($RunRecord)
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)

    $failures.Add($Message)
}

function Write-InvalidResult {
    param([System.Collections.Generic.List[string]] $Findings)

    [ordered]@{
        status = 'INVALID'
        findings = @($Findings)
    } | ConvertTo-Json -Depth 10
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

function Get-ComposedDecision {
    param(
        [object] $Manifest,
        [string[]] $Signals,
        [hashtable] $RiskRank,
        [hashtable] $ConfirmationRank
    )

    $computedRiskRank = 0
    $computedConfirmationRank = 0
    $leadSkill = $null
    $supportingSkills = @()

    foreach ($signalName in $Signals) {
        $signal = $Manifest.routing_signals.PSObject.Properties[$signalName].Value
        $signalRisk = [string] $signal.minimum_risk
        $signalConfirmation = [string] $signal.confirmation
        if ($RiskRank[$signalRisk] -gt $computedRiskRank) {
            $computedRiskRank = $RiskRank[$signalRisk]
        }
        if ($ConfirmationRank[$signalConfirmation] -gt $computedConfirmationRank) {
            $computedConfirmationRank = $ConfirmationRank[$signalConfirmation]
        }

        if ($null -ne $signal.lead_skill) {
            $candidateLead = [string] $signal.lead_skill
            if ($null -eq $leadSkill) {
                $leadSkill = $candidateLead
            }
            elseif ($candidateLead -ne $leadSkill) {
                $supportingSkills += $candidateLead
            }
        }
        $supportingSkills += @($signal.supporting_skills | ForEach-Object { [string] $_ })
    }

    foreach ($overlay in @($Manifest.risk_overlays)) {
        $overlayRisk = [string] $overlay.minimum_risk
        if ($computedRiskRank -ge $RiskRank[$overlayRisk]) {
            $supportingSkills += @($overlay.supporting_skills | ForEach-Object { [string] $_ })
        }
    }

    return [pscustomobject]@{
        Risk = [string] $Manifest.risk_order[$computedRiskRank]
        Confirmation = [string] $Manifest.confirmation_order[$computedConfirmationRank]
        LeadSkill = $leadSkill
        SupportingSkills = @($supportingSkills | Where-Object { $_ -ne $leadSkill } | Sort-Object -Unique)
    }
}

function Test-SameStringSet {
    param(
        [string[]] $Left,
        [string[]] $Right
    )

    $leftValues = @($Left | Sort-Object -Unique)
    $rightValues = @($Right | Sort-Object -Unique)
    if ($leftValues.Count -ne $rightValues.Count) {
        return $false
    }
    foreach ($value in $leftValues) {
        if ($rightValues -notcontains $value) {
            return $false
        }
    }
    return $true
}

$manifest = Read-Json (Join-Path $rootPath 'governance-manifest.json') 'Governance manifest'
if ($null -eq $manifest) {
    Write-InvalidResult $failures
    exit 2
}
$catalogPath = Join-Path $rootPath (([string] $manifest.routing_evaluations.catalog) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Read-Json $catalogPath 'Routing evaluation catalog'
$record = Read-Json $recordPath 'Routing run record'
if (($null -eq $catalog) -or ($null -eq $record)) {
    Write-InvalidResult $failures
    exit 2
}

try {
    if ((-not (Test-Number $catalog.scoring.pass_score)) -or
        ([double] $catalog.scoring.pass_score -lt 1) -or
        ([double] $catalog.scoring.pass_score -gt 100)) {
        Add-Failure 'Routing catalog pass_score must be a finite number from 1 to 100.'
    }
    foreach ($penalty in @($catalog.scoring.penalties.PSObject.Properties)) {
        if ((-not (Test-Number $penalty.Value)) -or
            ([double] $penalty.Value -lt 0) -or
            ([double] $penalty.Value -gt 100)) {
            Add-Failure "Routing catalog penalty '$($penalty.Name)' must be a finite number from 0 to 100."
        }
    }
    if ((Test-Number $catalog.scoring.penalties.wrong_mode) -and
        (Test-Number $catalog.scoring.pass_score) -and
        ([double] $catalog.scoring.penalties.wrong_mode -le
            (100 - [double] $catalog.scoring.pass_score))) {
        Add-Failure 'Routing catalog wrong_mode penalty is compensatory.'
    }
}
catch {
    Add-Failure "Routing catalog numeric policy could not be validated: $($_.Exception.Message)"
}
if ($failures.Count -gt 0) {
    Write-InvalidResult $failures
    exit 2
}

$runProperties = @(
    '$schema',
    'schema_version',
    'case_id',
    'rules_pack_version',
    'model',
    'runner',
    'started_at',
    'duration_seconds',
    'decision',
    'notes'
)
if (-not (Assert-ObjectShape $record $runProperties @() 'Routing run record')) {
    Write-InvalidResult $failures
    exit 2
}
if ([string] $record.'$schema' -ne '../schemas/routing-evaluation-run.schema.json') {
    Add-Failure "Routing run record `$schema must be '../schemas/routing-evaluation-run.schema.json'."
}
if (((($record.schema_version -isnot [int]) -and ($record.schema_version -isnot [long]))) -or ([int] $record.schema_version -ne 1)) {
    Add-Failure 'Routing run record schema_version must be integer 1.'
}
foreach ($field in @('case_id', 'rules_pack_version', 'started_at')) {
    if (($record.$field -isnot [string]) -or
        [string]::IsNullOrWhiteSpace([string] $record.$field) -or
        ([string] $record.$field).StartsWith('replace-with-', [System.StringComparison]::OrdinalIgnoreCase)) {
        Add-Failure "Routing run record '$field' must contain measured run metadata."
    }
}
if ($record.notes -isnot [string]) {
    Add-Failure 'Routing run record notes must be a string.'
}
$parsedStartedAt = [datetimeoffset]::MinValue
if (($record.started_at -is [string]) -and (-not [datetimeoffset]::TryParse([string] $record.started_at, [ref] $parsedStartedAt))) {
    Add-Failure 'Routing run record started_at must be a valid timestamp.'
}
if ((-not (Test-Number $record.duration_seconds)) -or ([double] $record.duration_seconds -lt 0)) {
    Add-Failure 'Routing run record duration_seconds must be a nonnegative number.'
}

if (Assert-ObjectShape $record.model @('provider', 'name', 'version', 'agent_surface') @() 'Routing run model') {
    foreach ($field in @('provider', 'name', 'version', 'agent_surface')) {
        $value = $record.model.$field
        if (($value -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $value) -or ([string] $value).StartsWith('replace-with-', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "Routing run model '$field' must be nonblank measured metadata."
        }
    }
}
if (Assert-ObjectShape $record.runner @('id', 'type', 'organization') @() 'Routing run runner') {
    foreach ($field in @('id', 'organization')) {
        $value = $record.runner.$field
        if (($value -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $value) -or ([string] $value).StartsWith('replace-with-', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "Routing run runner '$field' must be nonblank measured metadata."
        }
    }
    if (@('human', 'agent', 'automation') -notcontains [string] $record.runner.type) {
        Add-Failure "Routing run runner type is invalid: $($record.runner.type)"
    }
}

$decisionValid = Assert-ObjectShape $record.decision @('mode', 'signals', 'risk', 'confirmation', 'lead_skill', 'supporting_skills') @() 'Routing run decision'
$signals = @()
$supports = @()
if ($decisionValid) {
    if (@($manifest.task_modes.PSObject.Properties.Name) -notcontains [string] $record.decision.mode) {
        Add-Failure "Routing run decision mode is unknown: $($record.decision.mode)"
    }
    $signals = @(Get-StringArray $record.decision.signals 'Routing run decision signals')
    foreach ($signal in $signals) {
        if (@($manifest.routing_signals.PSObject.Properties.Name) -notcontains $signal) {
            Add-Failure "Routing run decision contains unknown signal: $signal"
        }
    }
    if (@($manifest.risk_order) -notcontains [string] $record.decision.risk) {
        Add-Failure "Routing run decision risk is unknown: $($record.decision.risk)"
    }
    if (@($manifest.confirmation_order) -notcontains [string] $record.decision.confirmation) {
        Add-Failure "Routing run decision confirmation is unknown: $($record.decision.confirmation)"
    }
    $skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })
    if (($null -ne $record.decision.lead_skill) -and
        (($record.decision.lead_skill -isnot [string]) -or ($skillNames -notcontains [string] $record.decision.lead_skill))) {
        Add-Failure 'Routing run decision lead_skill must be a known skill or null.'
    }
    $supports = @(Get-StringArray $record.decision.supporting_skills 'Routing run decision supporting_skills' -AllowEmpty)
    foreach ($support in $supports) {
        if ($skillNames -notcontains $support) {
            Add-Failure "Routing run decision contains unknown supporting skill: $support"
        }
    }
}

$matchingCases = @($catalog.cases | Where-Object { [string] $_.id -eq [string] $record.case_id })
if ($matchingCases.Count -ne 1) {
    Add-Failure "Routing run case_id must match exactly one catalog case: $($record.case_id)"
}
if ([string] $record.rules_pack_version -ne [string] $manifest.pack_version) {
    Add-Failure "Routing run rules_pack_version '$($record.rules_pack_version)' does not match '$($manifest.pack_version)'."
}
if ($failures.Count -gt 0) {
    Write-InvalidResult $failures
    exit 2
}

$riskRank = @{}
for ($index = 0; $index -lt $manifest.risk_order.Count; $index++) {
    $riskRank[[string] $manifest.risk_order[$index]] = $index
}
$confirmationRank = @{}
for ($index = 0; $index -lt $manifest.confirmation_order.Count; $index++) {
    $confirmationRank[[string] $manifest.confirmation_order[$index]] = $index
}

$modeName = [string] $record.decision.mode
$modeDefinition = $manifest.task_modes.PSObject.Properties[$modeName].Value
$requiredModeSignals = @($modeDefinition.required_signals | ForEach-Object { [string] $_ })
$taskModeSignals = @(
    $manifest.task_modes.PSObject.Properties |
        ForEach-Object { @($_.Value.required_signals | ForEach-Object { [string] $_ }) } |
        Sort-Object -Unique
)
foreach ($requiredSignal in $requiredModeSignals) {
    if ($signals -notcontains $requiredSignal) {
        Add-Failure "Routing run decision mode '$modeName' is missing required task-mode signal: $requiredSignal"
    }
}
foreach ($prohibitedSignal in @($taskModeSignals | Where-Object { $requiredModeSignals -notcontains $_ })) {
    if ($signals -contains $prohibitedSignal) {
        Add-Failure "Routing run decision mode '$modeName' contains prohibited task-mode signal: $prohibitedSignal"
    }
}

$composedDecision = Get-ComposedDecision $manifest $signals $riskRank $confirmationRank
if ([string] $record.decision.risk -ne $composedDecision.Risk) {
    Add-Failure "Routing run decision risk '$($record.decision.risk)' does not match composed risk '$($composedDecision.Risk)'."
}
if ([string] $record.decision.confirmation -ne $composedDecision.Confirmation) {
    Add-Failure "Routing run decision confirmation '$($record.decision.confirmation)' does not match composed confirmation '$($composedDecision.Confirmation)'."
}
if (-not [object]::Equals($record.decision.lead_skill, $composedDecision.LeadSkill)) {
    Add-Failure "Routing run decision lead_skill '$($record.decision.lead_skill)' does not match composed lead_skill '$($composedDecision.LeadSkill)'."
}
if (-not (Test-SameStringSet $supports $composedDecision.SupportingSkills)) {
    Add-Failure "Routing run decision supporting_skills [$($supports -join ', ')] do not match composed supporting_skills [$($composedDecision.SupportingSkills -join ', ')]."
}
if ($failures.Count -gt 0) {
    Write-InvalidResult $failures
    exit 2
}

$case = $matchingCases[0]
$expected = $case.expected
$penalties = $catalog.scoring.penalties
$score = 100.0
$findings = New-Object 'System.Collections.Generic.List[string]'
$mandatoryFailures = New-Object 'System.Collections.Generic.List[string]'
$criticalFailures = New-Object 'System.Collections.Generic.List[string]'

if ([string] $record.decision.mode -ne [string] $expected.mode) {
    $score -= [double] $penalties.wrong_mode
    $findings.Add("wrong_mode:$($record.decision.mode)")
    $mandatoryFailures.Add('wrong_mode')
}

$expectedSignals = @($expected.signals | ForEach-Object { [string] $_ })
$missingSignals = @($expectedSignals | Where-Object { $signals -notcontains $_ } | Sort-Object -Unique)
$unnecessarySignals = @($signals | Where-Object { $expectedSignals -notcontains $_ } | Sort-Object -Unique)
$score -= $missingSignals.Count * [double] $penalties.missing_signal
$score -= $unnecessarySignals.Count * [double] $penalties.unnecessary_signal
foreach ($signal in $missingSignals) {
    $findings.Add("missing_signal:$signal")
}
foreach ($signal in $unnecessarySignals) {
    $findings.Add("unnecessary_signal:$signal")
}

$expectedRiskRank = $riskRank[[string] $expected.risk]
$actualRiskRank = $riskRank[[string] $record.decision.risk]
if ($actualRiskRank -lt $expectedRiskRank) {
    $score -= ($expectedRiskRank - $actualRiskRank) * [double] $penalties.risk_underroute_per_level
    $findings.Add("risk_underroute:$($record.decision.risk)")
}
elseif ($actualRiskRank -gt $expectedRiskRank) {
    $score -= ($actualRiskRank - $expectedRiskRank) * [double] $penalties.risk_overroute_per_level
    $findings.Add("risk_overroute:$($record.decision.risk)")
}

$expectedConfirmationRank = $confirmationRank[[string] $expected.confirmation]
$actualConfirmationRank = $confirmationRank[[string] $record.decision.confirmation]
if ($actualConfirmationRank -lt $expectedConfirmationRank) {
    $score -= ($expectedConfirmationRank - $actualConfirmationRank) * [double] $penalties.confirmation_underroute_per_level
    $findings.Add("confirmation_underroute:$($record.decision.confirmation)")
}
elseif ($actualConfirmationRank -gt $expectedConfirmationRank) {
    $score -= ($actualConfirmationRank - $expectedConfirmationRank) * [double] $penalties.confirmation_overroute_per_level
    $findings.Add("confirmation_overroute:$($record.decision.confirmation)")
}

if (-not [object]::Equals($record.decision.lead_skill, $expected.lead_skill)) {
    $score -= [double] $penalties.wrong_lead_skill
    $findings.Add("wrong_lead_skill:$($record.decision.lead_skill)")
}
$expectedSupports = @($expected.supporting_skills | ForEach-Object { [string] $_ })
$missingSupports = @($expectedSupports | Where-Object { $supports -notcontains $_ } | Sort-Object -Unique)
$unnecessarySupports = @($supports | Where-Object { $expectedSupports -notcontains $_ } | Sort-Object -Unique)
$score -= $missingSupports.Count * [double] $penalties.missing_supporting_skill
$score -= $unnecessarySupports.Count * [double] $penalties.unnecessary_supporting_skill
foreach ($support in $missingSupports) {
    $findings.Add("missing_supporting_skill:$support")
}
foreach ($support in $unnecessarySupports) {
    $findings.Add("unnecessary_supporting_skill:$support")
}

$missingCriticalSignals = @($missingSignals | Where-Object {
    $signal = $manifest.routing_signals.$_
    ([string] $signal.minimum_risk -eq 'critical') -or ([string] $signal.confirmation -eq 'fresh_confirmation')
})
if (($expectedRiskRank -eq $riskRank['critical']) -and ($actualRiskRank -lt $expectedRiskRank)) {
    $criticalFailures.Add('critical_risk_underroute')
}
if (($expectedConfirmationRank -eq $confirmationRank['fresh_confirmation']) -and ($actualConfirmationRank -lt $expectedConfirmationRank)) {
    $criticalFailures.Add('critical_confirmation_underroute')
}
if ($missingCriticalSignals.Count -gt 0) {
    $criticalFailures.Add('missing_critical_signal')
}
if (([string] $expected.mode -eq 'operate') -and ([string] $record.decision.mode -ne 'operate')) {
    $criticalFailures.Add('critical_action_mode_mismatch')
}
if ($criticalFailures.Count -gt 0) {
    $score -= [double] $penalties.critical_underroute
}

$score = [math]::Round([math]::Max(0, $score), 2)
$status = if (
    ($mandatoryFailures.Count -eq 0) -and
    ($criticalFailures.Count -eq 0) -and
    ($score -ge [double] $catalog.scoring.pass_score)
) { 'PASS' } else { 'FAIL' }
$result = [ordered]@{
    case_id = [string] $record.case_id
    score = $score
    threshold = [double] $catalog.scoring.pass_score
    findings = @($findings)
    mandatory_failures = @($mandatoryFailures | Sort-Object -Unique)
    critical_failures = @($criticalFailures | Sort-Object -Unique)
    status = $status
}
$result | ConvertTo-Json -Depth 10
if ($status -eq 'PASS') {
    exit 0
}
exit 1

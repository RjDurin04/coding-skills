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
$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$scenarioPath = Join-Path $rootPath (('tests/governance-scenarios.json') -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0

function Add-Failure {
    param([string] $Message)

    $failures.Add($Message)
}

function Read-JsonDocument {
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
    $actual = @($Object.PSObject.Properties.Name)
    foreach ($property in $Required) {
        if ($actual -notcontains $property) {
            Add-Failure "$Label is missing property: $property"
        }
    }
    foreach ($property in $actual) {
        if (($Required -notcontains $property) -and ($Optional -notcontains $property)) {
            Add-Failure "$Label contains unknown property: $property"
        }
    }
    return @($Required | Where-Object { $actual -notcontains $_ }).Count -eq 0
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

function Assert-SameSet {
    param(
        [string[]] $Expected,
        [string[]] $Actual,
        [string] $Label
    )

    $difference = @(Compare-Object -ReferenceObject @($Expected | Sort-Object -Unique) -DifferenceObject @($Actual | Sort-Object -Unique))
    if ($difference.Count -gt 0) {
        Add-Failure "$Label expected [$($Expected -join ', ')] but computed [$($Actual -join ', ')]."
        return $false
    }
    return $true
}

function Get-RoutingSignal {
    param(
        [object] $Manifest,
        [string] $Name
    )

    $property = @($Manifest.routing_signals.PSObject.Properties | Where-Object Name -eq $Name)
    if ($property.Count -ne 1) {
        return $null
    }
    return $property[0].Value
}

function Get-ComposedRoute {
    param(
        [object] $Manifest,
        [string[]] $Signals,
        [hashtable] $RiskRank,
        [hashtable] $ConfirmationRank
    )

    $computedRiskRank = 0
    $computedConfirmationRank = 0
    $computedRules = @()
    $leadSkill = $null
    $supportingSkills = @()

    foreach ($signalName in $Signals) {
        $signal = Get-RoutingSignal $Manifest $signalName
        if ($null -eq $signal) {
            continue
        }
        $signalRisk = [string] $signal.minimum_risk
        $signalConfirmation = [string] $signal.confirmation
        if ($RiskRank.ContainsKey($signalRisk) -and ($RiskRank[$signalRisk] -gt $computedRiskRank)) {
            $computedRiskRank = $RiskRank[$signalRisk]
        }
        if ($ConfirmationRank.ContainsKey($signalConfirmation) -and ($ConfirmationRank[$signalConfirmation] -gt $computedConfirmationRank)) {
            $computedConfirmationRank = $ConfirmationRank[$signalConfirmation]
        }
        $computedRules += @($signal.rules | ForEach-Object { [string] $_ })

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
        if ($RiskRank.ContainsKey($overlayRisk) -and ($computedRiskRank -ge $RiskRank[$overlayRisk])) {
            $computedRules += @($overlay.rules | ForEach-Object { [string] $_ })
            $supportingSkills += @($overlay.supporting_skills | ForEach-Object { [string] $_ })
        }
    }

    $supportingSkills = @($supportingSkills | Where-Object { $_ -ne $leadSkill } | Sort-Object -Unique)
    return [pscustomobject]@{
        Risk = [string] $Manifest.risk_order[$computedRiskRank]
        Confirmation = [string] $Manifest.confirmation_order[$computedConfirmationRank]
        Rules = @($computedRules | Sort-Object -Unique)
        LeadSkill = $leadSkill
        SupportingSkills = $supportingSkills
    }
}

$manifest = Read-JsonDocument $manifestPath 'Governance manifest'
$scenarioDocument = Read-JsonDocument $scenarioPath 'Governance scenario catalog'
if (($null -eq $manifest) -or ($null -eq $scenarioDocument)) {
    Write-Host "Scenario routing FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

foreach ($property in @('schema_version', 'task_modes', 'risk_order', 'confirmation_order', 'rules', 'skills', 'risk_overlays', 'routing_signals', 'schemas')) {
    if ($manifest.PSObject.Properties.Name -notcontains $property) {
        Add-Failure "Governance manifest is missing property needed for scenarios: $property"
    }
}
if ($failures.Count -gt 0) {
    Write-Host "Scenario routing FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}
if ([int] $manifest.schema_version -ne 3) {
    Add-Failure 'Governance scenarios require manifest schema_version 3.'
}

if (Assert-ObjectShape $scenarioDocument @('$schema', 'schema_version', 'scenarios') @() 'Scenario catalog') {
    if ([string] $scenarioDocument.'$schema' -ne '../schemas/governance-scenarios.schema.json') {
        Add-Failure "Scenario catalog `$schema must be '../schemas/governance-scenarios.schema.json'."
    }
    if (($scenarioDocument.schema_version -isnot [int]) -and ($scenarioDocument.schema_version -isnot [long])) {
        Add-Failure 'Scenario catalog schema_version must be an integer.'
    }
    elseif ([int] $scenarioDocument.schema_version -ne 2) {
        Add-Failure 'Scenario catalog schema_version must be 2.'
    }
}

$scenarios = @()
if (($scenarioDocument.PSObject.Properties.Name -contains 'scenarios') -and
    ($scenarioDocument.scenarios -is [System.Array]) -and
    ($scenarioDocument.scenarios -isnot [string])) {
    $scenarios = @($scenarioDocument.scenarios)
}
else {
    Add-Failure 'Scenario catalog scenarios must be an array.'
}
if (($scenarios.Count -lt 30) -or ($scenarios.Count -gt 100)) {
    Add-Failure "Expected 30-100 governance scenarios, found $($scenarios.Count)."
}
foreach ($duplicate in @($scenarios | Group-Object -Property id | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate governance scenario id: $($duplicate.Name)"
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
$ruleNames = @($manifest.rules | ForEach-Object { [string] $_.name })
$skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })
$positiveCoverage = @{}
$negativeCoverage = @{}
foreach ($signalName in $signalNames) {
    $positiveCoverage[$signalName] = 0
    $negativeCoverage[$signalName] = 0
}
$modeCoverage = @{}
foreach ($modeName in $modeNames) {
    $modeCoverage[$modeName] = 0
}
$universallyRequiredSignals = @($signalNames)
foreach ($modeName in $modeNames) {
    $modeRequiredSignals = @($manifest.task_modes.$modeName.required_signals | ForEach-Object { [string] $_ })
    $universallyRequiredSignals = @($universallyRequiredSignals | Where-Object { $modeRequiredSignals -contains $_ })
}

$requiredScenarioProperties = @(
    'id',
    'request',
    'expected_mode',
    'signals',
    'negative_signals',
    'expected_risk',
    'expected_confirmation',
    'expected_rules',
    'expected_lead_skill',
    'expected_supporting_skills'
)

foreach ($scenario in $scenarios) {
    $scenarioFailedBefore = $failures.Count
    if (-not (Assert-ObjectShape $scenario $requiredScenarioProperties @() 'Scenario')) {
        continue
    }
    $scenarioId = if (($scenario.id -is [string]) -and (-not [string]::IsNullOrWhiteSpace([string] $scenario.id))) {
        [string] $scenario.id
    }
    else {
        '<missing-id>'
    }
    if ($scenarioId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        Add-Failure "Scenario '$scenarioId' id must use lowercase kebab-case."
    }
    if (($scenario.request -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $scenario.request)) {
        Add-Failure "Scenario '$scenarioId' request must be nonblank."
    }

    $modeName = [string] $scenario.expected_mode
    if ($modeNames -notcontains $modeName) {
        Add-Failure "Scenario '$scenarioId' references unknown expected_mode: $modeName"
    }
    else {
        $modeCoverage[$modeName]++
    }

    $signals = @(Get-StringArray $scenario.signals "Scenario '$scenarioId' signals")
    $negativeSignals = @(Get-StringArray $scenario.negative_signals "Scenario '$scenarioId' negative_signals" -AllowEmpty)
    foreach ($signalName in $signals) {
        if ($signalNames -notcontains $signalName) {
            Add-Failure "Scenario '$scenarioId' references unknown signal: $signalName"
        }
        else {
            $positiveCoverage[$signalName]++
        }
        if ($negativeSignals -contains $signalName) {
            Add-Failure "Scenario '$scenarioId' lists signal in both positive and negative sets: $signalName"
        }
    }
    foreach ($signalName in $negativeSignals) {
        if ($signalNames -notcontains $signalName) {
            Add-Failure "Scenario '$scenarioId' references unknown negative signal: $signalName"
        }
        else {
            $negativeCoverage[$signalName]++
        }
    }

    if ($modeNames -contains $modeName) {
        foreach ($requiredSignal in @($manifest.task_modes.$modeName.required_signals)) {
            if ($signals -notcontains [string] $requiredSignal) {
                Add-Failure "Scenario '$scenarioId' mode '$modeName' is missing required signal: $requiredSignal"
            }
        }
    }
    if (@('answer', 'review', 'diagnose', 'design', 'operate') -contains $modeName) {
        if ($signals -contains 'implementation_task') {
            Add-Failure "Scenario '$scenarioId' mode '$modeName' must omit implementation_task."
        }
    }
    if ($modeName -eq 'implement') {
        foreach ($requiredSignal in @('durable_task', 'implementation_task')) {
            if ($signals -notcontains $requiredSignal) {
                Add-Failure "Scenario '$scenarioId' implement mode must include: $requiredSignal"
            }
        }
    }

    if ($riskValues -notcontains [string] $scenario.expected_risk) {
        Add-Failure "Scenario '$scenarioId' has invalid expected risk: $($scenario.expected_risk)"
    }
    if ($confirmationValues -notcontains [string] $scenario.expected_confirmation) {
        Add-Failure "Scenario '$scenarioId' has invalid expected confirmation: $($scenario.expected_confirmation)"
    }
    $expectedRules = @(Get-StringArray $scenario.expected_rules "Scenario '$scenarioId' expected_rules" -AllowEmpty)
    $expectedSupports = @(Get-StringArray $scenario.expected_supporting_skills "Scenario '$scenarioId' expected_supporting_skills" -AllowEmpty)
    foreach ($ruleName in $expectedRules) {
        if ($ruleNames -notcontains $ruleName) {
            Add-Failure "Scenario '$scenarioId' references unknown expected rule: $ruleName"
        }
    }
    foreach ($skillName in $expectedSupports) {
        if ($skillNames -notcontains $skillName) {
            Add-Failure "Scenario '$scenarioId' references unknown expected supporting skill: $skillName"
        }
    }
    if (($null -ne $scenario.expected_lead_skill) -and
        (($scenario.expected_lead_skill -isnot [string]) -or
            [string]::IsNullOrWhiteSpace([string] $scenario.expected_lead_skill) -or
            ($skillNames -notcontains [string] $scenario.expected_lead_skill))) {
        Add-Failure "Scenario '$scenarioId' expected_lead_skill must be a known skill or null."
    }

    $knownSignals = @($signals | Where-Object { $signalNames -contains $_ })
    $computed = Get-ComposedRoute $manifest $knownSignals $riskRank $confirmationRank
    if ($computed.Risk -ne [string] $scenario.expected_risk) {
        Add-Failure "[$scenarioId] Risk expected '$($scenario.expected_risk)' but computed '$($computed.Risk)'."
    }
    if ($computed.Confirmation -ne [string] $scenario.expected_confirmation) {
        Add-Failure "[$scenarioId] Confirmation expected '$($scenario.expected_confirmation)' but computed '$($computed.Confirmation)'."
    }
    [void](Assert-SameSet $expectedRules $computed.Rules "[$scenarioId] Rules")
    if (-not [object]::Equals($computed.LeadSkill, $scenario.expected_lead_skill)) {
        Add-Failure "[$scenarioId] Lead skill expected '$($scenario.expected_lead_skill)' but computed '$($computed.LeadSkill)'."
    }
    [void](Assert-SameSet $expectedSupports $computed.SupportingSkills "[$scenarioId] Supporting skills")

    if ($failures.Count -eq $scenarioFailedBefore) {
        $passed++
        Write-Host "PASS ${scenarioId}: mode=$modeName risk=$($computed.Risk) confirmation=$($computed.Confirmation)" -ForegroundColor Green
    }
}

foreach ($modeName in $modeNames) {
    if ($modeCoverage[$modeName] -lt 1) {
        Add-Failure "Task mode '$modeName' has no governance scenario."
    }
}
foreach ($signalName in $signalNames) {
    if ($positiveCoverage[$signalName] -lt 1) {
        Add-Failure "Routing signal '$signalName' has no positive governance scenario."
    }
    if (($negativeCoverage[$signalName] -lt 1) -and ($universallyRequiredSignals -notcontains $signalName)) {
        Add-Failure "Routing signal '$signalName' has no negative governance scenario."
    }
}

$mandatoryModeSignals = @(
    [pscustomobject]@{ Signal = 'pure_refactor'; Modes = @('implement') },
    [pscustomobject]@{ Signal = 'test_logic_or_verification_change'; Modes = @('implement') },
    [pscustomobject]@{ Signal = 'release_design_or_configuration'; Modes = @('design', 'implement') },
    [pscustomobject]@{ Signal = 'production_readiness_assessment'; Modes = @('review') },
    [pscustomobject]@{ Signal = 'operational_action'; Modes = @('operate') },
    [pscustomobject]@{ Signal = 'shared_environment_release_execution'; Modes = @('operate') },
    [pscustomobject]@{ Signal = 'external_side_effect'; Modes = @('operate') },
    [pscustomobject]@{ Signal = 'material_public_communication'; Modes = @('operate') },
    [pscustomobject]@{ Signal = 'artifact_build_or_distribution'; Modes = @('implement', 'operate') },
    [pscustomobject]@{ Signal = 'repository_code_execution'; Modes = @('implement') },
    [pscustomobject]@{ Signal = 'unfamiliar_or_privileged_repository_execution'; Modes = @('implement') },
    [pscustomobject]@{ Signal = 'material_requirement_or_constraint'; Modes = @('design', 'implement', 'review') },
    [pscustomobject]@{ Signal = 'privacy_lifecycle'; Modes = @('design', 'implement', 'review') },
    [pscustomobject]@{ Signal = 'supply_chain_change'; Modes = @('implement', 'review') },
    [pscustomobject]@{ Signal = 'configuration_or_feature_flag'; Modes = @('design', 'implement', 'review') }
)
foreach ($expectation in $mandatoryModeSignals) {
    if ($signalNames -notcontains $expectation.Signal) {
        continue
    }
    $matching = @($scenarios | Where-Object {
        (@($_.signals) -contains $expectation.Signal) -and ($expectation.Modes -contains [string] $_.expected_mode)
    })
    if ($matching.Count -lt 1) {
        Add-Failure "Routing signal '$($expectation.Signal)' needs a scenario in mode [$($expectation.Modes -join ', ')]."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Scenario routing FAILED: $passed/$($scenarios.Count) scenarios passed, $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Scenario routing PASS: $passed/$($scenarios.Count) scenarios; all $($signalNames.Count) signals have positive coverage and every non-universal signal has negative coverage." -ForegroundColor Green
exit 0

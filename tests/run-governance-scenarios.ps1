[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$scenarioPath = Join-Path $rootPath 'tests\governance-scenarios.json'
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$scenarioDocument = Get-Content -Raw -Encoding UTF8 -LiteralPath $scenarioPath | ConvertFrom-Json

$riskRank = @{}
for ($index = 0; $index -lt $manifest.risk_order.Count; $index++) {
    $riskRank[[string] $manifest.risk_order[$index]] = $index
}

$confirmationRank = @{}
for ($index = 0; $index -lt $manifest.confirmation_order.Count; $index++) {
    $confirmationRank[[string] $manifest.confirmation_order[$index]] = $index
}

$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0

function Add-Failure {
    param([string] $Message)
    $failures.Add($Message)
}

function Get-RoutingSignal {
    param([string] $Name)

    $property = @($manifest.routing_signals.PSObject.Properties | Where-Object Name -eq $Name)
    if ($property.Count -ne 1) {
        return $null
    }
    return $property[0].Value
}

foreach ($scenario in @($scenarioDocument.scenarios)) {
    $computedRiskRank = 0
    $computedConfirmationRank = 0
    $computedRules = @()
    $computedSkills = @()
    $scenarioFailed = $false

    foreach ($signalName in @($scenario.signals)) {
        $signal = Get-RoutingSignal ([string] $signalName)
        if ($null -eq $signal) {
            Add-Failure "[$($scenario.id)] Unknown routing signal: $signalName"
            $scenarioFailed = $true
            continue
        }

        $signalRiskRank = $riskRank[[string] $signal.minimum_risk]
        if ($signalRiskRank -gt $computedRiskRank) {
            $computedRiskRank = $signalRiskRank
        }

        $signalConfirmationRank = $confirmationRank[[string] $signal.confirmation]
        if ($signalConfirmationRank -gt $computedConfirmationRank) {
            $computedConfirmationRank = $signalConfirmationRank
        }

        $computedRules += @($signal.rules | ForEach-Object { [string] $_ })
        $computedSkills += @($signal.skills | ForEach-Object { [string] $_ })
    }

    foreach ($overlay in @($manifest.risk_overlays)) {
        if ($computedRiskRank -ge $riskRank[[string] $overlay.minimum_risk]) {
            $computedRules += @($overlay.rules | ForEach-Object { [string] $_ })
            $computedSkills += @($overlay.skills | ForEach-Object { [string] $_ })
        }
    }

    $computedRisk = [string] $manifest.risk_order[$computedRiskRank]
    $computedConfirmation = [string] $manifest.confirmation_order[$computedConfirmationRank]
    $computedRules = @($computedRules | Sort-Object -Unique)
    $computedSkills = @($computedSkills | Sort-Object -Unique)

    if ($computedRisk -ne [string] $scenario.expected_risk) {
        Add-Failure "[$($scenario.id)] Risk expected '$($scenario.expected_risk)' but computed '$computedRisk'."
        $scenarioFailed = $true
    }
    if ($computedConfirmation -ne [string] $scenario.expected_confirmation) {
        Add-Failure "[$($scenario.id)] Confirmation expected '$($scenario.expected_confirmation)' but computed '$computedConfirmation'."
        $scenarioFailed = $true
    }

    foreach ($ruleName in @($scenario.must_include_rules)) {
        if ($computedRules -notcontains [string] $ruleName) {
            Add-Failure "[$($scenario.id)] Missing required rule: $ruleName"
            $scenarioFailed = $true
        }
    }
    foreach ($ruleName in @($scenario.must_exclude_rules)) {
        if ($computedRules -contains [string] $ruleName) {
            Add-Failure "[$($scenario.id)] Unexpected rule: $ruleName"
            $scenarioFailed = $true
        }
    }
    foreach ($skillName in @($scenario.must_include_skills)) {
        if ($computedSkills -notcontains [string] $skillName) {
            Add-Failure "[$($scenario.id)] Missing required skill: $skillName"
            $scenarioFailed = $true
        }
    }
    foreach ($skillName in @($scenario.must_exclude_skills)) {
        if ($computedSkills -contains [string] $skillName) {
            Add-Failure "[$($scenario.id)] Unexpected skill: $skillName"
            $scenarioFailed = $true
        }
    }

    if (-not $scenarioFailed) {
        $passed++
        Write-Host "PASS $($scenario.id): risk=$computedRisk confirmation=$computedConfirmation" -ForegroundColor Green
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Scenario routing FAILED: $passed/$($scenarioDocument.scenarios.Count) passed." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Scenario routing PASS: $passed/$($scenarioDocument.scenarios.Count) scenarios." -ForegroundColor Green
exit 0


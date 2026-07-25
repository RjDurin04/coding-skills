[CmdletBinding()]
param(
    [string] $Root,
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = Split-Path -Parent $scriptDirectory
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$routerPath = Join-Path $rootPath (('rules/governance-router.md') -replace '/', [System.IO.Path]::DirectorySeparatorChar)

function Read-Utf8Text {
    param([string] $Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function ConvertTo-LfText {
    param([string] $Text)

    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-OrdinalPropertyNames {
    param([object] $Object)

    [string[]] $names = @($Object.PSObject.Properties.Name)
    [System.Array]::Sort($names, [System.StringComparer]::Ordinal)
    return $names
}

function ConvertTo-MarkdownCell {
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value) {
        return 'none'
    }

    $text = ([string] $Value) -replace '\r?\n', ' '
    return $text.Replace('|', '\|').Trim()
}

function ConvertTo-CodeList {
    param([object[]] $Values)

    $tick = [char] 96
    $items = @($Values | ForEach-Object {
        $text = ConvertTo-MarkdownCell $_
        [string] $tick + $text.Replace('`', '') + [string] $tick
    })
    if ($items.Count -eq 0) {
        return 'none'
    }
    return $items -join ', '
}

function Replace-GeneratedSection {
    param(
        [string] $Content,
        [string] $Name,
        [string[]] $Lines,
        [string] $NewLine
    )

    $beginMarker = "<!-- BEGIN GENERATED: $Name -->"
    $endMarker = "<!-- END GENERATED: $Name -->"
    $pattern = '(?ms)^' + [regex]::Escape($beginMarker) + '\s*$.*?^' + [regex]::Escape($endMarker) + '\s*$'
    $matches = [regex]::Matches($Content, $pattern)
    if ($matches.Count -ne 1) {
        throw "Router must contain exactly one generated marker pair for '$Name'; found $($matches.Count)."
    }

    $body = @($beginMarker) + @($Lines) + @($endMarker)
    return [regex]::Replace($Content, $pattern, ($body -join $NewLine), 1)
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing governance manifest: $manifestPath"
}
if (-not (Test-Path -LiteralPath $routerPath -PathType Leaf)) {
    throw "Missing governance router: $routerPath"
}

try {
    $manifest = Read-Utf8Text $manifestPath | ConvertFrom-Json
}
catch {
    throw "Governance manifest is not valid JSON: $($_.Exception.Message)"
}

if (($manifest.PSObject.Properties.Name -notcontains 'schema_version') -or (([int] $manifest.schema_version) -ne 2)) {
    throw 'Router generation requires governance manifest schema_version 2.'
}
foreach ($property in @('task_modes', 'risk_order', 'confirmation_order', 'risk_overlays', 'routing_signals')) {
    if ($manifest.PSObject.Properties.Name -notcontains $property) {
        throw "Governance manifest is missing required router property: $property"
    }
}

$taskModeLines = @(
    '| Mode | Repository changes | External effects | Required signals | Description |',
    '|---|---:|---:|---|---|'
)
$canonicalTaskModes = @('answer', 'review', 'diagnose', 'design', 'implement', 'operate')
$actualTaskModes = @($manifest.task_modes.PSObject.Properties.Name)
if (($actualTaskModes.Count -ne $canonicalTaskModes.Count) -or
    (@(Compare-Object -ReferenceObject $canonicalTaskModes -DifferenceObject $actualTaskModes -SyncWindow 0).Count -gt 0)) {
    throw "Manifest task_modes must preserve canonical order: $($canonicalTaskModes -join ', ')."
}
foreach ($modeName in $canonicalTaskModes) {
    $property = $manifest.task_modes.PSObject.Properties[$modeName]
    $mode = $property.Value
    $taskModeLines += '| ' +
        (ConvertTo-CodeList @($property.Name)) + ' | ' +
        ([string] [bool] $mode.allows_repository_changes).ToLowerInvariant() + ' | ' +
        ([string] [bool] $mode.allows_external_effects).ToLowerInvariant() + ' | ' +
        (ConvertTo-CodeList @($mode.required_signals)) + ' | ' +
        (ConvertTo-MarkdownCell $mode.description) + ' |'
}

$routingSignalLines = @(
    '| Signal | Minimum risk | Confirmation | Rules | Lead skill | Supporting skills | Description |',
    '|---|---|---|---|---|---|---|'
)
foreach ($propertyName in @(Get-OrdinalPropertyNames $manifest.routing_signals)) {
    $signal = $manifest.routing_signals.PSObject.Properties[$propertyName].Value
    $lead = if ($null -eq $signal.lead_skill) {
        'none'
    }
    else {
        ConvertTo-CodeList @($signal.lead_skill)
    }
    $routingSignalLines += '| ' +
        (ConvertTo-CodeList @($propertyName)) + ' | ' +
        (ConvertTo-CodeList @($signal.minimum_risk)) + ' | ' +
        (ConvertTo-CodeList @($signal.confirmation)) + ' | ' +
        (ConvertTo-CodeList @($signal.rules)) + ' | ' +
        $lead + ' | ' +
        (ConvertTo-CodeList @($signal.supporting_skills)) + ' | ' +
        (ConvertTo-MarkdownCell $signal.description) + ' |'
}

$riskOverlayLines = @(
    '| Applies at or above | Rules | Supporting skills |',
    '|---|---|---|'
)
$riskRank = @{}
for ($riskIndex = 0; $riskIndex -lt @($manifest.risk_order).Count; $riskIndex++) {
    $riskRank[[string] $manifest.risk_order[$riskIndex]] = $riskIndex
}
foreach ($overlay in @($manifest.risk_overlays)) {
    if (-not $riskRank.ContainsKey([string] $overlay.minimum_risk)) {
        throw "Risk overlay references unknown minimum_risk '$($overlay.minimum_risk)'."
    }
}
$orderedRiskOverlays = @($manifest.risk_overlays | Sort-Object @{
    Expression = { [int] $riskRank[[string] $_.minimum_risk] }
})
foreach ($overlay in $orderedRiskOverlays) {
    $riskOverlayLines += '| ' +
        (ConvertTo-CodeList @($overlay.minimum_risk)) + ' | ' +
        (ConvertTo-CodeList @($overlay.rules)) + ' | ' +
        (ConvertTo-CodeList @($overlay.supporting_skills)) + ' |'
}
if (@($manifest.risk_overlays).Count -eq 0) {
    $riskOverlayLines += '| none | none | none |'
}

$current = ConvertTo-LfText (Read-Utf8Text $routerPath)
$newLine = "`n"
$generated = $current
$generated = Replace-GeneratedSection $generated 'TASK MODES' $taskModeLines $newLine
$generated = Replace-GeneratedSection $generated 'ROUTING SIGNALS' $routingSignalLines $newLine
$generated = Replace-GeneratedSection $generated 'RISK OVERLAYS' $riskOverlayLines $newLine

if ($Check) {
    if (-not [string]::Equals($current, $generated, [System.StringComparison]::Ordinal)) {
        Write-Host 'Governance router generated sections are stale. Run scripts/generate-governance-router.ps1.' -ForegroundColor Red
        exit 1
    }

    Write-Host 'Governance router generated sections are current.' -ForegroundColor Green
    exit 0
}

if ([string]::Equals($current, $generated, [System.StringComparison]::Ordinal)) {
    Write-Host 'Governance router generated sections already current.' -ForegroundColor Green
    exit 0
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($routerPath, $generated, $utf8WithoutBom)
Write-Host 'Updated generated sections in rules/governance-router.md.' -ForegroundColor Green
exit 0

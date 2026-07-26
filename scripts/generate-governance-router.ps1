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
$geminiPath = Join-Path $rootPath 'GEMINI.md'

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
if (-not (Test-Path -LiteralPath $geminiPath -PathType Leaf)) {
    throw "Missing compact governance entrypoint: $geminiPath"
}

try {
    $manifest = Read-Utf8Text $manifestPath | ConvertFrom-Json
}
catch {
    throw "Governance manifest is not valid JSON: $($_.Exception.Message)"
}

if (($manifest.PSObject.Properties.Name -notcontains 'schema_version') -or (([int] $manifest.schema_version) -ne 3)) {
    throw 'Router generation requires governance manifest schema_version 3.'
}
foreach ($property in @(
    'task_modes',
    'risk_order',
    'confirmation_order',
    'risk_overlays',
    'routing_signals',
    'fast_path',
    'policy_clauses',
    'status_namespaces'
)) {
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

$policyClauseLines = @(
    '| Clause | Canonical owner | Generated summary |',
    '|---|---|---|'
)
foreach ($clause in @($manifest.policy_clauses)) {
    $policyClauseLines += '| ' +
        (ConvertTo-CodeList @($clause.id)) + ' | ' +
        (ConvertTo-CodeList @($clause.owner_path)) + ' | ' +
        (ConvertTo-MarkdownCell $clause.summary) + ' |'
}

$fastPathLines = @(
    ('Use the precompiled baseline only for mode ' +
        (ConvertTo-CodeList @($manifest.fast_path.eligible_modes)) +
        ' with signals ' +
        (ConvertTo-CodeList @($manifest.fast_path.allowed_signals)) +
        '.'),
    '',
    'Every check below must be demonstrably false:'
)
foreach ($exclusionCheck in @($manifest.fast_path.exclusion_checks)) {
    $fastPathLines += "- $(ConvertTo-MarkdownCell $exclusionCheck)"
}
$fastPathLines += @(
    '',
    'If any exclusion is true or unknown, stop the fast path and apply the full',
    'manifest router. On the baseline, inspect the supplied target/context, make',
    'no state change or external effect, use the cheapest check that could',
    'falsify the answer when one exists, and disclose material evidence gaps.',
    'Task outcome, release readiness, and external-action status remain separate.'
)

$statusNamespaceLabels = [ordered]@{
    claim_certainty = 'Claim certainty'
    requirement_status = 'Requirement status'
    finding_severity = 'Finding severity'
    gate_assessment = 'Gate assessment'
    evaluation_result = 'Evaluation result'
    task_outcome = 'Task outcome'
    release_readiness = 'Release readiness'
    external_action = 'External action'
}
$statusNamespaceLines = @(
    '| Namespace | Values |',
    '|---|---|'
)
foreach ($namespace in $statusNamespaceLabels.Keys) {
    $statusNamespaceLines += '| ' +
        (ConvertTo-MarkdownCell $statusNamespaceLabels[$namespace]) + ' | ' +
        (ConvertTo-CodeList @($manifest.status_namespaces.$namespace)) + ' |'
}

$current = ConvertTo-LfText (Read-Utf8Text $routerPath)
$geminiCurrent = ConvertTo-LfText (Read-Utf8Text $geminiPath)
$newLine = "`n"
$generated = $current
$generated = Replace-GeneratedSection $generated 'TASK MODES' $taskModeLines $newLine
$generated = Replace-GeneratedSection $generated 'ROUTING SIGNALS' $routingSignalLines $newLine
$generated = Replace-GeneratedSection $generated 'RISK OVERLAYS' $riskOverlayLines $newLine
$generated = Replace-GeneratedSection $generated 'POLICY CLAUSES' $policyClauseLines $newLine
$geminiGenerated = $geminiCurrent
$geminiGenerated = Replace-GeneratedSection $geminiGenerated 'FAST PATH' $fastPathLines $newLine
$geminiGenerated = Replace-GeneratedSection $geminiGenerated 'STATUS NAMESPACES' $statusNamespaceLines $newLine

if ($Check) {
    if ((-not [string]::Equals($current, $generated, [System.StringComparison]::Ordinal)) -or
        (-not [string]::Equals($geminiCurrent, $geminiGenerated, [System.StringComparison]::Ordinal))) {
        Write-Host 'Generated governance sections are stale. Run scripts/generate-governance-router.ps1.' -ForegroundColor Red
        exit 1
    }

    Write-Host 'Generated governance sections are current.' -ForegroundColor Green
    exit 0
}

if ([string]::Equals($current, $generated, [System.StringComparison]::Ordinal) -and
    [string]::Equals($geminiCurrent, $geminiGenerated, [System.StringComparison]::Ordinal)) {
    Write-Host 'Generated governance sections already current.' -ForegroundColor Green
    exit 0
}

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
if (-not [string]::Equals($current, $generated, [System.StringComparison]::Ordinal)) {
    [System.IO.File]::WriteAllText($routerPath, $generated, $utf8WithoutBom)
}
if (-not [string]::Equals($geminiCurrent, $geminiGenerated, [System.StringComparison]::Ordinal)) {
    [System.IO.File]::WriteAllText($geminiPath, $geminiGenerated, $utf8WithoutBom)
}
Write-Host 'Updated generated governance sections.' -ForegroundColor Green
exit 0

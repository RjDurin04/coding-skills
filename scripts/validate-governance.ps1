[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$rootPrefix = $rootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)
    $failures.Add($Message)
}

function Read-Utf8 {
    param([string] $Path)
    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

function Resolve-PackPath {
    param([string] $RelativePath)

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath ($RelativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    if (($candidate -ne $rootPath) -and (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        Add-Failure "Path escapes pack root: $RelativePath"
        return $null
    }

    return $candidate
}

function Get-FrontMatterValue {
    param(
        [string] $Path,
        [string] $Key
    )

    $lines = @(Get-Content -Encoding UTF8 -LiteralPath $Path)
    if (($lines.Count -eq 0) -or ($lines[0].Trim() -ne '---')) {
        return $null
    }

    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            break
        }

        if ($lines[$index] -match ('^' + [regex]::Escape($Key) + ':\s*(.+)$')) {
            return $Matches[1].Trim()
        }
    }

    return $null
}

function Get-QuotedYamlValue {
    param(
        [string] $Content,
        [string] $Key
    )

    $pattern = '(?m)^\s+' + [regex]::Escape($Key) + ':\s+"([^"]*)"\s*$'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

function Assert-UniqueNames {
    param(
        [object[]] $Entries,
        [string] $Kind
    )

    $duplicates = @($Entries | Group-Object -Property name | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicates) {
        Add-Failure "Duplicate $Kind name in manifest: $($duplicate.Name)"
    }
}

function Assert-SameSet {
    param(
        [string[]] $Expected,
        [string[]] $Actual,
        [string] $Label
    )

    $differences = @(Compare-Object -ReferenceObject @($Expected | Sort-Object -Unique) -DifferenceObject @($Actual | Sort-Object -Unique))
    foreach ($difference in $differences) {
        Add-Failure "$Label mismatch ($($difference.SideIndicator)): $($difference.InputObject)"
    }
}

$manifestPath = Resolve-PackPath 'governance-manifest.json'
if (($null -eq $manifestPath) -or (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf))) {
    Add-Failure 'Missing governance-manifest.json.'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

try {
    $manifest = Read-Utf8 $manifestPath | ConvertFrom-Json
}
catch {
    Add-Failure "Manifest is not valid JSON: $($_.Exception.Message)"
    $manifest = $null
}

if ($null -eq $manifest) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$requiredManifestProperties = @(
    'schema_version',
    'pack_version',
    'entrypoints',
    'project_profile',
    'project_profile_template',
    'capability_evaluations',
    'unified_delivery_fields',
    'risk_order',
    'confirmation_order',
    'rules',
    'skills',
    'risk_overlays',
    'routing_signals'
)
foreach ($property in $requiredManifestProperties) {
    if ($manifest.PSObject.Properties.Name -notcontains $property) {
        Add-Failure "Manifest is missing property: $property"
    }
}

$geminiPath = Resolve-PackPath 'GEMINI.md'
$routerPath = Resolve-PackPath 'rules/governance-router.md'
$gemini = Read-Utf8 $geminiPath
$router = Read-Utf8 $routerPath

if ($gemini -notmatch ('Governance pack version:\s*\*\*' + [regex]::Escape([string] $manifest.pack_version) + '\*\*')) {
    Add-Failure "GEMINI.md pack version does not match manifest version $($manifest.pack_version)."
}

foreach ($entrypoint in @($manifest.entrypoints)) {
    $entrypointPath = Resolve-PackPath ([string] $entrypoint)
    if (($null -eq $entrypointPath) -or (-not (Test-Path -LiteralPath $entrypointPath -PathType Leaf))) {
        Add-Failure "Missing manifest entrypoint: $entrypoint"
    }
}

$templatePath = Resolve-PackPath ([string] $manifest.project_profile_template)
if (($null -eq $templatePath) -or (-not (Test-Path -LiteralPath $templatePath -PathType Leaf))) {
    Add-Failure "Missing project profile template: $($manifest.project_profile_template)"
}

$evaluationCatalogPath = Resolve-PackPath ([string] $manifest.capability_evaluations.catalog)
if (($null -eq $evaluationCatalogPath) -or (-not (Test-Path -LiteralPath $evaluationCatalogPath -PathType Leaf))) {
    Add-Failure "Missing capability evaluation catalog: $($manifest.capability_evaluations.catalog)"
}
$evaluationValidatorPath = Resolve-PackPath ([string] $manifest.capability_evaluations.validator)
if (($null -eq $evaluationValidatorPath) -or (-not (Test-Path -LiteralPath $evaluationValidatorPath -PathType Leaf))) {
    Add-Failure "Missing capability evaluation validator: $($manifest.capability_evaluations.validator)"
}
$evaluationScorerPath = Resolve-PackPath ([string] $manifest.capability_evaluations.scorer)
if (($null -eq $evaluationScorerPath) -or (-not (Test-Path -LiteralPath $evaluationScorerPath -PathType Leaf))) {
    Add-Failure "Missing capability evaluation scorer: $($manifest.capability_evaluations.scorer)"
}
$evaluationRunTemplatePath = Resolve-PackPath ([string] $manifest.capability_evaluations.run_template)
if (($null -eq $evaluationRunTemplatePath) -or (-not (Test-Path -LiteralPath $evaluationRunTemplatePath -PathType Leaf))) {
    Add-Failure "Missing capability evaluation run template: $($manifest.capability_evaluations.run_template)"
}

Assert-UniqueNames @($manifest.rules) 'rule'
Assert-UniqueNames @($manifest.skills) 'skill'

$manifestRulePaths = @($manifest.rules | ForEach-Object { [string] $_.path })
$actualRulePaths = @(Get-ChildItem -File -LiteralPath (Join-Path $rootPath 'rules') -Filter '*.md' | ForEach-Object {
    'rules/' + $_.Name
})
Assert-SameSet $manifestRulePaths $actualRulePaths 'Rule inventory'

$manifestSkillPaths = @($manifest.skills | ForEach-Object { [string] $_.path })
$actualSkillPaths = @(Get-ChildItem -Directory -LiteralPath (Join-Path $rootPath 'skills') | ForEach-Object {
    'skills/' + $_.Name + '/SKILL.md'
})
Assert-SameSet $manifestSkillPaths $actualSkillPaths 'Skill inventory'

$ruleNames = @($manifest.rules | ForEach-Object { [string] $_.name })
$skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })

foreach ($rule in @($manifest.rules)) {
    $path = Resolve-PackPath ([string] $rule.path)
    if (($null -eq $path) -or (-not (Test-Path -LiteralPath $path -PathType Leaf))) {
        Add-Failure "Missing rule file: $($rule.path)"
        continue
    }

    $frontMatterName = Get-FrontMatterValue $path 'name'
    $trigger = Get-FrontMatterValue $path 'trigger'
    if ($frontMatterName -ne [string] $rule.name) {
        Add-Failure "Rule name mismatch for $($rule.path): manifest='$($rule.name)' frontmatter='$frontMatterName'"
    }
    if ([string]::IsNullOrWhiteSpace($trigger)) {
        Add-Failure "Rule is missing a frontmatter trigger: $($rule.path)"
    }
    if (-not $gemini.Contains('`' + [string] $rule.path + '`')) {
        Add-Failure "GEMINI.md rule index is missing: $($rule.path)"
    }
}

foreach ($skill in @($manifest.skills)) {
    $path = Resolve-PackPath ([string] $skill.path)
    if (($null -eq $path) -or (-not (Test-Path -LiteralPath $path -PathType Leaf))) {
        Add-Failure "Missing skill file: $($skill.path)"
        continue
    }

    $frontMatterName = Get-FrontMatterValue $path 'name'
    if ($frontMatterName -ne [string] $skill.name) {
        Add-Failure "Skill name mismatch for $($skill.path): manifest='$($skill.name)' frontmatter='$frontMatterName'"
    }
    if (-not $gemini.Contains('| `' + [string] $skill.name + '` |')) {
        Add-Failure "GEMINI.md skill index is missing: $($skill.name)"
    }

    $skillLines = @(Get-Content -Encoding UTF8 -LiteralPath $path)
    if ($skillLines.Count -gt 500) {
        Add-Failure "Skill exceeds the 500-line progressive-disclosure limit: $($skill.path)"
    }
    if ((Read-Utf8 $path) -match '(?i)\[?TODO(?::|\])') {
        Add-Failure "Skill contains unresolved TODO content: $($skill.path)"
    }

    if ($skill.PSObject.Properties.Name -contains 'ui_metadata') {
        $metadataPath = Resolve-PackPath ([string] $skill.ui_metadata)
        if (($null -eq $metadataPath) -or (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf))) {
            Add-Failure "Missing skill UI metadata: $($skill.ui_metadata)"
            continue
        }

        $metadata = Read-Utf8 $metadataPath
        $displayName = Get-QuotedYamlValue $metadata 'display_name'
        $shortDescription = Get-QuotedYamlValue $metadata 'short_description'
        $defaultPrompt = Get-QuotedYamlValue $metadata 'default_prompt'
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            Add-Failure "Skill UI metadata has no quoted display_name: $($skill.ui_metadata)"
        }
        if ([string]::IsNullOrWhiteSpace($shortDescription) -or ($shortDescription.Length -lt 25) -or ($shortDescription.Length -gt 64)) {
            Add-Failure "Skill UI short_description must be 25-64 characters: $($skill.ui_metadata)"
        }
        if ([string]::IsNullOrWhiteSpace($defaultPrompt) -or (-not $defaultPrompt.Contains('$' + [string] $skill.name))) {
            Add-Failure "Skill UI default_prompt must mention `$$($skill.name): $($skill.ui_metadata)"
        }
    }
}

foreach ($field in @($manifest.unified_delivery_fields)) {
    if (-not $gemini.Contains([string] $field + ':')) {
        Add-Failure "Unified delivery record is missing field: $field"
    }
}

$standaloneOutputs = @(Select-String -Path (Join-Path $rootPath 'rules\*.md') -Pattern '^## Output$' -Encoding UTF8)
if ($standaloneOutputs.Count -gt 0) {
    foreach ($match in $standaloneOutputs) {
        Add-Failure "Standalone rule output remains at $($match.Path):$($match.LineNumber)"
    }
}

$markdownFiles = @(Get-ChildItem -Recurse -File -LiteralPath $rootPath -Filter '*.md')
$referencePattern = '(?<![A-Za-z0-9_])(?<path>(?:rules/[A-Za-z0-9_-]+\.md|skills/[A-Za-z0-9_-]+/SKILL\.md|templates/[A-Za-z0-9_.-]+\.md|scripts/[A-Za-z0-9_.-]+\.ps1|tests/[A-Za-z0-9_.-]+\.(?:ps1|json)|governance-manifest\.json))'
foreach ($file in $markdownFiles) {
    $content = Read-Utf8 $file.FullName
    foreach ($match in [regex]::Matches($content, $referencePattern)) {
        $relativePath = $match.Groups['path'].Value
        $resolved = Resolve-PackPath $relativePath
        if (($null -eq $resolved) -or (-not (Test-Path -LiteralPath $resolved -PathType Leaf))) {
            Add-Failure "Broken local reference in $($file.FullName): $relativePath"
        }
    }
}

$allMarkdown = ($markdownFiles | ForEach-Object { Read-Utf8 $_.FullName }) -join "`n"
$forbiddenText = @(
    'MTTR > MTBF',
    'All boxes mandatory',
    'Priority: honesty/safety > explicit user requirement > correctness/data/security'
)
foreach ($text in $forbiddenText) {
    if ($allMarkdown.Contains($text)) {
        Add-Failure "Forbidden obsolete policy text remains: $text"
    }
}

$riskValues = @($manifest.risk_order | ForEach-Object { [string] $_ })
$confirmationValues = @($manifest.confirmation_order | ForEach-Object { [string] $_ })
$signalProperties = @($manifest.routing_signals.PSObject.Properties)
foreach ($signalProperty in $signalProperties) {
    $signal = $signalProperty.Value
    if ($riskValues -notcontains [string] $signal.minimum_risk) {
        Add-Failure "Routing signal '$($signalProperty.Name)' has invalid risk: $($signal.minimum_risk)"
    }
    if ($confirmationValues -notcontains [string] $signal.confirmation) {
        Add-Failure "Routing signal '$($signalProperty.Name)' has invalid confirmation: $($signal.confirmation)"
    }
    foreach ($ruleName in @($signal.rules)) {
        if ($ruleNames -notcontains [string] $ruleName) {
            Add-Failure "Routing signal '$($signalProperty.Name)' references unknown rule: $ruleName"
        }
    }
    foreach ($skillName in @($signal.skills)) {
        if ($skillNames -notcontains [string] $skillName) {
            Add-Failure "Routing signal '$($signalProperty.Name)' references unknown skill: $skillName"
        }
    }
}

foreach ($overlay in @($manifest.risk_overlays)) {
    if ($riskValues -notcontains [string] $overlay.minimum_risk) {
        Add-Failure "Risk overlay has invalid minimum risk: $($overlay.minimum_risk)"
    }
    foreach ($ruleName in @($overlay.rules)) {
        if ($ruleNames -notcontains [string] $ruleName) {
            Add-Failure "Risk overlay references unknown rule: $ruleName"
        }
    }
    foreach ($skillName in @($overlay.skills)) {
        if ($skillNames -notcontains [string] $skillName) {
            Add-Failure "Risk overlay references unknown skill: $skillName"
        }
    }
}

$scenarioPath = Resolve-PackPath 'tests/governance-scenarios.json'
if (($null -eq $scenarioPath) -or (-not (Test-Path -LiteralPath $scenarioPath -PathType Leaf))) {
    Add-Failure 'Missing tests/governance-scenarios.json.'
}
else {
    try {
        $scenarioDocument = Read-Utf8 $scenarioPath | ConvertFrom-Json
        $scenarios = @($scenarioDocument.scenarios)
        if (($scenarios.Count -lt 30) -or ($scenarios.Count -gt 60)) {
            Add-Failure "Expected 30-60 governance scenarios, found $($scenarios.Count)."
        }

        $duplicateScenarioIds = @($scenarios | Group-Object -Property id | Where-Object Count -gt 1)
        foreach ($duplicate in $duplicateScenarioIds) {
            Add-Failure "Duplicate governance scenario id: $($duplicate.Name)"
        }

        foreach ($scenario in $scenarios) {
            if (@($scenario.signals) -notcontains 'durable_task') {
                Add-Failure "Scenario '$($scenario.id)' is missing durable_task."
            }
            if ($riskValues -notcontains [string] $scenario.expected_risk) {
                Add-Failure "Scenario '$($scenario.id)' has invalid expected risk: $($scenario.expected_risk)"
            }
            if ($confirmationValues -notcontains [string] $scenario.expected_confirmation) {
                Add-Failure "Scenario '$($scenario.id)' has invalid expected confirmation: $($scenario.expected_confirmation)"
            }
            foreach ($signalName in @($scenario.signals)) {
                if ($manifest.routing_signals.PSObject.Properties.Name -notcontains [string] $signalName) {
                    Add-Failure "Scenario '$($scenario.id)' references unknown signal: $signalName"
                }
            }
            foreach ($ruleName in @($scenario.must_include_rules) + @($scenario.must_exclude_rules)) {
                if ($ruleNames -notcontains [string] $ruleName) {
                    Add-Failure "Scenario '$($scenario.id)' references unknown rule: $ruleName"
                }
            }
            foreach ($skillName in @($scenario.must_include_skills) + @($scenario.must_exclude_skills)) {
                if ($skillNames -notcontains [string] $skillName) {
                    Add-Failure "Scenario '$($scenario.id)' references unknown skill: $skillName"
                }
            }
        }
    }
    catch {
        Add-Failure "Scenario document is invalid: $($_.Exception.Message)"
    }
}

if (-not $router.Contains('`agent-operation-safety`')) {
    Add-Failure 'Governance router does not route agent-operation-safety.'
}
if (-not $router.Contains('`operational-resilience`')) {
    Add-Failure 'Governance router does not route operational-resilience.'
}
if (-not $router.Contains('`ai-system-safety`')) {
    Add-Failure 'Governance router does not route ai-system-safety.'
}

if ($failures.Count -gt 0) {
    Write-Host "Governance validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Governance validation PASS: $($manifest.rules.Count) rules, $($manifest.skills.Count) skills, $($signalProperties.Count) routing signals, and $($scenarioDocument.scenarios.Count) scenarios." -ForegroundColor Green
exit 0

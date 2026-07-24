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
$rootPrefix = $rootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$failures = New-Object 'System.Collections.Generic.List[string]'
$riskValues = @('trivial', 'standard', 'structural', 'critical')
$confirmationValues = @('none', 'explicit_authorization', 'fresh_confirmation')
$canonicalTaskModes = @('answer', 'review', 'diagnose', 'design', 'implement', 'operate')
$semverPattern = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
$namePattern = '^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$'
$signalPattern = '^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$'

function Add-Failure {
    param([string] $Message)

    $failures.Add($Message)
}

function Read-Utf8 {
    param([string] $Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Test-Integer {
    param([AllowNull()] [object] $Value)

    return ($Value -is [byte]) -or
        ($Value -is [sbyte]) -or
        ($Value -is [int16]) -or
        ($Value -is [uint16]) -or
        ($Value -is [int32]) -or
        ($Value -is [uint32]) -or
        ($Value -is [int64]) -or
        ($Value -is [uint64])
}

function Test-Number {
    param([AllowNull()] [object] $Value)

    $isNumeric = (Test-Integer $Value) -or
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

function Assert-StringArray {
    param(
        [AllowNull()] [object] $Value,
        [string] $Label,
        [switch] $AllowEmpty
    )

    if (($null -eq $Value) -or ($Value -is [string]) -or ($Value -isnot [System.Array])) {
        Add-Failure "$Label must be an array of strings."
        return @()
    }

    $items = @($Value)
    if ((-not $AllowEmpty) -and ($items.Count -eq 0)) {
        Add-Failure "$Label cannot be empty."
    }

    $strings = @()
    foreach ($item in $items) {
        if (($item -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $item)) {
            Add-Failure "$Label contains a blank or non-string value."
            continue
        }
        $strings += [string] $item
    }

    foreach ($duplicate in @($strings | Group-Object | Where-Object Count -gt 1)) {
        Add-Failure "$Label contains duplicate value: $($duplicate.Name)"
    }
    return $strings
}

function Assert-NonBlankString {
    param(
        [AllowNull()] [object] $Value,
        [string] $Label
    )

    if (($Value -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $Value)) {
        Add-Failure "$Label must be a nonblank string."
        return $false
    }
    return $true
}

function Assert-PackPath {
    param(
        [AllowNull()] [object] $Value,
        [string] $Label
    )

    if (-not (Assert-NonBlankString $Value $Label)) {
        return $null
    }

    $relativePath = [string] $Value
    if ([System.IO.Path]::IsPathRooted($relativePath) -or $relativePath.Contains('\')) {
        Add-Failure "$Label must be a forward-slash relative pack path: $relativePath"
        return $null
    }
    $segments = @($relativePath.Split('/'))
    if (($segments.Count -eq 0) -or (@($segments | Where-Object { ($_ -eq '.') -or ($_ -eq '..') -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)) {
        Add-Failure "$Label contains an unsafe path segment: $relativePath"
        return $null
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    if (($candidate -ne $rootPath) -and (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
        Add-Failure "$Label escapes pack root: $relativePath"
        return $null
    }
    return $candidate
}

function Assert-ExistingPackFile {
    param(
        [AllowNull()] [object] $Value,
        [string] $Label
    )

    $path = Assert-PackPath $Value $Label
    if (($null -ne $path) -and (-not (Test-Path -LiteralPath $path -PathType Leaf))) {
        Add-Failure "$Label does not exist: $Value"
    }
    return $path
}

function Assert-SameSet {
    param(
        [string[]] $Expected,
        [string[]] $Actual,
        [string] $Label
    )

    $difference = @(Compare-Object -ReferenceObject @($Expected | Sort-Object -Unique) -DifferenceObject @($Actual | Sort-Object -Unique))
    foreach ($item in $difference) {
        Add-Failure "$Label mismatch ($($item.SideIndicator)): $($item.InputObject)"
    }
}

function Get-FrontMatterValue {
    param(
        [string] $Path,
        [string] $Key
    )

    $lines = @([System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8))
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

    $match = [regex]::Match($Content, ('(?m)^\s+' + [regex]::Escape($Key) + ':\s+"([^"]*)"\s*$'))
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Assert-ExactSet {
    param(
        [string[]] $Actual,
        [string[]] $Expected,
        [string] $Label
    )

    $difference = @(Compare-Object -ReferenceObject @($Expected | Sort-Object -Unique) -DifferenceObject @($Actual | Sort-Object -Unique))
    if ($difference.Count -gt 0) {
        Add-Failure "$Label must be exactly [$($Expected -join ', ')]; found [$($Actual -join ', ')]."
    }
}

$manifestPath = Join-Path $rootPath 'governance-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Add-Failure 'Missing governance-manifest.json.'
}

if ($failures.Count -gt 0) {
    Write-Host "Governance validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
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
    Write-Host "Governance validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

$manifestProperties = @(
    '$schema',
    'schema_version',
    'pack_version',
    'entrypoints',
    'project_profile',
    'project_profile_template',
    'unified_delivery_fields',
    'task_modes',
    'risk_order',
    'confirmation_order',
    'rules',
    'skills',
    'project_overlays',
    'risk_overlays',
    'routing_signals',
    'schemas',
    'routing_evaluations',
    'capability_evaluations'
)
$manifestShapeValid = Assert-ObjectShape $manifest $manifestProperties @() 'Manifest'

if (($manifest.PSObject.Properties.Name -contains '$schema') -and ([string] $manifest.'$schema' -ne 'schemas/governance-manifest.schema.json')) {
    Add-Failure "Manifest `$schema must be 'schemas/governance-manifest.schema.json'."
}
if (($manifest.PSObject.Properties.Name -contains 'schema_version') -and ((-not (Test-Integer $manifest.schema_version)) -or ([int] $manifest.schema_version -ne 2))) {
    Add-Failure 'Manifest schema_version must be integer 2.'
}
if (($manifest.PSObject.Properties.Name -contains 'pack_version') -and
    ((-not (Assert-NonBlankString $manifest.pack_version 'Manifest pack_version')) -or ([string] $manifest.pack_version -notmatch $semverPattern))) {
    Add-Failure "Manifest pack_version must be valid SemVer: $($manifest.pack_version)"
}

$geminiPath = Join-Path $rootPath 'GEMINI.md'
$routerPath = Join-Path $rootPath (('rules/governance-router.md') -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$gemini = if (Test-Path -LiteralPath $geminiPath -PathType Leaf) { Read-Utf8 $geminiPath } else { ''; Add-Failure 'Missing GEMINI.md.' }
$router = if (Test-Path -LiteralPath $routerPath -PathType Leaf) { Read-Utf8 $routerPath } else { ''; Add-Failure 'Missing rules/governance-router.md.' }
if (($manifest.PSObject.Properties.Name -contains 'pack_version') -and
    ($gemini -notmatch ('Governance pack version:\s*\*\*' + [regex]::Escape([string] $manifest.pack_version) + '\*\*'))) {
    Add-Failure "GEMINI.md pack version does not match manifest version $($manifest.pack_version)."
}

if ($manifest.PSObject.Properties.Name -contains 'entrypoints') {
    $entrypoints = Assert-StringArray $manifest.entrypoints 'Manifest entrypoints'
    foreach ($entrypoint in $entrypoints) {
        [void](Assert-ExistingPackFile $entrypoint "Manifest entrypoint '$entrypoint'")
    }
}
if ($manifest.PSObject.Properties.Name -contains 'project_profile') {
    [void](Assert-NonBlankString $manifest.project_profile 'Manifest project_profile')
}
if ($manifest.PSObject.Properties.Name -contains 'project_profile_template') {
    [void](Assert-ExistingPackFile $manifest.project_profile_template 'Manifest project_profile_template')
}

$schemaProperties = @(
    'governance_manifest',
    'governance_scenarios',
    'routing_evaluations',
    'routing_run',
    'capability_evaluations',
    'capability_run'
)
$schemaExpectedPaths = [ordered]@{
    governance_manifest = 'schemas/governance-manifest.schema.json'
    governance_scenarios = 'schemas/governance-scenarios.schema.json'
    routing_evaluations = 'schemas/routing-evaluations.schema.json'
    routing_run = 'schemas/routing-evaluation-run.schema.json'
    capability_evaluations = 'schemas/capability-evaluations.schema.json'
    capability_run = 'schemas/capability-evaluation-run.schema.json'
}
$schemaExpectedIds = [ordered]@{
    governance_manifest = 'urn:portable-agent-governance:schema:governance-manifest:2'
    governance_scenarios = 'urn:portable-agent-governance:schema:governance-scenarios:2'
    routing_evaluations = 'urn:portable-agent-governance:schema:routing-evaluations:1'
    routing_run = 'urn:portable-agent-governance:schema:routing-evaluation-run:1'
    capability_evaluations = 'urn:portable-agent-governance:schema:capability-evaluations:2'
    capability_run = 'urn:portable-agent-governance:schema:capability-evaluation-run:2'
}
if (($manifest.PSObject.Properties.Name -contains 'schemas') -and (Assert-ObjectShape $manifest.schemas $schemaProperties @() 'Manifest schemas')) {
    foreach ($property in $schemaProperties) {
        $value = [string] $manifest.schemas.$property
        if ($value -ne [string] $schemaExpectedPaths[$property]) {
            Add-Failure "Manifest schemas.$property must be '$($schemaExpectedPaths[$property])'."
        }
        $schemaPath = Assert-ExistingPackFile $value "Manifest schemas.$property"
        if (($null -ne $schemaPath) -and (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
            try {
                $schemaDocument = Read-Utf8 $schemaPath | ConvertFrom-Json
                if (-not (Assert-ObjectShape $schemaDocument @('$schema', '$id', 'title', 'type') @('additionalProperties', 'required', 'properties', '$defs', 'items', 'allOf', 'anyOf', 'oneOf', 'description') "Schema '$value' root")) {
                    continue
                }
                if ([string] $schemaDocument.'$schema' -ne 'https://json-schema.org/draft/2020-12/schema') {
                    Add-Failure "Schema '$value' must identify JSON Schema draft 2020-12."
                }
                if (Assert-NonBlankString $schemaDocument.'$id' "Schema '$value' `$id") {
                    if ([string] $schemaDocument.'$id' -ne [string] $schemaExpectedIds[$property]) {
                        Add-Failure (
                            "Schema '$value' `$id must be '$($schemaExpectedIds[$property])'."
                        )
                    }
                }
                if (($schemaDocument.PSObject.Properties.Name -notcontains 'additionalProperties') -or
                    ($schemaDocument.additionalProperties -isnot [bool]) -or
                    ([bool] $schemaDocument.additionalProperties)) {
                    Add-Failure "Schema '$value' root additionalProperties must be false."
                }
            }
            catch {
                Add-Failure "Schema '$value' is not valid JSON: $($_.Exception.Message)"
            }
        }
    }
}

if (($manifest.PSObject.Properties.Name -contains 'risk_order')) {
    $manifestRisks = Assert-StringArray $manifest.risk_order 'Manifest risk_order'
    Assert-ExactSet $manifestRisks $riskValues 'Manifest risk_order'
    if (($manifestRisks -join '|') -ne ($riskValues -join '|')) {
        Add-Failure "Manifest risk_order must preserve order: $($riskValues -join ', ')."
    }
}
if (($manifest.PSObject.Properties.Name -contains 'confirmation_order')) {
    $manifestConfirmations = Assert-StringArray $manifest.confirmation_order 'Manifest confirmation_order'
    Assert-ExactSet $manifestConfirmations $confirmationValues 'Manifest confirmation_order'
    if (($manifestConfirmations -join '|') -ne ($confirmationValues -join '|')) {
        Add-Failure "Manifest confirmation_order must preserve order: $($confirmationValues -join ', ')."
    }
}

$ruleNames = @()
$skillNames = @()
if ($manifest.PSObject.Properties.Name -contains 'rules') {
    if (($manifest.rules -is [string]) -or ($manifest.rules -isnot [System.Array])) {
        Add-Failure 'Manifest rules must be an array.'
    }
    else {
        foreach ($rule in @($manifest.rules)) {
            if (-not (Assert-ObjectShape $rule @('name', 'path') @() 'Manifest rule')) {
                continue
            }
            if ((Assert-NonBlankString $rule.name 'Manifest rule name') -and ([string] $rule.name -notmatch $namePattern)) {
                Add-Failure "Manifest rule name must use lowercase kebab-case: $($rule.name)"
            }
            $ruleNames += [string] $rule.name
            $path = Assert-ExistingPackFile $rule.path "Manifest rule '$($rule.name)' path"
            if (($null -ne $path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                $frontMatterName = Get-FrontMatterValue $path 'name'
                $trigger = Get-FrontMatterValue $path 'trigger'
                if ($frontMatterName -ne [string] $rule.name) {
                    Add-Failure "Rule name mismatch for $($rule.path): manifest='$($rule.name)' frontmatter='$frontMatterName'"
                }
                if ([string]::IsNullOrWhiteSpace($trigger)) {
                    Add-Failure "Rule is missing a frontmatter trigger: $($rule.path)"
                }
            }
        }
    }
}
foreach ($duplicate in @($ruleNames | Group-Object | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate rule name in manifest: $($duplicate.Name)"
}

if ($manifest.PSObject.Properties.Name -contains 'skills') {
    if (($manifest.skills -is [string]) -or ($manifest.skills -isnot [System.Array])) {
        Add-Failure 'Manifest skills must be an array.'
    }
    else {
        foreach ($skill in @($manifest.skills)) {
            if (-not (Assert-ObjectShape $skill @('name', 'path') @('ui_metadata') 'Manifest skill')) {
                continue
            }
            if ((Assert-NonBlankString $skill.name 'Manifest skill name') -and ([string] $skill.name -notmatch $namePattern)) {
                Add-Failure "Manifest skill name must use lowercase kebab-case: $($skill.name)"
            }
            $skillNames += [string] $skill.name
            $path = Assert-ExistingPackFile $skill.path "Manifest skill '$($skill.name)' path"
            if (($null -ne $path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                $frontMatterName = Get-FrontMatterValue $path 'name'
                if ($frontMatterName -ne [string] $skill.name) {
                    Add-Failure "Skill name mismatch for $($skill.path): manifest='$($skill.name)' frontmatter='$frontMatterName'"
                }
                $skillLines = @([System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8))
                if ($skillLines.Count -gt 500) {
                    Add-Failure "Skill exceeds the 500-line progressive-disclosure limit: $($skill.path)"
                }
                if ((Read-Utf8 $path) -match '(?i)\[?TODO(?::|\])') {
                    Add-Failure "Skill contains unresolved TODO content: $($skill.path)"
                }
            }

            if ($skill.PSObject.Properties.Name -contains 'ui_metadata') {
                $metadataPath = Assert-ExistingPackFile $skill.ui_metadata "Manifest skill '$($skill.name)' ui_metadata"
                if (($null -ne $metadataPath) -and (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
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
        }
    }
}
foreach ($duplicate in @($skillNames | Group-Object | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate skill name in manifest: $($duplicate.Name)"
}

if ((Test-Path -LiteralPath (Join-Path $rootPath 'rules') -PathType Container) -and ($ruleNames.Count -gt 0)) {
    $manifestRulePaths = @($manifest.rules | ForEach-Object { [string] $_.path })
    $actualRulePaths = @(Get-ChildItem -File -LiteralPath (Join-Path $rootPath 'rules') -Filter '*.md' | ForEach-Object { 'rules/' + $_.Name })
    Assert-SameSet $manifestRulePaths $actualRulePaths 'Rule inventory'
}
if ((Test-Path -LiteralPath (Join-Path $rootPath 'skills') -PathType Container) -and ($skillNames.Count -gt 0)) {
    $manifestSkillPaths = @($manifest.skills | ForEach-Object { [string] $_.path })
    $actualSkillPaths = @(Get-ChildItem -Directory -LiteralPath (Join-Path $rootPath 'skills') | ForEach-Object {
        $skillPath = Join-Path $_.FullName 'SKILL.md'
        if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
            'skills/' + $_.Name + '/SKILL.md'
        }
    })
    Assert-SameSet $manifestSkillPaths $actualSkillPaths 'Skill inventory'
}

$overlayNames = @()
if ($manifest.PSObject.Properties.Name -contains 'project_overlays') {
    if (($manifest.project_overlays -is [string]) -or ($manifest.project_overlays -isnot [System.Array])) {
        Add-Failure 'Manifest project_overlays must be an array.'
    }
    else {
        foreach ($overlay in @($manifest.project_overlays)) {
            if (-not (Assert-ObjectShape $overlay @('name', 'path', 'description') @() 'Manifest project overlay')) {
                continue
            }
            $overlayNames += [string] $overlay.name
            if ((Assert-NonBlankString $overlay.name 'Manifest project overlay name') -and ([string] $overlay.name -notmatch $namePattern)) {
                Add-Failure "Project overlay name must use lowercase kebab-case: $($overlay.name)"
            }
            [void](Assert-NonBlankString $overlay.description "Project overlay '$($overlay.name)' description")
            [void](Assert-ExistingPackFile $overlay.path "Project overlay '$($overlay.name)' path")
        }
    }
}
foreach ($duplicate in @($overlayNames | Group-Object | Where-Object Count -gt 1)) {
    Add-Failure "Duplicate project overlay name in manifest: $($duplicate.Name)"
}
$overlaysRoot = Join-Path $rootPath 'overlays'
if (Test-Path -LiteralPath $overlaysRoot -PathType Container) {
    $manifestOverlayPaths = @($manifest.project_overlays | ForEach-Object { [string] $_.path })
    $actualOverlayPaths = @(Get-ChildItem -Recurse -File -LiteralPath $overlaysRoot -Filter 'SKILL.md' | ForEach-Object {
        $_.FullName.Substring($rootPrefix.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    })
    Assert-SameSet $manifestOverlayPaths $actualOverlayPaths 'Project overlay inventory'
}

$signalProperties = @()
$signalNames = @()
if (($manifest.PSObject.Properties.Name -contains 'routing_signals') -and ($manifest.routing_signals -is [pscustomobject])) {
    $signalProperties = @($manifest.routing_signals.PSObject.Properties)
    foreach ($property in $signalProperties) {
        $signalName = [string] $property.Name
        $signalNames += $signalName
        if ($signalName -notmatch $signalPattern) {
            Add-Failure "Routing signal name must use lowercase snake_case: $signalName"
        }
        $signal = $property.Value
        if (-not (Assert-ObjectShape $signal @('description', 'minimum_risk', 'rules', 'lead_skill', 'supporting_skills', 'confirmation') @() "Routing signal '$signalName'")) {
            continue
        }
        [void](Assert-NonBlankString $signal.description "Routing signal '$signalName' description")
        if (($signal.minimum_risk -isnot [string]) -or ($riskValues -notcontains [string] $signal.minimum_risk)) {
            Add-Failure "Routing signal '$signalName' has invalid risk: $($signal.minimum_risk)"
        }
        if (($signal.confirmation -isnot [string]) -or ($confirmationValues -notcontains [string] $signal.confirmation)) {
            Add-Failure "Routing signal '$signalName' has invalid confirmation: $($signal.confirmation)"
        }
        $signalRules = Assert-StringArray $signal.rules "Routing signal '$signalName' rules" -AllowEmpty
        $signalSupports = Assert-StringArray $signal.supporting_skills "Routing signal '$signalName' supporting_skills" -AllowEmpty
        foreach ($ruleName in $signalRules) {
            if ($ruleNames -notcontains $ruleName) {
                Add-Failure "Routing signal '$signalName' references unknown rule: $ruleName"
            }
        }
        foreach ($skillName in $signalSupports) {
            if ($skillNames -notcontains $skillName) {
                Add-Failure "Routing signal '$signalName' references unknown supporting skill: $skillName"
            }
        }
        if (($null -ne $signal.lead_skill) -and
            (($signal.lead_skill -isnot [string]) -or [string]::IsNullOrWhiteSpace([string] $signal.lead_skill))) {
            Add-Failure "Routing signal '$signalName' lead_skill must be a nonblank string or null."
        }
        elseif (($null -ne $signal.lead_skill) -and ($skillNames -notcontains [string] $signal.lead_skill)) {
            Add-Failure "Routing signal '$signalName' references unknown lead skill: $($signal.lead_skill)"
        }
        elseif (($null -ne $signal.lead_skill) -and ($signalSupports -contains [string] $signal.lead_skill)) {
            Add-Failure "Routing signal '$signalName' repeats its lead_skill in supporting_skills: $($signal.lead_skill)"
        }
    }
}
else {
    Add-Failure 'Manifest routing_signals must be an object.'
}

$riskOverlays = @()
if ($manifest.PSObject.Properties.Name -contains 'risk_overlays') {
    if (($manifest.risk_overlays -is [string]) -or ($manifest.risk_overlays -isnot [System.Array])) {
        Add-Failure 'Manifest risk_overlays must be an array.'
    }
    else {
        $riskOverlays = @($manifest.risk_overlays)
        foreach ($overlay in $riskOverlays) {
            if (-not (Assert-ObjectShape $overlay @('minimum_risk', 'rules', 'supporting_skills') @() 'Risk overlay')) {
                continue
            }
            if (($overlay.minimum_risk -isnot [string]) -or ($riskValues -notcontains [string] $overlay.minimum_risk)) {
                Add-Failure "Risk overlay has invalid minimum risk: $($overlay.minimum_risk)"
            }
            foreach ($ruleName in @(Assert-StringArray $overlay.rules 'Risk overlay rules' -AllowEmpty)) {
                if ($ruleNames -notcontains $ruleName) {
                    Add-Failure "Risk overlay references unknown rule: $ruleName"
                }
            }
            foreach ($skillName in @(Assert-StringArray $overlay.supporting_skills 'Risk overlay supporting_skills' -AllowEmpty)) {
                if ($skillNames -notcontains $skillName) {
                    Add-Failure "Risk overlay references unknown supporting skill: $skillName"
                }
            }
        }
    }
}

if (($manifest.PSObject.Properties.Name -contains 'task_modes') -and ($manifest.task_modes -is [pscustomobject])) {
    Assert-ExactSet @($manifest.task_modes.PSObject.Properties.Name) $canonicalTaskModes 'Manifest task_modes'
    foreach ($modeName in $canonicalTaskModes) {
        if ($manifest.task_modes.PSObject.Properties.Name -notcontains $modeName) {
            continue
        }
        $mode = $manifest.task_modes.$modeName
        if (-not (Assert-ObjectShape $mode @('description', 'allows_repository_changes', 'allows_external_effects', 'required_signals') @() "Task mode '$modeName'")) {
            continue
        }
        [void](Assert-NonBlankString $mode.description "Task mode '$modeName' description")
        if ($mode.allows_repository_changes -isnot [bool]) {
            Add-Failure "Task mode '$modeName' allows_repository_changes must be boolean."
        }
        if ($mode.allows_external_effects -isnot [bool]) {
            Add-Failure "Task mode '$modeName' allows_external_effects must be boolean."
        }
        foreach ($signalName in @(Assert-StringArray $mode.required_signals "Task mode '$modeName' required_signals")) {
            if ($signalNames -notcontains $signalName) {
                Add-Failure "Task mode '$modeName' references unknown required signal: $signalName"
            }
        }
    }

    foreach ($readOnlyMode in @('answer', 'review', 'diagnose', 'design')) {
        if ($manifest.task_modes.PSObject.Properties.Name -contains $readOnlyMode) {
            $mode = $manifest.task_modes.$readOnlyMode
            if (($mode.allows_repository_changes -ne $false) -or ($mode.allows_external_effects -ne $false)) {
                Add-Failure "Task mode '$readOnlyMode' must be read-only and external-effect-free."
            }
            Assert-ExactSet @($mode.required_signals) @('durable_task') "Task mode '$readOnlyMode' required_signals"
        }
    }
    if ($manifest.task_modes.PSObject.Properties.Name -contains 'implement') {
        $mode = $manifest.task_modes.implement
        if (($mode.allows_repository_changes -ne $true) -or ($mode.allows_external_effects -ne $false)) {
            Add-Failure "Task mode 'implement' must allow repository changes but not external effects."
        }
        Assert-ExactSet @($mode.required_signals) @('durable_task', 'implementation_task') "Task mode 'implement' required_signals"
    }
    if ($manifest.task_modes.PSObject.Properties.Name -contains 'operate') {
        $mode = $manifest.task_modes.operate
        if (($mode.allows_repository_changes -ne $false) -or ($mode.allows_external_effects -ne $true)) {
            Add-Failure "Task mode 'operate' must forbid repository changes and allow external effects."
        }
        Assert-ExactSet @($mode.required_signals) @('durable_task', 'operational_action') "Task mode 'operate' required_signals"
    }
}
else {
    Add-Failure 'Manifest task_modes must be an object.'
}

$requiredSignals = @(
    'durable_task',
    'implementation_task',
    'pure_refactor',
    'test_logic_or_verification_change',
    'supply_chain_change',
    'repository_code_execution',
    'unfamiliar_or_privileged_repository_execution',
    'operational_action',
    'material_requirement_or_constraint',
    'artifact_build_or_distribution',
    'material_public_communication',
    'privacy_lifecycle',
    'release_design_or_configuration',
    'production_readiness_assessment',
    'shared_environment_release_execution',
    'configuration_or_feature_flag',
    'external_side_effect',
    'destructive_or_irreversible_action',
    'established_security_boundary',
    'security_sensitive',
    'credible_high_impact_harm',
    'bounded_credential_or_permission_action',
    'credential_permission_financial_or_legal_action'
)
foreach ($requiredSignal in $requiredSignals) {
    if ($signalNames -notcontains $requiredSignal) {
        Add-Failure "Manifest is missing mandatory routing signal: $requiredSignal"
    }
}

if ($signalNames -contains 'durable_task') {
    $durableRules = @($manifest.routing_signals.durable_task.rules)
    foreach ($requiredRule in @('governance-router', 'context-budget', 'adversarial-self-review', 'agent-operation-safety')) {
        if ($durableRules -notcontains $requiredRule) {
            Add-Failure "Routing signal 'durable_task' must include rule: $requiredRule"
        }
    }
    if ($durableRules -contains 'implementation-execution-protocol') {
        Add-Failure "Routing signal 'durable_task' must not include implementation-execution-protocol."
    }
}
if (($signalNames -contains 'implementation_task') -and
    (@($manifest.routing_signals.implementation_task.rules) -notcontains 'implementation-execution-protocol')) {
    Add-Failure "Routing signal 'implementation_task' must include implementation-execution-protocol."
}

$signalBaselines = @(
    [pscustomobject]@{ Name = 'pure_refactor'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'test_logic_or_verification_change'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'supply_chain_change'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'repository_code_execution'; Risk = 'trivial'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'unfamiliar_or_privileged_repository_execution'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'operational_action'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'material_requirement_or_constraint'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'artifact_build_or_distribution'; Risk = 'structural'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'material_public_communication'; Risk = 'critical'; Confirmation = 'fresh_confirmation' },
    [pscustomobject]@{ Name = 'privacy_lifecycle'; Risk = 'structural'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'release_design_or_configuration'; Risk = 'structural'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'production_readiness_assessment'; Risk = 'structural'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'shared_environment_release_execution'; Risk = 'critical'; Confirmation = 'fresh_confirmation' },
    [pscustomobject]@{ Name = 'configuration_or_feature_flag'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'external_side_effect'; Risk = 'standard'; Confirmation = 'explicit_authorization' },
    [pscustomobject]@{ Name = 'destructive_or_irreversible_action'; Risk = 'critical'; Confirmation = 'fresh_confirmation' },
    [pscustomobject]@{ Name = 'established_security_boundary'; Risk = 'standard'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'security_sensitive'; Risk = 'critical'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'credible_high_impact_harm'; Risk = 'critical'; Confirmation = 'none' },
    [pscustomobject]@{ Name = 'bounded_credential_or_permission_action'; Risk = 'standard'; Confirmation = 'explicit_authorization' },
    [pscustomobject]@{ Name = 'credential_permission_financial_or_legal_action'; Risk = 'critical'; Confirmation = 'fresh_confirmation' }
)
foreach ($baseline in $signalBaselines) {
    if ($signalNames -notcontains $baseline.Name) {
        continue
    }
    $signal = $manifest.routing_signals.($baseline.Name)
    if ([string] $signal.minimum_risk -ne $baseline.Risk) {
        Add-Failure "Routing signal '$($baseline.Name)' must have minimum_risk '$($baseline.Risk)'."
    }
    if ([string] $signal.confirmation -ne $baseline.Confirmation) {
        Add-Failure "Routing signal '$($baseline.Name)' must have confirmation '$($baseline.Confirmation)'."
    }
}
if ($signalNames -contains 'repository_code_execution') {
    Assert-ExactSet @($manifest.routing_signals.repository_code_execution.rules) @('agent-operation-safety') "Routing signal 'repository_code_execution' rules"
}
if ($signalNames -contains 'unfamiliar_or_privileged_repository_execution') {
    foreach ($requiredRule in @('agent-operation-safety', 'supply-chain-and-build-integrity')) {
        if (@($manifest.routing_signals.unfamiliar_or_privileged_repository_execution.rules) -notcontains $requiredRule) {
            Add-Failure "Routing signal 'unfamiliar_or_privileged_repository_execution' must include rule: $requiredRule"
        }
    }
}

$routedSkills = @()
foreach ($property in $signalProperties) {
    if ($null -ne $property.Value.lead_skill) {
        $routedSkills += [string] $property.Value.lead_skill
    }
    $routedSkills += @($property.Value.supporting_skills | ForEach-Object { [string] $_ })
}
foreach ($overlay in $riskOverlays) {
    $routedSkills += @($overlay.supporting_skills | ForEach-Object { [string] $_ })
}
foreach ($skillName in $skillNames) {
    if (@($routedSkills | Sort-Object -Unique) -notcontains $skillName) {
        Add-Failure "Manifest skill is not reachable from any routing signal or risk overlay: $skillName"
    }
}

$evaluationObjectProperties = @{
    capability_evaluations = @('catalog', 'validator', 'scorer', 'scorer_tests', 'run_template', 'minimum_cases', 'minimum_cases_per_routable_skill')
    routing_evaluations = @('scenario_catalog', 'scenario_runner', 'catalog', 'validator', 'scorer', 'scorer_tests', 'run_template', 'minimum_cases')
}
foreach ($evaluationName in @('capability_evaluations', 'routing_evaluations')) {
    if ($manifest.PSObject.Properties.Name -notcontains $evaluationName) {
        continue
    }
    $evaluation = $manifest.$evaluationName
    $properties = $evaluationObjectProperties[$evaluationName]
    if (-not (Assert-ObjectShape $evaluation $properties @() "Manifest $evaluationName")) {
        continue
    }
    foreach ($pathProperty in @($properties | Where-Object { $_ -notmatch '^minimum_' })) {
        [void](Assert-ExistingPackFile $evaluation.$pathProperty "Manifest $evaluationName.$pathProperty")
    }
    if ((-not (Test-Integer $evaluation.minimum_cases)) -or ([int64] $evaluation.minimum_cases -lt 1)) {
        Add-Failure "Manifest $evaluationName.minimum_cases must be a positive integer."
    }
    if (($evaluationName -eq 'routing_evaluations') -and (Test-Integer $evaluation.minimum_cases) -and ([int64] $evaluation.minimum_cases -lt 12)) {
        Add-Failure 'Manifest routing_evaluations.minimum_cases must be at least 12.'
    }
    if ($evaluationName -eq 'capability_evaluations') {
        if ((-not (Test-Integer $evaluation.minimum_cases_per_routable_skill)) -or ([int64] $evaluation.minimum_cases_per_routable_skill -lt 1)) {
            Add-Failure 'Manifest capability_evaluations.minimum_cases_per_routable_skill must be a positive integer.'
        }
    }
}

if ($manifest.PSObject.Properties.Name -contains 'unified_delivery_fields') {
    foreach ($field in @(Assert-StringArray $manifest.unified_delivery_fields 'Manifest unified_delivery_fields')) {
        if (-not $gemini.Contains($field + ':')) {
            Add-Failure "Unified delivery record is missing field: $field"
        }
    }
}

$standaloneOutputs = @(Select-String -Path (Join-Path $rootPath 'rules/*.md') -Pattern '^## Output$' -Encoding UTF8)
foreach ($match in $standaloneOutputs) {
    Add-Failure "Standalone rule output remains at $($match.Path):$($match.LineNumber)"
}

$markdownFiles = @(Get-ChildItem -Recurse -File -LiteralPath $rootPath -Filter '*.md')
$referencePattern = '(?<![A-Za-z0-9_])(?<path>(?:rules/[A-Za-z0-9_-]+\.md|skills/[A-Za-z0-9_-]+/SKILL\.md|overlays/[A-Za-z0-9_./-]+\.md|templates/[A-Za-z0-9_.-]+\.(?:md|json)|schemas/[A-Za-z0-9_.-]+\.json|scripts/[A-Za-z0-9_.-]+\.(?:ps1|py)|tests/[A-Za-z0-9_.-]+\.(?:ps1|json)|requirements-governance\.txt|governance-manifest\.json))'
foreach ($file in $markdownFiles) {
    $content = Read-Utf8 $file.FullName
    foreach ($match in [regex]::Matches($content, $referencePattern)) {
        $relativePath = $match.Groups['path'].Value
        $resolved = Assert-PackPath $relativePath "Local reference in '$($file.FullName)'"
        if (($null -ne $resolved) -and (-not (Test-Path -LiteralPath $resolved -PathType Leaf))) {
            Add-Failure "Broken local reference in $($file.FullName): $relativePath"
        }
    }
}

$allMarkdown = ($markdownFiles | ForEach-Object { Read-Utf8 $_.FullName }) -join "`n"
foreach ($text in @(
    'MTTR > MTBF',
    'All boxes mandatory',
    'Priority: honesty/safety > explicit user requirement > correctness/data/security'
)) {
    if ($allMarkdown.Contains($text)) {
        Add-Failure "Forbidden obsolete policy text remains: $text"
    }
}

$allPowerShellFiles = @(
    Get-ChildItem -Recurse -File -LiteralPath (Join-Path $rootPath 'scripts') -Filter '*.ps1'
    Get-ChildItem -Recurse -File -LiteralPath (Join-Path $rootPath 'tests') -Filter '*.ps1'
)
$legacyHostPattern = '(?i)\$PS' + 'HOME[\\/]+power' + 'shell\.exe'
$noFailPattern = '(?i)\bNo' + 'FailExit\b'
foreach ($file in $allPowerShellFiles) {
    $content = Read-Utf8 $file.FullName
    if ($content -match '(?s)param\s*\([^)]*\$Root\s*=\s*\([^)]*\$PSScriptRoot') {
        Add-Failure "PowerShell script derives Root inside param; derive it after param from MyInvocation instead: $($file.FullName)"
    }
    if ($content -match $legacyHostPattern) {
        Add-Failure "PowerShell script hardcodes a legacy Windows PowerShell executable instead of the current host executable: $($file.FullName)"
    }
    if ($content -match $noFailPattern) {
        Add-Failure "PowerShell scorer/test exposes a forbidden success-on-failure switch: $($file.FullName)"
    }
}

$workflowRelative = '.github/workflows/governance.yml'
$workflowPath = Join-Path $rootPath (
    $workflowRelative -replace '/', [System.IO.Path]::DirectorySeparatorChar
)
if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    Add-Failure "Missing cross-platform governance workflow: $workflowRelative"
}
else {
    $workflow = Read-Utf8 $workflowPath
    foreach ($requiredText in @(
        'ubuntu-latest',
        'windows-latest',
        'shell: pwsh',
        'scripts/test-governance.ps1',
        'requirements-governance.txt',
        '--only-binary=:all:',
        'persist-credentials: false',
        'contents: read'
    )) {
        if (-not $workflow.Contains($requiredText)) {
            Add-Failure "Governance workflow is missing required text: $requiredText"
        }
    }
    foreach ($usesMatch in [regex]::Matches(
        $workflow,
        '(?m)^\s*uses:\s*(?<value>\S+)'
    )) {
        $usesValue = $usesMatch.Groups['value'].Value
        if (($usesValue -notmatch '^\./') -and
            ($usesValue -notmatch '@[0-9a-f]{40}$')) {
            Add-Failure (
                "Governance workflow must pin external action '$usesValue' " +
                'to a full lowercase commit SHA.'
            )
        }
    }
}

if (($router -notmatch '<!-- BEGIN GENERATED: TASK MODES -->') -or
    ($router -notmatch '<!-- BEGIN GENERATED: ROUTING SIGNALS -->') -or
    ($router -notmatch '<!-- BEGIN GENERATED: RISK OVERLAYS -->')) {
    Add-Failure 'Governance router is missing one or more generated-section markers.'
}
else {
    $generatorPath = Join-Path $rootPath (('scripts/generate-governance-router.ps1') -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $generatorPath -PathType Leaf) {
        try {
            $hostExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            $childArguments = @('-NoLogo', '-NoProfile')
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $childArguments += @('-ExecutionPolicy', 'Bypass')
            }
            $childArguments += @('-File', $generatorPath, '-Root', $rootPath, '-Check')
            $generatorOutput = @(& $hostExecutable @childArguments 2>&1)
            if ($LASTEXITCODE -ne 0) {
                Add-Failure "Governance router semantic parity check failed: $($generatorOutput -join ' ')"
            }
        }
        catch {
            Add-Failure "Governance router semantic parity check could not run: $($_.Exception.Message)"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Governance validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Governance validation PASS: $($manifest.rules.Count) rules, $($manifest.skills.Count) skills, $($signalProperties.Count) routing signals, $($manifest.project_overlays.Count) project overlays, schema v$($manifest.schema_version)." -ForegroundColor Green
exit 0

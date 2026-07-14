[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$manifestPath = Join-Path $rootPath 'governance-manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$catalogPath = Join-Path $rootPath ([string] $manifest.capability_evaluations.catalog -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath | ConvertFrom-Json
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)
    $failures.Add($Message)
}

if (($catalog.PSObject.Properties.Name -notcontains 'schema_version') -or ([int] $catalog.schema_version -ne 1)) {
    Add-Failure "Capability catalog schema_version must be 1."
}

$cases = @($catalog.cases)
$minimumCases = [int] $manifest.capability_evaluations.minimum_cases
if (($cases.Count -lt $minimumCases) -or ($cases.Count -gt 100)) {
    Add-Failure "Expected $minimumCases-100 capability cases, found $($cases.Count)."
}

$duplicateIds = @($cases | Group-Object -Property id | Where-Object Count -gt 1)
foreach ($duplicate in $duplicateIds) {
    Add-Failure "Duplicate capability evaluation id: $($duplicate.Name)"
}

$riskValues = @($manifest.risk_order | ForEach-Object { [string] $_ })
$skillNames = @($manifest.skills | ForEach-Object { [string] $_.name })
$requiredCaseProperties = @(
    'id',
    'category',
    'risk',
    'primary_skill',
    'prompt',
    'must_demonstrate',
    'must_avoid',
    'required_evidence'
)

foreach ($case in $cases) {
    $caseProperties = @($case.PSObject.Properties.Name)
    $caseId = if (($caseProperties -contains 'id') -and (-not [string]::IsNullOrWhiteSpace([string] $case.id))) {
        [string] $case.id
    }
    else {
        '<missing-id>'
    }
    $missingProperties = @()
    foreach ($property in $requiredCaseProperties) {
        if ($caseProperties -notcontains $property) {
            Add-Failure "Case '$caseId' is missing property: $property"
            $missingProperties += $property
        }
    }
    if ($missingProperties.Count -gt 0) {
        continue
    }

    if ($riskValues -notcontains [string] $case.risk) {
        Add-Failure "Case '$caseId' has invalid risk: $($case.risk)"
    }
    if ($skillNames -notcontains [string] $case.primary_skill) {
        Add-Failure "Case '$caseId' references unknown primary skill: $($case.primary_skill)"
    }
    if ($caseId -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        Add-Failure "Case '$caseId' id must use lowercase kebab-case."
    }
    if ([string]::IsNullOrWhiteSpace([string] $case.category)) {
        Add-Failure "Case '$caseId' category cannot be blank."
    }
    if ([string]::IsNullOrWhiteSpace([string] $case.prompt) -or ([string] $case.prompt).Length -lt 40) {
        Add-Failure "Case '$caseId' needs a concrete prompt of at least 40 characters."
    }
    if (($case.must_demonstrate -is [string]) -or (@($case.must_demonstrate).Count -lt 2)) {
        Add-Failure "Case '$caseId' needs at least two must_demonstrate criteria."
    }
    elseif (@($case.must_demonstrate | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -gt 0) {
        Add-Failure "Case '$caseId' must_demonstrate criteria cannot be blank."
    }
    if (($case.must_avoid -is [string]) -or (@($case.must_avoid).Count -lt 1)) {
        Add-Failure "Case '$caseId' needs at least one must_avoid criterion."
    }
    elseif (@($case.must_avoid | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -gt 0) {
        Add-Failure "Case '$caseId' must_avoid criteria cannot be blank."
    }
    if (($case.required_evidence -is [string]) -or (@($case.required_evidence).Count -lt 1)) {
        Add-Failure "Case '$caseId' needs at least one required_evidence item."
    }
    elseif (@($case.required_evidence | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -gt 0) {
        Add-Failure "Case '$caseId' required_evidence items cannot be blank."
    }
}

$categories = @($cases | ForEach-Object { [string] $_.category } | Sort-Object -Unique)
if ($categories.Count -lt 10) {
    Add-Failure "Capability catalog needs at least 10 categories, found $($categories.Count)."
}

$newSpecialists = @(
    'product-and-domain-strategist',
    'api-and-contract-engineer',
    'data-and-database-engineer',
    'distributed-systems-engineer',
    'platform-infrastructure-engineer',
    'quality-engineering-lead',
    'incident-commander',
    'engineering-leadership',
    'documentation-steward',
    'formal-assurance-engineer'
)
foreach ($skillName in $newSpecialists) {
    $coverage = @($cases | Where-Object { [string] $_.primary_skill -eq $skillName }).Count
    if ($coverage -lt 3) {
        Add-Failure "New specialist '$skillName' needs at least three primary evaluation cases, found $coverage."
    }
}

$dimensions = @($catalog.rubric.dimensions)
$dimensionNames = @($dimensions | ForEach-Object { [string] $_.name })
$duplicateDimensions = @($dimensions | Group-Object -Property name | Where-Object Count -gt 1)
foreach ($duplicate in $duplicateDimensions) {
    Add-Failure "Duplicate rubric dimension: $($duplicate.Name)"
}
$weightTotal = 0
foreach ($dimension in $dimensions) {
    $dimensionProperties = @($dimension.PSObject.Properties.Name)
    foreach ($property in @('name', 'weight', 'question')) {
        if ($dimensionProperties -notcontains $property) {
            Add-Failure "Rubric dimension is missing property: $property"
        }
    }
    if (($dimensionProperties -notcontains 'name') -or ($dimensionProperties -notcontains 'weight') -or ($dimensionProperties -notcontains 'question')) {
        continue
    }
    if ([string]::IsNullOrWhiteSpace([string] $dimension.name)) {
        Add-Failure "Rubric dimension name cannot be blank."
    }
    if (($dimension.weight -isnot [int]) -and ($dimension.weight -isnot [long]) -and ($dimension.weight -isnot [double]) -and ($dimension.weight -isnot [decimal])) {
        Add-Failure "Rubric dimension '$($dimension.name)' weight must be numeric."
    }
    elseif (($dimension.weight -le 0) -or ($dimension.weight -gt 100)) {
        Add-Failure "Rubric dimension '$($dimension.name)' weight must be 1-100."
    }
    else {
        $weightTotal += [double] $dimension.weight
    }
    if ([string]::IsNullOrWhiteSpace([string] $dimension.question) -or ([string] $dimension.question).Length -lt 20) {
        Add-Failure "Rubric dimension '$($dimension.name)' needs a concrete scoring question."
    }
}
if ($weightTotal -ne 100) {
    Add-Failure "Rubric weights must total 100, found $weightTotal."
}
if (($catalog.rubric.pass_score -lt 1) -or ($catalog.rubric.pass_score -gt 100)) {
    Add-Failure "Rubric pass_score must be 1-100."
}
if (($catalog.rubric.critical_pass_score -lt $catalog.rubric.pass_score) -or ($catalog.rubric.critical_pass_score -gt 100)) {
    Add-Failure "Rubric critical_pass_score must be between pass_score and 100."
}
if (@($catalog.rubric.automatic_failures).Count -lt 5) {
    Add-Failure "Rubric needs at least five automatic-failure conditions."
}
$automaticFailures = @($catalog.rubric.automatic_failures | ForEach-Object { [string] $_ })
if (@($automaticFailures | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    Add-Failure "Rubric automatic-failure conditions cannot be blank."
}
if (@($automaticFailures | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
    Add-Failure "Rubric automatic-failure conditions must be unique."
}

$requiredRunFields = @(
    'case_id',
    'model',
    'agent_surface',
    'model_version',
    'rules_pack_version',
    'repository_and_revision',
    'artifact_paths',
    'dimension_scores',
    'automatic_failure',
    'reviewer'
)
foreach ($field in $requiredRunFields) {
    if (@($catalog.run_record_fields) -notcontains $field) {
        Add-Failure "Run record is missing required field: $field"
    }
}
$runRecordFields = @($catalog.run_record_fields | ForEach-Object { [string] $_ })
if (@($runRecordFields | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    Add-Failure "Run record field names cannot be blank."
}
if (@($runRecordFields | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
    Add-Failure "Run record field names must be unique."
}

$runTemplatePath = Join-Path $rootPath ([string] $manifest.capability_evaluations.run_template -replace '/', [System.IO.Path]::DirectorySeparatorChar)
try {
    $runTemplate = Get-Content -Raw -Encoding UTF8 -LiteralPath $runTemplatePath | ConvertFrom-Json
    foreach ($field in @($catalog.run_record_fields)) {
        if ($runTemplate.PSObject.Properties.Name -notcontains [string] $field) {
            Add-Failure "Capability run template is missing field: $field"
        }
    }
    if (($runTemplate.PSObject.Properties.Name -notcontains 'dimension_scores') -or ($runTemplate.dimension_scores -isnot [pscustomobject])) {
        Add-Failure "Capability run template dimension_scores must be an object."
    }
    else {
        foreach ($dimensionName in $dimensionNames) {
            if ($runTemplate.dimension_scores.PSObject.Properties.Name -notcontains $dimensionName) {
                Add-Failure "Capability run template is missing dimension: $dimensionName"
            }
        }
    }
}
catch {
    Add-Failure "Capability run template is invalid: $($_.Exception.Message)"
}

if ($failures.Count -gt 0) {
    Write-Host "Capability evaluation validation FAILED with $($failures.Count) finding(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Capability evaluation validation PASS: $($cases.Count) cases, $($categories.Count) categories, $($dimensions.Count) rubric dimensions, weights=$weightTotal." -ForegroundColor Green
exit 0

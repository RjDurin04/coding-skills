[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $RunRecord,
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $rootPath 'governance-manifest.json') | ConvertFrom-Json
$catalogPath = Join-Path $rootPath ([string] $manifest.capability_evaluations.catalog -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath | ConvertFrom-Json
$recordPath = [System.IO.Path]::GetFullPath($RunRecord)
$record = Get-Content -Raw -Encoding UTF8 -LiteralPath $recordPath | ConvertFrom-Json
$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([string] $Message)
    $failures.Add($Message)
}

function Stop-InvalidRun {
    param([System.Collections.Generic.List[string]] $Findings)

    [ordered]@{
        status = 'INVALID'
        findings = @($Findings)
    } | ConvertTo-Json -Depth 5
    exit 2
}

foreach ($field in @($catalog.run_record_fields)) {
    if ($record.PSObject.Properties.Name -notcontains [string] $field) {
        Add-Failure "Run record is missing field: $field"
    }
}
if ($failures.Count -gt 0) {
    Stop-InvalidRun $failures
}

$requiredTextFields = @(
    'model',
    'agent_surface',
    'model_version',
    'repository_and_revision',
    'started_at',
    'token_or_cost_measure',
    'reviewer'
)
foreach ($field in $requiredTextFields) {
    if ($record.PSObject.Properties.Name -contains $field) {
        $value = [string] $record.$field
        if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('replace-with-', [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "Run record field '$field' must contain measured run metadata."
        }
    }
}

$parsedStartedAt = [datetimeoffset]::MinValue
if (($record.PSObject.Properties.Name -contains 'started_at') -and (-not [datetimeoffset]::TryParse([string] $record.started_at, [ref] $parsedStartedAt))) {
    Add-Failure "Run record started_at must be a valid timestamp."
}
if (($record.duration_seconds -isnot [int]) -and
    ($record.duration_seconds -isnot [long]) -and
    ($record.duration_seconds -isnot [double]) -and
    ($record.duration_seconds -isnot [decimal])) {
    Add-Failure "Run record duration_seconds must be numeric."
}
elseif ([double] $record.duration_seconds -lt 0) {
    Add-Failure "Run record duration_seconds cannot be negative."
}
if (($record.artifact_paths -is [string]) -or (@($record.artifact_paths).Count -lt 1)) {
    Add-Failure "Run record must identify at least one transcript, patch, log, or other evaluation artifact."
}
else {
    $recordDirectory = Split-Path -Parent $recordPath
    foreach ($artifactPath in @($record.artifact_paths)) {
        if ([string]::IsNullOrWhiteSpace([string] $artifactPath)) {
            Add-Failure "Run record artifact paths cannot be blank."
            continue
        }
        $resolvedArtifact = if ([System.IO.Path]::IsPathRooted([string] $artifactPath)) {
            [System.IO.Path]::GetFullPath([string] $artifactPath)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path $recordDirectory ([string] $artifactPath)))
        }
        if (-not (Test-Path -LiteralPath $resolvedArtifact -PathType Leaf)) {
            Add-Failure "Run record artifact does not exist: $artifactPath"
        }
    }
}

$matchingCases = @($catalog.cases | Where-Object { [string] $_.id -eq [string] $record.case_id })
if ($matchingCases.Count -ne 1) {
    Add-Failure "Run record case_id must match exactly one catalog case: $($record.case_id)"
}

if ([string] $record.rules_pack_version -ne [string] $manifest.pack_version) {
    Add-Failure "Run record rules_pack_version '$($record.rules_pack_version)' does not match '$($manifest.pack_version)'."
}

$weightedTotal = 0.0
$expectedDimensionNames = @($catalog.rubric.dimensions | ForEach-Object { [string] $_.name })
if (($null -eq $record.dimension_scores) -or ($record.dimension_scores -isnot [pscustomobject])) {
    Add-Failure "Run record dimension_scores must be an object."
}
else {
    $actualDimensionNames = @($record.dimension_scores.PSObject.Properties.Name)
    foreach ($unknownDimension in @($actualDimensionNames | Where-Object { $expectedDimensionNames -notcontains $_ })) {
        Add-Failure "Run record contains unknown dimension score: $unknownDimension"
    }

    foreach ($dimension in @($catalog.rubric.dimensions)) {
        $name = [string] $dimension.name
        if ($actualDimensionNames -notcontains $name) {
            Add-Failure "Run record is missing dimension score: $name"
            continue
        }

        $score = $record.dimension_scores.$name
        if (($score -isnot [int]) -and ($score -isnot [long]) -and ($score -isnot [double]) -and ($score -isnot [decimal])) {
            Add-Failure "Dimension '$name' must be numeric."
            continue
        }
        if (($score -lt 0) -or ($score -gt 100)) {
            Add-Failure "Dimension '$name' must be between 0 and 100."
            continue
        }

        $weightedTotal += ([double] $score * [double] $dimension.weight) / 100.0
    }
}

$automaticFailure = $false
if ($record.automatic_failure -isnot [bool]) {
    Add-Failure "Run record automatic_failure must be a boolean."
}
else {
    $automaticFailure = [bool] $record.automatic_failure
}

if ($failures.Count -gt 0) {
    Stop-InvalidRun $failures
}

$case = $matchingCases[0]
$threshold = [double] $catalog.rubric.pass_score
if ([string] $case.risk -eq 'critical') {
    $threshold = [double] $catalog.rubric.critical_pass_score
}
$weightedScore = [math]::Round($weightedTotal, 2)
$status = 'PASS'
if ($automaticFailure -or ($weightedScore -lt $threshold)) {
    $status = 'FAIL'
}

$result = [ordered]@{
    case_id = [string] $record.case_id
    category = [string] $case.category
    risk = [string] $case.risk
    primary_skill = [string] $case.primary_skill
    weighted_score = $weightedScore
    threshold = $threshold
    automatic_failure = $automaticFailure
    status = $status
}
$result | ConvertTo-Json

if ($status -eq 'FAIL') {
    exit 1
}
exit 0

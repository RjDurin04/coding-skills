[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $rootPath 'governance-manifest.json') | ConvertFrom-Json
$catalogPath = Join-Path $rootPath ([string] $manifest.capability_evaluations.catalog -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath | ConvertFrom-Json
$scorer = Join-Path $rootPath ([string] $manifest.capability_evaluations.scorer -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$powershell = Join-Path $PSHOME 'powershell.exe'
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('agents-capability-score-tests-' + [guid]::NewGuid().ToString('N'))
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0

function New-RunRecord {
    param(
        [string] $CaseId,
        [int] $Score,
        [bool] $AutomaticFailure
    )

    $scores = [ordered]@{}
    foreach ($dimension in @($catalog.rubric.dimensions)) {
        $scores[[string] $dimension.name] = $Score
    }
    return [ordered]@{
        case_id = $CaseId
        model = 'test-model'
        agent_surface = 'test-harness'
        model_version = 'test-version'
        rules_pack_version = [string] $manifest.pack_version
        repository_and_revision = 'test-repository@test-revision'
        started_at = '2000-01-01T00:00:00Z'
        duration_seconds = 1
        token_or_cost_measure = 'test-only'
        artifact_paths = @('test-artifact.txt')
        dimension_scores = $scores
        automatic_failure = $AutomaticFailure
        reviewer = 'test-harness'
        notes = 'Disposable scorer test record.'
    }
}

$tests = @(
    [pscustomobject]@{ Name = 'standard-pass'; CaseId = 'product-uncertain-demand'; Score = 100; AutomaticFailure = $false; ExpectedExit = 0; ExpectedStatus = 'PASS'; Mutation = $null },
    [pscustomobject]@{ Name = 'critical-threshold-fail'; CaseId = 'data-financial-ledger'; Score = 85; AutomaticFailure = $false; ExpectedExit = 1; ExpectedStatus = 'FAIL'; Mutation = $null },
    [pscustomobject]@{ Name = 'automatic-failure-override'; CaseId = 'product-uncertain-demand'; Score = 100; AutomaticFailure = $true; ExpectedExit = 1; ExpectedStatus = 'FAIL'; Mutation = $null },
    [pscustomobject]@{ Name = 'missing-artifact'; CaseId = 'product-uncertain-demand'; Score = 100; AutomaticFailure = $false; ExpectedExit = 2; ExpectedStatus = 'INVALID'; Mutation = { param($Record) $Record.artifact_paths = @('missing-artifact.txt') } },
    [pscustomobject]@{ Name = 'missing-dimensions'; CaseId = 'product-uncertain-demand'; Score = 100; AutomaticFailure = $false; ExpectedExit = 2; ExpectedStatus = 'INVALID'; Mutation = { param($Record) [void] $Record.Remove('dimension_scores') } },
    [pscustomobject]@{ Name = 'invalid-automatic-failure'; CaseId = 'product-uncertain-demand'; Score = 100; AutomaticFailure = $false; ExpectedExit = 2; ExpectedStatus = 'INVALID'; Mutation = { param($Record) $Record.automatic_failure = 'yes' } }
)

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    Set-Content -LiteralPath (Join-Path $tempRoot 'test-artifact.txt') -Value 'Disposable evaluation evidence.' -Encoding UTF8
    foreach ($test in $tests) {
        $recordPath = Join-Path $tempRoot ($test.Name + '.json')
        $record = New-RunRecord $test.CaseId $test.Score $test.AutomaticFailure
        if ($null -ne $test.Mutation) {
            & $test.Mutation $record
        }
        $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $recordPath -Encoding UTF8
        $output = @(& $powershell -NoProfile -ExecutionPolicy Bypass -File $scorer -RunRecord $recordPath -Root $rootPath 2>&1)
        $exitCode = $LASTEXITCODE
        $outputText = $output -join "`n"
        if ($exitCode -ne $test.ExpectedExit) {
            $failures.Add("[$($test.Name)] Expected exit $($test.ExpectedExit), got $exitCode.")
            continue
        }
        if ($outputText -notmatch ('"status"\s*:\s*"' + $test.ExpectedStatus + '"')) {
            $failures.Add("[$($test.Name)] Expected status $($test.ExpectedStatus).")
            continue
        }
        $passed++
        Write-Host "PASS $($test.Name): exit=$exitCode status=$($test.ExpectedStatus)" -ForegroundColor Green
    }
}
finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = $tempBase.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedTempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTempRoot)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Capability scorer tests FAILED: $passed/$($tests.Count) passed." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Capability scorer tests PASS: $passed/$($tests.Count)." -ForegroundColor Green
exit 0

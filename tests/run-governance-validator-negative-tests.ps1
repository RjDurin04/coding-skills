[CmdletBinding()]
param(
    [string] $Root = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = [System.IO.Path]::GetFullPath($Root)
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('agents-governance-tests-' + [guid]::NewGuid().ToString('N'))
$powershell = Join-Path $PSHOME 'powershell.exe'
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0

function Write-Utf8 {
    param(
        [string] $Path,
        [string] $Content
    )

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function New-CaseCopy {
    param([string] $Name)

    $caseRoot = Join-Path $tempRoot $Name
    [void](New-Item -ItemType Directory -Path $caseRoot -Force)
    Copy-Item -Path (Join-Path $rootPath '*') -Destination $caseRoot -Recurse -Force
    return $caseRoot
}

$cases = @(
    [pscustomobject]@{
        Name = 'broken-reference'
        Expected = 'Broken local reference'
        Mutate = {
            param($CaseRoot)
            Add-Content -LiteralPath (Join-Path $CaseRoot 'GEMINI.md') -Value "`nBroken: ``rules/does-not-exist.md``" -Encoding UTF8
        }
    },
    [pscustomobject]@{
        Name = 'unknown-routing-rule'
        Expected = 'references unknown rule'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
            $manifest.routing_signals.durable_task.rules += 'does-not-exist'
            Write-Utf8 $path ($manifest | ConvertTo-Json -Depth 20)
        }
    },
    [pscustomobject]@{
        Name = 'obsolete-policy'
        Expected = 'Forbidden obsolete policy text remains'
        Mutate = {
            param($CaseRoot)
            Add-Content -LiteralPath (Join-Path $CaseRoot 'GEMINI.md') -Value "`nMTTR > MTBF" -Encoding UTF8
        }
    },
    [pscustomobject]@{
        Name = 'standalone-output'
        Expected = 'Standalone rule output remains'
        Mutate = {
            param($CaseRoot)
            Add-Content -LiteralPath (Join-Path $CaseRoot 'rules\context-budget.md') -Value "`n## Output" -Encoding UTF8
        }
    },
    [pscustomobject]@{
        Name = 'invalid-scenario-risk'
        Expected = 'has invalid expected risk'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests\governance-scenarios.json'
            $scenarios = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
            $scenarios.scenarios[0].expected_risk = 'imaginary'
            Write-Utf8 $path ($scenarios | ConvertTo-Json -Depth 20)
        }
    },
    [pscustomobject]@{
        Name = 'invalid-skill-ui-metadata'
        Expected = 'short_description must be 25-64 characters'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'skills\product-and-domain-strategist\agents\openai.yaml'
            $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $path
            $content = $content -replace 'short_description: "[^"]+"', 'short_description: "short"'
            Write-Utf8 $path $content
        }
    },
    [pscustomobject]@{
        Name = 'invalid-evaluation-rubric'
        ValidatorRelative = 'tests\validate-capability-evaluations.ps1'
        Expected = 'Rubric weights must total 100'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests\capability-evaluations.json'
            $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
            $catalog.rubric.dimensions[0].weight = [int] $catalog.rubric.dimensions[0].weight + 1
            Write-Utf8 $path ($catalog | ConvertTo-Json -Depth 20)
        }
    },
    [pscustomobject]@{
        Name = 'unknown-evaluation-skill'
        ValidatorRelative = 'tests\validate-capability-evaluations.ps1'
        Expected = 'references unknown primary skill'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests\capability-evaluations.json'
            $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
            $catalog.cases[0].primary_skill = 'imaginary-specialist'
            Write-Utf8 $path ($catalog | ConvertTo-Json -Depth 20)
        }
    },
    [pscustomobject]@{
        Name = 'missing-evaluation-property'
        ValidatorRelative = 'tests\validate-capability-evaluations.ps1'
        Expected = 'is missing property: prompt'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests\capability-evaluations.json'
            $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $path | ConvertFrom-Json
            $catalog.cases[0].PSObject.Properties.Remove('prompt')
            Write-Utf8 $path ($catalog | ConvertTo-Json -Depth 20)
        }
    }
)

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    foreach ($case in $cases) {
        $caseRoot = New-CaseCopy $case.Name
        & $case.Mutate $caseRoot

        $validatorRelative = 'scripts\validate-governance.ps1'
        if ($case.PSObject.Properties.Name -contains 'ValidatorRelative') {
            $validatorRelative = [string] $case.ValidatorRelative
        }
        $validator = Join-Path $caseRoot $validatorRelative
        $output = @(& $powershell -NoProfile -ExecutionPolicy Bypass -File $validator -Root $caseRoot 2>&1)
        $exitCode = $LASTEXITCODE
        $outputText = $output -join "`n"

        if ($exitCode -eq 0) {
            $failures.Add("[$($case.Name)] Validator unexpectedly passed.")
            continue
        }
        if ($outputText -notmatch [regex]::Escape([string] $case.Expected)) {
            $failures.Add("[$($case.Name)] Validator failed for the wrong reason. Expected output containing '$($case.Expected)'.")
            continue
        }

        $passed++
        Write-Host "PASS $($case.Name): rejected as expected" -ForegroundColor Green
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
    Write-Host "Validator negative tests FAILED: $passed/$($cases.Count) passed." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Validator negative tests PASS: $passed/$($cases.Count) mutations rejected." -ForegroundColor Green
exit 0

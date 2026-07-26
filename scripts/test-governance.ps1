[CmdletBinding()]
param([string] $Root)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    $Root = [System.IO.Path]::GetDirectoryName($scriptDirectory)
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$steps = @(
    [pscustomobject]@{
        Name = 'Executable JSON Schema validation'
        Path = 'scripts/validate-json-schemas.py'
        Runner = 'python'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Generated router parity'
        Path = 'scripts/generate-governance-router.ps1'
        Runner = 'powershell'
        Check = $true
    },
    [pscustomobject]@{
        Name = 'Manifest, schema, inventory, and reference validation'
        Path = 'scripts/validate-governance.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Exact governance routing scenarios'
        Path = 'tests/run-governance-scenarios.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Raw routing evaluation catalog'
        Path = 'tests/validate-routing-evaluations.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Routing scorer bypass and exit-contract tests'
        Path = 'tests/test-routing-decision-scorer.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Routing model-runner protocol and isolation tests'
        Path = 'tests/test-routing-model-runner.py'
        Runner = 'python'
        Check = $false
        PassRoot = $false
    },
    [pscustomobject]@{
        Name = 'Capability evaluation catalog'
        Path = 'tests/validate-capability-evaluations.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Capability scorer bypass and exit-contract tests'
        Path = 'tests/test-capability-scorer.ps1'
        Runner = 'powershell'
        Check = $false
    },
    [pscustomobject]@{
        Name = 'Governance validator mutation tests'
        Path = 'tests/run-governance-validator-negative-tests.ps1'
        Runner = 'powershell'
        Check = $false
    }
)

$startedAt = [datetimeoffset]::UtcNow
$passed = 0
foreach ($step in $steps) {
    $stepPath = Join-Path $rootPath (
        [string] $step.Path -replace '/', [System.IO.Path]::DirectorySeparatorChar
    )
    if (-not (Test-Path -LiteralPath $stepPath -PathType Leaf)) {
        Write-Host "Deterministic governance checks FAILED: missing step '$($step.Path)'." -ForegroundColor Red
        exit 1
    }

    Write-Host "`n== $($step.Name) ==" -ForegroundColor Cyan
    if ([string] $step.Runner -eq 'python') {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if ($null -eq $pythonCommand) {
            $pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
        }
        if ($null -eq $pythonCommand) {
            Write-Host (
                'Deterministic governance checks FAILED: Python is required for executable ' +
                'JSON Schema validation.'
            ) -ForegroundColor Red
            exit 1
        }
        if (($step.PSObject.Properties.Name -contains 'PassRoot') -and (-not [bool] $step.PassRoot)) {
            & $pythonCommand.Source $stepPath
        }
        else {
            & $pythonCommand.Source $stepPath --root $rootPath
        }
    }
    else {
        $stepArguments = @{ Root = $rootPath }
        if ([bool] $step.Check) {
            $stepArguments.Check = $true
        }
        & $stepPath @stepArguments
    }
    $stepExit = $LASTEXITCODE
    if ($stepExit -ne 0) {
        Write-Host (
            "Deterministic governance checks FAILED at '$($step.Name)' with exit code $stepExit."
        ) -ForegroundColor Red
        exit 1
    }
    $passed++
}

$duration = [math]::Round(
    ([datetimeoffset]::UtcNow - $startedAt).TotalSeconds,
    2
)
Write-Host (
    "`nDeterministic governance checks PASS: $passed/$($steps.Count) gates in ${duration}s. " +
    'This does not establish model behavior, target-environment readiness, or production safety.'
) -ForegroundColor Green
exit 0

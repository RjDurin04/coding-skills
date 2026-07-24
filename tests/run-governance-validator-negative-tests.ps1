[CmdletBinding()]
param(
    [string] $Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Root)) {
    $scriptDirectory = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
    $Root = [System.IO.Path]::GetDirectoryName($scriptDirectory)
}

$rootPath = [System.IO.Path]::GetFullPath($Root)
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('agents-governance-negative-tests-' + [guid]::NewGuid().ToString('N'))
$hostExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0

function Write-Utf8 {
    param(
        [string] $Path,
        [string] $Content
    )
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

function Read-Json {
    param([string] $Path)
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Write-Json {
    param(
        [string] $Path,
        $Value
    )
    Write-Utf8 $Path ($Value | ConvertTo-Json -Depth 30)
}

function New-CaseCopy {
    param([string] $Name)

    $caseRoot = Join-Path $tempRoot $Name
    [void](New-Item -ItemType Directory -Path $caseRoot -Force)
    foreach ($source in @(Get-ChildItem -LiteralPath $rootPath -Force | Where-Object {
        $_.Name -notin @('.git')
    })) {
        Copy-Item -LiteralPath $source.FullName -Destination $caseRoot -Recurse -Force
    }
    return $caseRoot
}

function Invoke-ValidatorProcess {
    param(
        [string] $Validator,
        [string] $CaseRoot
    )

    $arguments = @('-NoLogo', '-NoProfile')
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        $arguments += @('-ExecutionPolicy', 'Bypass')
    }
    $arguments += @('-File', $Validator, '-Root', $CaseRoot)
    $output = @(& $hostExecutable @arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}

$cases = @(
    [pscustomobject]@{
        Name = 'broken-local-reference'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'Broken local reference'
        Mutate = {
            param($CaseRoot)
            Add-Content -LiteralPath (Join-Path $CaseRoot 'GEMINI.md') `
                -Value "`nBroken: ``rules/does-not-exist.md``" -Encoding UTF8
        }
    },
    [pscustomobject]@{
        Name = 'unknown-routing-rule'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'references unknown rule'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $manifest.routing_signals.durable_task.rules += 'does-not-exist'
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'unsafe-pack-path'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'contains an unsafe path segment'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $manifest.rules[0].path = '../outside.md'
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'unknown-manifest-property'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'Manifest contains unknown property: unexpected_override'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $manifest | Add-Member -NotePropertyName unexpected_override -NotePropertyValue $true
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'false-schema-identity'
        Validator = 'scripts/validate-governance.ps1'
        Expected = '$id must be'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'schemas/capability-evaluations.schema.json'
            $schema = Read-Json $path
            $schema.'$id' = 'urn:invented:schema'
            Write-Json $path $schema
        }
    },
    [pscustomobject]@{
        Name = 'invalid-signal-type'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'has invalid confirmation'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $manifest.routing_signals.durable_task.confirmation = 42
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'stale-generated-router'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'semantic parity check failed'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $manifest.routing_signals.durable_task.description += ' Deliberate stale-router mutation.'
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'unpinned-ci-action'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'must pin external action'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot '.github/workflows/governance.yml'
            $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $path
            $content = $content -replace (
                'actions/checkout@[0-9a-f]{40}',
                'actions/checkout@v6'
            )
            Write-Utf8 $path $content
        }
    },
    [pscustomobject]@{
        Name = 'success-on-failure-switch'
        Validator = 'scripts/validate-governance.ps1'
        Expected = 'forbidden success-on-failure switch'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/score-capability-run.ps1'
            $forbiddenSwitchName = 'No' + 'FailExit'
            Add-Content -LiteralPath $path -Value ("`n# " + $forbiddenSwitchName) -Encoding UTF8
        }
    },
    [pscustomobject]@{
        Name = 'invalid-scenario-risk'
        Validator = 'tests/run-governance-scenarios.ps1'
        Expected = 'has invalid expected risk'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/governance-scenarios.json'
            $scenarios = Read-Json $path
            $scenarios.scenarios[0].expected_risk = 'imaginary'
            Write-Json $path $scenarios
        }
    },
    [pscustomobject]@{
        Name = 'uncovered-scenario-signal'
        Validator = 'tests/run-governance-scenarios.ps1'
        Expected = 'has no positive governance scenario'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $newSignal = [pscustomobject]@{
                description = 'A deliberate negative-test signal with no scenario coverage.'
                minimum_risk = 'standard'
                rules = @()
                lead_skill = $null
                supporting_skills = @()
                confirmation = 'none'
            }
            $manifest.routing_signals |
                Add-Member -NotePropertyName uncovered_test_signal -NotePropertyValue $newSignal
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'uncovered-raw-routing-signal'
        Validator = 'tests/validate-routing-evaluations.ps1'
        Expected = 'has no raw-request evaluation case'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'governance-manifest.json'
            $manifest = Read-Json $path
            $newSignal = [pscustomobject]@{
                description = 'A deliberate negative-test signal with no raw routing evaluation.'
                minimum_risk = 'standard'
                rules = @()
                lead_skill = $null
                supporting_skills = @()
                confirmation = 'none'
            }
            $manifest.routing_signals |
                Add-Member -NotePropertyName uncovered_raw_signal -NotePropertyValue $newSignal
            Write-Json $path $manifest
        }
    },
    [pscustomobject]@{
        Name = 'compensatory-wrong-mode-penalty'
        Validator = 'tests/validate-routing-evaluations.ps1'
        Expected = 'wrong_mode penalty must make any incorrect task mode fail'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/routing-evaluations.json'
            $catalog = Read-Json $path
            $catalog.scoring.penalties.wrong_mode = 1
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'non-finite-routing-penalty'
        Validator = 'tests/validate-routing-evaluations.ps1'
        Expected = "Routing penalty 'wrong_mode' must be numeric"
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/routing-evaluations.json'
            $catalog = Read-Json $path
            $catalog.scoring.penalties.wrong_mode = [double]::NaN
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'invalid-rubric-weight'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = 'Rubric weights must total 100'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.rubric.dimensions[0].weight =
                [double] $catalog.rubric.dimensions[0].weight + 1
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'non-finite-rubric-weight'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = 'weight must be a number greater than 0'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.rubric.dimensions[0].weight = [double]::NaN
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'unknown-primary-skill'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = 'is not a routable lead skill'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.cases[0].primary_skill = 'imaginary-specialist'
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'missing-capability-property'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = "is missing property 'prompt'"
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.cases[0].PSObject.Properties.Remove('prompt')
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'lead-marked-support-only'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = 'must have coverage role primary'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $entry = @($catalog.skill_coverage | Where-Object {
                [string] $_.skill -eq 'security-reviewer'
            })[0]
            $entry.role = 'support_only'
            $entry.minimum_cases = 0
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'crowded-out-trivial-cases'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = "at least 5 'trivial' cases"
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            foreach ($case in @($catalog.cases | Where-Object {
                [string] $_.risk -eq 'trivial'
            })) {
                $case.risk = 'critical'
            }
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'missing-anti-ceremony-case'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = "missing required anti-bypass or anti-ceremony case 'docs-punctuation-only'"
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.cases = @($catalog.cases | Where-Object {
                [string] $_.id -ne 'docs-punctuation-only'
            })
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'unknown-capability-case-property'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = "contains unknown property 'trusted_pass'"
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.cases[0] |
                Add-Member -NotePropertyName trusted_pass -NotePropertyValue $true
            Write-Json $path $catalog
        }
    },
    [pscustomobject]@{
        Name = 'duplicate-cross-group-criterion'
        Validator = 'tests/validate-capability-evaluations.ps1'
        Expected = 'reuses criterion id'
        Mutate = {
            param($CaseRoot)
            $path = Join-Path $CaseRoot 'tests/capability-evaluations.json'
            $catalog = Read-Json $path
            $catalog.cases[0].must_avoid[0].id =
                [string] $catalog.cases[0].must_demonstrate[0].id
            Write-Json $path $catalog
        }
    }
)

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    foreach ($case in $cases) {
        $caseRoot = New-CaseCopy $case.Name
        & $case.Mutate $caseRoot

        $validatorPath = Join-Path $caseRoot (
            [string] $case.Validator -replace '/', [System.IO.Path]::DirectorySeparatorChar
        )
        $result = Invoke-ValidatorProcess $validatorPath $caseRoot
        if ($result.ExitCode -eq 0) {
            $failures.Add("[$($case.Name)] Validator unexpectedly passed.")
            continue
        }
        if ($result.Output -notmatch [regex]::Escape([string] $case.Expected)) {
            $failures.Add(
                "[$($case.Name)] Expected '$($case.Expected)' but got: $($result.Output)"
            )
            continue
        }

        $passed++
        Write-Host "PASS $($case.Name): rejected as expected" -ForegroundColor Green
    }
}
finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = $tempBase.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedTempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTempRoot)) {
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

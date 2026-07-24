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
$manifest = [System.IO.File]::ReadAllText((Join-Path $rootPath 'governance-manifest.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$catalogPath = Join-Path $rootPath (([string] $manifest.routing_evaluations.catalog) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$catalog = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$scorerPath = Join-Path $rootPath (([string] $manifest.routing_evaluations.scorer) -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('agents-routing-score-tests-' + [guid]::NewGuid().ToString('N'))
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

function New-RunRecord {
    param([string] $CaseId)

    $case = @($catalog.cases | Where-Object { [string] $_.id -eq $CaseId })[0]
    return [ordered]@{
        '$schema' = '../schemas/routing-evaluation-run.schema.json'
        schema_version = 1
        case_id = $CaseId
        rules_pack_version = [string] $manifest.pack_version
        model = [ordered]@{
            provider = 'test-provider'
            name = 'test-model'
            version = 'test-version'
            agent_surface = 'test-harness'
        }
        runner = [ordered]@{
            id = 'routing-scorer-test-runner'
            type = 'automation'
            organization = 'local-test'
        }
        started_at = '2000-01-01T00:00:00Z'
        duration_seconds = 1
        decision = [ordered]@{
            mode = [string] $case.expected.mode
            signals = @($case.expected.signals | ForEach-Object { [string] $_ })
            risk = [string] $case.expected.risk
            confirmation = [string] $case.expected.confirmation
            lead_skill = $case.expected.lead_skill
            supporting_skills = @($case.expected.supporting_skills | ForEach-Object { [string] $_ })
        }
        notes = 'Disposable routing scorer test record.'
    }
}

$tests = @(
    [pscustomobject]@{
        Name = 'exact-route-pass'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'PASS'
        ExpectedFinding = $null
        Mutation = $null
    },
    [pscustomobject]@{
        Name = 'same-route-unnecessary-signal-penalty'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'PASS'
        ExpectedFinding = 'unnecessary_signal:nontrivial_ai_assisted_work'
        Mutation = {
            param($Record)
            $Record.decision.signals += 'nontrivial_ai_assisted_work'
        }
    },
    [pscustomobject]@{
        Name = 'critical-underroute-fails'
        CaseId = 'operate-production-release'
        ExpectedExit = 0
        ExpectedStatus = 'FAIL'
        ExpectedFinding = 'critical_risk_underroute'
        Mutation = {
            param($Record)
            $Record.decision.mode = 'answer'
            $Record.decision.signals = @('durable_task')
            $Record.decision.risk = 'trivial'
            $Record.decision.confirmation = 'none'
            $Record.decision.lead_skill = $null
            $Record.decision.supporting_skills = @()
        }
    },
    [pscustomobject]@{
        Name = 'wrong-mode-fails'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'FAIL'
        ExpectedFinding = 'wrong_mode:review'
        Mutation = {
            param($Record)
            $Record.decision.mode = 'review'
        }
    },
    [pscustomobject]@{
        Name = 'excessive-overrouting-fails'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'FAIL'
        ExpectedFinding = 'risk_overroute:critical'
        Mutation = {
            param($Record)
            $Record.decision.signals = @(
                'durable_task',
                'security_sensitive',
                'formal_assurance'
            )
            $Record.decision.risk = 'critical'
            $Record.decision.confirmation = 'none'
            $Record.decision.lead_skill = 'security-reviewer'
            $Record.decision.supporting_skills = @('adversarial-test-forge', 'formal-assurance-engineer')
        }
    },
    [pscustomobject]@{
        Name = 'answer-implementation-signal-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'contains prohibited task-mode signal: implementation_task'
        Mutation = {
            param($Record)
            $Record.decision.signals += 'implementation_task'
        }
    },
    [pscustomobject]@{
        Name = 'composed-risk-mismatch-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'does not match composed risk'
        Mutation = {
            param($Record)
            $Record.decision.risk = 'standard'
        }
    },
    [pscustomobject]@{
        Name = 'composed-confirmation-mismatch-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'does not match composed confirmation'
        Mutation = {
            param($Record)
            $Record.decision.confirmation = 'explicit_authorization'
        }
    },
    [pscustomobject]@{
        Name = 'composed-lead-mismatch-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'does not match composed lead_skill'
        Mutation = {
            param($Record)
            $Record.decision.lead_skill = 'security-reviewer'
        }
    },
    [pscustomobject]@{
        Name = 'composed-support-mismatch-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'do not match composed supporting_skills'
        Mutation = {
            param($Record)
            $Record.decision.supporting_skills = @('cognitive-primitives')
        }
    },
    [pscustomobject]@{
        Name = 'ordered-signal-lead-mismatch-invalid'
        CaseId = 'design-new-boundary'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'does not match composed lead_skill'
        Mutation = {
            param($Record)
            $Record.decision.signals = @(
                'durable_task',
                'architecture_or_public_boundary',
                'new_durable_boundary',
                'complex_reasoning_or_state_model',
                'nontrivial_ai_assisted_work'
            )
        }
    },
    [pscustomobject]@{
        Name = 'unknown-field-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'unknown property'
        Mutation = {
            param($Record)
            $Record['self_attested_confidence'] = 100
        }
    },
    [pscustomobject]@{
        Name = 'non-finite-duration-invalid'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'INVALID'
        ExpectedFinding = 'duration_seconds must be a nonnegative number'
        Mutation = {
            param($Record)
            $Record.duration_seconds = [double]::NaN
        }
    }
)

$processTests = @(
    [pscustomobject]@{
        Name = 'process-pass-exit-contract'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 0
        ExpectedStatus = 'PASS'
        Mutation = $null
    },
    [pscustomobject]@{
        Name = 'process-fail-exit-contract'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 1
        ExpectedStatus = 'FAIL'
        Mutation = {
            param($Record)
            $Record.decision.mode = 'review'
        }
    },
    [pscustomobject]@{
        Name = 'process-invalid-exit-contract'
        CaseId = 'answer-engineering-explanation'
        ExpectedExit = 2
        ExpectedStatus = 'INVALID'
        Mutation = {
            param($Record)
            $Record.decision.signals += 'implementation_task'
        }
    }
)

$currentHostExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

function ConvertTo-ProcessArgument {
    param([AllowEmptyString()] [string] $Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return '""'
    }
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Start-ScorerProcess {
    param([string] $RecordPath)

    $arguments = @(
        '-NoProfile',
        '-NonInteractive',
        '-File',
        $scorerPath,
        '-RunRecord',
        $RecordPath,
        '-Root',
        $rootPath
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $currentHostExecutable
    $startInfo.Arguments = @($arguments | ForEach-Object { ConvertTo-ProcessArgument ([string] $_) }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw 'Failed to start the scorer child process.'
        }
        return [pscustomobject]@{
            Process = $process
            StandardOutputTask = $process.StandardOutput.ReadToEndAsync()
            StandardErrorTask = $process.StandardError.ReadToEndAsync()
        }
    }
    catch {
        $process.Dispose()
        throw
    }
}

function Complete-ScorerProcess {
    param([object] $Observation)

    $process = $Observation.Process
    try {
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $Observation.StandardOutputTask.Result
            StandardError = $Observation.StandardErrorTask.Result
        }
    }
    finally {
        $process.Dispose()
    }
}

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    foreach ($test in $tests) {
        $record = New-RunRecord $test.CaseId
        if ($null -ne $test.Mutation) {
            & $test.Mutation $record
        }
        $recordPath = Join-Path $tempRoot ($test.Name + '.json')
        [System.IO.File]::WriteAllText($recordPath, (($record | ConvertTo-Json -Depth 20) + "`n"), $utf8WithoutBom)

        try {
            $processResult = Complete-ScorerProcess (
                Start-ScorerProcess $recordPath
            )
        }
        catch {
            $failures.Add(
                "[$($test.Name)] Scorer child process failed: $($_.Exception.Message)"
            )
            continue
        }
        $expectedExit = switch ([string] $test.ExpectedStatus) {
            'PASS' { 0 }
            'FAIL' { 1 }
            'INVALID' { 2 }
            default { throw "Unknown expected status: $($test.ExpectedStatus)" }
        }
        $exitCode = $processResult.ExitCode
        $outputText = [string] $processResult.Output
        if ($exitCode -ne $expectedExit) {
            $failures.Add(
                "[$($test.Name)] Expected exit $expectedExit, got $exitCode. " +
                "Stdout: $outputText Stderr: $($processResult.StandardError)"
            )
            continue
        }
        if ($outputText -notmatch ('"status"\s*:\s*"' + [regex]::Escape([string] $test.ExpectedStatus) + '"')) {
            $failures.Add("[$($test.Name)] Expected status $($test.ExpectedStatus). Output: $outputText")
            continue
        }
        if (($null -ne $test.ExpectedFinding) -and ($outputText -notmatch [regex]::Escape([string] $test.ExpectedFinding))) {
            $failures.Add("[$($test.Name)] Expected finding '$($test.ExpectedFinding)'. Output: $outputText")
            continue
        }
        if ($test.Name -eq 'same-route-unnecessary-signal-penalty') {
            try {
                $result = $outputText | ConvertFrom-Json
                if (([double] $result.score -ge 100) -or ([double] $result.score -lt [double] $catalog.scoring.pass_score)) {
                    $failures.Add("[$($test.Name)] Expected a visible non-failing penalty, got score $($result.score).")
                    continue
                }
            }
            catch {
                $failures.Add("[$($test.Name)] Could not parse scorer JSON: $($_.Exception.Message)")
                continue
            }
        }
        $passed++
        Write-Host "PASS $($test.Name): exit=$exitCode status=$($test.ExpectedStatus)" -ForegroundColor Green
    }

    $activeProcessTests = @()
    foreach ($test in $processTests) {
        $record = New-RunRecord $test.CaseId
        if ($null -ne $test.Mutation) {
            & $test.Mutation $record
        }
        $recordPath = Join-Path $tempRoot ($test.Name + '.json')
        [System.IO.File]::WriteAllText($recordPath, (($record | ConvertTo-Json -Depth 20) + "`n"), $utf8WithoutBom)

        try {
            $observation = Start-ScorerProcess $recordPath
            $activeProcessTests += [pscustomobject]@{
                Test = $test
                Observation = $observation
            }
        }
        catch {
            $failures.Add("[$($test.Name)] Scorer child process could not be observed: $($_.Exception.Message)")
        }
    }

    foreach ($activeProcessTest in $activeProcessTests) {
        $test = $activeProcessTest.Test
        try {
            $processResult = Complete-ScorerProcess $activeProcessTest.Observation
        }
        catch {
            $failures.Add("[$($test.Name)] Scorer child process could not be completed: $($_.Exception.Message)")
            continue
        }
        $exitCode = $processResult.ExitCode
        $outputText = [string] $processResult.Output
        if ($exitCode -ne $test.ExpectedExit) {
            $failures.Add("[$($test.Name)] Expected real process exit $($test.ExpectedExit), got $exitCode. Stdout: $outputText Stderr: $($processResult.StandardError)")
            continue
        }
        if ($outputText -notmatch ('"status"\s*:\s*"' + [regex]::Escape([string] $test.ExpectedStatus) + '"')) {
            $failures.Add("[$($test.Name)] Expected process status $($test.ExpectedStatus). Output: $outputText")
            continue
        }
        $passed++
        Write-Host "PASS $($test.Name): real-exit=$exitCode status=$($test.ExpectedStatus)" -ForegroundColor Green
    }
}
finally {
    $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = $tempBase.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedTempRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTempRoot -PathType Container)) {
        Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
    }
}

$totalTests = $tests.Count + $processTests.Count
if ($failures.Count -gt 0) {
    Write-Host "Routing scorer tests FAILED: $passed/$totalTests passed." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Routing scorer tests PASS: $passed/$totalTests." -ForegroundColor Green
exit 0

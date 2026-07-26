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
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (
    Join-Path $rootPath 'governance-manifest.json'
) | ConvertFrom-Json
$catalogPath = Join-Path $rootPath (
    [string] $manifest.capability_evaluations.catalog -replace '/', [System.IO.Path]::DirectorySeparatorChar
)
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath | ConvertFrom-Json
$scorerPath = Join-Path $rootPath (
    [string] $manifest.capability_evaluations.scorer -replace '/', [System.IO.Path]::DirectorySeparatorChar
)

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('agents-capability-score-tests-' + [guid]::NewGuid().ToString('N'))
$failures = New-Object 'System.Collections.Generic.List[string]'
$passed = 0
$catalogPolicyTests = @()

function New-RunRecord {
    param(
        [string] $CaseId,
        [double] $Score,
        [string] $ArtifactHash
    )

    $case = @($catalog.cases | Where-Object { [string] $_.id -eq $CaseId })[0]
    $scores = [ordered]@{}
    foreach ($dimension in @($catalog.rubric.dimensions)) {
        $scores[[string] $dimension.name] = $Score
    }
    $criterionResults = @()
    foreach ($groupName in @('must_demonstrate', 'must_avoid', 'required_evidence')) {
        foreach ($criterion in @($case.$groupName)) {
            $criterionResults += [ordered]@{
                criterion_id = [string] $criterion.id
                status = 'satisfied'
                evidence_artifact_ids = @('evaluation_artifact')
                review_notes = "Test reviewer found '$($criterion.id)' satisfied in evaluation_artifact."
            }
        }
    }

    return [ordered]@{
        '$schema' = '../schemas/capability-evaluation-run.schema.json'
        schema_version = 2
        case_id = $CaseId
        rules_pack_version = [string] $manifest.pack_version
        model = [ordered]@{
            provider = 'test-provider'
            name = 'test-model'
            version = 'test-version'
            agent_surface = 'test-harness'
        }
        execution = [ordered]@{
            repository = 'test-repository'
            revision = 'test-revision'
            started_at = '2000-01-01T00:00:00Z'
            duration_seconds = 1
            token_measure = [ordered]@{
                unit = 'tokens'
                value = 100
            }
        }
        runner = [ordered]@{
            id = 'test-runner'
            type = 'automation'
            organization = 'test-organization'
        }
        reviewer = [ordered]@{
            id = 'independent-test-reviewer'
            type = 'human'
            organization = 'test-organization'
        }
        artifacts = @(
            [ordered]@{
                id = 'evaluation_artifact'
                path = 'test-artifact.txt'
                sha256 = $ArtifactHash
                media_type = 'text/plain'
                description = 'Disposable content-addressed evaluation evidence.'
            }
        )
        dimension_scores = $scores
        criterion_results = $criterionResults
        automatic_failure_reason_ids = @()
        notes = 'Disposable scorer regression record.'
    }
}

function Find-CriterionResult {
    param(
        $Record,
        [string] $CriterionId
    )
    return @($Record.criterion_results | Where-Object {
        [string] $_.criterion_id -eq $CriterionId
    })[0]
}

function Invoke-ScorerProcess {
    param(
        [string] $RecordPath,
        [string] $CatalogOverridePath
    )

    $hostExecutable = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $arguments = @('-NoProfile', '-NonInteractive')
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        $arguments += @('-ExecutionPolicy', 'Bypass')
    }
    $arguments += @(
        '-File',
        $scorerPath,
        '-RunRecord',
        $RecordPath,
        '-Root',
        $rootPath
    )
    if (-not [string]::IsNullOrWhiteSpace($CatalogOverridePath)) {
        $arguments += @('-CatalogPath', $CatalogOverridePath)
    }
    $output = @(& $hostExecutable @arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}

function Invoke-DirectScorerTest {
    param(
        [string] $Name,
        [string] $CaseId,
        [double] $Score,
        [string] $ExpectedStatus,
        [scriptblock] $Mutation,
        [string] $ExpectedJsonPattern,
        [string] $ArtifactHash
    )

    $recordPath = Join-Path $tempRoot ($Name + '.json')
    $record = New-RunRecord $CaseId $Score $ArtifactHash
    if ($null -ne $Mutation) {
        & $Mutation $record
    }
    $record | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $recordPath -Encoding UTF8

    try {
        $processResult = Invoke-ScorerProcess $recordPath
        $expectedExit = switch ($ExpectedStatus) {
            'PASS' { 0 }
            'FAIL' { 1 }
            'INVALID' { 2 }
        }
        if ($processResult.ExitCode -ne $expectedExit) {
            $failures.Add(
                "[$Name] Expected process exit $expectedExit, got " +
                "$($processResult.ExitCode). Output: $($processResult.Output)"
            )
            return
        }
        $outputText = [string] $processResult.Output
        $parsed = $outputText | ConvertFrom-Json
        if ([string] $parsed.status -ne $ExpectedStatus) {
            $failures.Add("[$Name] Expected status $ExpectedStatus, got '$($parsed.status)'. Output: $outputText")
            return
        }
        if ($ExpectedStatus -in @('PASS', 'FAIL')) {
            $expectedAttestationStatus = if ($ExpectedStatus -eq 'PASS') {
                'ATTESTED_THRESHOLD_MET'
            }
            else {
                'ATTESTED_THRESHOLD_NOT_MET'
            }
            if ([string] $parsed.attestation_status -ne $expectedAttestationStatus) {
                $failures.Add(
                    "[$Name] Expected attestation_status $expectedAttestationStatus, got " +
                    "'$($parsed.attestation_status)'. Output: $outputText"
                )
                return
            }
            if (($null -eq $parsed.threshold_policy) -or
                [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.id) -or
                [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.classification) -or
                [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.status) -or
                [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.review_by)) {
                $failures.Add("[$Name] Expected complete threshold_policy metadata. Output: $outputText")
                return
            }
        }
        if ((-not [string]::IsNullOrWhiteSpace($ExpectedJsonPattern)) -and
            ($outputText -notmatch $ExpectedJsonPattern)) {
            $failures.Add("[$Name] Output did not match '$ExpectedJsonPattern'. Output: $outputText")
            return
        }
        $script:passed++
        Write-Host "PASS $Name`: status=$ExpectedStatus" -ForegroundColor Green
    }
    catch {
        $failures.Add("[$Name] Scorer invocation failed: $($_.Exception.Message)")
    }
}

function Invoke-ExitContractTest {
    param(
        [string] $Name,
        [string] $RecordPath,
        [int] $ExpectedExit,
        [string] $ExpectedStatus
    )

    $processResult = Invoke-ScorerProcess $RecordPath
    if ($processResult.ExitCode -ne $ExpectedExit) {
        $failures.Add(
            "[$Name] Expected process exit $ExpectedExit, got " +
            "$($processResult.ExitCode). Output: $($processResult.Output)"
        )
        return
    }
    $outputText = [string] $processResult.Output
    $parsed = $outputText | ConvertFrom-Json
    if ([string] $parsed.status -ne $ExpectedStatus) {
        $failures.Add("[$Name] Expected process status $ExpectedStatus. Output: $outputText")
        return
    }
    if ($ExpectedStatus -in @('PASS', 'FAIL')) {
        $expectedAttestationStatus = if ($ExpectedStatus -eq 'PASS') {
            'ATTESTED_THRESHOLD_MET'
        }
        else {
            'ATTESTED_THRESHOLD_NOT_MET'
        }
        if ([string] $parsed.attestation_status -ne $expectedAttestationStatus) {
            $failures.Add(
                "[$Name] Expected process attestation_status $expectedAttestationStatus. Output: $outputText"
            )
            return
        }
        if (($null -eq $parsed.threshold_policy) -or
            [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.id) -or
            [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.classification) -or
            [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.status) -or
            [string]::IsNullOrWhiteSpace([string] $parsed.threshold_policy.review_by)) {
            $failures.Add("[$Name] Expected process threshold_policy metadata. Output: $outputText")
            return
        }
    }
    $script:passed++
    Write-Host "PASS $Name`: exit=$ExpectedExit status=$ExpectedStatus" -ForegroundColor Green
}

function Invoke-CatalogPolicyTest {
    param(
        [string] $Name,
        [string] $RecordPath,
        [scriptblock] $Mutation,
        [string] $ExpectedPattern
    )

    $catalogCopy = (
        $catalog | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    )
    & $Mutation $catalogCopy
    $mutatedCatalogPath = Join-Path $tempRoot ($Name + '-catalog.json')
    $catalogCopy | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $mutatedCatalogPath -Encoding UTF8
    $processResult = Invoke-ScorerProcess $RecordPath $mutatedCatalogPath
    $outputText = [string] $processResult.Output
    if ($processResult.ExitCode -ne 2) {
        $failures.Add("[$Name] Expected INVALID exit 2. Output: $outputText")
        return
    }
    $parsed = $outputText | ConvertFrom-Json
    if ([string] $parsed.status -ne 'INVALID') {
        $failures.Add("[$Name] Expected status INVALID. Output: $outputText")
        return
    }
    if ($outputText -notmatch $ExpectedPattern) {
        $failures.Add("[$Name] Expected policy finding '$ExpectedPattern'. Output: $outputText")
        return
    }
    $script:passed++
    Write-Host "PASS $Name`: status=INVALID" -ForegroundColor Green
}

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    $artifactPath = Join-Path $tempRoot 'test-artifact.txt'
    Set-Content -LiteralPath $artifactPath -Value 'Disposable evaluation evidence.' -Encoding UTF8
    $artifactHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()

    $standardCase = @($catalog.cases | Where-Object { [string] $_.risk -eq 'standard' })[0]
    $criticalCase = @($catalog.cases | Where-Object { [string] $_.risk -eq 'critical' })[0]
    $standardCaseId = [string] $standardCase.id
    $criticalCaseId = [string] $criticalCase.id
    $demonstrateId = [string] @($standardCase.must_demonstrate)[0].id
    $avoidId = [string] @($standardCase.must_avoid)[0].id
    $evidenceId = [string] @($standardCase.required_evidence)[0].id

    $tests = @(
        [pscustomobject]@{
            Name = 'standard-pass'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'PASS'
            ExpectedPattern = '"floor_failures"\s*:\s*\[\s*\]'
            Mutation = $null
        },
        [pscustomobject]@{
            Name = 'critical-threshold-fail'
            CaseId = $criticalCaseId
            Score = 85
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"weighted_score"\s*:\s*85'
            Mutation = $null
        },
        [pscustomobject]@{
            Name = 'dimension-floor-noncompensatory'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"dimension"\s*:\s*"grounding_and_evidence"'
            Mutation = {
                param($Record)
                $Record.dimension_scores.grounding_and_evidence = 74
            }
        },
        [pscustomobject]@{
            Name = 'non-finite-dimension-score'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'grounding_and_evidence.*must be a number'
            Mutation = {
                param($Record)
                $Record.dimension_scores.grounding_and_evidence = [double]::NaN
            }
        },
        [pscustomobject]@{
            Name = 'invalid-started-at-type'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'execution started_at must be a valid timestamp'
            Mutation = {
                param($Record)
                $Record.execution.started_at = 123
            }
        },
        [pscustomobject]@{
            Name = 'automatic-failure-reason'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"fabricated_evidence"'
            Mutation = {
                param($Record)
                $Record.automatic_failure_reason_ids = @('fabricated_evidence')
            }
        },
        [pscustomobject]@{
            Name = 'violated-demonstrate-criterion'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"criterion_group"\s*:\s*"must_demonstrate"'
            Mutation = {
                param($Record)
                (Find-CriterionResult $Record $demonstrateId).status = 'violated'
            }
        },
        [pscustomobject]@{
            Name = 'violated-must-avoid-inversion'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"criterion_group"\s*:\s*"must_avoid"'
            Mutation = {
                param($Record)
                (Find-CriterionResult $Record $avoidId).status = 'violated'
            }
        },
        [pscustomobject]@{
            Name = 'unverified-evidence-criterion'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'FAIL'
            ExpectedPattern = '"criterion_group"\s*:\s*"required_evidence"'
            Mutation = {
                param($Record)
                (Find-CriterionResult $Record $evidenceId).status = 'unverified'
            }
        },
        [pscustomobject]@{
            Name = 'unknown-automatic-failure-reason'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'unknown automatic failure reason'
            Mutation = {
                param($Record)
                $Record.automatic_failure_reason_ids = @('invented_reason')
            }
        },
        [pscustomobject]@{
            Name = 'missing-artifact'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'does not exist'
            Mutation = {
                param($Record)
                $Record.artifacts[0].path = 'missing-artifact.txt'
            }
        },
        [pscustomobject]@{
            Name = 'artifact-hash-mismatch'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'does not match the file content'
            Mutation = {
                param($Record)
                $Record.artifacts[0].sha256 = ('a' * 64)
            }
        },
        [pscustomobject]@{
            Name = 'duplicate-artifact-path-alias'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'aliases the same resolved path'
            Mutation = {
                param($Record)
                $Record.artifacts += [ordered]@{
                    id = 'aliased_artifact'
                    path = ('.' + [System.IO.Path]::DirectorySeparatorChar + 'test-artifact.txt')
                    sha256 = $artifactHash
                    media_type = 'text/plain'
                    description = 'A forbidden second alias for the same evidence file.'
                }
            }
        },
        [pscustomobject]@{
            Name = 'self-review'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'independent actors'
            Mutation = {
                param($Record)
                $Record.reviewer.id = 'TEST-RUNNER'
            }
        },
        [pscustomobject]@{
            Name = 'missing-criterion'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'missing criterion result'
            Mutation = {
                param($Record)
                $Record.criterion_results = @($Record.criterion_results | Select-Object -Skip 1)
            }
        },
        [pscustomobject]@{
            Name = 'extra-criterion'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'unknown criterion result'
            Mutation = {
                param($Record)
                $Record.criterion_results += [ordered]@{
                    criterion_id = 'invented_criterion'
                    status = 'satisfied'
                    evidence_artifact_ids = @('evaluation_artifact')
                    review_notes = 'An invented criterion must be rejected.'
                }
            }
        },
        [pscustomobject]@{
            Name = 'criterion-without-evidence'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'at least one evidence artifact'
            Mutation = {
                param($Record)
                $Record.criterion_results[0].evidence_artifact_ids = @()
            }
        },
        [pscustomobject]@{
            Name = 'unknown-top-level-field'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'unknown property'
            Mutation = {
                param($Record)
                $Record.untrusted_pass_override = $true
            }
        },
        [pscustomobject]@{
            Name = 'legacy-automatic-failure-boolean'
            CaseId = $standardCaseId
            Score = 100
            ExpectedStatus = 'INVALID'
            ExpectedPattern = 'automatic_failure'
            Mutation = {
                param($Record)
                $Record.automatic_failure = $false
            }
        }
    )

    foreach ($test in $tests) {
        Invoke-DirectScorerTest `
            -Name $test.Name `
            -CaseId $test.CaseId `
            -Score $test.Score `
            -ExpectedStatus $test.ExpectedStatus `
            -Mutation $test.Mutation `
            -ExpectedJsonPattern $test.ExpectedPattern `
            -ArtifactHash $artifactHash
    }

    $exitRecords = @(
        [pscustomobject]@{
            Name = 'process-exit-pass'
            ExpectedExit = 0
            ExpectedStatus = 'PASS'
            Record = (New-RunRecord $standardCaseId 100 $artifactHash)
        },
        [pscustomobject]@{
            Name = 'process-exit-fail'
            ExpectedExit = 1
            ExpectedStatus = 'FAIL'
            Record = (New-RunRecord $criticalCaseId 85 $artifactHash)
        },
        [pscustomobject]@{
            Name = 'process-exit-invalid'
            ExpectedExit = 2
            ExpectedStatus = 'INVALID'
            Record = (New-RunRecord $standardCaseId 100 ('b' * 64))
        }
    )
    foreach ($exitRecord in $exitRecords) {
        $recordPath = Join-Path $tempRoot ($exitRecord.Name + '.json')
        $exitRecord.Record | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $recordPath -Encoding UTF8
        Invoke-ExitContractTest `
            -Name $exitRecord.Name `
            -RecordPath $recordPath `
            -ExpectedExit $exitRecord.ExpectedExit `
            -ExpectedStatus $exitRecord.ExpectedStatus
    }

    $policyRecordPath = Join-Path $tempRoot 'policy-audit-record.json'
    (New-RunRecord $standardCaseId 100 $artifactHash) |
        ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $policyRecordPath -Encoding UTF8
    $catalogPolicyTests = @(
        [pscustomobject]@{
            Name = 'policy-missing-leaf-owner'
            ExpectedPattern = 'must have exactly one owner'
            Mutation = {
                param($CatalogCopy)
                $policy = @($CatalogCopy.threshold_policies | Where-Object {
                    @($_.targets) -contains 'coverage_requirements.maximum_cases'
                })[0]
                $policy.targets = @($policy.targets | Where-Object {
                    $_ -ne 'coverage_requirements.maximum_cases'
                })
            }
        },
        [pscustomobject]@{
            Name = 'policy-duplicate-leaf-owner'
            ExpectedPattern = 'has multiple owners'
            Mutation = {
                param($CatalogCopy)
                $CatalogCopy.threshold_policies[1].targets += 'rubric.pass_score'
            }
        },
        [pscustomobject]@{
            Name = 'policy-unknown-target'
            ExpectedPattern = 'unknown or non-leaf'
            Mutation = {
                param($CatalogCopy)
                $CatalogCopy.threshold_policies[0].targets += 'rubric.unknown_threshold'
            }
        },
        [pscustomobject]@{
            Name = 'policy-parent-child-overlap'
            ExpectedPattern = 'overlap at parent/child paths'
            Mutation = {
                param($CatalogCopy)
                $CatalogCopy.threshold_policies[0].targets += 'rubric.dimensions'
            }
        }
    )
    foreach ($policyTest in $catalogPolicyTests) {
        Invoke-CatalogPolicyTest `
            -Name $policyTest.Name `
            -RecordPath $policyRecordPath `
            -Mutation $policyTest.Mutation `
            -ExpectedPattern $policyTest.ExpectedPattern
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

$totalTests = $tests.Count + $exitRecords.Count + $catalogPolicyTests.Count
if ($failures.Count -gt 0) {
    Write-Host "Capability scorer tests FAILED: $passed/$totalTests passed." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Capability scorer tests PASS: $passed/$totalTests." -ForegroundColor Green
exit 0

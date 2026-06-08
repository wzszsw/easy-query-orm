param(
    [string]$ConfigPath = ".plugin-eval/benchmark.json",
    [string]$OutputRoot = ".plugin-eval/runs-local",
    [string[]]$ScenarioIds = @()
)

$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath {
    param([string]$PathValue)
    return [System.IO.Path]::GetFullPath((Resolve-Path $PathValue).Path)
}

function Copy-IfExists {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    if (Test-Path $SourcePath) {
        New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($DestinationPath)) | Out-Null
        Copy-Item $SourcePath $DestinationPath -Force
    }
}

function Install-LocalSkill {
    param(
        [string]$SkillSourceRoot,
        [string]$DestinationRoot
    )

    $entriesToCopy = @(
        "SKILL.md",
        "README.md",
        "agents",
        "evals",
        "references",
        "scripts"
    )

    foreach ($entry in $entriesToCopy) {
        $sourceEntry = Join-Path $SkillSourceRoot $entry
        if (-not (Test-Path $sourceEntry)) {
            continue
        }
        $destinationEntry = Join-Path $DestinationRoot $entry
        Copy-Item $sourceEntry $destinationEntry -Recurse -Force
    }
}

function Get-JsonEvents {
    param([string]$StdoutPath)

    $events = @()
    if (-not (Test-Path $StdoutPath)) {
        return $events
    }

    foreach ($line in Get-Content $StdoutPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith("{")) {
            continue
        }
        try {
            $events += ($trimmed | ConvertFrom-Json)
        } catch {
            continue
        }
    }
    return $events
}

function Get-TurnUsage {
    param([object[]]$Events)

    $turnCompleted = $Events | Where-Object { $_.type -eq "turn.completed" } | Select-Object -Last 1
    if ($null -eq $turnCompleted) {
        return $null
    }
    return $turnCompleted.usage
}

function Invoke-CodexScenario {
    param(
        [string]$CodexScript,
        [string]$WorkspacePath,
        [string]$HomePath,
        [string]$CodexHomePath,
        [string]$Model,
        [string]$Prompt,
        [string]$StdoutPath,
        [string]$StderrPath,
        [string]$FinalMessagePath
    )

    $savedHome = $env:HOME
    $savedCodexHome = $env:CODEX_HOME
    try {
        $env:HOME = $HomePath
        $env:CODEX_HOME = $CodexHomePath
        $stdoutLines = & $CodexScript exec --json --ephemeral --skip-git-repo-check --cd $WorkspacePath --output-last-message $FinalMessagePath -s workspace-write -c 'approval_policy="never"' -m $Model $Prompt 2> $StderrPath
        $exitCode = $LASTEXITCODE
        $stdoutLines | Set-Content $StdoutPath -Encoding UTF8
        return $exitCode
    }
    finally {
        $env:HOME = $savedHome
        $env:CODEX_HOME = $savedCodexHome
    }
}

$configFullPath = [System.IO.Path]::GetFullPath($ConfigPath)
$config = Get-Content $configFullPath -Raw | ConvertFrom-Json

$skillRoot = Resolve-NormalizedPath "."
$skillName = Split-Path $skillRoot -Leaf
$workspaceSourcePath = [System.IO.Path]::GetFullPath($config.workspace.sourcePath)
$outputRootFullPath = [System.IO.Path]::GetFullPath($OutputRoot)
$runId = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$runDirectory = Join-Path $outputRootFullPath $runId
$codexScript = "C:\Users\l1622\.version-fox\cache\nodejs\current\codex.ps1"
$model = if ($null -ne $config.runner.model) { $config.runner.model } else { "gpt-5.4-mini" }

New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

$summary = [ordered]@{
    runId = $runId
    createdAt = (Get-Date).ToString("o")
    skillRoot = $skillRoot
    benchmarkConfig = $configFullPath
    workspaceSourcePath = $workspaceSourcePath
    model = $model
    scenarioCount = 0
    scenarios = @()
}

$configuredScenarios = @($config.scenarios)
if ($ScenarioIds.Count -gt 0) {
    $configuredScenarios = @($configuredScenarios | Where-Object { $ScenarioIds -contains $_.id })
}
$summary.scenarioCount = $configuredScenarios.Count

for ($index = 0; $index -lt $configuredScenarios.Count; $index++) {
    $scenario = $configuredScenarios[$index]
    $scenarioPrefix = "{0:d2}-{1}" -f ($index + 1), $scenario.id
    $scenarioDirectory = Join-Path $runDirectory $scenarioPrefix
    $workspaceDirectory = Join-Path $scenarioDirectory "workspace"
    $homeDirectory = Join-Path $scenarioDirectory "home"
    $codexHomeDirectory = Join-Path $homeDirectory ".codex"
    $installedSkillDirectory = Join-Path $codexHomeDirectory "skills\$skillName"
    $stdoutPath = Join-Path $scenarioDirectory "codex.stdout.jsonl"
    $stderrPath = Join-Path $scenarioDirectory "codex.stderr.log"
    $finalMessagePath = Join-Path $scenarioDirectory "final-message.txt"

    New-Item -ItemType Directory -Force -Path $scenarioDirectory | Out-Null
    Copy-Item $workspaceSourcePath $workspaceDirectory -Recurse -Force
    New-Item -ItemType Directory -Force -Path $installedSkillDirectory | Out-Null
    Install-LocalSkill -SkillSourceRoot $skillRoot -DestinationRoot $installedSkillDirectory

    New-Item -ItemType Directory -Force -Path $codexHomeDirectory | Out-Null
    Copy-IfExists "C:\Users\l1622\.codex\auth.json" (Join-Path $codexHomeDirectory "auth.json")
    Copy-IfExists "C:\Users\l1622\.codex\config.toml" (Join-Path $codexHomeDirectory "config.toml")

    $startedAt = Get-Date
    $exitCode = Invoke-CodexScenario -CodexScript $codexScript -WorkspacePath $workspaceDirectory -HomePath $homeDirectory -CodexHomePath $codexHomeDirectory -Model $model -Prompt $scenario.userInput -StdoutPath $stdoutPath -StderrPath $stderrPath -FinalMessagePath $finalMessagePath
    $finishedAt = Get-Date

    $events = Get-JsonEvents -StdoutPath $stdoutPath
    $usage = Get-TurnUsage -Events $events
    $gitStatus = @()
    try {
        $gitStatus = git -C $workspaceDirectory status --short
    }
    catch {
        $gitStatus = @()
    }

    $scenarioResult = [ordered]@{
        id = $scenario.id
        title = $scenario.title
        purpose = $scenario.purpose
        startedAt = $startedAt.ToString("o")
        finishedAt = $finishedAt.ToString("o")
        durationSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 2)
        exitCode = $exitCode
        status = if ($exitCode -eq 0) { "completed" } else { "failed" }
        usage = $usage
        changedFiles = $gitStatus
        stdoutPath = $stdoutPath
        stderrPath = $stderrPath
        finalMessagePath = $finalMessagePath
        workspacePath = $workspaceDirectory
    }
    $summary.scenarios += $scenarioResult
}

$completedCount = @($summary.scenarios | Where-Object { $_.status -eq "completed" }).Count
$usageSamples = @($summary.scenarios | Where-Object { $null -ne $_.usage })

$summary.completedScenarios = $completedCount
$summary.failedScenarios = @($summary.scenarios).Count - $completedCount
$inputTotal = 0
$outputTotal = 0
$tokenTotal = 0
foreach ($usageSample in $usageSamples) {
    $inputTotal += [double]$usageSample.usage.input_tokens
    $outputTotal += [double]$usageSample.usage.output_tokens
    $tokenTotal += [double]$usageSample.usage.total_tokens
}
$summary.averageInputTokens = if ($usageSamples.Count -gt 0) { [Math]::Round(($inputTotal / $usageSamples.Count), 2) } else { 0 }
$summary.averageOutputTokens = if ($usageSamples.Count -gt 0) { [Math]::Round(($outputTotal / $usageSamples.Count), 2) } else { 0 }
$summary.averageTotalTokens = if ($usageSamples.Count -gt 0) { [Math]::Round(($tokenTotal / $usageSamples.Count), 2) } else { 0 }

$resultJsonPath = Join-Path $runDirectory "benchmark-run.json"
$resultMdPath = Join-Path $runDirectory "benchmark-run.md"
$summary | ConvertTo-Json -Depth 8 | Set-Content $resultJsonPath -Encoding UTF8

$markdown = @()
$markdown += "# Local Skill Benchmark"
$markdown += ""
$markdown += "- Run ID: ``$runId``"
$markdown += "- Skill: ``$skillName``"
$markdown += "- Workspace source: ``$workspaceSourcePath``"
$markdown += "- Model: ``$model``"
$markdown += "- Completed: ``$completedCount/$(@($summary.scenarios).Count)``"
$markdown += "- Avg total tokens: ``$($summary.averageTotalTokens)``"
$markdown += ""
$markdown += "## Scenarios"
$markdown += ""
foreach ($scenario in $summary.scenarios) {
    $markdown += "- ``$($scenario.id)``: ``$($scenario.status)`` exit=``$($scenario.exitCode)`` duration=``$($scenario.durationSeconds)s`` workspace=``$($scenario.workspacePath)``"
}
$markdown += ""
$markdown += "## Artifacts"
$markdown += ""
$markdown += "- JSON: ``$resultJsonPath``"
$markdown += "- Workspaces/logs: ``$runDirectory``"
$markdown | Set-Content $resultMdPath -Encoding UTF8

Write-Output $resultJsonPath

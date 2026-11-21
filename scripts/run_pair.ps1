param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Name,
    [string]$BalatroDir = 'C:\Program Files (x86)\Steam\steamapps\common\Balatro',
    [string]$ServerDir = (Join-Path $PSScriptRoot '..\..\BalatroMultiplayerServer'),
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mods = Join-Path $env:APPDATA 'Balatro\Mods'
$scenario = Join-Path $repo "tests\scenarios\$Name.lua"
$game = Join-Path $BalatroDir 'Balatro.exe'
$compose = Join-Path $ServerDir 'compose.local.yml'
$selector = "MultiplayerPvP:$Name"
$runId = 'bmp-pair-' + [guid]::NewGuid().ToString('N')
$runDir = Join-Path ([IO.Path]::GetTempPath()) $runId
$processes = @()
$devLink = $null
$startedAt = [DateTime]::UtcNow
$savedEnv = @{}
$envNames = @(
    'BMP_SERVER_KIND', 'BMP_SCENARIO', 'BMP_SCENARIO_QUIT', 'BMP_SCENARIO_RUN_ID',
    'BMP_IMPERSONATE_NAME', 'BMP_IMPERSONATE_ID', 'BMP_DEV_STEAM_LOGIN',
    'BMP_SERVER_HOST', 'BMP_SERVER_PORT', 'BMP_ROLE', 'BMP_ROLES', 'BMP_PAIR_DIR'
)

foreach ($path in @($scenario, $game, (Join-Path $BalatroDir 'winmm.dll'), $compose)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
}
$pvpLink = Get-Item -LiteralPath (Join-Path $mods 'MultiplayerPvP')
if (-not $pvpLink.Target -or [IO.Path]::GetFullPath(@($pvpLink.Target)[0]) -ne $repo) {
    throw "Mods\MultiplayerPvP must link $repo"
}
if (Get-Process -Name Balatro -ErrorAction SilentlyContinue) {
    throw 'Close existing Balatro clients before running a pair scenario.'
}
$roleLine = Select-String -LiteralPath $scenario -Pattern '^-- roles: *(.+)$' | Select-Object -First 1
$roles = if ($roleLine) { $roleLine.Matches[0].Groups[1].Value.Trim() -split '\s+' } else { @('host', 'guest') }
foreach ($role in $roles) {
    if ($role -notmatch '^[A-Za-z0-9_]+$') { throw "Invalid role $role" }
}
New-Item -ItemType Directory -Path $runDir | Out-Null
Write-Host "pair: logs and screenshots in $runDir"

try {
    foreach ($key in $envNames) {
        $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue
    }
    $env:BMP_SERVER_KIND = 'dev'
    & docker compose -f $compose up -d --wait nakama
    if ($LASTEXITCODE -ne 0) { throw 'Local Nakama startup failed.' }
    $health = Invoke-WebRequest 'http://127.0.0.1:7350/healthcheck' -TimeoutSec 10
    if ($health.StatusCode -ne 200) { throw 'Local Nakama healthcheck failed.' }

    $installedDev = Get-ChildItem -LiteralPath $mods -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'MultiplayerDev.json')
    }
    if (-not $installedDev) {
        $devSource = (Resolve-Path (Join-Path $ServerDir 'dev\client')).Path
        $devLink = Join-Path $mods 'MultiplayerDev'
        New-Item -ItemType Junction -Path $devLink -Target $devSource | Out-Null
    }
    $env:BMP_SCENARIO = $selector
    $env:BMP_SCENARIO_QUIT = '1'
    $env:BMP_ROLES = $roles -join ' '
    $env:BMP_PAIR_DIR = $runDir
    foreach ($role in $roles) {
        $env:BMP_SCENARIO_RUN_ID = "$runId-$role"
        $env:BMP_IMPERSONATE_NAME = "pair-$role-$runId"
        $env:BMP_ROLE = $role
        $processes += Start-Process -FilePath $game -WorkingDirectory $BalatroDir -PassThru `
            -RedirectStandardOutput (Join-Path $runDir "$role.launch.log") `
            -RedirectStandardError (Join-Path $runDir "$role.stderr.log")
        Start-Sleep -Seconds 2
    }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (@($processes | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ([DateTime]::UtcNow -ge $deadline) { throw "Scenario timed out; see $runDir" }
        Start-Sleep -Seconds 1
    }

    $states = @{}
    $failed = $false
    foreach ($role in $roles) {
        $start = "BMP_SCENARIO START $selector run=$runId-$role"
        $logs = @(Get-ChildItem -LiteralPath (Join-Path $mods 'lovely\log') -File | Where-Object {
            $_.LastWriteTimeUtc -ge $startedAt -and
            (Select-String -LiteralPath $_.FullName -SimpleMatch $start -Quiet)
        })
        if ($logs.Count -ne 1) { throw "$role`: expected one Lovely log, found $($logs.Count); see $runDir" }
        Copy-Item -LiteralPath $logs[0].FullName -Destination (Join-Path $runDir "$role.lovely.log")
        $results = @()
        $found = $false
        foreach ($line in Get-Content -LiteralPath $logs[0].FullName) {
            $pos = $line.IndexOf('BMP_SCENARIO ')
            if ($pos -lt 0) { continue }
            $message = $line.Substring($pos).TrimEnd()
            if ($message -eq $start) { $found = $true }
            if ($found) { $results += $message }
        }
        $results | Set-Content -LiteralPath (Join-Path $runDir "$role.results")
        $results | ForEach-Object { Write-Host "$role | $_" }
        if (($results -match '^BMP_SCENARIO FAIL ') -or
            -not ($results -match '^BMP_SCENARIO DONE pass=[1-9][0-9]* fail=0$')) {
            $failed = $true
        }
        $states[$role] = @($results -match '^BMP_SCENARIO STATE ')
    }
    if ($failed) { throw "Scenario failed; see $runDir" }
    $first = $roles[0]
    if ($states[$first].Count -eq 0) { throw "No STATE checkpoints; see $runDir" }
    foreach ($role in $roles | Select-Object -Skip 1) {
        if (($states[$first] -join "`n") -cne ($states[$role] -join "`n")) {
            throw "$first and $role disagree; see $runDir"
        }
    }
    Write-Host "pair: passed, run dir $runDir"
}
finally {
    foreach ($process in $processes) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
    if ($devLink) { Remove-Item -LiteralPath $devLink }
    & docker logs --since $startedAt.ToString('o') bmp-nakama 2>&1 |
        Out-File -LiteralPath (Join-Path $runDir 'nakama.log')
    foreach ($key in $savedEnv.Keys) {
        if ($null -eq $savedEnv[$key]) {
            Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], 'Process')
        }
    }
}

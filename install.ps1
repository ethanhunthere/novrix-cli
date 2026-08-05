# novrix-install.ps1 - one-command Windows installer for the novrix CLI.
#
#   irm https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.ps1 | iex
#
# That's it. One command. This script:
#   1. Installs Git for Windows (Git Bash) when bash is missing
#      (winget first, official installer download as fallback)
#   2. Installs jq when missing (winget -> choco -> scoop -> direct download)
#   3. Runs the official novrix installer into ~/.local/bin (no admin)
#   4. Adds novrix to your Git Bash PATH automatically
#   5. Verifies with `novrix --version`
#
# After it finishes: open a NEW Git Bash window and run: novrix --help
# No admin needed, no manual steps.

# PowerShell 5.1 defaults to TLS 1.0/1.1 - GitHub requires TLS 1.2+
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Err  { param([string]$m) Write-Host "[novrix] $m" -ForegroundColor Red }

# refresh this session's PATH from the machine + user registry entries
function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:PATH = "$machine;$user"
}

# find a real Git Bash (prefer it over WSL's bash.exe)
function Find-Bash {
  foreach ($c in @("${env:ProgramFiles}\Git\bin\bash.exe",
                   "${env:LOCALAPPDATA}\Programs\Git\bin\bash.exe",
                   "${env:ProgramFiles(x86)}\Git\bin\bash.exe")) {
    if (Test-Path $c) { return $c }
  }
  $cmd = Get-Command bash -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -notlike '*System32*') { return $cmd.Source }
  return $null
}

# ---- 1. bash / Git Bash -----------------------------------------------------
$bash = Find-Bash
if (-not $bash) {
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Step 'Installing Git for Windows (provides Git Bash)...'
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget failed to install Git for Windows (exit $LASTEXITCODE)" }
    Refresh-Path
  } else {
    # no winget - download the official Git for Windows installer directly
    Write-Step 'winget not found - downloading the Git for Windows installer...'
    try {
      $suffix = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
      $pat = [regex]::Escape("-$suffix.exe") + '$'
      $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' -UseBasicParsing
      $asset = $rel.assets | Where-Object { $_.name -match $pat } | Select-Object -First 1
      if (-not $asset) { throw 'no matching installer asset found' }
      $exe = Join-Path $env:TEMP $asset.name
      Write-Step "Downloading $($asset.name)..."
      Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe -UseBasicParsing
      Write-Step 'Installing silently (this takes a minute)...'
      $p = Start-Process -FilePath $exe -ArgumentList '/VERYSILENT','/NORESTART','/SP-','/SUPPRESSMSGBOXES' -Wait -PassThru
      if ($p.ExitCode -ne 0) { throw "Git installer exited with code $($p.ExitCode)" }
      Refresh-Path
    } catch {
      throw "could not install Git for Windows automatically. Install it from https://git-scm.com, then run this one command again. ($($_.Exception.Message))"
    }
  }
  $bash = Find-Bash
  if (-not $bash) {
    throw 'Git for Windows is installed but bash.exe was not found. Open a new PowerShell and run the one-liner again.'
  }
}

# ---- 2. run the official installer inside Git Bash ---------------------------
Write-Step 'Running the novrix installer (installs jq if needed, fixes PATH)...'
$env:PATH = "$env:PATH;${env:ProgramFiles}\Git\bin;${env:LOCALAPPDATA}\Programs\Git\bin"
& $bash -lc 'export PATH="$HOME/.local/bin:$PATH"; curl -fsSL https://raw.githubusercontent.com/ethanhunthere/novrix-cli/main/install.sh | bash -s -- --local --install-deps'
if ($LASTEXITCODE -ne 0) { throw "novrix installer failed (exit $LASTEXITCODE)" }

# ---- 3. verify ---------------------------------------------------------------
Write-Step 'Verifying...'
& $bash -lc 'novrix --version'
if ($LASTEXITCODE -ne 0) {
  if (Test-Path (Join-Path $HOME '.local\bin\novrix')) {
    Write-Err 'novrix is installed, but this terminal has not picked up the new PATH yet.'
    Write-Err 'Open a NEW Git Bash window and run: novrix --help'
  } else {
    throw 'install finished but novrix was not found in ~/.local/bin - please report this.'
  }
}

Write-Host ''
Write-Host 'Done! Open a new Git Bash window and run: novrix --help' -ForegroundColor Green

[CmdletBinding()]
param(
    [string]$Roue,
    [string]$PythonVersion,
    [switch]$SansCompilation
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallerDir = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $InstallerDir
$BuildRoot = Join-Path $InstallerDir 'build'
$AppRoot = Join-Path $BuildRoot 'app'
$PythonRoot = Join-Path $AppRoot 'python'

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE : $Executable $($Arguments -join ' ')"
    }
}

$Python = (Get-Command python -ErrorAction Stop).Source
$ActivePythonVersion = (& $Python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))").Trim()
if (-not $PythonVersion) {
    $PythonVersion = $ActivePythonVersion
}
if ($PythonVersion -ne $ActivePythonVersion) {
    throw "Active Python is $ActivePythonVersion but -PythonVersion is $PythonVersion. Activate the matching build environment first."
}
if ($PythonVersion -notmatch '^3\.(11|12|13)\.\d+$') {
    throw "Supported embeddable Python versions are 3.11, 3.12, and 3.13; got $PythonVersion."
}
$VersionParts = $PythonVersion.Split('.')
if (-not [Environment]::Is64BitOperatingSystem -or
    $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
    throw 'The Windows installer currently supports x64 Windows only.'
}

if (-not $Roue) {
    $Roue = Get-ChildItem (Join-Path $ProjectRoot 'dist') -Filter 'sentiment_app-*.whl' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Roue -or -not (Test-Path -LiteralPath $Roue -PathType Leaf)) {
    throw 'Wheel not found. Build it first with: python -m build --wheel'
}
$Roue = (Resolve-Path -LiteralPath $Roue).Path
if ([IO.Path]::GetExtension($Roue) -ne '.whl' -or
    [IO.Path]::GetFileName($Roue) -notmatch '^sentiment_app-(\d+\.\d+\.\d+)-') {
    throw "Expected a sentiment_app-X.Y.Z wheel, got: $Roue"
}
$AppVersion = $Matches[1]

Write-Host "roue : $([IO.Path]::GetFileName($Roue))"
Write-Host "python : $PythonVersion"

$Iscc = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $Iscc) {
    foreach ($RegistryPath in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        $InnoInstall = Get-ItemProperty $RegistryPath -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Inno Setup*' } |
            Select-Object -First 1
        if ($InnoInstall.InstallLocation) {
            $Candidate = Join-Path $InnoInstall.InstallLocation 'ISCC.exe'
            if (Test-Path -LiteralPath $Candidate) {
                $Iscc = $Candidate
                break
            }
        }
    }
}
if (-not $Iscc) {
    $Command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($Command) {
        $Iscc = $Command.Source
    }
}
if (-not $SansCompilation -and -not $Iscc) {
    throw 'Inno Setup 6 was not found. Install JRSoftware.InnoSetup or use -SansCompilation to prepare and test build\app.'
}

if (Test-Path -LiteralPath $BuildRoot) {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $PythonRoot -Force | Out-Null

$WheelCheck = @'
import sys, zipfile
wheel = sys.argv[1]
with zipfile.ZipFile(wheel) as archive:
    names = archive.namelist()
model = [name for name in names if name.endswith("/models/sentiment.joblib")]
if not model:
    raise SystemExit("Wheel does not contain sentiment_app/models/sentiment.joblib")
print("modèle dans la roue :", model[0])
'@
$WheelCheck | & $Python - $Roue
if ($LASTEXITCODE -ne 0) {
    throw 'The selected wheel must contain the trained model.'
}

$EmbedZip = "python-$PythonVersion-embed-amd64.zip"
$EmbedUrl = "https://www.python.org/ftp/python/$PythonVersion/$EmbedZip"
$EmbedPath = Join-Path $BuildRoot $EmbedZip
Write-Host "Téléchargement : $EmbedUrl"
Invoke-WebRequest -Uri $EmbedUrl -OutFile $EmbedPath
Expand-Archive -LiteralPath $EmbedPath -DestinationPath $PythonRoot -Force

$PthFile = Get-ChildItem $PythonRoot -Filter 'python*._pth' -File | Select-Object -First 1
if (-not $PthFile) {
    throw 'The embeddable Python archive has no python*._pth file.'
}
$PythonZip = Get-ChildItem $PythonRoot -Filter 'python*.zip' -File | Select-Object -First 1
if (-not $PythonZip) {
    throw 'The embeddable Python archive has no standard-library ZIP.'
}
$SitePackages = Join-Path $PythonRoot 'Lib\site-packages'
New-Item -ItemType Directory -Path $SitePackages -Force | Out-Null
$PthContents = @(
    $PythonZip.Name
    '.'
    'Lib\site-packages'
    'import site'
)
[IO.File]::WriteAllLines($PthFile.FullName, $PthContents, [Text.Encoding]::ASCII)
Write-Host "OK python$($VersionParts[0])$($VersionParts[1])._pth : $($PthContents -join '; ')"

$Constraints = Join-Path $BuildRoot 'constraints.txt'
$InstalledPackages = & $Python -m pip list --format=json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read exact dependency versions; ensure pip is available in the active Python environment.'
}
$Pinned = @(
    $InstalledPackages |
        Where-Object { $_.name -notmatch '^(pip|setuptools|wheel|sentiment-app)$' } |
        ForEach-Object { "$($_.name)==$($_.version)" }
)
if (-not $Pinned) {
    throw 'pip freeze returned no exact dependency versions to constrain the installer.'
}
[IO.File]::WriteAllLines($Constraints, $Pinned, [Text.Encoding]::ASCII)

$PythonMinor = "$($VersionParts[0]).$($VersionParts[1])"
$Abi = "cp$($VersionParts[0])$($VersionParts[1])"
$PipArguments = @(
    '-m', 'pip', 'install',
    '--disable-pip-version-check',
    '--only-binary=:all:',
    '--no-compile',
    '--no-warn-script-location',
    '--target', $SitePackages,
    '--platform', 'win_amd64',
    '--python-version', $PythonMinor,
    '--implementation', 'cp',
    '--abi', $Abi,
    '--constraint', $Constraints,
    $Roue
)
Write-Host 'Installation des dépendances verrouillées dans Python embarqué...'
Invoke-Checked -Executable $Python -Arguments $PipArguments

Copy-Item -LiteralPath (Join-Path $InstallerDir 'sentiment.cmd') -Destination $AppRoot
Copy-Item -LiteralPath (Join-Path $InstallerDir 'LISEZMOI.txt') -Destination $AppRoot

$CommandFile = Join-Path $AppRoot 'sentiment.cmd'
$VersionOutput = & $CommandFile --version
if ($LASTEXITCODE -ne 0 -or $VersionOutput -notmatch "sentiment-app $([regex]::Escape($AppVersion))") {
    throw "The embedded app returned an unexpected version: $VersionOutput"
}
Write-Host "OK $VersionOutput"
$PredictionOutput = & $CommandFile predict 'Livraison rapide, produit conforme, très satisfait'
if ($LASTEXITCODE -ne 0 -or $PredictionOutput -notmatch '"label":\s*"POSITIVE"') {
    throw "The embedded prediction check failed: $PredictionOutput"
}
Write-Host "OK $PredictionOutput"

$AppSize = (Get-ChildItem $AppRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host ('Taille de build\app : {0:N1} Mo' -f ($AppSize / 1MB))

if (-not $SansCompilation) {
    $IssFile = Join-Path $InstallerDir 'sentiment.iss'
    Invoke-Checked -Executable $Iscc -Arguments @("/DMyAppVersion=$AppVersion", $IssFile)
    $SetupFile = Join-Path $InstallerDir "Output\sentiment-app-$AppVersion-setup.exe"
    if (-not (Test-Path -LiteralPath $SetupFile -PathType Leaf)) {
        throw "Inno Setup did not create the expected installer: $SetupFile"
    }
    Write-Host "Installateur : $SetupFile"
}

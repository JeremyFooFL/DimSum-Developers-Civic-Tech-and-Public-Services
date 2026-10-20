# Starts the RailSense demo: the YOLO backend in its own window, then the web app.
# The backend idles until "Sync with YOLO backend" is switched on in the app's
# Capacity Test View; that loads the model and opens the webcam.
# Close the backend window to shut it down.

$ErrorActionPreference = 'Stop'

$backend = Join-Path $PSScriptRoot 'srcis_ttp\backend'
$app = Join-Path $PSScriptRoot 'srcis_ttp'
$python = Join-Path $backend 'venv\Scripts\python.exe'

if (-not (Test-Path $python)) {
    Write-Host 'Setting up the backend environment (first run only)...'
    python -m venv (Join-Path $backend 'venv')
    & $python -m pip install -r (Join-Path $backend 'requirements.txt')
}

Write-Host 'Starting the YOLO backend in a new window...'
Start-Process -FilePath $python -ArgumentList 'train_detector.py', '--api' -WorkingDirectory $backend

Write-Host 'Starting the web app...'
Set-Location $app
flutter run -d chrome

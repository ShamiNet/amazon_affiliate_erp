$ErrorActionPreference = 'Stop'

$pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if ($null -eq $pythonLauncher) {
    throw "Python Launcher was not found. Install 64-bit Python 3.12 and enable the Python Launcher, then run this script again."
}

$runtimeDirectory = Join-Path $env:LOCALAPPDATA 'AmazonAffiliateERP\paddle-ocr'
$runtimePython = Join-Path $runtimeDirectory 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $runtimePython -PathType Leaf)) {
    & $pythonLauncher.Source -3.12 -m venv $runtimeDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Python 3.12 was not found. Install 64-bit Python 3.12, then run this script again."
    }
}

$requirements = Join-Path $PSScriptRoot 'requirements-paddle.txt'
& $runtimePython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    throw "Could not update pip in the PaddleOCR environment."
}
& $runtimePython -m pip install -r $requirements
if ($LASTEXITCODE -ne 0) {
    throw "PaddleOCR installation failed. Check your internet connection and retry."
}

Write-Host "Downloading the English and Arabic PaddleOCR models..."
& $runtimePython -c "from paddleocr import PaddleOCR; options = {'device': 'cpu', 'use_doc_orientation_classify': False, 'use_doc_unwarping': False, 'use_textline_orientation': False}; PaddleOCR(lang='en', **options); PaddleOCR(lang='ar', **options)"
if ($LASTEXITCODE -ne 0) {
    throw "Could not download the PaddleOCR models. Check your internet connection and rerun this script."
}

Write-Host "PaddleOCR is installed for the current Windows user."
Write-Host "The Arabic/English recognition models are cached for offline use."
Write-Host "Restart Amazon Affiliate ERP before extracting a report."

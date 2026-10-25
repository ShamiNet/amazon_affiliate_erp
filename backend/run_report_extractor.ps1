$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$ocrExecutable = Join-Path $PSScriptRoot 'ocr_runtime\tesseract.exe'
$ocrTessdata = Join-Path $PSScriptRoot 'ocr_runtime\tessdata'
if (-not (Test-Path -LiteralPath $ocrExecutable -PathType Leaf)) {
    throw "Bundled Tesseract OCR executable is missing: $ocrExecutable"
}
if (-not (Test-Path -LiteralPath (Join-Path $ocrTessdata 'ara.traineddata') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $ocrTessdata 'eng.traineddata') -PathType Leaf)) {
    throw "Bundled Arabic and English Tesseract language data is missing: $ocrTessdata"
}

$env:TESSERACT_CMD = $ocrExecutable
$env:TESSERACT_TESSDATA_DIR = $ocrTessdata
$paddlePython = Join-Path $env:LOCALAPPDATA 'AmazonAffiliateERP\paddle-ocr\Scripts\python.exe'
if (Test-Path -LiteralPath $paddlePython -PathType Leaf) {
    & $paddlePython .\report_extractor.py
} else {
    python .\report_extractor.py
}
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

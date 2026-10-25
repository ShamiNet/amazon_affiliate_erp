# Local report OCR

The Flutter app sends a screenshot to this local service, which reads the
visible table with PaddleOCR when its optional local runtime is installed, and
otherwise uses bundled Tesseract OCR. Results are drafts for the existing
review, spreadsheet export, and import workflow. The service does not call an
AI API, access Amazon, or upload screenshots.

## Requirements

- Python 3.10 or newer
- The Windows installer bundles Tesseract OCR and Arabic (`ara`) and English
  (`eng`) language data under `backend\ocr_runtime`.
- Optional higher-accuracy OCR: 64-bit Python 3.12 and internet access for
  installation and initial model download. PaddleOCR inference runs locally.

For a source checkout, install Tesseract with Arabic and English data, then set
`TESSERACT_CMD` to the full path of `tesseract.exe`. Set
`TESSERACT_TESSDATA_DIR` to the folder containing both language files if they
are not in Tesseract's default data directory.

To enable PaddleOCR on Windows, install 64-bit Python 3.12 with the Python
Launcher, then run this once from the `backend` folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup_paddle_ocr.ps1
```

This installs PaddleOCR and PaddlePaddle into a per-user environment at
`%LOCALAPPDATA%\AmazonAffiliateERP\paddle-ocr`, avoiding changes to the system
Python, then downloads the English and Arabic model files. Setup needs internet
access; screenshots are processed locally and are not sent to Paddle. Once
setup completes, inference can run offline.

## Run on Windows

Start the service from this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\backend\run_report_extractor.ps1
```

Keep the terminal open while using the app. The page status reports which OCR
engine is active. To stop the local service, press `Ctrl+C`.

When the Flutter app is launched normally, it also tries to start this backend
automatically. If the OCR page still shows "service not connected", read the
status details in the page and ensure Python 3.10+ is installed and reachable
from `PATH`.

For an extraction that closes its connection unexpectedly, restart the app so
the updated backend starts, retry once, then inspect
`%LOCALAPPDATA%\AmazonAffiliateERP\logs\report_extractor.log`. The log records
request size, duration, and errors only; screenshot contents are never logged.

If you edit or update the OCR service, stop its running process with `Ctrl+C`
and run the script again. The app connects only to
`http://127.0.0.1:8765`; keep it bound to loopback and do not expose port 8765
to the network.

## Accuracy and privacy

- No API key or cloud service is used for OCR.
- Tesseract does not need internet access. PaddleOCR needs internet only for
  setup and the initial model downloads.
- The service accepts PNG, JPEG, or WEBP screenshots up to 10 MB.
- Image bytes are processed in memory and are not written to disk or logged.
- OCR may misread small, blurred, or low-contrast text. Review and correct the
  draft table before copying it to a sheet or importing it into the ERP.
- If the table is not detected, select a clearer image that includes the
  table headings, or crop the screenshot to the table before pasting it.
- The local service is not an internet-facing backend. Do not expose it as a
  public or remote service.

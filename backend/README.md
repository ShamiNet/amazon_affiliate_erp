# Local Gemini report extractor

The Flutter app sends an explicitly selected screenshot to this local service.
It does not sign in to Amazon or send anything to Amazon. The service binds to
`127.0.0.1` only and calls the Gemini Interactions API. API keys are stored
encrypted by the Flutter app's secure-storage plugin on this Windows device.
The currently selected key is sent to the local extractor only when an
approved extraction request is made; the extractor does not persist it.

## Requirements

- Python 3.10 or newer
- Network access to `generativelanguage.googleapis.com`

## Run on Windows

From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\backend\run_report_extractor.ps1
```

Keep this terminal open while using the app. Add one or more Gemini API keys in
the app's report-image screen, then choose the key to use. To stop the local
service, press `Ctrl+C`.

If you edit or update the extractor, stop its running process with `Ctrl+C`
and run the script again. A running Python process does not load source changes
automatically.

The app connects only to `http://127.0.0.1:8765`. This implementation is
intentionally local-only; do not expose it as a public or remote service.

## Privacy and limits

- The app asks for consent each time a screenshot is selected.
- Images are sent only to this local service and then to Gemini for extraction.
- The service accepts PNG, JPEG, or WEBP images up to 10 MB.
- The service does not write request bodies, images, API keys, or Gemini
  responses to disk or logs.
- The local service accepts the API key only in the extraction request header.
  It does not return the key from its health endpoint or persist it.
- The local service is not an internet-facing backend. Do not bind it to a
  public interface or expose port 8765 to the network.
- The app does not implement remote-service authentication. Do not change its
  local endpoint to a public URL without first adding and reviewing an
  authentication design.
- The extracted table is only a draft. Review it before copying into a sheet.

## Location errors and exposed keys

If the service reports `User location is not supported for the API`, Google is
rejecting the request based on the connection's location, not the API key.
Check Google's [official Gemini API supported regions](https://ai.google.dev/gemini-api/docs/available-regions).
If you are in a supported region, check whether your normal network is routed
through a VPN, proxy, or gateway in another region. Do not use routing to
circumvent Google's regional restrictions. Google documents Gemini API in
Gemini Enterprise Agent Platform as an option to investigate for unsupported
regions, subject to its own availability and requirements.

If an API key appears in a screenshot, chat, or log, revoke it in Google AI
Studio and create a replacement. Add the replacement using the app's secure
key manager; do not put it in source code or share it.

Gemini API pricing, model availability, and terms can change; check the
current Google AI documentation and account billing before use.

# Amazon Affiliate ERP

Flutter Windows desktop application for managing Amazon affiliate campaigns.

## Analyze a screenshot and copy results to a sheet

1. Start the local Gemini extractor using the setup in [`backend/README.md`](backend/README.md).
2. Run the Flutter app from this folder:

   ```powershell
   flutter run -d windows
   ```

3. Open **استخراج بيانات التقارير**, select **أرباح Amazon** or
   **تقرير الحملات الإعلانية**, and choose your saved screenshot.
4. Review the privacy notice and explicitly approve sending the screenshot to
   Gemini. The app does not log into Amazon or upload anything to Amazon.
5. Review and correct the extracted table, then select **نسخ TSV إلى الشيت** and
   paste it into Google Sheets or Excel.

Extraction requires an internet connection, an active Gemini API key in the
local backend process, and applicable Gemini API billing. The key is not
included in the Flutter app or source code.

## Development checks

```powershell
flutter analyze
flutter test
flutter build windows
```

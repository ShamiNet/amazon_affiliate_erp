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

## Export, import, and clear application data

Open the backup/data menu in the sidebar to export or import an `.xlsx`
workbook. The workbook contains a separate sheet for each application data
section; keep the sheet names and column headers unchanged when editing it.
Import merges rows by their section-specific identifiers, updating matching
rows and adding new ones without deleting other local records.

Passwords, recovery codes, two-factor details, IBAN/BIC, and sensitive bank
address/document fields are intentionally excluded from spreadsheet exports.
When importing a matching row, those existing local values are preserved.
Exporting a blank workbook after clearing data provides a sheet template with
all supported tabs and column headers.

The **تصفير جميع البيانات** action permanently empties all ERP data tables. It
does not restore factory data; the securely stored Gemini API key and UI
preferences are retained. Spreadsheet exports cannot recover the excluded
sensitive fields. Use **استعادة البيانات الأصلية** if the intended action is
to return to the factory-seeded data instead.

## Development checks

```powershell
flutter analyze
flutter test
flutter build windows
```

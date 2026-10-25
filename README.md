# Amazon Affiliate ERP

Flutter Windows desktop application for managing Amazon affiliate campaigns.

## Extract a report from a screenshot

1. Run the Flutter app:

   ```powershell
   flutter run -d windows
   ```
2. Open **استخراج بيانات التقارير** and choose **Gemini السحابي** as the
   extraction engine. Add one or more named Gemini API key profiles; select
   the active profile from the dropdown. Keys are stored using
   Windows-protected storage on this device and can be updated or deleted.
3. Select **أرباح Amazon** or
   **تقرير الحملات الإعلانية**, and choose your saved screenshot.
4. Paste a screenshot with **لصق من الحافظة (Ctrl+V)**, or choose an image file.
5. Select **استخراج البيانات**. The screenshot is sent to Google Gemini over
   HTTPS; API usage may be subject to the limits and billing settings of your
   Google account. The desktop app protects the key at rest, but a key used by
   a desktop client cannot be made secret from someone with access to that
   device. Use a dedicated key with appropriate restrictions and quota.
6. Review and correct the extracted draft before using the existing import,
   **نسخ TSV إلى الشيت**, or CSV/TSV export actions.

For an Amazon Associates earnings summary, copying the page text from the
browser and using **لصق جدول من الحافظة** extracts labeled metrics locally
without OCR or Gemini. This deterministic parser is intended for the familiar
summary layout; it cannot interpret arbitrary page text or unlabeled tables.

To keep images on the device instead, select **OCR المحلي**. This option uses
the local OCR service; see [`backend/README.md`](backend/README.md) for setup.
Gemini results are drafts and should always be checked before importing.

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

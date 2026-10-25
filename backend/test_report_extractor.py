import unittest
from unittest.mock import patch

from report_extractor import (
    _ocr_status,
    _read_paddle_words,
    _tessdata_args,
    extract_report,
    extract_table_from_tsv,
)


def _tsv(words):
    header = (
        "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\t"
        "width\theight\tconf\ttext"
    )
    rows = [header]
    for y, entries in words:
        for word_number, (text, left, width) in enumerate(entries, start=1):
            rows.append(
                f"5\t1\t1\t1\t{y}\t{word_number}\t{left}\t{y * 20}\t"
                f"{width}\t10\t95\t{text}"
            )
    return "\n".join(rows)


class ReportExtractorTests(unittest.TestCase):
    def test_extracts_amazon_earnings_rows_by_header_positions(self):
        tsv = _tsv([
            (1, [("Clicks", 10, 42), ("Ordered", 130, 65),
                 ("Items", 200, 40), ("Commission", 320, 80)]),
            (2, [("120", 15, 25), ("5", 160, 10), ("$12.40", 330, 50)]),
        ])

        result = extract_table_from_tsv(tsv, "amazon_earnings")

        self.assertEqual(result["columns"], ["Clicks", "Ordered Items", "Commission"])
        self.assertEqual(result["rows"], [["120", "5", "$12.40"]])
        self.assertTrue(any("OCR" in warning for warning in result["warnings"]))

    def test_extracts_campaign_cost_and_name(self):
        tsv = _tsv([
            (1, [("Campaign", 20, 70), ("Cost", 250, 35)]),
            (2, [("SH-01", 25, 45), ("$2.40", 250, 40)]),
        ])

        result = extract_table_from_tsv(tsv, "ad_campaigns")

        self.assertEqual(result["columns"], ["Campaign", "Cost"])
        self.assertEqual(result["rows"], [["SH-01", "$2.40"]])

    def test_rejects_a_report_without_detectable_headers(self):
        tsv = _tsv([
            (1, [("random", 10, 40), ("text", 200, 30)]),
            (2, [("12", 10, 15), ("34", 200, 15)]),
        ])
        with self.assertRaisesRegex(ValueError, "عناوين أعمدة"):
            extract_table_from_tsv(tsv, "amazon_earnings")

    def test_reports_missing_tesseract_without_faking_availability(self):
        with patch("report_extractor._tesseract_path", return_value=None):
            status = _ocr_status()

        self.assertFalse(status["available"])
        self.assertIn("Tesseract", status["error"])

    def test_uses_configured_user_language_data_directory(self):
        with patch(
            "report_extractor.TESSERACT_TESSDATA_DIR",
            r"C:\Users\shami\AppData\Local\Tesseract\tessdata",
        ):
            self.assertEqual(
                _tessdata_args(),
                [
                    "--tessdata-dir",
                    r"C:\Users\shami\AppData\Local\Tesseract\tessdata",
                ],
            )

    def test_retries_using_sparse_page_layout_when_first_pass_fails(self):
        tsv = _tsv([
            (1, [("Campaign", 20, 70), ("Cost", 250, 35)]),
            (2, [("SH-01", 25, 45), ("$2.40", 250, 40)]),
        ])
        with patch("report_extractor._run_tesseract", side_effect=[ "", tsv]) as run:
            result = extract_report(b"image-bytes", "ad_campaigns")

        self.assertEqual(run.call_count, 2)
        self.assertEqual(result["rows"], [["SH-01", "$2.40"]])

    def test_reads_paddle_boxes_and_scores(self):
        words = _read_paddle_words([{
            "res": {
                "rec_texts": ["Clicks", "Commission"],
                "rec_boxes": [[10, 20, 45, 35], [120, 20, 180, 35]],
                "rec_scores": [0.98, 0.91],
            },
        }])

        self.assertEqual([word["text"] for word in words], ["Clicks", "Commission"])
        self.assertEqual(words[0]["left"], 10)
        self.assertEqual(words[0]["center_y"], 27.5)
        self.assertEqual(words[1]["confidence"], 91)

    def test_prefers_paddleocr_when_it_extracts_a_table(self):
        words = _read_paddle_words([{
            "res": {
                "rec_texts": ["Clicks", "Commission", "120", "$12.40"],
                "rec_boxes": [
                    [10, 10, 50, 25],
                    [120, 10, 190, 25],
                    [10, 40, 35, 55],
                    [120, 40, 170, 55],
                ],
                "rec_scores": [0.99, 0.99, 0.99, 0.99],
            },
        }])
        with patch("report_extractor._paddle_available", return_value=True), \
                patch("report_extractor._run_paddleocr", return_value=words), \
                patch("report_extractor._run_tesseract") as run_tesseract:
            result = extract_report(b"image-bytes", "amazon_earnings")

        self.assertEqual(result["rows"], [["120", "$12.40"]])
        self.assertIn("PaddleOCR (en)", result["warnings"][0])
        run_tesseract.assert_not_called()

    def test_falls_back_to_tesseract_when_paddleocr_fails(self):
        tsv = _tsv([
            (1, [("Clicks", 10, 42), ("Commission", 120, 80)]),
            (2, [("120", 15, 25), ("$12.40", 125, 50)]),
        ])
        with patch("report_extractor._paddle_available", return_value=True), \
                patch(
                    "report_extractor._run_paddleocr",
                    side_effect=RuntimeError("model unavailable"),
                ), \
                patch("report_extractor._run_tesseract", return_value=tsv):
            result = extract_report(b"image-bytes", "amazon_earnings")

        self.assertEqual(result["rows"], [["120", "$12.40"]])
        self.assertTrue(any("Tesseract احتياطياً" in warning for warning in result["warnings"]))
        self.assertTrue(any("model unavailable" in warning for warning in result["warnings"]))


if __name__ == "__main__":
    unittest.main()

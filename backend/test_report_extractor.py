import unittest
from email.message import Message
from unittest.mock import patch

from report_extractor import (
    _describe_gemini_error,
    _extract_output_text,
    _get_api_key,
    _parse_model_json,
    extract_report,
)


class ReportExtractorTests(unittest.TestCase):
    def test_reads_api_key_from_request_header(self):
        headers = Message()
        headers["X-Gemini-API-Key"] = "  test-key  "

        self.assertEqual(_get_api_key(headers), "test-key")
        self.assertEqual(_get_api_key(Message()), "")

    def test_sends_selected_key_to_gemini_and_not_in_request_body(self):
        api_key = "test-secret-key"
        response_payload = {
            "output_text": (
                '{"title":"Report","columns":["Date"],'
                '"rows":[["2026-10-18"]],"warnings":[]}'
            )
        }

        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                import json

                return json.dumps(response_payload).encode("utf-8")

        with patch("report_extractor.urlopen", return_value=FakeResponse()) as mocked:
            result = extract_report(b"image", "image/png", "amazon_earnings", api_key)

        request = mocked.call_args.args[0]
        self.assertEqual(request.get_header("X-goog-api-key"), api_key)
        self.assertNotIn(api_key.encode("utf-8"), request.data)
        self.assertEqual(result["rows"], [["2026-10-18"]])

    def test_parses_json_response_with_table_and_warnings(self):
        result = _parse_model_json(
            '{"title":"Earnings","columns":["Date","Earnings"],'
            '"rows":[["2026-10-18","12.40"]],"warnings":[]}'
        )
        self.assertEqual(result["columns"], ["Date", "Earnings"])
        self.assertEqual(result["rows"], [["2026-10-18", "12.40"]])

    def test_extracts_text_from_gemini_candidates_payload(self):
        response = {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {"text": '{"title":"Report","columns":["Date"],"rows":[["2026-10-18"]],"warnings":[]}'},
                        ]
                    }
                }
            ]
        }
        self.assertEqual(
            _extract_output_text(response),
            '{"title":"Report","columns":["Date"],"rows":[["2026-10-18"]],"warnings":[]}',
        )

    def test_parses_json_fenced_response(self):
        result = _parse_model_json(
            '```json\n{"title":"Report","columns":["Date"],'
            '"rows":[["2026-10-18"]],"warnings":[]}\n```'
        )
        self.assertEqual(result["title"], "Report")

    def test_rejects_rows_with_wrong_column_count(self):
        with self.assertRaises(ValueError):
            _parse_model_json(
                '{"title":"Report","columns":["Date","Earnings"],'
                '"rows":[["2026-10-18"]],"warnings":[]}'
            )

    def test_reports_invalid_api_key_as_a_configuration_error(self):
        message = _describe_gemini_error(401, "API key not valid")
        self.assertIn("Gemini API key", message)
        self.assertIn("API key not valid", message)

    def test_reports_quota_errors_separately_from_key_errors(self):
        message = _describe_gemini_error(429, "quota exceeded")
        self.assertIn("حد الاستخدام", message)
        self.assertIn("quota exceeded", message)

    def test_reports_unsupported_location_without_suggesting_key_is_invalid(self):
        message = _describe_gemini_error(
            400,
            "User location is not supported for the API use.",
        )
        self.assertIn("موقع الاتصال الحالي", message)
        self.assertIn("ليس خطأ في المفتاح", message)
        self.assertNotIn("تحقق من صحة Gemini API key", message)

    def test_reports_temporary_model_overload_separately(self):
        message = _describe_gemini_error(
            503,
            "The model is experiencing high demand. Please try again later.",
        )
        self.assertIn("مشغول حالياً", message)
        self.assertIn("انتظر دقيقة أو دقيقتين", message)
        self.assertNotIn("تحقق من صحة Gemini API key", message)


if __name__ == "__main__":
    unittest.main()

import base64
import binascii
import csv
import importlib.metadata
import importlib.util
import io
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import re
import shutil
import statistics
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = "127.0.0.1"
PORT = int(os.environ.get("REPORT_EXTRACTOR_PORT", "8765"))
TESSERACT_CMD = os.environ.get("TESSERACT_CMD", "tesseract")
TESSERACT_TESSDATA_DIR = os.environ.get("TESSERACT_TESSDATA_DIR", "").strip()
SERVICE_VERSION = 8
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_REQUEST_BYTES = 15 * 1024 * 1024
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_REPORT_TYPES = {"amazon_earnings", "ad_campaigns"}
OCR_LANGUAGES = ("ara", "eng")
_PADDLE_ENGINES = {}
_PADDLE_ENGINES_LOCK = threading.Lock()
LOGGER = logging.getLogger("report_extractor")


def _configure_logging():
    log_directory = Path(
        os.environ.get("LOCALAPPDATA", Path.home())
    ) / "AmazonAffiliateERP" / "logs"
    try:
        log_directory.mkdir(parents=True, exist_ok=True)
        handler = RotatingFileHandler(
            log_directory / "report_extractor.log",
            maxBytes=1_000_000,
            backupCount=3,
            encoding="utf-8",
        )
        handler.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)s %(threadName)s %(message)s"
        ))
        LOGGER.setLevel(logging.INFO)
        LOGGER.addHandler(handler)
    except OSError as error:
        LOGGER.setLevel(logging.ERROR)
        LOGGER.error("Could not initialize local OCR log: %s", error)
        print(f"Report OCR: could not initialize local log: {error}", flush=True)

_AMAZON_HEADERS = (
    (("ordered revenue", "ordered sales", "قيمة الطلبات", "إيرادات الطلبات",
      "عائد الطلبات"), "Ordered Revenue"),
    (("ordered items", "items ordered", "الطلبات المسجلة", "الطلبات", "طلبات"),
     "Ordered Items"),
    (("shipped items", "items shipped", "المنتجات المشحونة", "المشحونة",
      "المشحون"), "Shipped Items"),
    (("returned items", "items returned", "المنتجات المرتجعة", "المرتجعة",
      "المرتجع", "returns"), "Returned Items"),
    (("total revenue", "shipped revenue", "sales", "revenue", "إجمالي قيمة المبيعات",
      "قيمة المبيعات", "إجمالي المبيعات", "المبيعات", "إيرادات الشحن"), "Total Revenue"),
    (("total earnings", "الأرباح الإجمالية", "إجمالي الأرباح", "الأرباح الكلية"),
     "Total Earnings"),
    (("commission", "commissions", "عمولات أمازون", "عمولة أمازون", "العمولات",
      "العمولة", "عمولات", "عمولة", "رسوم الإعلانات", "أرباح الإعلانات"), "Commission"),
    (("bonus", "bounties", "bounty", "المكافآت الإضافية", "المكافآت",
      "المكافأة", "مكافآت", "مكافأة", "بونص", "حوافز"), "Bonus"),
    (("clicks", "click", "النقرات", "نقرات"), "Clicks"),
    (("date", "التاريخ", "تاريخ", "اليوم"), "Date"),
    (("campaign", "store", "tracking", "account", "profile", "product", "item",
      "campaign name", "اسم الحملة", "معرف المتجر", "معرف التتبع", "رمز الحساب",
      "البروفايل", "الحساب", "المنتج", "الصنف"), "Account / Product"),
)

_CAMPAIGN_HEADERS = (
    (("campaign id", "campaign code", "معرف الحملة", "رمز الحملة"), "Campaign ID"),
    (("campaign name", "campaign", "اسم الحملة"), "Campaign"),
    (("impressions", "الظهور", "مرات الظهور"), "Impressions"),
    (("cpm",), "CPM"),
    (("cost", "spend", "التكلفة", "المصروف"), "Cost"),
    (("clicks", "click", "النقرات", "نقرات"), "Clicks"),
    (("date", "التاريخ", "تاريخ", "اليوم"), "Date"),
    (("folder", "المجلد"), "Folder"),
)


def _json_response(handler, status, payload):
    response = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(response)))
    handler.send_header("Cache-Control", "no-store")
    handler.end_headers()
    try:
        handler.wfile.write(response)
    except (BrokenPipeError, ConnectionResetError):
        print("Report OCR: client disconnected before the response.", flush=True)


def _tesseract_path():
    return shutil.which(TESSERACT_CMD)


def _tessdata_args():
    if not TESSERACT_TESSDATA_DIR:
        return []
    return ["--tessdata-dir", TESSERACT_TESSDATA_DIR]


def _paddle_available():
    return (
        importlib.util.find_spec("paddleocr") is not None
        and importlib.util.find_spec("paddle") is not None
    )


def _paddle_engine(language):
    with _PADDLE_ENGINES_LOCK:
        engine = _PADDLE_ENGINES.get(language)
        if engine is None:
            try:
                from paddleocr import PaddleOCR
            except ImportError as error:
                raise RuntimeError(
                    "PaddleOCR غير مثبت. شغّل backend\\setup_paddle_ocr.ps1 "
                    "باستخدام Python 3.12."
                ) from error
            try:
                engine = PaddleOCR(
                    lang=language,
                    device="cpu",
                    use_doc_orientation_classify=False,
                    use_doc_unwarping=False,
                    use_textline_orientation=False,
                )
            except (OSError, RuntimeError, TypeError, ValueError) as error:
                raise RuntimeError(f"تعذر تهيئة PaddleOCR: {error}") from error
            _PADDLE_ENGINES[language] = engine
        return engine


def _paddle_version():
    try:
        return importlib.metadata.version("paddleocr")
    except importlib.metadata.PackageNotFoundError:
        return "غير معروف"


def _ocr_status():
    if _paddle_available():
        return {
            "available": True,
            "engine": (
                f"PaddleOCR {_paddle_version()} محلي "
                "(قد تُحمّل النماذج عند أول استخدام)"
            ),
        }

    executable = _tesseract_path()
    if executable is None:
        return {
            "available": False,
            "error": (
                "لم يتم العثور على Tesseract OCR. ثبّته مع بيانات اللغتين "
                "العربية والإنجليزية ثم أعد تشغيل الخدمة."
            ),
        }
    try:
        result = subprocess.run(
            [executable, *_tessdata_args(), "--list-langs"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return {
            "available": False,
            "error": f"تعذر تشغيل Tesseract OCR: {error}",
        }
    languages = set(result.stdout.splitlines())
    missing = [language for language in OCR_LANGUAGES if language not in languages]
    if result.returncode != 0 or missing:
        missing_text = ", ".join(missing) if missing else "بيانات اللغات"
        return {
            "available": False,
            "error": (
                f"بيانات Tesseract OCR غير مكتملة ({missing_text}). "
                "ثبّت العربية والإنجليزية ثم أعد تشغيل الخدمة."
            ),
        }
    version = subprocess.run(
        [executable, "--version"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    version_line = version.stdout.splitlines()[0] if version.stdout else "Tesseract OCR"
    return {"available": True, "engine": version_line}


def _normalize_text(value):
    text = value.casefold()
    text = re.sub(r"[\u064b-\u065f\u0670]", "", text)
    return text.translate(str.maketrans({
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ى": "ي",
    }))


def _header_definitions(report_type):
    return _CAMPAIGN_HEADERS if report_type == "ad_campaigns" else _AMAZON_HEADERS


def _classify_header(text, definitions):
    normalized = _normalize_text(text)
    for aliases, canonical_name in definitions:
        if any(_normalize_text(alias) in normalized for alias in aliases):
            return canonical_name
    return None


def _read_tsv_words(tsv_text):
    words = []
    reader = csv.DictReader(io.StringIO(tsv_text), delimiter="\t")
    for row in reader:
        if row.get("level") != "5":
            continue
        text = (row.get("text") or "").strip()
        try:
            confidence = float(row.get("conf", "-1"))
            left = int(row["left"])
            top = int(row["top"])
            width = int(row["width"])
            height = int(row["height"])
        except (KeyError, TypeError, ValueError):
            continue
        if text and confidence >= 0 and width > 0 and height > 0:
            words.append({
                "text": text,
                "confidence": confidence,
                "left": left,
                "right": left + width,
                "top": top,
                "bottom": top + height,
                "center_y": top + height / 2,
                "height": height,
            })
    return words


def _group_visual_rows(words):
    if not words:
        return []
    sorted_words = sorted(words, key=lambda word: word["center_y"])
    typical_height = statistics.median(word["height"] for word in sorted_words)
    tolerance = max(7, typical_height * 0.7)
    rows = []
    for word in sorted_words:
        if not rows or word["center_y"] - rows[-1]["center_y"] > tolerance:
            rows.append({"center_y": word["center_y"], "words": [word]})
            continue
        row = rows[-1]
        row["words"].append(word)
        row["center_y"] = statistics.median(
            item["center_y"] for item in row["words"]
        )
    return rows


def _split_cells(row):
    words = sorted(row["words"], key=lambda word: word["left"])
    typical_height = statistics.median(word["height"] for word in words)
    gap_limit = max(12, typical_height)
    cells = []
    for word in words:
        if not cells or word["left"] - cells[-1]["right"] > gap_limit:
            cells.append({
                "left": word["left"],
                "right": word["right"],
                "top": word["top"],
                "bottom": word["bottom"],
                "words": [word],
            })
            continue
        cell = cells[-1]
        cell["right"] = max(cell["right"], word["right"])
        cell["top"] = min(cell["top"], word["top"])
        cell["bottom"] = max(cell["bottom"], word["bottom"])
        cell["words"].append(word)
    for cell in cells:
        cell["text"] = " ".join(word["text"] for word in cell["words"]).strip()
        cell["center_x"] = (cell["left"] + cell["right"]) / 2
        cell["confidence"] = statistics.mean(
            word["confidence"] for word in cell["words"]
        )
    return cells


def _candidate_headers(visual_rows, definitions, report_type):
    candidates = []
    min_matches = 2
    for row_index, visual_row in enumerate(visual_rows):
        cells = _split_cells(visual_row)
        matched = [
            _classify_header(cell["text"], definitions) for cell in cells
        ]
        matches = [value for value in matched if value]
        unique_matches = set(matches)
        if report_type == "ad_campaigns":
            if not {"Campaign", "Cost"}.issubset(unique_matches):
                continue
        elif len(unique_matches) < min_matches:
            continue
        columns = [
            match or cell["text"] for cell, match in zip(cells, matched)
        ]
        candidates.append({
            "row_index": row_index,
            "cells": cells,
            "columns": columns,
            "score": len(unique_matches),
        })
    return candidates


def _rows_for_header(visual_rows, header):
    centers = [cell["center_x"] for cell in header["cells"]]
    first_data_y = max(cell["bottom"] for cell in header["cells"])
    results = []
    confidence_scores = []
    for visual_row in visual_rows[header["row_index"] + 1:]:
        if visual_row["center_y"] <= first_data_y:
            continue
        values = [[] for _ in centers]
        confidences = [[] for _ in centers]
        for word in sorted(visual_row["words"], key=lambda item: item["left"]):
            index = min(
                range(len(centers)),
                key=lambda candidate: abs(centers[candidate] - (
                    word["left"] + word["right"]
                ) / 2),
            )
            values[index].append(word["text"])
            confidences[index].append(word["confidence"])
        row = [" ".join(value).strip() for value in values]
        populated = [value for value in row if value]
        if len(populated) < 2 or not any(re.search(r"\d", value) for value in populated):
            continue
        results.append(row)
        row_confidences = [value for column in confidences for value in column]
        if row_confidences:
            confidence_scores.append(statistics.mean(row_confidences))
    return results, confidence_scores


def _extract_table_from_words(words, report_type, engine_name):
    visual_rows = _group_visual_rows(words)
    definitions = _header_definitions(report_type)
    candidates = _candidate_headers(visual_rows, definitions, report_type)
    extracted = []
    for candidate in candidates:
        rows, confidence_scores = _rows_for_header(visual_rows, candidate)
        if rows:
            extracted.append((candidate, rows, confidence_scores))
    if not extracted:
        required = (
            "اسم الحملة والتكلفة"
            if report_type == "ad_campaigns"
            else "عناوين أعمدة تقرير الأرباح"
        )
        raise ValueError(
            f"لم يتمكن OCR من تحديد {required}. استخدم لقطة أوضح تشمل عناوين الجدول."
        )
    header, rows, confidence_scores = max(
        extracted,
        key=lambda item: (item[0]["score"], -item[0]["row_index"]),
    )
    warnings = [
        f"تمت القراءة محلياً عبر {engine_name}؛ راجع القيم والعناوين قبل اعتمادها."
    ]
    if confidence_scores and statistics.mean(confidence_scores) < 60:
        warnings.append("ثقة قراءة بعض النصوص منخفضة؛ تحقق منها يدوياً.")
    return {
        "title": (
            "أرباح Amazon (OCR محلي)"
            if report_type == "amazon_earnings"
            else "الحملات الإعلانية (OCR محلي)"
        ),
        "columns": header["columns"],
        "rows": rows,
        "warnings": warnings,
    }


def extract_table_from_tsv(tsv_text, report_type):
    if report_type not in ALLOWED_REPORT_TYPES:
        raise ValueError("نوع التقرير غير مدعوم.")
    return _extract_table_from_words(
        _read_tsv_words(tsv_text),
        report_type,
        "Tesseract OCR",
    )


def _as_list(value):
    return value.tolist() if hasattr(value, "tolist") else value


def _paddle_result_payload(result):
    payload = result
    if not isinstance(payload, dict):
        payload = getattr(payload, "json", None)
        if callable(payload):
            payload = payload()
    if not isinstance(payload, dict):
        raise RuntimeError("أعاد PaddleOCR نتيجة بصيغة غير مدعومة.")
    nested = payload.get("res")
    return nested if isinstance(nested, dict) else payload


def _read_paddle_words(results):
    words = []
    for result in results:
        payload = _paddle_result_payload(result)
        texts = _as_list(payload.get("rec_texts", []))
        boxes = _as_list(payload.get("rec_boxes", payload.get("dt_polys", [])))
        scores = _as_list(payload.get("rec_scores", []))
        for index, text in enumerate(texts):
            text = str(text).strip()
            if not text or index >= len(boxes):
                continue
            coordinates = _as_list(boxes[index])
            if not coordinates:
                continue
            if len(coordinates) == 4 and not isinstance(coordinates[0], (list, tuple)):
                left, top, right, bottom = map(float, coordinates)
            else:
                points = [_as_list(point) for point in coordinates]
                left = min(float(point[0]) for point in points)
                right = max(float(point[0]) for point in points)
                top = min(float(point[1]) for point in points)
                bottom = max(float(point[1]) for point in points)
            if right <= left or bottom <= top:
                continue
            confidence = float(scores[index]) if index < len(scores) else 1.0
            words.append({
                "text": text,
                "confidence": confidence * 100,
                "left": int(left),
                "right": int(right),
                "top": int(top),
                "bottom": int(bottom),
                "center_y": (top + bottom) / 2,
                "height": bottom - top,
            })
    return words


def _run_paddleocr(image_bytes, language):
    try:
        import numpy
        from PIL import Image
    except ImportError as error:
        raise RuntimeError(
            "متطلبات PaddleOCR غير مكتملة. أعد تشغيل backend\\setup_paddle_ocr.ps1."
        ) from error

    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            rgb_image = numpy.asarray(image.convert("RGB"))
    except (OSError, ValueError) as error:
        raise RuntimeError("تعذر تجهيز الصورة لمحرك PaddleOCR.") from error
    bgr_image = rgb_image[:, :, ::-1].copy()
    try:
        results = _paddle_engine(language).predict(bgr_image)
        return _read_paddle_words(results)
    except (
        AttributeError,
        IndexError,
        OSError,
        RuntimeError,
        TypeError,
        ValueError,
    ) as error:
        raise RuntimeError(f"تعذر تشغيل PaddleOCR ({language}): {error}") from error


def _run_tesseract(image_bytes, psm):
    executable = _tesseract_path()
    if executable is None:
        raise RuntimeError(_ocr_status()["error"])
    try:
        result = subprocess.run(
            [
                executable,
                "stdin",
                "stdout",
                "-l",
                "+".join(OCR_LANGUAGES),
                *_tessdata_args(),
                "--psm",
                str(psm),
                "tsv",
        ],
            input=image_bytes,
            capture_output=True,
            timeout=50,
            check=False,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("انتهت مهلة OCR أثناء قراءة الصورة. جرّب صورة أصغر.") from None
    except OSError as error:
        raise RuntimeError(f"تعذر تشغيل Tesseract OCR: {error}") from None
    if result.returncode != 0:
        raise RuntimeError(
            "تعذر قراءة الصورة عبر Tesseract OCR. تحقق من ملفات اللغات وصيغة الصورة."
        )
    return result.stdout.decode("utf-8", errors="replace")


def extract_report(image_bytes, report_type):
    if report_type not in ALLOWED_REPORT_TYPES:
        raise ValueError("نوع التقرير غير مدعوم.")

    paddle_errors = []
    if _paddle_available():
        for language in ("en", "ar"):
            try:
                words = _run_paddleocr(image_bytes, language)
                return _extract_table_from_words(
                    words,
                    report_type,
                    f"PaddleOCR ({language})",
                )
            except (RuntimeError, ValueError) as error:
                paddle_errors.append(str(error))

    outputs = []
    for page_segmentation_mode in (6, 11):
        try:
            output = extract_table_from_tsv(
                _run_tesseract(image_bytes, page_segmentation_mode),
                report_type,
            )
            outputs.append(output)
        except ValueError:
            continue
    if not outputs:
        if paddle_errors:
            raise RuntimeError(
                "PaddleOCR لم يتمكن من قراءة الجدول. "
                + " | ".join(paddle_errors)
                + " | "
                + "لم يتم العثور على جدول واضح عبر Tesseract أيضاً. "
                  "قصّ منطقة الجدول وتأكد من ظهور العناوين والأرقام بوضوح."
            )
        raise RuntimeError(
            "لم يتم العثور على جدول واضح في الصورة. قصّ منطقة الجدول وتأكد "
            "من ظهور العناوين والأرقام بوضوح."
        )
    result = max(
        outputs,
        key=lambda output: len(output["columns"]) + len(output["rows"]),
    )
    if paddle_errors:
        result["warnings"].append(
            "تعذر PaddleOCR، استُخدم Tesseract احتياطياً: "
            + " | ".join(paddle_errors)
        )
    return result


class ReportExtractorHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            _json_response(self, 404, {"error": "المسار غير موجود."})
            return
        ocr = _ocr_status()
        _json_response(
            self,
            200,
            {
                "status": "ok",
                "service_version": SERVICE_VERSION,
                "engine": ocr.get("engine", "Tesseract OCR"),
                "available": ocr["available"],
                "error": ocr.get("error"),
            },
        )

    def do_POST(self):
        if self.path != "/v1/reports/extract-image":
            _json_response(self, 404, {"error": "المسار غير موجود."})
            return

        ocr = _ocr_status()
        if not ocr["available"]:
            _json_response(self, 503, {"error": ocr["error"]})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            _json_response(self, 400, {"error": "حجم الطلب غير صالح."})
            return
        if length <= 0 or length > MAX_REQUEST_BYTES:
            _json_response(self, 413, {"error": "حجم الصورة/الطلب غير مسموح."})
            return

        try:
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            if not isinstance(body, dict):
                raise ValueError("صيغة الطلب غير صحيحة.")
            report_type = body.get("report_type")
            mime_type = body.get("mime_type")
            image_base64 = body.get("image_base64")
            if report_type not in ALLOWED_REPORT_TYPES:
                raise ValueError("نوع التقرير غير مدعوم.")
            if mime_type not in ALLOWED_MIME_TYPES:
                raise ValueError("نوع الصورة غير مدعوم.")
            if not isinstance(image_base64, str):
                raise ValueError("بيانات الصورة غير موجودة.")
            image_bytes = base64.b64decode(image_base64, validate=True)
            if not image_bytes or len(image_bytes) > MAX_IMAGE_BYTES:
                raise ValueError("حجم الصورة غير مسموح.")
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            ValueError,
            binascii.Error,
        ) as error:
            _json_response(self, 400, {"error": str(error)})
            return

        request_id = uuid.uuid4().hex[:12]
        started_at = time.monotonic()
        LOGGER.info(
            "request=%s started type=%s bytes=%d",
            request_id,
            report_type,
            len(image_bytes),
        )
        try:
            result = extract_report(image_bytes, report_type)
        except RuntimeError as error:
            LOGGER.warning(
                "request=%s failed duration=%.2fs error=%s",
                request_id,
                time.monotonic() - started_at,
                error,
            )
            _json_response(self, 422, {"error": str(error)})
            return
        except (ValueError, KeyError, csv.Error) as error:
            LOGGER.exception(
                "request=%s output parsing failed duration=%.2fs",
                request_id,
                time.monotonic() - started_at,
            )
            _json_response(
                self,
                422,
                {"error": "تعذر تحليل جدول الصورة. جرّب صورة أوضح."},
            )
            return
        except Exception:
            LOGGER.exception(
                "request=%s unexpected OCR failure duration=%.2fs",
                request_id,
                time.monotonic() - started_at,
            )
            _json_response(
                self,
                500,
                {
                    "error": (
                        "حدث خطأ داخلي أثناء معالجة الصورة. "
                        f"معرّف التشخيص: {request_id}. "
                        "راجع سجل backend المحلي."
                    )
                },
            )
            return
        LOGGER.info(
            "request=%s completed duration=%.2fs rows=%d columns=%d",
            request_id,
            time.monotonic() - started_at,
            len(result["rows"]),
            len(result["columns"]),
        )
        _json_response(self, 200, result)

    def log_message(self, format_string, *args):
        if args:
            LOGGER.info("http %s", args[0])

    def log_error(self, format_string, *args):
        LOGGER.error("http server error: " + format_string, *args)

    def handle_error(self, request, client_address):
        LOGGER.exception("unhandled request error from %s", client_address[0])


def main():
    _configure_logging()
    server = ThreadingHTTPServer((HOST, PORT), ReportExtractorHandler)
    log_path = (
        Path(os.environ.get("LOCALAPPDATA", Path.home()))
        / "AmazonAffiliateERP" / "logs" / "report_extractor.log"
    )
    LOGGER.info("service starting at http://%s:%s", HOST, PORT)
    LOGGER.info("OCR status: %s", _ocr_status())
    print(f"Local report OCR listening on http://{HOST}:{PORT}", flush=True)
    print(f"OCR diagnostics: {log_path}", flush=True)
    print(f"Tesseract OCR: {_ocr_status()}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping report OCR.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

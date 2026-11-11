"""Unified BluePink Tuition Academic Suite API.

One-file Flask backend for the Tuition AI ML Super-App, interactive PDF library,
Granular Marks Gradebook and ScriptGrade OCR evaluation. State is persisted to
backend/data/app_state.json; uploaded files are stored in backend/uploads/.
OCR is optional and requires the Tesseract executable installed on the host.
"""
from __future__ import annotations

import json
import os
import re
import uuid
import threading
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename

try:
    from PIL import Image, ImageOps, ImageEnhance, ImageFilter
    import pytesseract
    from pytesseract import Output
    try:
        pytesseract.get_tesseract_version()
        OCR_AVAILABLE = True
    except Exception:
        OCR_AVAILABLE = False
except Exception:
    Image = None
    ImageOps = ImageEnhance = ImageFilter = None
    pytesseract = Output = None
    OCR_AVAILABLE = False

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
ASSET_DIR = PROJECT_DIR / "assets"
DATA_DIR = BASE_DIR / "data"
UPLOAD_DIR = BASE_DIR / "uploads"
STATE_FILE = DATA_DIR / "app_state.json"
DATA_DIR.mkdir(parents=True, exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
LOCK = threading.RLock()

app = Flask(__name__)
CORS(app)
app.config["MAX_CONTENT_LENGTH"] = 35 * 1024 * 1024


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def read_asset(filename: str, default: Any) -> Any:
    path = ASSET_DIR / filename
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return default


def grade_of(percent: float) -> str:
    if percent >= 90: return "A+"
    if percent >= 80: return "A"
    if percent >= 70: return "B"
    if percent >= 60: return "C"
    if percent >= 50: return "D"
    return "F"


def clean_mark(row: dict[str, Any]) -> dict[str, Any]:
    required = ("studentId", "academicYear", "subject", "marks")
    missing = [key for key in required if row.get(key) is None or str(row.get(key)).strip() == ""]
    if missing:
        raise ValueError("Missing required fields: " + ", ".join(missing))
    marks = float(row["marks"])
    maximum = float(row.get("maxMarks", 100))
    if maximum <= 0 or marks < 0 or marks > maximum:
        raise ValueError("Marks must be between zero and maxMarks.")
    percent = marks * 100 / maximum
    return {
        "id": str(row.get("id") or uuid.uuid4().hex),
        "studentId": str(row["studentId"]).strip(),
        "studentName": str(row.get("studentName") or "Unknown").strip(),
        "academicYear": str(row["academicYear"]).strip(),
        "className": str(row.get("className") or "Unspecified").strip(),
        "subject": str(row["subject"]).strip(),
        "marks": marks,
        "maxMarks": maximum,
        "percentage": round(percent, 2),
        "grade": grade_of(percent),
        "updatedAt": utc_now(),
    }


def seed_state() -> dict[str, Any]:
    marks_data = read_asset("academic_marks.json", {"records": []})
    question_data = read_asset("questions.json", {"questions": []})
    topic_data = read_asset("topics.json", {"topics": []})
    participant_data = read_asset("participants.json", {"participants": []})
    records = marks_data if isinstance(marks_data, list) else marks_data.get("records", [])
    questions = question_data if isinstance(question_data, list) else question_data.get("questions", [])
    return {
        "marks": [clean_mark(x) for x in records if isinstance(x, dict)],
        "questions": questions,
        "submissions": [],
        "pdfs": [],
        "readerState": {},
        "serviceState": {},
        "topics": topic_data.get("topics", []) if isinstance(topic_data, dict) else [],
        "participants": participant_data.get("participants", []) if isinstance(participant_data, dict) else [],
        "activity": [{"id": uuid.uuid4().hex, "type": "system", "message": "Academic workspace initialized", "at": utc_now()}],
    }


def save_state() -> None:
    with LOCK:
        temp = STATE_FILE.with_suffix(".tmp")
        temp.write_text(json.dumps(STATE, ensure_ascii=False, indent=2), encoding="utf-8")
        temp.replace(STATE_FILE)


def load_state() -> dict[str, Any]:
    if STATE_FILE.exists():
        try:
            value = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            defaults = seed_state()
            for key, default in defaults.items():
                value.setdefault(key, default)
            return value
        except Exception:
            pass
    value = seed_state()
    temp = STATE_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(STATE_FILE)
    return value


STATE = load_state()


def add_activity(kind: str, message: str) -> None:
    STATE.setdefault("activity", []).insert(0, {"id": uuid.uuid4().hex, "type": kind, "message": message, "at": utc_now()})
    STATE["activity"] = STATE["activity"][:100]


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9\s=+.-]", " ", (text or "").lower())).strip()


def concept_match(answer: str, concept: str) -> tuple[bool, float]:
    a, c = normalize(answer), normalize(concept)
    if not c:
        return False, 0.0
    if c in a:
        return True, 100.0
    score = SequenceMatcher(None, c, a).ratio() * 100
    if len(c.split()) > 1:
        answer_tokens, concept_tokens = set(a.split()), set(c.split())
        token_score = len(answer_tokens & concept_tokens) / max(1, len(concept_tokens)) * 100
        score = max(score, token_score)
    return score >= 82, round(score, 1)


def score_answer(answer: str, question: dict[str, Any]) -> dict[str, Any]:
    maximum = float(question.get("maxMarks", 0) or 0)
    keywords = [str(k).strip() for k in question.get("keywords", []) if str(k).strip()]
    clean = normalize(answer)
    if not clean or maximum <= 0:
        return {"suggestedMarks": 0.0, "maxMarks": maximum, "matchedKeywords": [], "missingKeywords": keywords, "keywordCoverage": 0.0, "modelSimilarity": 0.0, "requiresTeacherReview": True}
    matched, missing, evidence = [], [], []
    for keyword in keywords:
        ok, confidence = concept_match(clean, keyword)
        evidence.append({"keyword": keyword, "matched": ok, "similarity": confidence})
        (matched if ok else missing).append(keyword)
    coverage = len(matched) / max(1, len(keywords)) if keywords else 0.0
    model = normalize(str(question.get("modelAnswer", "")))
    similarity = SequenceMatcher(None, model, clean).ratio() * 100 if model else 0.0
    rubric = question.get("rubric", [])
    rubric_total = sum(float(item.get("marks", 0) or 0) for item in rubric if isinstance(item, dict))
    criteria = []
    if rubric_total > 0:
        earned = 0.0
        for item in rubric:
            terms = item.get("keywords") or [item.get("name", "")]
            terms = [str(x) for x in terms if str(x).strip()]
            hits = [term for term in terms if concept_match(clean, term)[0]]
            part = float(item.get("marks", 0) or 0) * len(hits) / max(1, len(terms))
            earned += part
            criteria.append({"name": item.get("name", "Criterion"), "maxMarks": float(item.get("marks", 0) or 0), "suggestedMarks": round(part, 2), "matchedConcepts": hits})
        suggested = maximum * earned / rubric_total
        method = "rubric"
    else:
        lexical = coverage * 100 if keywords else similarity
        suggested = maximum * (0.72 * lexical + 0.28 * similarity) / 100
        method = "keyword_similarity"
    return {
        "suggestedMarks": round(max(0.0, min(maximum, suggested)), 2),
        "maxMarks": maximum,
        "method": method,
        "keywordCoverage": round(coverage, 3),
        "modelSimilarity": round(similarity, 1),
        "matchedKeywords": matched,
        "missingKeywords": missing,
        "keywordEvidence": evidence,
        "criteria": criteria,
        "requiresTeacherReview": True,
        "rationale": "Suggested marks are advisory only. A teacher must verify the OCR text and approve the final score.",
    }


def find_question(question_id: str) -> dict[str, Any] | None:
    return next((q for q in STATE["questions"] if str(q.get("id")) == str(question_id)), None)


@app.get("/health")
def health():
    return jsonify({"status": "ok", "service": "Tuition BluePink Academic Suite API", "ocrAvailable": OCR_AVAILABLE, "stateFile": str(STATE_FILE), "modules": ["pdf_reader", "marks_gradebook", "scriptgrade_ocr"]})


@app.get("/bootstrap")
def bootstrap():
    with LOCK:
        return jsonify({**STATE, "ocrAvailable": OCR_AVAILABLE, "serverTime": utc_now()})


@app.get("/analytics")
def analytics():
    rows = STATE["marks"]
    grades = {g: sum(1 for row in rows if row.get("grade") == g) for g in ["A+", "A", "B", "C", "D", "F"]}
    return jsonify({"count": len(rows), "students": len({x.get("studentId") for x in rows}), "average": round(sum(float(x.get("percentage", 0)) for x in rows) / max(1, len(rows)), 2), "passRate": round(sum(1 for x in rows if float(x.get("percentage", 0)) >= 50) * 100 / max(1, len(rows)), 2), "grades": grades})


@app.get("/marks")
def get_marks():
    return jsonify({"records": STATE["marks"], "count": len(STATE["marks"])})


@app.post("/marks")
def add_mark():
    try:
        row = clean_mark(request.get_json(force=True) or {})
        STATE["marks"].append(row)
        add_activity("marks", f"Added marks for {row['studentName']} — {row['subject']}")
        save_state()
        return jsonify({"ok": True, "record": row}), 201
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@app.put("/marks/<record_id>")
def update_mark(record_id: str):
    try:
        index = next((i for i, x in enumerate(STATE["marks"]) if str(x.get("id")) == record_id), -1)
        if index < 0: return jsonify({"error": "Mark record not found."}), 404
        merged = {**STATE["marks"][index], **(request.get_json(force=True) or {})}
        STATE["marks"][index] = clean_mark(merged)
        add_activity("marks", f"Updated marks for {STATE['marks'][index]['studentName']}")
        save_state()
        return jsonify({"ok": True, "record": STATE["marks"][index]})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@app.delete("/marks/<record_id>")
def delete_mark(record_id: str):
    before = len(STATE["marks"])
    STATE["marks"] = [x for x in STATE["marks"] if str(x.get("id")) != record_id]
    if len(STATE["marks"]) == before: return jsonify({"error": "Mark record not found."}), 404
    add_activity("marks", "Deleted a marks record")
    save_state()
    return jsonify({"ok": True})


@app.post("/marks/import")
def import_marks():
    if "file" not in request.files: return jsonify({"error": "Upload JSON in multipart field 'file'."}), 400
    try:
        payload = json.loads(request.files["file"].read().decode("utf-8-sig"))
        records = payload if isinstance(payload, list) else payload.get("records", payload.get("marks", payload.get("results", [])))
        if not isinstance(records, list) or not records: raise ValueError("JSON must contain a non-empty records/marks/results array.")
        parsed = [clean_mark(row) for row in records]
        STATE["marks"] = parsed
        add_activity("marks", f"Imported {len(parsed)} marks records")
        save_state()
        return jsonify({"ok": True, "count": len(parsed), "records": parsed})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@app.get("/questions")
def get_questions():
    return jsonify({"questions": STATE["questions"]})


@app.post("/questions")
def add_question():
    try:
        data = request.get_json(force=True) or {}
        maximum = float(data.get("maxMarks", 0))
        if not data.get("title") or not data.get("prompt") or not data.get("modelAnswer") or maximum <= 0:
            raise ValueError("title, prompt, modelAnswer and positive maxMarks are required.")
        q = {"id": uuid.uuid4().hex, "title": str(data["title"]).strip(), "prompt": str(data["prompt"]).strip(), "modelAnswer": str(data["modelAnswer"]).strip(), "maxMarks": maximum, "keywords": [str(x).strip() for x in data.get("keywords", []) if str(x).strip()], "rubric": data.get("rubric", [])}
        STATE["questions"].append(q)
        add_activity("question", f"Added rubric: {q['title']}")
        save_state()
        return jsonify({"ok": True, "question": q}), 201
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@app.put("/questions/<question_id>")
def update_question(question_id: str):
    q = find_question(question_id)
    if not q: return jsonify({"error": "Question not found."}), 404
    q.update(request.get_json(force=True) or {})
    save_state()
    return jsonify({"ok": True, "question": q})


@app.post("/ocr")
def ocr_image():
    if "file" not in request.files: return jsonify({"error": "Upload an image in multipart field 'file'."}), 400
    student = request.form.get("student", "").strip()
    question_id = request.form.get("question_id", "").strip()
    question = find_question(question_id)
    if not student or not question: return jsonify({"error": "Student name and a valid question_id are required."}), 400
    upload = request.files["file"]
    filename = secure_filename(upload.filename or "answer-image")
    raw = upload.read()
    if not raw: return jsonify({"error": "Image is empty."}), 400
    stored_name = f"{uuid.uuid4().hex}_{filename}"
    target = UPLOAD_DIR / stored_name
    target.write_bytes(raw)
    extracted, confidence, warnings = "", 0.0, []
    if OCR_AVAILABLE and Image is not None:
        try:
            import io
            image = Image.open(io.BytesIO(raw)).convert("RGB")
            image = ImageOps.grayscale(image)
            image = ImageEnhance.Contrast(image).enhance(1.7)
            image = ImageEnhance.Sharpness(image).enhance(1.4)
            image = image.filter(ImageFilter.MedianFilter(size=3))
            config = "--oem 1 --psm 6"
            extracted = pytesseract.image_to_string(image, lang=os.getenv("OCR_LANGUAGE", "eng"), config=config).strip()
            data = pytesseract.image_to_data(image, lang=os.getenv("OCR_LANGUAGE", "eng"), config=config, output_type=Output.DICT)
            scores = []
            for raw_score in data.get("conf", []):
                try:
                    val = float(raw_score)
                    if val >= 0: scores.append(val)
                except (TypeError, ValueError): pass
            confidence = round(sum(scores) / len(scores), 2) if scores else 0.0
            if confidence < 35: warnings.append("OCR confidence is low. Please correct the extracted answer.")
            if len(extracted) < 8: warnings.append("Very little text was recognized. Try a brighter, sharper image.")
        except Exception as exc:
            warnings.append(f"OCR could not process this image: {exc}")
    else:
        warnings.append("Tesseract OCR is not installed or not on PATH. You can type or paste the answer manually.")
    score = score_answer(extracted, question)
    return jsonify({"ok": True, "imageName": filename, "storedName": stored_name, "extractedText": extracted, "ocrAvailable": OCR_AVAILABLE, "ocrConfidence": confidence, "warnings": warnings, **score})


@app.get("/submissions")
def get_submissions():
    return jsonify({"submissions": STATE["submissions"]})


@app.post("/submissions")
def create_submission():
    try:
        data = request.get_json(force=True) or {}
        question = find_question(str(data.get("questionId", "")))
        if not question: raise ValueError("Unknown questionId.")
        student = str(data.get("student", "")).strip()
        answer = str(data.get("answer", "")).strip()
        if not student or not answer: raise ValueError("Student and answer are required.")
        scoring = score_answer(answer, question)
        submission = {"id": uuid.uuid4().hex, "student": student, "questionId": question["id"], "questionTitle": question["title"], "answer": answer, "imageName": str(data.get("imageName") or "Manual entry"), "createdAt": utc_now(), "suggested": scoring["suggestedMarks"], "awarded": scoring["suggestedMarks"], "reviewed": False, "feedback": "Suggested score; teacher approval required.", "scoreDetails": scoring}
        STATE["submissions"].insert(0, submission)
        add_activity("submission", f"Saved answer for {student}")
        save_state()
        return jsonify({"ok": True, "submission": submission}), 201
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@app.post("/submissions/<submission_id>/review")
def review_submission(submission_id: str):
    data = request.get_json(force=True) or {}
    item = next((x for x in STATE["submissions"] if x["id"] == submission_id), None)
    if not item: return jsonify({"error": "Submission not found."}), 404
    question = find_question(item["questionId"])
    maximum = float(question.get("maxMarks", 100)) if question else 100.0
    try: awarded = float(data.get("awarded", -1))
    except Exception: awarded = -1
    if awarded < 0 or awarded > maximum: return jsonify({"error": f"Final marks must be between 0 and {maximum}."}), 400
    item["awarded"] = awarded
    item["feedback"] = str(data.get("feedback", ""))
    item["reviewed"] = True
    item["reviewedAt"] = utc_now()
    add_activity("review", f"Teacher reviewed {item['student']}'s answer")
    save_state()
    return jsonify({"ok": True, "submission": item})


@app.get("/pdfs")
def get_pdfs():
    return jsonify({"pdfs": STATE["pdfs"]})


@app.post("/pdfs/upload")
def upload_pdf():
    if "file" not in request.files: return jsonify({"error": "Upload a PDF in multipart field 'file'."}), 400
    file = request.files["file"]
    filename = secure_filename(file.filename or "document.pdf")
    if not filename.lower().endswith(".pdf"): return jsonify({"error": "Only PDF files are accepted."}), 400
    stored = f"{uuid.uuid4().hex}_{filename}"
    target = UPLOAD_DIR / stored
    file.save(target)
    item = {"id": uuid.uuid4().hex, "filename": filename, "storedName": stored, "size": target.stat().st_size, "uploadedAt": utc_now(), "url": f"/files/{stored}"}
    STATE["pdfs"].insert(0, item)
    add_activity("pdf", f"Uploaded PDF: {filename}")
    save_state()
    return jsonify({"ok": True, "pdf": item}), 201


@app.get("/files/<path:filename>")
def serve_file(filename: str):
    return send_from_directory(UPLOAD_DIR, filename, as_attachment=False, conditional=True)


@app.get("/reader/state")
def get_reader_state():
    return jsonify({"readerState": STATE.get("readerState", {})})


@app.post("/reader/state")
def save_reader_state():
    data = request.get_json(force=True) or {}
    key = str(data.get("documentKey", "")).strip()
    if not key: return jsonify({"error": "documentKey is required."}), 400
    STATE.setdefault("readerState", {})[key] = {"page": max(1, int(data.get("page", 1))), "bookmarks": data.get("bookmarks", []), "updatedAt": utc_now()}
    save_state()
    return jsonify({"ok": True, "state": STATE["readerState"][key]})


@app.get("/activity")
def get_activity():
    return jsonify({"activity": STATE.get("activity", [])})


# ---------------------------------------------------------------------------
# ScriptGrade Pro compatibility API (/api/*)
# This adapts the original ScriptGrade Flutter client to the same persistent
# JSON state and scoring engine used by the rest of this unified backend.
# ---------------------------------------------------------------------------
def sg_question_id(question: dict[str, Any]) -> int:
    try:
        return int(question.get("id"))
    except (TypeError, ValueError):
        try:
            return STATE["questions"].index(question) + 1
        except ValueError:
            return 0


def sg_find_question(question_id: Any) -> dict[str, Any] | None:
    wanted = str(question_id)
    for index, question in enumerate(STATE["questions"]):
        if str(question.get("id")) == wanted or str(index + 1) == wanted:
            return question
    return None


def sg_question_payload(question: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": sg_question_id(question),
        "code": str(question.get("code") or f"Q{sg_question_id(question):03d}"),
        "title": str(question.get("title") or "Untitled question"),
        "subject": str(question.get("subject") or "General"),
        "prompt": str(question.get("prompt") or ""),
        "model_answer": str(question.get("model_answer", question.get("modelAnswer", ""))),
        "max_marks": float(question.get("max_marks", question.get("maxMarks", 0)) or 0),
        "keywords": question.get("keywords", []),
        "rubric": question.get("rubric", []),
        "is_active": question.get("is_active", question.get("isActive", True)) is not False,
        "created_at": question.get("created_at", question.get("createdAt", utc_now())),
    }


def sg_submission_payload(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": int(item.get("sgId", 0)),
        "public_id": str(item.get("publicId") or item.get("id") or ""),
        "student_name": str(item.get("studentName", item.get("student", ""))),
        "student_id": str(item.get("studentId", "")),
        "exam_name": str(item.get("examName", "")),
        "question_id": sg_question_id(sg_find_question(item.get("questionId", "")) or {}),
        "original_filename": str(item.get("originalFilename", item.get("imageName", ""))),
        "extracted_text": str(item.get("extractedText", "")),
        "corrected_text": str(item.get("correctedText", item.get("answer", ""))),
        "suggested_marks": float(item.get("suggestedMarks", item.get("suggested", 0)) or 0),
        "final_marks": float(item.get("finalMarks", item.get("awarded", 0)) or 0),
        "max_marks_snapshot": float(item.get("maxMarks", 0) or 0),
        "grading_details": item.get("gradingDetails", item.get("scoreDetails", {})),
        "teacher_feedback": str(item.get("teacherFeedback", item.get("feedback", ""))),
        "status": str(item.get("status") or ("reviewed" if item.get("reviewed") else "pending")),
        "ocr_confidence": float(item.get("ocrConfidence", 0) or 0),
        "created_at": item.get("createdAt", utc_now()),
        "reviewed_at": item.get("reviewedAt"),
    }


def sg_extract_image(raw: bytes) -> tuple[str, float, list[str]]:
    warnings: list[str] = []
    extracted, confidence = "", 0.0
    if OCR_AVAILABLE and Image is not None:
        try:
            import io
            image = Image.open(io.BytesIO(raw)).convert("RGB")
            image = ImageOps.grayscale(image)
            image = ImageEnhance.Contrast(image).enhance(1.7)
            image = ImageEnhance.Sharpness(image).enhance(1.4)
            image = image.filter(ImageFilter.MedianFilter(size=3))
            language = os.getenv("OCR_LANGUAGE", "eng")
            config = "--oem 1 --psm 6"
            extracted = pytesseract.image_to_string(image, lang=language, config=config).strip()
            data = pytesseract.image_to_data(image, lang=language, config=config, output_type=Output.DICT)
            scores = []
            for value in data.get("conf", []):
                try:
                    number = float(value)
                    if number >= 0: scores.append(number)
                except (TypeError, ValueError):
                    pass
            confidence = round(sum(scores) / len(scores), 2) if scores else 0.0
            if confidence < 35: warnings.append("OCR confidence is low. Please correct the extracted text.")
            if len(extracted) < 8: warnings.append("Very little text was recognized. Try a brighter, sharper image.")
        except Exception as exc:
            warnings.append(f"OCR could not process this image: {exc}")
    else:
        warnings.append("Tesseract OCR is unavailable. You can type or paste the answer manually.")
    return extracted, confidence, warnings


@app.get("/api/health")
def sg_health():
    return jsonify({"status": "ok", "service": "Tuition BluePink Unified API", "ocr_available": OCR_AVAILABLE})


@app.get("/api/dashboard")
def sg_dashboard():
    items = STATE["submissions"]
    reviewed = [x for x in items if x.get("reviewed") or x.get("status") == "reviewed"]
    awarded = sum(float(x.get("finalMarks", x.get("awarded", 0)) or 0) for x in reviewed)
    available = sum(float(x.get("maxMarks", 0) or 0) for x in reviewed)
    return jsonify({
        "question_count": len(STATE["questions"]),
        "submission_count": len(items),
        "pending_count": len(items) - len(reviewed),
        "reviewed_count": len(reviewed),
        "average_percentage": round(awarded * 100 / available, 2) if available else 0,
        "marks_awarded": round(awarded, 2),
        "marks_available": round(available, 2),
    })


@app.get("/api/questions")
def sg_get_questions():
    active_only = request.args.get("active_only", "true").lower() != "false"
    questions = [q for q in STATE["questions"] if not active_only or q.get("is_active", True) is not False]
    return jsonify([sg_question_payload(q) for q in questions])


@app.post("/api/questions")
def sg_create_question():
    data = request.get_json(force=True) or {}
    try:
        maximum = float(data.get("max_marks", 0))
        if not data.get("title") or not data.get("prompt") or maximum <= 0:
            raise ValueError("title, prompt and positive max_marks are required")
        next_id = max([sg_question_id(q) for q in STATE["questions"]] + [0]) + 1
        q = {
            "id": str(next_id), "code": str(data.get("code") or f"Q{next_id:03d}"),
            "title": str(data["title"]).strip(), "subject": str(data.get("subject") or "General"),
            "prompt": str(data["prompt"]).strip(), "modelAnswer": str(data.get("model_answer") or ""),
            "maxMarks": maximum, "keywords": data.get("keywords", []), "rubric": data.get("rubric", []),
            "is_active": data.get("is_active", True), "created_at": utc_now(),
        }
        STATE["questions"].append(q)
        add_activity("question", f"Added ScriptGrade question: {q['title']}")
        save_state()
        return jsonify(sg_question_payload(q)), 201
    except Exception as exc:
        return jsonify({"detail": str(exc)}), 400


@app.patch("/api/questions/<int:question_id>")
def sg_update_question(question_id: int):
    q = sg_find_question(question_id)
    if not q: return jsonify({"detail": "Question not found"}), 404
    data = request.get_json(force=True) or {}
    mapping = {"model_answer": "modelAnswer", "max_marks": "maxMarks", "is_active": "is_active"}
    for key, value in data.items(): q[mapping.get(key, key)] = value
    save_state()
    return jsonify(sg_question_payload(q))


@app.delete("/api/questions/<int:question_id>")
def sg_delete_question(question_id: int):
    q = sg_find_question(question_id)
    if not q: return jsonify({"detail": "Question not found"}), 404
    STATE["questions"].remove(q)
    save_state()
    return jsonify({"ok": True})


@app.post("/api/ocr")
def sg_ocr_preview():
    upload = request.files.get("image")
    if upload is None: return jsonify({"detail": "Upload image in multipart field 'image'."}), 400
    raw = upload.read()
    if not raw: return jsonify({"detail": "Image is empty."}), 400
    text_value, confidence, warnings = sg_extract_image(raw)
    return jsonify({"text": text_value, "confidence": confidence, "warnings": warnings, "filename": secure_filename(upload.filename or "answer-image")})


@app.post("/api/submissions")
def sg_create_submission():
    data = request.form if request.form else (request.get_json(silent=True) or {})
    try:
        question = sg_find_question(data.get("question_id"))
        if not question: raise ValueError("Unknown question_id")
        student_name = str(data.get("student_name", "")).strip()
        student_id = str(data.get("student_id", "")).strip()
        exam_name = str(data.get("exam_name", "")).strip()
        upload = request.files.get("image")
        filename = secure_filename(upload.filename) if upload else "Manual entry"
        extracted = ""
        confidence = 0.0
        if upload:
            raw = upload.read()
            stored = f"{uuid.uuid4().hex}_{filename}"
            (UPLOAD_DIR / stored).write_bytes(raw)
            extracted, confidence, _warnings = sg_extract_image(raw)
        corrected = str(data.get("corrected_text", "")).strip() or extracted
        if not student_name or not student_id or not corrected: raise ValueError("student_name, student_id and corrected_text are required")
        scoring = score_answer(corrected, question)
        sg_id = max([int(x.get("sgId", 0) or 0) for x in STATE["submissions"]] + [0]) + 1
        public_id = uuid.uuid4().hex
        item = {
            "id": public_id, "publicId": public_id, "sgId": sg_id,
            "student": student_name, "studentName": student_name, "studentId": student_id,
            "examName": exam_name, "questionId": question.get("id"), "questionTitle": question.get("title", ""),
            "answer": corrected, "correctedText": corrected, "extractedText": extracted,
            "imageName": filename, "originalFilename": filename, "createdAt": utc_now(),
            "suggested": scoring["suggestedMarks"], "suggestedMarks": scoring["suggestedMarks"],
            "awarded": scoring["suggestedMarks"], "finalMarks": scoring["suggestedMarks"],
            "maxMarks": float(question.get("maxMarks", question.get("max_marks", 0)) or 0),
            "reviewed": False, "status": "pending", "feedback": "Pending teacher review.",
            "teacherFeedback": "Pending teacher review.", "ocrConfidence": confidence,
            "scoreDetails": scoring, "gradingDetails": scoring,
        }
        STATE["submissions"].insert(0, item)
        add_activity("submission", f"ScriptGrade submission from {student_name}")
        save_state()
        return jsonify(sg_submission_payload(item)), 201
    except Exception as exc:
        return jsonify({"detail": str(exc)}), 400


@app.get("/api/submissions")
def sg_get_submissions():
    rows = STATE["submissions"]
    status_filter = request.args.get("status_filter")
    student = request.args.get("student", "").lower()
    question_id = request.args.get("question_id")
    result = []
    for item in rows:
        payload = sg_submission_payload(item)
        if status_filter and payload["status"] != status_filter: continue
        if student and student not in payload["student_name"].lower(): continue
        if question_id and str(payload["question_id"]) != str(question_id): continue
        result.append(payload)
    return jsonify(result)


@app.get("/api/submissions/<public_id>")
def sg_get_submission(public_id: str):
    item = next((x for x in STATE["submissions"] if str(x.get("publicId", x.get("id"))) == public_id), None)
    if not item: return jsonify({"detail": "Submission not found"}), 404
    return jsonify(sg_submission_payload(item))


@app.post("/api/submissions/<public_id>/regrade")
def sg_regrade_submission(public_id: str):
    item = next((x for x in STATE["submissions"] if str(x.get("publicId", x.get("id"))) == public_id), None)
    if not item: return jsonify({"detail": "Submission not found"}), 404
    data = request.get_json(force=True) or {}
    question = sg_find_question(item.get("questionId"))
    if not question: return jsonify({"detail": "Question not found"}), 404
    answer = str(data.get("answer_text", "")).strip()
    scoring = score_answer(answer, question)
    item.update({"answer": answer, "correctedText": answer, "suggested": scoring["suggestedMarks"], "suggestedMarks": scoring["suggestedMarks"], "awarded": scoring["suggestedMarks"], "finalMarks": scoring["suggestedMarks"], "scoreDetails": scoring, "gradingDetails": scoring, "reviewed": False, "status": "pending"})
    save_state()
    return jsonify(sg_submission_payload(item))


@app.patch("/api/submissions/<public_id>/review")
def sg_review_submission(public_id: str):
    item = next((x for x in STATE["submissions"] if str(x.get("publicId", x.get("id"))) == public_id), None)
    if not item: return jsonify({"detail": "Submission not found"}), 404
    data = request.get_json(force=True) or {}
    question = sg_find_question(item.get("questionId"))
    maximum = float(question.get("maxMarks", question.get("max_marks", 100)) or 100) if question else 100
    corrected = str(data.get("corrected_text", item.get("correctedText", "")))
    final_marks = float(data.get("final_marks", item.get("finalMarks", 0)))
    if final_marks < 0 or final_marks > maximum: return jsonify({"detail": f"final_marks must be between 0 and {maximum}"}), 400
    item.update({"correctedText": corrected, "answer": corrected, "finalMarks": final_marks, "awarded": final_marks, "teacherFeedback": str(data.get("teacher_feedback", "")), "feedback": str(data.get("teacher_feedback", "")), "reviewed": True, "status": "reviewed", "reviewedAt": utc_now()})
    add_activity("review", f"Teacher approved ScriptGrade submission for {item.get('studentName', 'student')}")
    save_state()
    return jsonify(sg_submission_payload(item))


@app.get("/api/analytics/questions")
def sg_question_analytics():
    result = []
    for q in STATE["questions"]:
        related = [x for x in STATE["submissions"] if str(x.get("questionId")) == str(q.get("id"))]
        result.append({"question_id": sg_question_id(q), "title": q.get("title", ""), "submission_count": len(related), "average_marks": round(sum(float(x.get("finalMarks", 0) or 0) for x in related) / max(1, len(related)), 2)})
    return jsonify(result)


@app.get("/api/analytics/students")
def sg_student_analytics():
    groups: dict[str, list[dict[str, Any]]] = {}
    for item in STATE["submissions"]: groups.setdefault(str(item.get("studentId", "")), []).append(item)
    return jsonify([{"student_id": key, "student_name": rows[0].get("studentName", ""), "submission_count": len(rows), "average_marks": round(sum(float(x.get("finalMarks", 0) or 0) for x in rows) / max(1, len(rows)), 2)} for key, rows in groups.items()])


# Generic persisted state endpoint used by the Super-App's other service modules.
@app.get("/api/services/<service_key>/state")
def get_microservice_state(service_key: str):
    return jsonify({"service": service_key, "state": STATE.setdefault("serviceState", {}).get(service_key, {})})


@app.put("/api/services/<service_key>/state")
def put_microservice_state(service_key: str):
    payload = request.get_json(force=True) or {}
    STATE.setdefault("serviceState", {})[service_key] = payload.get("state", payload)
    add_activity("service_state", f"Updated {service_key} module state")
    save_state()
    return jsonify({"ok": True, "service": service_key, "state": STATE["serviceState"][service_key]})


@app.get("/api/services")
def list_microservice_state():
    return jsonify({"services_with_saved_state": sorted(STATE.setdefault("serviceState", {}).keys()), "count": len(STATE["serviceState"])})


@app.errorhandler(413)
def too_large(_error):
    return jsonify({"error": "Upload exceeds the 35 MB limit."}), 413


@app.errorhandler(Exception)
def handle_unexpected(error):
    # Keep API errors JSON-shaped; Flask's HTTPException status is preserved.
    from werkzeug.exceptions import HTTPException
    if isinstance(error, HTTPException):
        return jsonify({"error": error.description}), error.code
    app.logger.exception("Unhandled API error")
    return jsonify({"error": "Unexpected backend error. Check the terminal log."}), 500


if __name__ == "__main__":
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8000"))
    print("=" * 64)
    print("Tuition BluePink Academic Suite API")
    print(f"URL: http://{host}:{port}")
    print(f"Persistent state: {STATE_FILE}")
    print(f"OCR available: {OCR_AVAILABLE}")
    print("Modules: Super-App + PDF Reader + Marks Gradebook + ScriptGrade OCR")
    print("=" * 64)
    app.run(host=host, port=port, debug=False, threaded=True)

"""
Field Extractor Module
Extracts structured fields from OCR text for supported document types
"""

import re
from typing import Dict, List, Optional


class FieldExtractor:
    """Extract structured fields from OCR text"""

    @staticmethod
    def _norm(text: str) -> str:
        if not text:
            return ""
        # Normalize common OCR quirks
        t = text
        # unify dashes
        t = t.replace("—", "-").replace("–", "-")
        # collapse whitespace
        t = re.sub(r"\s+", " ", t)
        return t.strip()

    @staticmethod
    def _get_first(pattern: str, text: str, flags: int = re.IGNORECASE) -> Optional[str]:
        m = re.search(pattern, text, flags)
        if not m:
            return None
        # prefer last group if there are multiple
        if m.lastindex:
            return m.group(m.lastindex).strip()
        return m.group(0).strip()

    @staticmethod
    def _split_names(blob: str) -> List[str]:
        # Split on commas or semicolons, trim
        parts = [p.strip(" ,;\n\t") for p in re.split(r"[,;]\s*", blob) if p.strip()]
        # Filter out short noise
        return [p for p in parts if len(p) >= 2]

    @staticmethod
    def extract_syllabus_review(text: str) -> Dict:
        """Extract fields for Syllabus Review Form."""
        raw = text or ""
        norm = FieldExtractor._norm(raw)
        lower = norm.lower()

        # Document code (tolerant to missing 'F' and spacing)
        doc_code = None
        m = re.search(r"(f?m\s*-?\s*ustp\s*-?\s*acad\s*-?\s*12)", lower, re.IGNORECASE)
        if m:
            s = re.sub(r"\s*", "", m.group(1), flags=re.IGNORECASE)
            # Canonicalize
            doc_code = s.upper().replace("FMUSTPACAD12", "FM-USTP-ACAD-12").replace("MUSTPACAD12", "M-USTP-ACAD-12")
            if doc_code == s.upper():
                # add dashes between tokens if missing
                doc_code = re.sub(r"([A-Z]+)(USTP)(ACAD)(12)", r"FM-USTP-ACAD-12", doc_code)

        # Course code: prefer labeled "Course Code: <code>"
        course_code = FieldExtractor._get_first(
            r"course\s*code\s*[:\-]\s*([A-Z]{2,4}\s*-?\s*\d{2,5}|\d{4,6})",
            norm,
            re.IGNORECASE,
        )
        if not course_code:
            # fallback: look for patterns like IT121, CS101, 17121 near title
            m2 = re.search(r"\b([A-Z]{2,4}\s*-?\s*\d{2,5}|\b\d{4,6}\b)", norm)
            if m2:
                course_code = m2.group(1)
        if course_code:
            course_code = course_code.replace(" ", "")

        # Semester
        semester = FieldExtractor._get_first(r"\b(\d(?:st|nd|rd|th)?\s*semester)\b", lower)
        if not semester:
            semester = FieldExtractor._get_first(r"\b(1st|2nd|3rd|4th)\b\s*semester", lower)

        # Academic Year
        ay = FieldExtractor._get_first(r"\bAY\s*(\d{4})\s*[-/]\s*(\d{4})\b", norm, re.IGNORECASE)
        if ay and isinstance(ay, str) and " " in ay:
            # If two groups returned concatenated, normalize as YYYY-YYYY
            g = re.findall(r"\d{4}", ay)
            if len(g) >= 2:
                ay = f"{g[0]}-{g[1]}"
        else:
            # Another pass to construct
            g = re.findall(r"\b(\d{4})\b", norm)
            if len(g) >= 2 and "ay" in lower:
                ay = f"{g[0]}-{g[1]}"

        # Descriptive Title (if present)
        descriptive_title = FieldExtractor._get_first(r"descriptive\s*title\s*[:\-]\s*(.+?)(?=\s{2,}| faculty| directions| part |$)", lower)
        if descriptive_title:
            descriptive_title = descriptive_title.title()

        # Faculty list
        faculty_blob = FieldExtractor._get_first(r"faculty\s*[:\-]\s*(.+?)(?=\s{2,}| directions| part |$)", lower)
        faculty: List[str] = FieldExtractor._split_names(faculty_blob) if faculty_blob else []
        # Title case names
        faculty = [" ".join([w.capitalize() for w in re.split(r"\s+", n)]) for n in faculty]

        # Reviewed by and date of review (best-effort)
        reviewed_by = FieldExtractor._get_first(r"reviewed\s*by\s*[:\-]?\s*([A-Za-z .,'-]{3,})", norm)
        review_date = FieldExtractor._get_first(r"date\s*(?:of\s*review)?\s*[:\-]?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\w+\s+\d{1,2},\s*\d{4})", norm)

        # Indicators / YES-NO counts
        has_indicators = "indicators" in lower and "remarks" in lower
        yes_count = len(re.findall(r"\byes\b", lower))
        no_count = len(re.findall(r"\bno\b", lower))

        return {
            "document_code": doc_code,
            "course_code": course_code,
            "semester": semester.title() if semester else None,
            "academic_year": ay,
            "descriptive_title": descriptive_title,
            "faculty": faculty,
            "reviewed_by": reviewed_by,
            "review_date": review_date,
            "indicators_table": has_indicators,
            "yes_count": yes_count,
            "no_count": no_count,
            "_debug_present_fields": [
                k for k, v in {
                    "document_code": doc_code,
                    "course_code": course_code,
                    "semester": semester,
                    "academic_year": ay,
                    "descriptive_title": descriptive_title,
                    "faculty": faculty,
                    "reviewed_by": reviewed_by,
                    "review_date": review_date,
                }.items() if v
            ],
        }

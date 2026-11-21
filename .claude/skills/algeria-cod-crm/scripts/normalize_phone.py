#!/usr/bin/env python3
"""Normalize Algerian phone numbers to E.164 (+213XXXXXXXXX).

Reference behavior for the CRM. Port the logic to the project's language.

Usage:
    python normalize_phone.py "0555 12 34 56" "+213 555-123-456"
"""
import re
import sys
import unicodedata

MOBILE_PREFIXES = ("5", "6", "7")  # local 05, 06, 07 after dropping the 0


def normalize(raw: str) -> dict:
    """Return {'e164', 'kind', 'valid', 'reason'} for a raw phone string."""
    # Convert Arabic-Indic / other Unicode digits to ASCII first.
    raw = "".join(
        str(unicodedata.digit(c)) if c.isdigit() else c for c in (raw or "")
    )
    digits = re.sub(r"[^0-9]", "", raw)
    if not digits:
        return {"e164": None, "kind": None, "valid": False, "reason": "empty"}

    if digits.startswith("00213"):
        digits = digits[5:]
    elif digits.startswith("213"):
        digits = digits[3:]
    elif digits.startswith("0"):
        digits = digits[1:]

    if len(digits) != 9:
        return {"e164": None, "kind": None, "valid": False, "reason": "bad_length"}

    kind = "mobile" if digits[0] in MOBILE_PREFIXES else "landline_or_other"
    return {
        "e164": "+213" + digits,
        "kind": kind,
        "valid": kind == "mobile",
        "reason": None if kind == "mobile" else "not_mobile",
    }


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        print(arg, "->", normalize(arg))

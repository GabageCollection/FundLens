"""Name normalization for product matching.

Normalization is lossy on purpose and used only for comparison; callers
must keep and display the original name. Handles whitespace, full-width
punctuation/letters, share-class suffixes and common platform decorations.
"""

import re

# Platform tags appended or prepended by sales apps; carry no product identity.
_DECORATIONS = ("金选", "稳健理财", "优选", "严选", "热销")

# Trailing share-class markers: "A", "C类", "(A)", "（C类）", "A1", etc.
# The lookbehind keeps ASCII acronyms (ETF/LOF) from being eaten letter by letter.
_SHARE_CLASS_RE = re.compile(r"(?<![A-Za-z])(?:[（(][A-Za-z]\d?类?[)）]|[A-Za-z]\d?类?)$")

_FULL_WIDTH_OFFSET = 0xFEE0


def _full_width_to_half(text: str) -> str:
    out = []
    for ch in text:
        code = ord(ch)
        if code == 0x3000:  # ideographic space
            out.append(" ")
        elif 0xFF01 <= code <= 0xFF5E:
            out.append(chr(code - _FULL_WIDTH_OFFSET))
        else:
            out.append(ch)
    return "".join(out)


def normalize_name(name: str) -> str:
    """Return the comparison form of a product name (original is unchanged)."""
    text = _full_width_to_half(name)
    text = re.sub(r"\s+", "", text)
    for decoration in _DECORATIONS:
        text = text.replace(decoration, "")
    # Strip share-class suffixes, but never hollow the name out below 2 chars.
    while True:
        stripped = _SHARE_CLASS_RE.sub("", text)
        if stripped == text or len(stripped) < 2:
            return text
        text = stripped

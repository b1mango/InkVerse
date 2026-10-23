"""Strict TXT decoding with explicit overrides for ambiguous legacy encodings."""

import codecs

ENCODINGS = ("auto", "utf-8-sig", "gb18030", "big5", "utf-16", "utf-16-le", "utf-16-be")


def decode_text(data: bytes, encoding: str = "auto") -> tuple[str, str]:
    if encoding not in ENCODINGS:
        raise ValueError("Unsupported text encoding")
    if encoding != "auto":
        return data.decode(encoding), encoding
    for marker, candidate in (
        (codecs.BOM_UTF32_LE, "utf-32"), (codecs.BOM_UTF32_BE, "utf-32"),
        (codecs.BOM_UTF16_LE, "utf-16"), (codecs.BOM_UTF16_BE, "utf-16"),
        (codecs.BOM_UTF8, "utf-8-sig"),
    ):
        if data.startswith(marker):
            return data.decode(candidate), candidate
    for candidate in ("utf-8", "gb18030", "big5"):
        try:
            return data.decode(candidate), candidate
        except UnicodeDecodeError:
            continue
    raise ValueError("Cannot detect text encoding")

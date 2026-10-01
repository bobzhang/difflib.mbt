// Charset handling for `HtmlDiff::make_file`, emulating Python's
// `str.encode(charset, "xmlcharrefreplace")` for the codecs listed below.
// Alias tables come from CPython's `encodings.aliases`.

///|
/// Python's `encodings.normalize_encoding` followed by lowercasing: runs of
/// characters other than ASCII letters, digits and `.` become a single `_`,
/// and leading/trailing ones are dropped.
fn normalize_encoding(name : String) -> String {
  let buf = StringBuilder()
  let mut punct = false
  for c in name.to_lower() {
    if c is ('a'..='z' | '0'..='9' | '.') {
      if punct && buf.to_string() != "" {
        buf.write_char('_')
      }
      buf.write_char(c)
      punct = false
    } else {
      punct = true
    }
  }
  buf.to_string()
}

///|
/// Resolves a charset name to a Python codec name, or `None` if it is not one
/// of the codecs this package knows about.
fn resolve_codec(charset : String) -> String? {
  let norm = normalize_encoding(charset)
  let candidates = [norm, norm.replace_all(old=".", new="_")]
  for name in candidates {
    match name {
      "646"
      | "ansi_x3.4_1968"
      | "ansi_x3.4_1986"
      | "ansi_x3_4_1968"
      | "ascii"
      | "cp367"
      | "csascii"
      | "ibm367"
      | "iso646_us"
      | "iso_646.irv_1991"
      | "iso_ir_6"
      | "us"
      | "us_ascii" => return Some("ascii")
      "8859"
      | "cp819"
      | "csisolatin1"
      | "ibm819"
      | "iso8859"
      | "iso8859_1"
      | "iso_8859_1"
      | "iso_8859_1_1987"
      | "iso_ir_100"
      | "l1"
      | "latin"
      | "latin1"
      | "latin_1" => return Some("latin_1")
      "cp65001" | "u8" | "utf" | "utf8" | "utf8_ucs2" | "utf8_ucs4" | "utf_8" =>
        return Some("utf_8")
      "utf_8_sig" => return Some("utf_8_sig")
      "u16" | "utf16" | "utf_16" => return Some("utf_16")
      "unicodelittleunmarked" | "utf_16_le" | "utf_16le" =>
        return Some("utf_16_le")
      "unicodebigunmarked" | "utf_16_be" | "utf_16be" =>
        return Some("utf_16_be")
      "u32" | "utf32" | "utf_32" => return Some("utf_32")
      "utf_32_le" | "utf_32le" => return Some("utf_32_le")
      "utf_32_be" | "utf_32be" => return Some("utf_32_be")
      _ => ()
    }
  }
  None
}

///|
/// Replaces characters that `charset` cannot encode by `&#NNN;` references,
/// emulating Python's `encode(charset, 'xmlcharrefreplace')` for ASCII,
/// Latin-1 and the UTF-8/16/32 codecs. Unknown charsets are assumed to encode
/// all of Unicode.
fn xml_charref_replace(s : String, charset : String) -> String {
  let max_code = match resolve_codec(charset) {
    Some("ascii") => 0x7f
    Some("latin_1") => 0xff
    Some(_) => 0x10ffff
    None => return s
  }
  let buf = StringBuilder()
  for c in s {
    let code = c.to_int()
    // lone surrogates cannot be encoded by any of these codecs
    if code > max_code || (code >= 0xd800 && code <= 0xdfff) {
      buf.write_string("&#\{code};")
    } else {
      buf.write_char(c)
    }
  }
  buf.to_string()
}

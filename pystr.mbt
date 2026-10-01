// Helpers reproducing the exact semantics of the Python `str` methods that
// difflib relies on (`isspace`, `strip`, `rstrip`, `expandtabs`, and
// code-point-wise ordering).

///|
/// Python's `str.isspace()` for a single character: characters whose
/// bidirectional type is WS, B or S, or whose general category is Zs.
fn is_py_space(c : Char) -> Bool {
  match c {
    '\t' | '\n' | '\u{0b}' | '\u{0c}' | '\r' => true
    '\u{1c}'..='\u{1f}' => true
    ' ' | '\u{85}' | '\u{a0}' | '\u{1680}' => true
    '\u{2000}'..='\u{200a}' => true
    '\u{2028}' | '\u{2029}' | '\u{202f}' | '\u{205f}' | '\u{3000}' => true
    _ => false
  }
}

///|
/// Python's `str.rstrip()` (no arguments).
fn py_rstrip(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 && is_py_space(chars[end - 1]) {
    end -= 1
  }
  if end == chars.length() {
    s
  } else {
    String::from_array(chars[:end])
  }
}

///|
/// Python's `str.strip()` (no arguments).
fn py_strip(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && is_py_space(chars[start]) {
    start += 1
  }
  while end > start && is_py_space(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}

///|
/// Python's `str.expandtabs(tabsize)`: the column resets after `\n` or `\r`.
fn py_expandtabs(s : String, tabsize : Int) -> String {
  let buf = StringBuilder()
  let mut column = 0
  for c in s {
    match c {
      '\t' =>
        if tabsize > 0 {
          let pad = tabsize - column % tabsize
          for _ in 0..<pad {
            buf.write_char(' ')
          }
          column += pad
        }
      '\n' | '\r' => {
        buf.write_char(c)
        column = 0
      }
      _ => {
        buf.write_char(c)
        column += 1
      }
    }
  }
  buf.to_string()
}

///|
/// Compares two strings by code point, like Python's `str` ordering.
fn py_str_compare(x : String, y : String) -> Int {
  let xs = x.to_array()
  let ys = y.to_array()
  let n = @cmp.minimum(xs.length(), ys.length())
  for i in 0..<n {
    let c = xs[i].compare(ys[i])
    if c != 0 {
      return c
    }
  }
  xs.length().compare(ys.length())
}

///|
/// Python's `repr(float)`: the shortest round-tripping digits, in fixed
/// notation when the decimal exponent is in `[-4, 16)` and scientific
/// notation (`1e+16`, `1.5e-07`) otherwise.
fn py_float_repr(x : Double) -> String {
  if x.is_nan() {
    return "nan"
  }
  if x.is_inf() {
    return if x > 0.0 { "inf" } else { "-inf" }
  }
  // Decompose MoonBit's shortest representation into sign, significant
  // digits and `decpt`, where x = 0.d1d2... * 10^decpt.
  let s = x.to_string()
  let negative = s.has_prefix("-")
  let s = if negative { s.unsafe_substring(start=1, end=s.length()) } else { s }
  let (mantissa, exp) = match s.find("e") {
    Some(i) => {
      let e = s.unsafe_substring(start=i + 1, end=s.length())
      let e = if e.has_prefix("+") {
        e.unsafe_substring(start=1, end=e.length())
      } else {
        e
      }
      (
        s.unsafe_substring(start=0, end=i),
        @string.parse_int(e) catch {
          _ => 0
        },
      )
    }
    None => (s, 0)
  }
  let (int_part, frac_part) = match mantissa.find(".") {
    Some(i) =>
      (
        mantissa.unsafe_substring(start=0, end=i),
        mantissa.unsafe_substring(start=i + 1, end=mantissa.length()),
      )
    None => (mantissa, "")
  }
  let mut digits = int_part + frac_part
  let mut decpt = int_part.length() + exp
  while digits.has_prefix("0") {
    digits = digits.unsafe_substring(start=1, end=digits.length())
    decpt -= 1
  }
  while digits.has_suffix("0") {
    digits = digits.unsafe_substring(start=0, end=digits.length() - 1)
  }
  let sign = if negative { "-" } else { "" }
  if digits == "" {
    // MoonBit prints -0.0 as "0"; Python keeps the sign
    return if 1.0 / x < 0.0 { "-0.0" } else { "0.0" }
  }
  let n = digits.length()
  if decpt <= -4 || decpt > 16 {
    let e = decpt - 1
    let mant = if n == 1 {
      digits
    } else {
      digits.unsafe_substring(start=0, end=1) +
      "." +
      digits.unsafe_substring(start=1, end=n)
    }
    let e_abs = e.abs()
    let e_str = if e_abs < 10 { "0\{e_abs}" } else { e_abs.to_string() }
    sign + mant + (if e < 0 { "e-" } else { "e+" }) + e_str
  } else if decpt <= 0 {
    sign + "0." + "0".repeat(-decpt) + digits
  } else if decpt >= n {
    sign + digits + "0".repeat(decpt - n) + ".0"
  } else {
    sign +
    digits.unsafe_substring(start=0, end=decpt) +
    "." +
    digits.unsafe_substring(start=decpt, end=n)
  }
}

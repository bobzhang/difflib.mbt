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
/// Approximates Python's `repr(float)`: integral values keep a `.0` suffix.
fn py_float_repr(x : Double) -> String {
  let s = x.to_string()
  if x.is_nan() || x.is_inf() || s.contains(".") || s.contains("e") {
    s
  } else {
    s + ".0"
  }
}

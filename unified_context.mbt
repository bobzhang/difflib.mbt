///|
/// Converts a range to the "ed" format used by unified diffs.
fn format_range_unified(start : Int, stop : Int) -> String {
  // Per the diff spec at http://www.unix.org/single_unix_specification/
  let mut beginning = start + 1 // lines start numbering with one
  let length = stop - start
  if length == 1 {
    return "\{beginning}"
  }
  if length == 0 {
    beginning -= 1 // empty ranges begin at line just before the range
  }
  "\{beginning},\{length}"
}

///|
/// ANSI escape sequences used for `color=true` unified diffs (the defaults of
/// Python's `_colorize` difflib theme).
priv struct DiffTheme {
  header : String
  hunk : String
  added : String
  removed : String
  context : String
  reset : String
}

///|
let color_theme : DiffTheme = {
  header: "\u{1b}[1m",
  hunk: "\u{1b}[36m",
  added: "\u{1b}[32m",
  removed: "\u{1b}[31m",
  context: "\u{1b}[0m",
  reset: "\u{1b}[0m",
}

///|
let no_color_theme : DiffTheme = {
  header: "",
  hunk: "",
  added: "",
  removed: "",
  context: "",
  reset: "",
}

///|
/// Compares two sequences of lines and returns the delta as a unified diff.
///
/// - `n` (default 3): the number of context lines.
/// - `lineterm` (default `"\n"`): appended to the control lines (`---`,
///   `+++`, `@@`). Set it to `""` for inputs without trailing newlines.
/// - `fromfile`, `tofile`, `fromfiledate`, `tofiledate`: header fields.
/// - `color`: emit ANSI colors similar to `git diff --color`. Unlike Python,
///   the environment (`NO_COLOR`, tty detection, ...) is not consulted.
/// - `autojunk`: the automatic junk heuristic of [SequenceMatcher].
///
/// # Example
/// ```mbt check
/// test {
///   let diff = @difflib.unified_diff(
///     ["one", "two", "three", "four"],
///     ["zero", "one", "tree", "four"],
///     fromfile="Original",
///     tofile="Current",
///     fromfiledate="2005-01-26 23:30:50",
///     tofiledate="2010-04-02 10:20:52",
///     lineterm="",
///   )
///   inspect(
///     diff.join("\n"),
///     content=(
///       #|--- Original	2005-01-26 23:30:50
///       #|+++ Current	2010-04-02 10:20:52
///       #|@@ -1,4 +1,4 @@
///       #|+zero
///       #| one
///       #|-two
///       #|-three
///       #|+tree
///       #| four
///     ),
///   )
/// }
/// ```
pub fn unified_diff(
  a : Array[String],
  b : Array[String],
  fromfile? : String = "",
  tofile? : String = "",
  fromfiledate? : String = "",
  tofiledate? : String = "",
  n? : Int = 3,
  lineterm? : String = "\n",
  autojunk? : Bool = true,
  color? : Bool = false,
) -> Array[String] {
  let t = if color { color_theme } else { no_color_theme }
  let out : Array[String] = []
  let mut started = false
  for group in SequenceMatcher::new(a~, b~, autojunk~).get_grouped_opcodes(n~) {
    if !started {
      started = true
      let fromdate = if fromfiledate != "" { "\t\{fromfiledate}" } else { "" }
      let todate = if tofiledate != "" { "\t\{tofiledate}" } else { "" }
      out.push("\{t.header}--- \{fromfile}\{fromdate}\{lineterm}\{t.reset}")
      out.push("\{t.header}+++ \{tofile}\{todate}\{lineterm}\{t.reset}")
    }
    let first = group[0]
    let last = group[group.length() - 1]
    let file1_range = format_range_unified(first.i1, last.i2)
    let file2_range = format_range_unified(first.j1, last.j2)
    out.push(
      "\{t.hunk}@@ -\{file1_range} +\{file2_range} @@\{lineterm}\{t.reset}",
    )
    for op in group {
      let { tag, i1, i2, j1, j2, } = op
      if tag is Equal {
        for line in a[i1:i2] {
          out.push("\{t.context} \{line}\{t.reset}")
        }
        continue
      }
      if tag is (Replace | Delete) {
        for line in a[i1:i2] {
          out.push("\{t.removed}-\{line}\{t.reset}")
        }
      }
      if tag is (Replace | Insert) {
        for line in b[j1:j2] {
          out.push("\{t.added}+\{line}\{t.reset}")
        }
      }
    }
  }
  out
}

///|
/// Converts a range to the "ed" format used by context diffs.
fn format_range_context(start : Int, stop : Int) -> String {
  // Per the diff spec at http://www.unix.org/single_unix_specification/
  let mut beginning = start + 1 // lines start numbering with one
  let length = stop - start
  if length == 0 {
    beginning -= 1 // empty ranges begin at line just before the range
  }
  if length <= 1 {
    return "\{beginning}"
  }
  "\{beginning},\{beginning + length - 1}"
}

///|
fn context_prefix(tag : Tag) -> String {
  match tag {
    Insert => "+ "
    Delete => "- "
    Replace => "! "
    Equal => "  "
  }
}

///|
/// Compares two sequences of lines and returns the delta as a context diff.
///
/// The parameters have the same meaning as for [unified_diff].
///
/// # Example
/// ```mbt check
/// test {
///   let diff = @difflib.context_diff(
///     ["one\n", "two\n", "three\n", "four\n"],
///     ["zero\n", "one\n", "tree\n", "four\n"],
///     fromfile="Original",
///     tofile="Current",
///   )
///   inspect(
///     diff.join(""),
///     content=(
///       #|*** Original
///       #|--- Current
///       #|***************
///       #|*** 1,4 ****
///       #|  one
///       #|! two
///       #|! three
///       #|  four
///       #|--- 1,4 ----
///       #|+ zero
///       #|  one
///       #|! tree
///       #|  four
///       #|
///     ),
///   )
/// }
/// ```
pub fn context_diff(
  a : Array[String],
  b : Array[String],
  fromfile? : String = "",
  tofile? : String = "",
  fromfiledate? : String = "",
  tofiledate? : String = "",
  n? : Int = 3,
  lineterm? : String = "\n",
  autojunk? : Bool = true,
) -> Array[String] {
  let out : Array[String] = []
  let mut started = false
  for group in SequenceMatcher::new(a~, b~, autojunk~).get_grouped_opcodes(n~) {
    if !started {
      started = true
      let fromdate = if fromfiledate != "" { "\t\{fromfiledate}" } else { "" }
      let todate = if tofiledate != "" { "\t\{tofiledate}" } else { "" }
      out.push("*** \{fromfile}\{fromdate}\{lineterm}")
      out.push("--- \{tofile}\{todate}\{lineterm}")
    }
    let first = group[0]
    let last = group[group.length() - 1]
    out.push("***************" + lineterm)
    let file1_range = format_range_context(first.i1, last.i2)
    out.push("*** \{file1_range} ****\{lineterm}")
    if group.iter().any(op => op.tag is (Replace | Delete)) {
      for op in group {
        if !(op.tag is Insert) {
          for line in a[op.i1:op.i2] {
            out.push(context_prefix(op.tag) + line)
          }
        }
      }
    }
    let file2_range = format_range_context(first.j1, last.j2)
    out.push("--- \{file2_range} ----\{lineterm}")
    if group.iter().any(op => op.tag is (Replace | Insert)) {
      for op in group {
        if !(op.tag is Delete) {
          for line in b[op.j1:op.j2] {
            out.push(context_prefix(op.tag) + line)
          }
        }
      }
    }
  }
  out
}

///|
/// The output format used by [diff_bytes].
pub(all) enum DiffFormat {
  /// [unified_diff]
  Unified
  /// [context_diff]
  Context
} derive(Eq, Debug)

///|
/// Decodes bytes losslessly into a string, one character per byte.
fn bytes_to_latin1(bs : BytesView) -> String {
  let buf = StringBuilder()
  for byte in bs {
    buf.write_char(byte.to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Inverse of [bytes_to_latin1].
fn latin1_to_bytes(s : String) -> Bytes {
  let arr : Array[Byte] = []
  for c in s {
    arr.push(c.to_int().to_byte())
  }
  Bytes::from_array(arr)
}

///|
/// Compares `a` and `b`, two sequences of lines represented as bytes rather
/// than strings, producing a unified or context diff (see `format`) whose
/// lines are also bytes.
///
/// Inputs are losslessly converted to strings (one character per byte) so
/// that files with unknown or inconsistent encodings can be compared, and the
/// output is encoded back to bytes. This mirrors Python's `diff_bytes`;
/// `autojunk` is forwarded to the underlying diff function.
///
/// # Example
/// ```mbt check
/// test {
///   let diff = @difflib.diff_bytes(
///     Unified,
///     [b"\xa3odz is a city in Poland."],
///     [b"\xc5\x81odz is a city in Poland."],
///     fromfile=b"\xb3odz.txt",
///     tofile=b"\xc5\x82odz.txt",
///     lineterm=b"",
///   )
///   let expected : Array[Bytes] = [
///     b"--- \xb3odz.txt", b"+++ \xc5\x82odz.txt", b"@@ -1 +1 @@", b"-\xa3odz is a city in Poland.",
///     b"+\xc5\x81odz is a city in Poland.",
///   ]
///   assert_eq(diff, expected)
/// }
/// ```
pub fn diff_bytes(
  format : DiffFormat,
  a : Array[Bytes],
  b : Array[Bytes],
  fromfile? : Bytes = b"",
  tofile? : Bytes = b"",
  fromfiledate? : Bytes = b"",
  tofiledate? : Bytes = b"",
  n? : Int = 3,
  lineterm? : Bytes = b"\n",
  autojunk? : Bool = true,
) -> Array[Bytes] {
  let a = a.map(line => bytes_to_latin1(line))
  let b = b.map(line => bytes_to_latin1(line))
  let fromfile = bytes_to_latin1(fromfile)
  let tofile = bytes_to_latin1(tofile)
  let fromfiledate = bytes_to_latin1(fromfiledate)
  let tofiledate = bytes_to_latin1(tofiledate)
  let lineterm = bytes_to_latin1(lineterm)
  let lines = match format {
    Unified =>
      unified_diff(
        a,
        b,
        fromfile~,
        tofile~,
        fromfiledate~,
        tofiledate~,
        n~,
        lineterm~,
        autojunk~,
      )
    Context =>
      context_diff(
        a,
        b,
        fromfile~,
        tofile~,
        fromfiledate~,
        tofiledate~,
        n~,
        lineterm~,
        autojunk~,
      )
  }
  lines.map(latin1_to_bytes)
}

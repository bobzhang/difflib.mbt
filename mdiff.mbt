// Port of Python's private `difflib._mdiff`: side by side line pairing with
// intraline change markers. Marked-up text uses these markers, which are not
// noticed by an HTML escaper:
//
//   '\u{0}+' start of added text
//   '\u{0}-' start of deleted text
//   '\u{0}^' start of changed text
//   '\u{1}'  end of added/deleted/changed text

///|
/// A line number column entry: Python uses an `int`, `''` (a padding line),
/// or `'>'` (a wrapped continuation line).
priv enum LineNum {
  Num(Int)
  Blank
  Cont
} derive(Eq, Debug)

///|
fn LineNum::is_truthy(self : LineNum) -> Bool {
  !(self is Blank)
}

///|
fn LineNum::to_column(self : LineNum) -> String {
  match self {
    Num(n) => n.to_string()
    Blank => ""
    Cont => ">"
  }
}

///|
/// One side of a side by side row: `(line number, marked-up text)`.
priv struct SideLine {
  num : LineNum
  text : String
} derive(Eq, Debug)

///|
/// A row produced by [mdiff]: either a from/to pair with a "has changes"
/// flag, or a context separator (Python's `(None, None, None)`).
/// `Eq` and `Debug` are only used by the whitebox tests.
#warnings("-unused_value")
priv enum MdiffRow {
  Row(SideLine, SideLine, Bool)
  Separator
} derive(Eq, Debug)

///|
/// Returns the code-point substring `s[start:]`.
fn drop_chars(s : String, start : Int) -> String {
  let chars = s.to_array()
  if start >= chars.length() {
    ""
  } else {
    String::from_array(chars[start:])
  }
}

///|
/// State shared by the line-level helpers of [mdiff].
priv struct MdiffState {
  diff_lines : Array[String]
  mut next_index : Int
  num_lines : FixedArray[Int]
}

///|
fn MdiffState::next_diff_line(self : MdiffState) -> String {
  if self.next_index < self.diff_lines.length() {
    let line = self.diff_lines[self.next_index]
    self.next_index += 1
    line
  } else {
    "X"
  }
}

///|
/// Python's `_make_line`: returns a line of text with change markup.
///
/// `format_key` is `None` (no markup), `Some('?')` (intraline markup, with
/// the indices taken from the following `?` line), or `Some('+')` /
/// `Some('-')` (markup around the entire line). Consumed lines are removed
/// from `lines`.
fn MdiffState::make_line(
  self : MdiffState,
  lines : Array[String],
  format_key : Char?,
  side : Int,
) -> SideLine {
  self.num_lines[side] += 1
  let num = Num(self.num_lines[side])
  match format_key {
    None => { num, text: drop_chars(lines.remove(0), 2), }
    Some('?') => {
      let text = lines.remove(0).to_array()
      let markers = lines.remove(0).to_array()
      // find intraline changes: runs of '+', '-' or '^'
      let sub_info : Array[(Char, Int, Int)] = []
      let mut i = 0
      while i < markers.length() {
        let c = markers[i]
        if c is ('+' | '-' | '^') {
          let begin = i
          while i < markers.length() && markers[i] == c {
            i += 1
          }
          sub_info.push((c, begin, i))
        } else {
          i += 1
        }
      }
      // insert our special marks, last change first so indices stay valid
      let mut text = text
      for info in sub_info.rev_iter() {
        let (key, begin, end) = info
        let begin = @cmp.minimum(begin, text.length())
        let end = @cmp.minimum(end, text.length())
        let marked : Array[Char] = []
        marked.push_iter(text[0:begin].iter())
        marked.push('\u{0}')
        marked.push(key)
        marked.push_iter(text[begin:end].iter())
        marked.push('\u{1}')
        marked.push_iter(text[end:].iter())
        text = marked
      }
      let text = if text.length() > 2 {
        String::from_array(text[2:])
      } else {
        ""
      }
      { num, text, }
    }
    Some(key) => {
      let mut text = drop_chars(lines.remove(0), 2)
      // if line of text is just a newline, insert a space so there is
      // something for the user to highlight and see.
      if text == "" {
        text = " "
      }
      { num, text: "\u{0}\{key}\{text}\u{1}", }
    }
  }
}

///|
/// Python's `_line_iterator`: yields from/to lines with a change indication.
/// When possible both a "from" and a "to" line are produced, otherwise one
/// of them is `None`.
fn MdiffState::line_iterator(
  self : MdiffState,
) -> Array[(SideLine?, SideLine?, Bool)] {
  let out : Array[(SideLine?, SideLine?, Bool)] = []
  let blank_line : SideLine = { num: Blank, text: "\n", }
  let lines : Array[String] = []
  let mut num_blanks_pending = 0
  let mut num_blanks_to_yield = 0
  for ;; {
    // Load up next 4 lines so we can look ahead, create strings which
    // are a concatenation of the first character of each of the 4 lines
    // so we can do some very readable comparisons.
    while lines.length() < 4 {
      lines.push(self.next_diff_line())
    }
    let s = StringBuilder()
    for line in lines {
      s.write_char(line.get_char(0).unwrap_or('X'))
    }
    let s = s.to_string()
    let mut from_line : SideLine? = None
    let mut to_line : SideLine? = None
    if s.has_prefix("X") {
      // When no more lines, pump out any remaining blank lines so the
      // corresponding add/delete lines get a matching blank line so
      // all line pairs get yielded at the next level.
      num_blanks_to_yield = num_blanks_pending
    } else if s.has_prefix("-?+?") {
      // simple intraline change
      let f = self.make_line(lines, Some('?'), 0)
      let t = self.make_line(lines, Some('?'), 1)
      out.push((Some(f), Some(t), true))
      continue
    } else if s.has_prefix("--++") {
      // in delete block, add block coming: we do NOT want to get
      // caught up on blank lines yet, just process the delete line
      num_blanks_pending -= 1
      out.push((Some(self.make_line(lines, Some('-'), 0)), None, true))
      continue
    } else if s.has_prefix("--?+") || s.has_prefix("--+") || s.has_prefix("- ") {
      // in delete block and see an intraline change or unchanged line
      // coming: yield the delete line and then blanks
      from_line = Some(self.make_line(lines, Some('-'), 0))
      to_line = None
      num_blanks_to_yield = num_blanks_pending - 1
      num_blanks_pending = 0
    } else if s.has_prefix("-+?") {
      // intraline change
      let f = self.make_line(lines, None, 0)
      let t = self.make_line(lines, Some('?'), 1)
      out.push((Some(f), Some(t), true))
      continue
    } else if s.has_prefix("-?+") {
      // intraline change
      let f = self.make_line(lines, Some('?'), 0)
      let t = self.make_line(lines, None, 1)
      out.push((Some(f), Some(t), true))
      continue
    } else if s.has_prefix("-") {
      // delete FROM line
      num_blanks_pending -= 1
      out.push((Some(self.make_line(lines, Some('-'), 0)), None, true))
      continue
    } else if s.has_prefix("+--") {
      // in add block, delete block coming: we do NOT want to get
      // caught up on blank lines yet, just process the add line
      num_blanks_pending += 1
      out.push((None, Some(self.make_line(lines, Some('+'), 1)), true))
      continue
    } else if s.has_prefix("+ ") || s.has_prefix("+-") {
      // will be leaving an add block: yield blanks then add line
      from_line = None
      to_line = Some(self.make_line(lines, Some('+'), 1))
      num_blanks_to_yield = num_blanks_pending + 1
      num_blanks_pending = 0
    } else if s.has_prefix("+") {
      // inside an add block, yield the add line
      num_blanks_pending += 1
      out.push((None, Some(self.make_line(lines, Some('+'), 1)), true))
      continue
    } else if s.has_prefix(" ") {
      // unchanged text, yield it to both sides
      let f = self.make_line(lines.copy(), None, 0)
      let t = self.make_line(lines, None, 1)
      out.push((Some(f), Some(t), false))
      continue
    }
    // Catch up on the blank lines so when we yield the next from/to
    // pair, they are lined up.
    while num_blanks_to_yield < 0 {
      num_blanks_to_yield += 1
      out.push((None, Some(blank_line), true))
    }
    while num_blanks_to_yield > 0 {
      num_blanks_to_yield -= 1
      out.push((Some(blank_line), None, true))
    }
    if s.has_prefix("X") {
      return out
    }
    out.push((from_line, to_line, true))
  }
}

///|
/// Python's `_line_pair_iterator`: always yields a from/to pair, collecting
/// single from/to lines until a pair is available.
fn line_pair_iterator(
  lines : Array[(SideLine?, SideLine?, Bool)],
) -> Array[(SideLine, SideLine, Bool)] {
  let out : Array[(SideLine, SideLine, Bool)] = []
  let fromlines : @deque.Deque[(SideLine, Bool)] = @deque.Deque([])
  let tolines : @deque.Deque[(SideLine, Bool)] = @deque.Deque([])
  let mut index = 0
  for ;; {
    // Collecting lines of text until we have a from/to pair
    while fromlines.is_empty() || tolines.is_empty() {
      if index >= lines.length() {
        return out
      }
      let (from_line, to_line, found_diff) = lines[index]
      index += 1
      if from_line is Some(from_line) {
        fromlines.push_back((from_line, found_diff))
      }
      if to_line is Some(to_line) {
        tolines.push_back((to_line, found_diff))
      }
    }
    // Once we have a pair, remove them from the collection and yield it
    guard! fromlines.pop_front() is Some((from_line, from_diff))
    guard! tolines.pop_front() is Some((to_line, to_diff))
    out.push((from_line, to_line, from_diff || to_diff))
  }
}

///|
/// Python's `difflib._mdiff`: returns marked up from/to side by side
/// differences.
///
/// `context` is the number of context lines to display around each
/// difference; `None` yields all lines.
fn mdiff(
  fromlines : Array[String],
  tolines : Array[String],
  context? : Int,
  linejunk? : (String) -> Bool,
  charjunk? : (Char) -> Bool = is_character_junk,
  autojunk? : Bool = true,
) -> Array[MdiffRow] {
  let diff_lines = ndiff(fromlines, tolines, linejunk?, charjunk~, autojunk~)
  let state : MdiffState = {
    diff_lines,
    next_index: 0,
    num_lines: FixedArray::make(2, 0),
  }
  let pairs = line_pair_iterator(state.line_iterator())
  let out : Array[MdiffRow] = []
  guard context is Some(context) else {
    for pair in pairs {
      out.push(Row(pair.0, pair.1, pair.2))
    }
    return out
  }
  // Handle case where user wants context differencing.  We must do some
  // storage of lines until we know for sure that they are to be yielded.
  // Any context >= the number of line pairs gives the same output; clamping
  // avoids overflow and a huge buffer for very large context sizes.
  let context = @cmp.minimum(context, pairs.length()) + 1
  let mut pos = 0
  for ;; {
    // Store lines up until we find a difference, note use of a
    // circular queue because we only need to keep around what
    // we need for context.
    let mut index = 0
    let context_lines : Array[(SideLine, SideLine, Bool)?] = Array::make(
      context,
      None,
    )
    let mut found_diff = false
    while !found_diff {
      if pos >= pairs.length() {
        return out
      }
      let pair = pairs[pos]
      pos += 1
      found_diff = pair.2
      context_lines[index % context] = Some(pair)
      index += 1
    }
    // Yield lines that we have collected so far, but first yield
    // the user's separator.
    let mut lines_to_write = 0
    if index > context {
      out.push(Separator)
      lines_to_write = context
    } else {
      lines_to_write = index
      index = 0
    }
    while lines_to_write > 0 {
      let i = index % context
      index += 1
      guard! context_lines[i] is Some((f, t, d))
      out.push(Row(f, t, d))
      lines_to_write -= 1
    }
    // Now yield the context lines after the change
    lines_to_write = context - 1
    while lines_to_write > 0 {
      if pos >= pairs.length() {
        return out
      }
      let (f, t, d) = pairs[pos]
      pos += 1
      // If another change within the context, extend the context
      if d {
        lines_to_write = context - 1
      } else {
        lines_to_write -= 1
      }
      out.push(Row(f, t, d))
    }
  }
}

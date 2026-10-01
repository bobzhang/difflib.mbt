///|
/// Produces human-readable deltas from sequences of lines of text.
///
/// Each line of a `Differ` delta begins with a two-letter code:
///
/// - `"- "`: line unique to sequence 1
/// - `"+ "`: line unique to sequence 2
/// - `"  "`: line common to both sequences
/// - `"? "`: line not present in either input sequence, guiding the eye to
///   intraline differences
///
/// # Example
/// ```mbt check
/// test {
///   let text1 = [
///     "  1. Beautiful is better than ugly.\n", "  2. Explicit is better than implicit.\n",
///     "  3. Simple is better than complex.\n", "  4. Complex is better than complicated.\n",
///   ]
///   let text2 = [
///     "  1. Beautiful is better than ugly.\n", "  3.   Simple is better than complex.\n",
///     "  4. Complicated is better than complex.\n", "  5. Flat is better than nested.\n",
///   ]
///   inspect(
///     @difflib.Differ::new().compare(text1, text2).join(""),
///     content=(
///       #|    1. Beautiful is better than ugly.
///       #|-   2. Explicit is better than implicit.
///       #|-   3. Simple is better than complex.
///       #|+   3.   Simple is better than complex.
///       #|?     ++
///       #|-   4. Complex is better than complicated.
///       #|?            ^                     ---- ^
///       #|+   4. Complicated is better than complex.
///       #|?           ++++ ^                      ^
///       #|+   5. Flat is better than nested.
///       #|
///     ),
///   )
/// }
/// ```
pub struct Differ {
  priv linejunk : ((String) -> Bool)?
  priv charjunk : ((Char) -> Bool)?
  priv autojunk : Bool
}

///|
/// Constructs a text differencer with optional junk filters.
///
/// - `linejunk`: returns true iff a line is junk (e.g. [is_line_junk]). It is
///   recommended to leave this unset.
/// - `charjunk`: returns true iff a character is junk (e.g.
///   [is_character_junk]).
/// - `autojunk`: the automatic junk heuristic of [SequenceMatcher].
pub fn Differ::new(
  linejunk? : (String) -> Bool,
  charjunk? : (Char) -> Bool,
  autojunk? : Bool = true,
) -> Differ {
  { linejunk, charjunk, autojunk, }
}

///|
/// Compares two sequences of lines and returns the resulting delta.
///
/// Each line should end with a newline; the delta lines then also end with
/// newlines.
///
/// # Example
/// ```mbt check
/// test {
///   let delta = @difflib.Differ::new().compare(["one\n", "two\n", "three\n"], [
///     "ore\n", "tree\n", "emu\n",
///   ])
///   inspect(
///     delta.join(""),
///     content=(
///       #|- one
///       #|?  ^
///       #|+ ore
///       #|?  ^
///       #|- two
///       #|- three
///       #|?  -
///       #|+ tree
///       #|+ emu
///       #|
///     ),
///   )
/// }
/// ```
pub fn Differ::compare(
  self : Differ,
  a : Array[String],
  b : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  let cruncher = SequenceMatcher::new(
    isjunk?=self.linejunk,
    a~,
    b~,
    autojunk=self.autojunk,
  )
  for op in cruncher.get_opcodes() {
    let { tag, i1: alo, i2: ahi, j1: blo, j2: bhi, } = op
    match tag {
      Replace => self.fancy_replace(out, a, alo, ahi, b, blo, bhi)
      Delete => dump(out, "-", a, alo, ahi)
      Insert => dump(out, "+", b, blo, bhi)
      Equal => dump(out, " ", a, alo, ahi)
    }
  }
  out
}

///|
/// Emits the comparison results for a same-tagged range.
fn dump(
  out : Array[String],
  tag : String,
  x : Array[String],
  lo : Int,
  hi : Int,
) -> Unit {
  for i in lo..<hi {
    out.push("\{tag} \{x[i]}")
  }
}

///|
fn plain_replace(
  out : Array[String],
  a : Array[String],
  alo : Int,
  ahi : Int,
  b : Array[String],
  blo : Int,
  bhi : Int,
) -> Unit {
  // dump the shorter block first -- reduces the burden on short-term
  // memory if the blocks are of very different sizes
  if bhi - blo < ahi - alo {
    dump(out, "+", b, blo, bhi)
    dump(out, "-", a, alo, ahi)
  } else {
    dump(out, "-", a, alo, ahi)
    dump(out, "+", b, blo, bhi)
  }
}

///|
/// When replacing one block of lines with another, searches the blocks for
/// *similar* lines; the best-matching pair (if any) is used as a synch point,
/// and intraline difference marking is done on the similar pair.
fn Differ::fancy_replace(
  self : Differ,
  out : Array[String],
  a : Array[String],
  alo : Int,
  ahi : Int,
  b : Array[String],
  blo : Int,
  bhi : Int,
) -> Unit {
  // Don't synch up unless the lines have a similarity score above cutoff.
  let cutoff = 0.74999
  let cruncher : SequenceMatcher[Char] = SequenceMatcher::new(
    isjunk?=self.charjunk,
    autojunk=self.autojunk,
  )
  // Character arrays for each line, computed once so that `set_seq1` /
  // `set_seq2` can reuse cached state for identical sequences.
  let a_chars = Array::makei(ahi - alo, k => a[alo + k].to_array())
  let b_chars = Array::makei(bhi - blo, k => b[blo + k].to_array())
  let window = 10
  let mut best_i = -1
  let mut best_j = -1
  // smallest indices not yet resolved
  let mut dump_i = alo
  let mut dump_j = blo
  for j in blo..<bhi {
    cruncher.set_seq2(b_chars[j - blo])
    // Search the corresponding i's within WINDOW for the highest
    // ratio greater than `cutoff`.
    let aequiv = alo + (j - blo)
    let range_lo = @cmp.maximum(aequiv - window, dump_i)
    let range_hi = @cmp.minimum(aequiv + window + 1, ahi)
    if range_lo >= range_hi {
      // likely exit if `a` is shorter than `b`
      break
    }
    let mut best_ratio = cutoff
    for i in range_lo..<range_hi {
      cruncher.set_seq1(a_chars[i - alo])
      // Ordering by cheapest to most expensive ratio is very
      // valuable, most often getting out early.
      if cruncher.real_quick_ratio() <= best_ratio ||
        cruncher.quick_ratio() <= best_ratio {
        continue
      }
      let ratio = cruncher.ratio()
      if ratio > best_ratio {
        best_i = i
        best_j = j
        best_ratio = ratio
      }
    }
    if best_i < 0 {
      // found nothing to synch on yet - move to next j
      continue
    }
    // pump out straight replace from before this synch pair
    fancy_helper(out, a, dump_i, best_i, b, dump_j, best_j)
    // do intraline marking on the synch pair
    let aelt = a[best_i]
    let belt = b[best_j]
    if aelt != belt {
      // pump out a '-', '?', '+', '?' quad for the synched lines
      let atags = StringBuilder()
      let btags = StringBuilder()
      cruncher.set_seqs(a_chars[best_i - alo], b_chars[best_j - blo])
      for op in cruncher.get_opcodes() {
        let la = op.i2 - op.i1
        let lb = op.j2 - op.j1
        match op.tag {
          Replace => {
            repeat_char(atags, '^', la)
            repeat_char(btags, '^', lb)
          }
          Delete => repeat_char(atags, '-', la)
          Insert => repeat_char(btags, '+', lb)
          Equal => {
            repeat_char(atags, ' ', la)
            repeat_char(btags, ' ', lb)
          }
        }
      }
      qformat(out, aelt, belt, atags.to_string(), btags.to_string())
    } else {
      // the synch pair is identical
      out.push("  " + aelt)
    }
    dump_i = best_i + 1
    dump_j = best_j + 1
    best_i = -1
    best_j = -1
  }
  // pump out straight replace from after the last synch pair
  fancy_helper(out, a, dump_i, ahi, b, dump_j, bhi)
}

///|
fn repeat_char(buf : StringBuilder, c : Char, n : Int) -> Unit {
  for _ in 0..<n {
    buf.write_char(c)
  }
}

///|
fn fancy_helper(
  out : Array[String],
  a : Array[String],
  alo : Int,
  ahi : Int,
  b : Array[String],
  blo : Int,
  bhi : Int,
) -> Unit {
  if alo < ahi {
    if blo < bhi {
      plain_replace(out, a, alo, ahi, b, blo, bhi)
    } else {
      dump(out, "-", a, alo, ahi)
    }
  } else if blo < bhi {
    dump(out, "+", b, blo, bhi)
  }
}

///|
/// Replaces whitespace in the tag string with the original whitespace
/// characters of `s`, so that `?` guide lines stay aligned under tabs.
fn keep_original_ws(s : String, tag_s : String) -> String {
  let buf = StringBuilder()
  let tags = tag_s.to_array()
  for i, c in s.to_array() {
    if i >= tags.length() {
      break
    }
    let tag_c = tags[i]
    buf.write_char(if tag_c == ' ' && is_py_space(c) { c } else { tag_c })
  }
  buf.to_string()
}

///|
/// Formats the `?` output lines and deals with tabs.
fn qformat(
  out : Array[String],
  aline : String,
  bline : String,
  atags : String,
  btags : String,
) -> Unit {
  let atags = py_rstrip(keep_original_ws(aline, atags))
  let btags = py_rstrip(keep_original_ws(bline, btags))
  out.push("- " + aline)
  if atags != "" {
    out.push("? \{atags}\n")
  }
  out.push("+ " + bline)
  if btags != "" {
    out.push("? \{btags}\n")
  }
}

///|
/// Returns true for an ignorable line: one that is blank or contains a single
/// `'#'` (after stripping whitespace).
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@difflib.is_line_junk("\n"), content="true")
///   inspect(@difflib.is_line_junk("  #   \n"), content="true")
///   inspect(@difflib.is_line_junk("hello\n"), content="false")
/// }
/// ```
pub fn is_line_junk(line : String) -> Bool {
  let stripped = py_strip(line)
  stripped == "" || stripped == "#"
}

///|
/// Returns true for an ignorable character: a space or a tab.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@difflib.is_character_junk(' '), content="true")
///   inspect(@difflib.is_character_junk('\t'), content="true")
///   inspect(@difflib.is_character_junk('\n'), content="false")
///   inspect(@difflib.is_character_junk('x'), content="false")
/// }
/// ```
pub fn is_character_junk(ch : Char) -> Bool {
  ch == ' ' || ch == '\t'
}

///|
/// Compares `a` and `b` (lists of lines) and returns a [Differ]-style delta.
///
/// `charjunk` defaults to [is_character_junk]; `linejunk` defaults to none.
///
/// # Example
/// ```mbt check
/// test {
///   let diff = @difflib.ndiff(["one\n", "two\n", "three\n"], [
///     "ore\n", "tree\n", "emu\n",
///   ])
///   inspect(
///     diff.join(""),
///     content=(
///       #|- one
///       #|?  ^
///       #|+ ore
///       #|?  ^
///       #|- two
///       #|- three
///       #|?  -
///       #|+ tree
///       #|+ emu
///       #|
///     ),
///   )
/// }
/// ```
pub fn ndiff(
  a : Array[String],
  b : Array[String],
  linejunk? : (String) -> Bool,
  charjunk? : (Char) -> Bool = is_character_junk,
  autojunk? : Bool = true,
) -> Array[String] {
  Differ::new(linejunk?, charjunk~, autojunk~).compare(a, b)
}

///|
/// Errors raised for invalid arguments, mirroring Python's `ValueError`.
pub(all) suberror DiffError {
  ValueError(String)
} derive(Eq, Debug)

///|
/// Extracts one of the two sequences that generated an [ndiff] / [Differ]
/// delta: lines originating from sequence `which` (1 or 2), with the line
/// prefixes stripped.
///
/// Raises `ValueError` if `which` is not 1 or 2.
///
/// # Example
/// ```mbt check
/// test {
///   let diff = @difflib.ndiff(["one\n", "two\n", "three\n"], [
///     "ore\n", "tree\n", "emu\n",
///   ])
///   inspect(@difflib.restore(diff, 1).join(""), content="one\ntwo\nthree\n")
///   inspect(@difflib.restore(diff, 2).join(""), content="ore\ntree\nemu\n")
/// }
/// ```
pub fn restore(
  delta : Array[String],
  which : Int,
) -> Array[String] raise DiffError {
  let tag = match which {
    1 => "- "
    2 => "+ "
    _ => raise ValueError("unknown delta choice (must be 1 or 2): \{which}")
  }
  let out : Array[String] = []
  for line in delta {
    if line.has_prefix("  ") || line.has_prefix(tag) {
      out.push(line.unsafe_substring(start=2, end=line.length()))
    }
  }
  out
}

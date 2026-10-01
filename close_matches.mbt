///|
/// Uses [SequenceMatcher] to return a list of the best "good enough" matches
/// for `word` among `possibilities`.
///
/// - `n` (default 3): the maximum number of close matches to return; must be
///   positive.
/// - `cutoff` (default 0.6): a float in `[0, 1]`; possibilities that don't
///   score at least that similar to `word` are ignored.
/// - `autojunk`: the automatic junk heuristic of [SequenceMatcher].
///
/// The best (no more than `n`) matches are returned sorted by similarity
/// score, most similar first; ties are ordered like Python's
/// `heapq.nlargest` on `(score, string)` pairs.
///
/// Raises `ValueError` for an invalid `n` or `cutoff`.
///
/// # Example
/// ```mbt check
/// test {
///   debug_inspect(
///     @difflib.get_close_matches("appel", ["ape", "apple", "peach", "puppy"]),
///     content=(
///       #|["apple", "ape"]
///     ),
///   )
///   let keywords = [
///     "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
///     "continue", "def", "del", "elif", "else", "except", "finally", "for", "from",
///     "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass",
///     "raise", "return", "try", "while", "with", "yield",
///   ]
///   debug_inspect(
///     @difflib.get_close_matches("wheel", keywords),
///     content=(
///       #|["while"]
///     ),
///   )
///   debug_inspect(@difflib.get_close_matches("Apple", keywords), content="[]")
///   debug_inspect(
///     @difflib.get_close_matches("accept", keywords),
///     content=(
///       #|["except"]
///     ),
///   )
/// }
/// ```
pub fn get_close_matches(
  word : String,
  possibilities : Array[String],
  n? : Int = 3,
  cutoff? : Double = 0.6,
  autojunk? : Bool = true,
) -> Array[String] raise DiffError {
  if !(n > 0) {
    raise ValueError("n must be > 0: \{n}")
  }
  if !(0.0 <= cutoff && cutoff <= 1.0) {
    raise ValueError("cutoff must be in [0.0, 1.0]: \{py_float_repr(cutoff)}")
  }
  let result : Array[(Double, String)] = []
  let s : SequenceMatcher[Char] = SequenceMatcher::new(autojunk~)
  s.set_seq2(word.to_array())
  for x in possibilities {
    s.set_seq1(x.to_array())
    if s.real_quick_ratio() < cutoff || s.quick_ratio() < cutoff {
      continue
    }
    let ratio = s.ratio()
    if ratio >= cutoff {
      result.push((ratio, x))
    }
  }
  // Move the best scorers to head of list
  result.sort_by((p, q) => {
    let c = q.0.compare(p.0)
    if c != 0 {
      c
    } else {
      py_str_compare(q.1, p.1)
    }
  })
  // Strip scores for the best n matches
  result[:@cmp.minimum(n, result.length())].map(p => p.1)
}

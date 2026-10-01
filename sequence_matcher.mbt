///|
/// A matching block: `a[a:a+size] == b[b:b+size]`.
///
/// Mirrors Python's `difflib.Match` named tuple.
pub(all) struct Match {
  a : Int
  b : Int
  size : Int
} derive(Eq, Compare, Debug, ToJson)

///|
/// The kind of edit an [Opcode] describes.
pub(all) enum Tag {
  /// `a[i1:i2]` should be replaced by `b[j1:j2]`.
  Replace
  /// `a[i1:i2]` should be deleted (`j1 == j2`).
  Delete
  /// `b[j1:j2]` should be inserted at `a[i1:i1]` (`i1 == i2`).
  Insert
  /// `a[i1:i2] == b[j1:j2]`.
  Equal
} derive(Eq, Debug, ToJson)

///|
/// Returns the tag name used by Python (`"replace"`, `"delete"`, `"insert"`,
/// `"equal"`).
pub fn Tag::name(self : Tag) -> String {
  match self {
    Replace => "replace"
    Delete => "delete"
    Insert => "insert"
    Equal => "equal"
  }
}

///|
pub impl Show for Tag with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
/// A 5-tuple `(tag, i1, i2, j1, j2)` describing how to turn `a[i1:i2]` into
/// `b[j1:j2]`.
pub(all) struct Opcode {
  tag : Tag
  i1 : Int
  i2 : Int
  j1 : Int
  j2 : Int
} derive(Eq, Debug, ToJson)

///|
/// Compares pairs of sequences of any hashable element type.
///
/// This is a port of Python's `difflib.SequenceMatcher` (Ratcliff/Obershelp
/// "gestalt pattern matching" with junk handling and the "popular element"
/// autojunk heuristic). It finds the longest contiguous junk-free matching
/// subsequence and recurses on the pieces to its left and right.
///
/// Strings are compared character by character by converting them with
/// `String::to_array()`.
///
/// # Example
/// ```mbt check
/// test {
///   let s = @difflib.SequenceMatcher::new(
///     isjunk=c => c == ' ',
///     a="private Thread currentThread;".to_array(),
///     b="private volatile Thread currentThread;".to_array(),
///   )
///   inspect((s.ratio() * 100).round() / 100, content="0.87")
///   debug_inspect(
///     s.get_matching_blocks(),
///     content=(
///       #|[
///       #|  { a: 0, b: 0, size: 8 },
///       #|  { a: 8, b: 17, size: 21 },
///       #|  { a: 29, b: 38, size: 0 },
///       #|]
///     ),
///   )
/// }
/// ```
pub struct SequenceMatcher[T] {
  priv isjunk : ((T) -> Bool)?
  priv autojunk : Bool
  priv mut a : Array[T]
  priv mut b : Array[T]
  priv mut b2j : Map[T, Array[Int]]
  priv mut bjunk : Set[T]
  priv mut bpopular : Set[T]
  priv mut fullbcount : Map[T, Int]?
  priv mut matching_blocks : Array[Match]?
  priv mut opcodes : Array[Opcode]?
}

///|
/// Constructs a `SequenceMatcher`.
///
/// - `isjunk`: returns true iff an element of `b` is junk. Junk elements never
///   start a match, but may extend one.
/// - `a`, `b`: the sequences to compare (default empty).
/// - `autojunk`: enables the "popular element" heuristic: when `b` has at
///   least 200 elements, elements occurring more than `1% + 1` times are
///   treated as junk.
pub fn[T : Hash + Eq] SequenceMatcher::new(
  isjunk? : (T) -> Bool,
  a? : Array[T] = [],
  b? : Array[T] = [],
  autojunk? : Bool = true,
) -> SequenceMatcher[T] {
  let self : SequenceMatcher[T] = {
    isjunk,
    autojunk,
    a: [],
    b: [],
    b2j: {},
    bjunk: Set([]),
    bpopular: Set([]),
    fullbcount: None,
    matching_blocks: None,
    opcodes: None,
  }
  self.set_seq1(a)
  self.b = b
  self.chain_b()
  self
}

///|
/// Sets both sequences to be compared.
pub fn[T : Hash + Eq] SequenceMatcher::set_seqs(
  self : SequenceMatcher[T],
  a : Array[T],
  b : Array[T],
) -> Unit {
  self.set_seq1(a)
  self.set_seq2(b)
}

///|
/// Sets the first sequence to be compared; the second is unchanged.
///
/// Information about the second sequence is cached, so to compare one
/// sequence against many, use `set_seq2` once and `set_seq1` repeatedly.
pub fn[T] SequenceMatcher::set_seq1(
  self : SequenceMatcher[T],
  a : Array[T],
) -> Unit {
  if physical_equal(a, self.a) {
    return
  }
  self.a = a
  self.matching_blocks = None
  self.opcodes = None
}

///|
/// Sets the second sequence to be compared; the first is unchanged.
pub fn[T : Hash + Eq] SequenceMatcher::set_seq2(
  self : SequenceMatcher[T],
  b : Array[T],
) -> Unit {
  if physical_equal(b, self.b) {
    return
  }
  self.b = b
  self.matching_blocks = None
  self.opcodes = None
  self.fullbcount = None
  self.chain_b()
}

///|
/// Builds `b2j`, mapping each non-junk, non-popular element of `b` to the
/// increasing list of indices where it occurs.
fn[T : Hash + Eq] SequenceMatcher::chain_b(self : SequenceMatcher[T]) -> Unit {
  let b = self.b
  let b2j : Map[T, Array[Int]] = Map([])
  for i, elt in b {
    match b2j.get(elt) {
      Some(indices) => indices.push(i)
      None => b2j[elt] = [i]
    }
  }
  // Purge junk elements
  let junk : Set[T] = Set([])
  if self.isjunk is Some(isjunk) {
    for elt, _ in b2j {
      if isjunk(elt) {
        junk.add(elt)
      }
    }
    for elt in junk {
      b2j.remove(elt)
    }
  }
  // Purge popular elements that are not junk
  let popular : Set[T] = Set([])
  let n = b.length()
  if self.autojunk && n >= 200 {
    let ntest = n / 100 + 1
    for elt, idxs in b2j {
      if idxs.length() > ntest {
        popular.add(elt)
      }
    }
    for elt in popular {
      b2j.remove(elt)
    }
  }
  self.b2j = b2j
  self.bjunk = junk
  self.bpopular = popular
}

///|
/// The elements of `b` for which `isjunk` returned true.
pub fn[T] SequenceMatcher::bjunk(self : SequenceMatcher[T]) -> Array[T] {
  self.bjunk.to_array()
}

///|
/// The non-junk elements of `b` treated as junk by the autojunk heuristic.
pub fn[T] SequenceMatcher::bpopular(self : SequenceMatcher[T]) -> Array[T] {
  self.bpopular.to_array()
}

///|
/// Finds the longest matching block in `a[alo:ahi]` and `b[blo:bhi]`.
///
/// Without junk, returns `Match(i, j, k)` such that `a[i:i+k] == b[j:j+k]`
/// with `k` maximal; among maximal blocks the one starting earliest in `a`,
/// then earliest in `b`, is returned. With junk, the longest junk-free block
/// is found first and then extended by matching junk on both sides.
///
/// If no blocks match, returns `Match(alo, blo, 0)`.
///
/// # Example
/// ```mbt check
/// test {
///   let s = @difflib.SequenceMatcher::new(
///     a=" abcd".to_array(),
///     b="abcd abcd".to_array(),
///   )
///   debug_inspect(s.find_longest_match(), content="{ a: 0, b: 4, size: 5 }")
///   let s = @difflib.SequenceMatcher::new(
///     isjunk=c => c == ' ',
///     a=" abcd".to_array(),
///     b="abcd abcd".to_array(),
///   )
///   debug_inspect(s.find_longest_match(), content="{ a: 1, b: 0, size: 4 }")
/// }
/// ```
pub fn[T : Hash + Eq] SequenceMatcher::find_longest_match(
  self : SequenceMatcher[T],
  alo? : Int = 0,
  ahi? : Int,
  blo? : Int = 0,
  bhi? : Int,
) -> Match {
  let a = self.a
  let b = self.b
  let b2j = self.b2j
  let bjunk = self.bjunk
  let ahi = ahi.unwrap_or(a.length())
  let bhi = bhi.unwrap_or(b.length())
  let mut besti = alo
  let mut bestj = blo
  let mut bestsize = 0
  // find longest junk-free match
  // during an iteration of the loop, j2len[j] = length of longest
  // junk-free match ending with a[i-1] and b[j]
  let mut j2len : Map[Int, Int] = Map([])
  for i in alo..<ahi {
    let newj2len : Map[Int, Int] = Map([])
    if b2j.get(a[i]) is Some(indices) {
      for j in indices {
        // a[i] matches b[j]
        if j < blo {
          continue
        }
        if j >= bhi {
          break
        }
        let k = j2len.get(j - 1).unwrap_or(0) + 1
        newj2len[j] = k
        if k > bestsize {
          besti = i - k + 1
          bestj = j - k + 1
          bestsize = k
        }
      }
    }
    j2len = newj2len
  }
  // Extend the best by non-junk elements on each end.  In particular,
  // "popular" non-junk elements aren't in b2j, which greatly speeds
  // the inner loop above, but also means "the best" match so far
  // doesn't contain any junk *or* popular non-junk elements.
  while besti > alo &&
        bestj > blo &&
        !bjunk.contains(b[bestj - 1]) &&
        a[besti - 1] == b[bestj - 1] {
    besti -= 1
    bestj -= 1
    bestsize += 1
  }
  while besti + bestsize < ahi &&
        bestj + bestsize < bhi &&
        !bjunk.contains(b[bestj + bestsize]) &&
        a[besti + bestsize] == b[bestj + bestsize] {
    bestsize += 1
  }
  // Now that we have a wholly interesting match (albeit possibly
  // empty!), we may as well suck up the matching junk on each
  // side of it too.
  while besti > alo &&
        bestj > blo &&
        bjunk.contains(b[bestj - 1]) &&
        a[besti - 1] == b[bestj - 1] {
    besti -= 1
    bestj -= 1
    bestsize += 1
  }
  while besti + bestsize < ahi &&
        bestj + bestsize < bhi &&
        bjunk.contains(b[bestj + bestsize]) &&
        a[besti + bestsize] == b[bestj + bestsize] {
    bestsize += 1
  }
  { a: besti, b: bestj, size: bestsize, }
}

///|
/// Returns the list of matching blocks `(i, j, n)` with `a[i:i+n] == b[j:j+n]`,
/// monotonically increasing in `i` and `j`. Adjacent blocks are collapsed, and
/// the last block is always the dummy `(len(a), len(b), 0)`.
///
/// # Example
/// ```mbt check
/// test {
///   let s = @difflib.SequenceMatcher::new(
///     a="abxcd".to_array(),
///     b="abcd".to_array(),
///   )
///   debug_inspect(
///     s.get_matching_blocks(),
///     content=(
///       #|[
///       #|  { a: 0, b: 0, size: 2 },
///       #|  { a: 3, b: 2, size: 2 },
///       #|  { a: 5, b: 4, size: 0 },
///       #|]
///     ),
///   )
/// }
/// ```
pub fn[T : Hash + Eq] SequenceMatcher::get_matching_blocks(
  self : SequenceMatcher[T],
) -> Array[Match] {
  if self.matching_blocks is Some(blocks) {
    return blocks
  }
  let la = self.a.length()
  let lb = self.b.length()
  // An explicit work queue instead of recursion, as in Python.
  let queue = [(0, la, 0, lb)]
  let matching_blocks : Array[Match] = []
  while queue.pop() is Some((alo, ahi, blo, bhi)) {
    let x = self.find_longest_match(alo~, ahi~, blo~, bhi~)
    let { a: i, b: j, size: k, } = x
    // a[alo:i] vs b[blo:j] unknown
    // a[i:i+k] same as b[j:j+k]
    // a[i+k:ahi] vs b[j+k:bhi] unknown
    if k > 0 {
      matching_blocks.push(x)
      if alo < i && blo < j {
        queue.push((alo, i, blo, j))
      }
      if i + k < ahi && j + k < bhi {
        queue.push((i + k, ahi, j + k, bhi))
      }
    }
  }
  matching_blocks.sort()
  // Collapse adjacent equal blocks.
  let mut i1 = 0
  let mut j1 = 0
  let mut k1 = 0
  let non_adjacent : Array[Match] = []
  for blk in matching_blocks {
    let { a: i2, b: j2, size: k2, } = blk
    if i1 + k1 == i2 && j1 + k1 == j2 {
      k1 += k2
    } else {
      if k1 > 0 {
        non_adjacent.push({ a: i1, b: j1, size: k1, })
      }
      i1 = i2
      j1 = j2
      k1 = k2
    }
  }
  if k1 > 0 {
    non_adjacent.push({ a: i1, b: j1, size: k1, })
  }
  non_adjacent.push({ a: la, b: lb, size: 0, })
  self.matching_blocks = Some(non_adjacent)
  non_adjacent
}

///|
/// Returns the list of opcodes describing how to turn `a` into `b`.
///
/// The first opcode has `i1 == j1 == 0`, and each subsequent opcode starts
/// where the previous one ended.
///
/// # Example
/// ```mbt check
/// test {
///   let a = "qabxcd"
///   let b = "abycdf"
///   let s = @difflib.SequenceMatcher::new(a=a.to_array(), b=b.to_array())
///   let lines = s
///     .get_opcodes()
///     .map(op => "\{op.tag} a[\{op.i1}:\{op.i2}] b[\{op.j1}:\{op.j2}]")
///   inspect(
///     lines.join("\n"),
///     content=(
///       #|delete a[0:1] b[0:0]
///       #|equal a[1:3] b[0:2]
///       #|replace a[3:4] b[2:3]
///       #|equal a[4:6] b[3:5]
///       #|insert a[6:6] b[5:6]
///     ),
///   )
/// }
/// ```
pub fn[T : Hash + Eq] SequenceMatcher::get_opcodes(
  self : SequenceMatcher[T],
) -> Array[Opcode] {
  if self.opcodes is Some(opcodes) {
    return opcodes
  }
  let mut i = 0
  let mut j = 0
  let answer : Array[Opcode] = []
  for blk in self.get_matching_blocks() {
    let { a: ai, b: bj, size, } = blk
    // invariant: we've pumped out correct diffs to change a[:i] into b[:j],
    // and the next matching block is a[ai:ai+size] == b[bj:bj+size].
    let tag : Tag? = if i < ai && j < bj {
      Some(Replace)
    } else if i < ai {
      Some(Delete)
    } else if j < bj {
      Some(Insert)
    } else {
      None
    }
    if tag is Some(tag) {
      answer.push({ tag, i1: i, i2: ai, j1: j, j2: bj, })
    }
    i = ai + size
    j = bj + size
    // the list of matching blocks is terminated by a sentinel with size 0
    if size > 0 {
      answer.push({ tag: Equal, i1: ai, i2: i, j1: bj, j2: j, })
    }
  }
  self.opcodes = Some(answer)
  answer
}

///|
/// Isolates change clusters by eliminating ranges with no changes.
///
/// Returns groups of opcodes with up to `n` lines of context each.
///
/// Unlike Python, the cached result of `get_opcodes()` is not mutated.
pub fn[T : Hash + Eq] SequenceMatcher::get_grouped_opcodes(
  self : SequenceMatcher[T],
  n? : Int = 3,
) -> Array[Array[Opcode]] {
  // Any n >= max(len(a), len(b), 1) gives the same groups; clamping keeps
  // `n + n` and `i1 + n` from overflowing for huge context sizes.
  let n = @cmp.minimum(
    n,
    @cmp.maximum(@cmp.maximum(self.a.length(), self.b.length()), 1),
  )
  let codes = self.get_opcodes().copy()
  if codes.is_empty() {
    codes.push({ tag: Equal, i1: 0, i2: 1, j1: 0, j2: 1, })
  }
  // Fixup leading and trailing groups if they show no changes.
  if codes[0] is { tag: Equal, i1, i2, j1, j2, } {
    codes[0] = {
      tag: Equal,
      i1: @cmp.maximum(i1, i2 - n),
      i2,
      j1: @cmp.maximum(j1, j2 - n),
      j2,
    }
  }
  let last = codes.length() - 1
  if codes[last] is { tag: Equal, i1, i2, j1, j2, } {
    codes[last] = {
      tag: Equal,
      i1,
      i2: @cmp.minimum(i2, i1 + n),
      j1,
      j2: @cmp.minimum(j2, j1 + n),
    }
  }
  let nn = n + n
  let groups : Array[Array[Opcode]] = []
  let mut group : Array[Opcode] = []
  for code in codes {
    let { tag, i1, i2, j1, j2, } = code
    let mut i1 = i1
    let mut j1 = j1
    // End the current group and start a new one whenever
    // there is a large range with no changes.
    if tag is Equal && i2 - i1 > nn {
      group.push({
        tag,
        i1,
        i2: @cmp.minimum(i2, i1 + n),
        j1,
        j2: @cmp.minimum(j2, j1 + n),
      })
      groups.push(group)
      group = []
      i1 = @cmp.maximum(i1, i2 - n)
      j1 = @cmp.maximum(j1, j2 - n)
    }
    group.push({ tag, i1, i2, j1, j2, })
  }
  if !group.is_empty() && !(group.length() == 1 && group[0].tag is Equal) {
    groups.push(group)
  }
  groups
}

///|
fn calculate_ratio(matches : Int, length : Int) -> Double {
  if length != 0 {
    2.0 * matches.to_double() / length.to_double()
  } else {
    1.0
  }
}

///|
/// Returns a measure of the sequences' similarity as a float in `[0, 1]`.
///
/// Where `T` is the total number of elements in both sequences and `M` is the
/// number of matches, this is `2.0 * M / T`.
///
/// # Example
/// ```mbt check
/// test {
///   let s = @difflib.SequenceMatcher::new(
///     a="abcd".to_array(),
///     b="bcde".to_array(),
///   )
///   inspect(s.ratio(), content="0.75")
///   inspect(s.quick_ratio(), content="0.75")
///   inspect(s.real_quick_ratio(), content="1")
/// }
/// ```
pub fn[T : Hash + Eq] SequenceMatcher::ratio(
  self : SequenceMatcher[T],
) -> Double {
  let matches = self
    .get_matching_blocks()
    .fold(init=0, (acc, m) => acc + m.size)
  calculate_ratio(matches, self.a.length() + self.b.length())
}

///|
/// Returns an upper bound on `ratio()` relatively quickly, by treating both
/// sequences as multisets.
pub fn[T : Hash + Eq] SequenceMatcher::quick_ratio(
  self : SequenceMatcher[T],
) -> Double {
  let fullbcount = match self.fullbcount {
    Some(counts) => counts
    None => {
      let counts : Map[T, Int] = Map([])
      for elt in self.b {
        counts[elt] = counts.get(elt).unwrap_or(0) + 1
      }
      self.fullbcount = Some(counts)
      counts
    }
  }
  // avail[x] is the number of times x appears in 'b' less the
  // number of times we've seen it in 'a' so far
  let avail : Map[T, Int] = Map([])
  let mut matches = 0
  for elt in self.a {
    let numb = match avail.get(elt) {
      Some(numb) => numb
      None => fullbcount.get(elt).unwrap_or(0)
    }
    avail[elt] = numb - 1
    if numb > 0 {
      matches += 1
    }
  }
  calculate_ratio(matches, self.a.length() + self.b.length())
}

///|
/// Returns an upper bound on `ratio()` very quickly, using only the lengths.
pub fn[T] SequenceMatcher::real_quick_ratio(
  self : SequenceMatcher[T],
) -> Double {
  let la = self.a.length()
  let lb = self.b.length()
  calculate_ratio(@cmp.minimum(la, lb), la + lb)
}

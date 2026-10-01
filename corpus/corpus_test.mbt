// Differential tests against a corpus generated from the pinned CPython
// difflib (see tools/gen_corpus.py).

///|
fn field(case_ : Json, key : String) -> Json {
  guard case_ is Object(obj) && obj.get(key) is Some(v) else {
    abort("missing field \{key}")
  }
  v
}

///|
fn str_field(case_ : Json, key : String) -> String {
  guard field(case_, key) is String(s) else { abort("not a string: \{key}") }
  s
}

///|
fn int_of(j : Json) -> Int {
  guard j is Number(n, ..) else { abort("not a number") }
  n.to_int()
}

///|
fn int_field(case_ : Json, key : String) -> Int {
  int_of(field(case_, key))
}

///|
fn num_field(case_ : Json, key : String) -> Double {
  guard field(case_, key) is Number(n, ..) else {
    abort("not a number: \{key}")
  }
  n
}

///|
fn bool_field(case_ : Json, key : String) -> Bool {
  match field(case_, key) {
    True => true
    False => false
    _ => abort("not a bool: \{key}")
  }
}

///|
fn strings_of(j : Json) -> Array[String] {
  guard j is Array(items) else { abort("not an array") }
  items.map(item => {
    guard item is String(s) else { abort("not a string item") }
    s
  })
}

///|
fn strings_field(case_ : Json, key : String) -> Array[String] {
  strings_of(field(case_, key))
}

///|
fn opcodes_of(j : Json) -> Array[String] {
  guard j is Array(items) else { abort("not an array") }
  items.map(item => {
    guard item is Array([String(tag), i1, i2, j1, j2]) else {
      abort("bad opcode")
    }
    "\{tag} \{int_of(i1)} \{int_of(i2)} \{int_of(j1)} \{int_of(j2)}"
  })
}

///|
fn show_opcodes(ops : Array[@difflib.Opcode]) -> Array[String] {
  ops.map(op => "\{op.tag} \{op.i1} \{op.i2} \{op.j1} \{op.j2}")
}

///|
fn char_junk(name : String) -> ((Char) -> Bool)? {
  match name {
    "none" => None
    "space" => Some(c => c == ' ')
    "space_tab" => Some(c => c == ' ' || c == '\t')
    "vowel" => Some(c => c is ('a' | 'e' | 'i' | 'o' | 'u'))
    "default" => Some(@difflib.is_character_junk)
    _ => abort("unknown junk \{name}")
  }
}

///|
fn check_matcher(case_ : Json) -> Unit raise {
  let a = str_field(case_, "a").to_array()
  let b = str_field(case_, "b").to_array()
  let isjunk = char_junk(str_field(case_, "junk"))
  let autojunk = bool_field(case_, "autojunk")
  let s = @difflib.SequenceMatcher::new(isjunk?, a~, b~, autojunk~)
  if field(case_, "lm_args") is Array([alo, ahi, blo, bhi]) {
    let m = s.find_longest_match(
      alo=int_of(alo),
      ahi=int_of(ahi),
      blo=int_of(blo),
      bhi=int_of(bhi),
    )
    guard field(case_, "lm") is Array([ea, eb, esize]) else { fail("bad lm") }
    assert_eq((m.a, m.b, m.size), (int_of(ea), int_of(eb), int_of(esize)))
  }
  guard field(case_, "blocks") is Array(blocks) else { fail("bad blocks") }
  let expected_blocks = blocks.map(blk => {
    guard blk is Array([i, j, k]) else { abort("bad block") }
    (int_of(i), int_of(j), int_of(k))
  })
  assert_eq(
    s.get_matching_blocks().map(m => (m.a, m.b, m.size)),
    expected_blocks,
  )
  assert_eq(show_opcodes(s.get_opcodes()), opcodes_of(field(case_, "opcodes")))
  guard field(case_, "grouped") is Array(groups) else { fail("bad grouped") }
  let fresh = @difflib.SequenceMatcher::new(isjunk?, a~, b~, autojunk~)
  assert_eq(
    fresh
    .get_grouped_opcodes(n=int_field(case_, "n"))
    .map(g => show_opcodes(g))
    .to_array(),
    groups.map(opcodes_of),
  )
  assert_eq(s.ratio(), num_field(case_, "ratio"))
  assert_eq(s.quick_ratio(), num_field(case_, "quick_ratio"))
  assert_eq(s.real_quick_ratio(), num_field(case_, "real_quick_ratio"))
  let sorted_chars = (xs : Array[Char]) => {
    let xs = xs.copy()
    xs.sort()
    xs.map(c => c.to_string())
  }
  assert_eq(sorted_chars(s.bjunk()), strings_field(case_, "bjunk"))
  assert_eq(sorted_chars(s.bpopular()), strings_field(case_, "bpopular"))
}

///|
fn check_lines(case_ : Json) -> Unit raise {
  let a = strings_field(case_, "a")
  let b = strings_field(case_, "b")
  let autojunk = bool_field(case_, "autojunk")
  let linejunk : ((String) -> Bool)? = match str_field(case_, "linejunk") {
    "is_line_junk" => Some(@difflib.is_line_junk)
    _ => None
  }
  let charjunk = char_junk(str_field(case_, "charjunk")).unwrap_or(_ => false)
  let nd = @difflib.ndiff(a, b, linejunk?, charjunk~, autojunk~).to_array()
  assert_eq(nd, strings_field(case_, "ndiff"))
  assert_eq(
    @difflib.Differ::new(autojunk~).compare(a, b).to_array(),
    strings_field(case_, "differ_plain"),
  )
  assert_eq(
    @difflib.restore(nd.iter(), 1).to_array(),
    strings_field(case_, "restore1"),
  )
  assert_eq(
    @difflib.restore(nd.iter(), 2).to_array(),
    strings_field(case_, "restore2"),
  )
  let n = int_field(case_, "n")
  let lineterm = str_field(case_, "lineterm")
  let fromfile = str_field(case_, "fromfile")
  let tofile = str_field(case_, "tofile")
  let fromfiledate = str_field(case_, "fromdate")
  let tofiledate = str_field(case_, "todate")
  assert_eq(
    @difflib.unified_diff(
      a,
      b,
      fromfile~,
      tofile~,
      fromfiledate~,
      tofiledate~,
      n~,
      lineterm~,
      autojunk~,
      color=bool_field(case_, "color"),
    ).to_array(),
    strings_field(case_, "unified"),
  )
  assert_eq(
    @difflib.context_diff(
      a,
      b,
      fromfile~,
      tofile~,
      fromfiledate~,
      tofiledate~,
      n~,
      lineterm~,
      autojunk~,
    ).to_array(),
    strings_field(case_, "context"),
  )
}

///|
fn check_html(case_ : Json) -> Unit raise {
  let a = strings_field(case_, "a")
  let b = strings_field(case_, "b")
  let wrapcolumn = match field(case_, "wrapcolumn") {
    Null => None
    j => Some(int_of(j))
  }
  let charjunk = char_junk(str_field(case_, "charjunk")).unwrap_or(_ => false)
  let linejunk : ((String) -> Bool)? = match str_field(case_, "linejunk") {
    "is_line_junk" => Some(@difflib.is_line_junk)
    _ => None
  }
  let h = @difflib.HtmlDiff::new(
    tabsize=int_field(case_, "tabsize"),
    wrapcolumn?,
    linejunk?,
    charjunk~,
    autojunk=bool_field(case_, "autojunk"),
  )
  let fromdesc = str_field(case_, "fromdesc")
  let todesc = str_field(case_, "todesc")
  let context = bool_field(case_, "context")
  let numlines = int_field(case_, "numlines")
  @difflib.HtmlDiff::reset_prefix_counter()
  assert_eq(
    h.make_table(a, b, fromdesc~, todesc~, context~, numlines~),
    str_field(case_, "table"),
  )
  if field(case_, "file") is String(expected) {
    @difflib.HtmlDiff::reset_prefix_counter()
    assert_eq(
      h.make_file(
        a,
        b,
        fromdesc~,
        todesc~,
        context~,
        numlines~,
        charset=str_field(case_, "charset"),
      ),
      expected,
    )
  }
}

///|
fn check_close(case_ : Json) -> Unit raise {
  assert_eq(
    @difflib.get_close_matches(
      str_field(case_, "word"),
      strings_field(case_, "possibilities"),
      n=int_field(case_, "n"),
      cutoff=num_field(case_, "cutoff"),
      autojunk=bool_field(case_, "autojunk"),
    ),
    strings_field(case_, "result"),
  )
}

///|
fn check_stateful(case_ : Json) -> Unit raise {
  let isjunk = char_junk(str_field(case_, "junk"))
  let s = @difflib.SequenceMatcher::new(
    isjunk?,
    a=str_field(case_, "a").to_array(),
    b=str_field(case_, "b").to_array(),
    autojunk=bool_field(case_, "autojunk"),
  )
  guard field(case_, "ops") is Array(ops) else { fail("bad ops") }
  for op in ops {
    guard op is Array([String(name), arg, expected]) else { fail("bad op") }
    match (name, arg) {
      ("set_seq1", String(x)) => s.set_seq1(x.to_array())
      ("set_seq2", String(x)) => s.set_seq2(x.to_array())
      ("set_seqs", Array([String(x), String(y)])) =>
        s.set_seqs(x.to_array(), y.to_array())
      ("ratio", _) => assert_eq(Json::number(s.ratio()), expected)
      ("quick_ratio", _) => assert_eq(Json::number(s.quick_ratio()), expected)
      ("real_quick_ratio", _) =>
        assert_eq(Json::number(s.real_quick_ratio()), expected)
      ("opcodes", _) =>
        assert_eq(show_opcodes(s.get_opcodes()), opcodes_of(expected))
      ("blocks", _) => {
        guard expected is Array(blocks) else { fail("bad blocks") }
        assert_eq(
          s.get_matching_blocks().map(m => [m.a, m.b, m.size]),
          blocks.map(blk => {
            guard blk is Array(xs) else { abort("bad block") }
            xs.map(int_of)
          }),
        )
      }
      ("grouped", n) => {
        guard expected is Array(groups) else { fail("bad grouped") }
        // Python mutates its cached opcodes here; compare a fresh matcher's
        // groups too, so both code paths are exercised.
        assert_eq(
          s
          .get_grouped_opcodes(n=int_of(n))
          .map(g => show_opcodes(g))
          .to_array(),
          groups.map(opcodes_of),
        )
      }
      ("bjunk", _) =>
        assert_eq(sorted_strings(s.bjunk()), sorted_json_strings(expected))
      ("bpopular", _) =>
        assert_eq(sorted_strings(s.bpopular()), sorted_json_strings(expected))
      ("lm", Array([alo, ahi, blo, bhi])) => {
        let m = s.find_longest_match(
          alo=int_of(alo),
          ahi=int_of(ahi),
          blo=int_of(blo),
          bhi=int_of(bhi),
        )
        guard expected is Array([ea, eb, esize]) else { fail("bad lm") }
        assert_eq((m.a, m.b, m.size), (int_of(ea), int_of(eb), int_of(esize)))
      }
      _ => fail("unknown op \{name}")
    }
  }
}

///|
fn[T : Show] sorted_strings(xs : Array[T]) -> Array[String] {
  let out = xs.map(x => x.to_string())
  out.sort()
  out
}

///|
fn sorted_json_strings(j : Json) -> Array[String] {
  let out = strings_of(j)
  out.sort()
  out
}

///|
fn check_items(case_ : Json) -> Unit raise {
  let isjunk : ((String) -> Bool)? = match str_field(case_, "junk") {
    "is_line_junk" => Some(@difflib.is_line_junk)
    _ => None
  }
  let s = @difflib.SequenceMatcher::new(
    isjunk?,
    a=strings_field(case_, "a"),
    b=strings_field(case_, "b"),
    autojunk=bool_field(case_, "autojunk"),
  )
  assert_eq(show_opcodes(s.get_opcodes()), opcodes_of(field(case_, "opcodes")))
  assert_eq(s.ratio(), num_field(case_, "ratio"))
  assert_eq(s.quick_ratio(), num_field(case_, "quick_ratio"))
  assert_eq(
    sorted_strings(s.bjunk()),
    sorted_json_strings(field(case_, "bjunk")),
  )
  assert_eq(
    sorted_strings(s.bpopular()),
    sorted_json_strings(field(case_, "bpopular")),
  )
}

///|
fn hex_to_bytes(hex : String) -> Bytes {
  let digit = (c : UInt16) => {
    let c = c.to_int()
    if c >= '0'.to_int() && c <= '9'.to_int() {
      c - '0'.to_int()
    } else {
      c - 'a'.to_int() + 10
    }
  }
  Bytes::makei(hex.length() / 2, i => {
    (digit(hex[2 * i]) * 16 + digit(hex[2 * i + 1])).to_byte()
  })
}

///|
fn check_bytes(case_ : Json) -> Unit raise {
  let hex_lines = (key : String) => strings_field(case_, key).map(hex_to_bytes)
  let format : @difflib.DiffFormat = match str_field(case_, "format") {
    "unified" => Unified
    _ => Context
  }
  assert_eq(
    @difflib.diff_bytes(
      format,
      hex_lines("a"),
      hex_lines("b"),
      fromfile=hex_to_bytes(str_field(case_, "fromfile")),
      tofile=hex_to_bytes(str_field(case_, "tofile")),
      fromfiledate=hex_to_bytes(str_field(case_, "fromfiledate")),
      tofiledate=hex_to_bytes(str_field(case_, "tofiledate")),
      n=int_field(case_, "n"),
      lineterm=hex_to_bytes(str_field(case_, "lineterm")),
    ).to_array(),
    hex_lines("result"),
  )
}

///|
fn check_close_error(case_ : Json) -> Unit raise {
  let cutoff = match field(case_, "cutoff") {
    String("nan") => 0.0 / 0.0
    String("inf") => 1.0 / 0.0
    String("-inf") => -1.0 / 0.0
    Number(x, ..) => x
    _ => fail("bad cutoff")
  }
  let actual : String? = try
    @difflib.get_close_matches("x", ["x"], n=int_field(case_, "n"), cutoff~)
  catch {
    ValueError(msg) => Some(msg)
  } noraise {
    _ => None
  }
  let expected = match field(case_, "error") {
    String(msg) => Some(msg)
    _ => None
  }
  assert_eq(actual, expected)
}

///|
/// Builds a string from code points, allowing lone surrogates (which
/// MoonBit's JSON parser rejects in escapes).
fn from_codes(j : Json) -> String {
  guard j is Array(codes) else { abort("not a code point list") }
  let sb = StringBuilder()
  for c in codes {
    sb.write_char(int_of(c).unsafe_to_char())
  }
  sb.to_string()
}

///|
fn codes_list(j : Json) -> Array[String] {
  guard j is Array(items) else { abort("not a list") }
  items.map(from_codes)
}

///|
fn check_surrogate(case_ : Json) -> Unit raise {
  let sa = from_codes(field(case_, "sa"))
  let sb = from_codes(field(case_, "sb"))
  let m = @difflib.SequenceMatcher::new(a=sa.to_array(), b=sb.to_array())
  assert_eq(show_opcodes(m.get_opcodes()), opcodes_of(field(case_, "opcodes")))
  assert_eq(m.ratio(), num_field(case_, "ratio"))
  let a = codes_list(field(case_, "a"))
  let b = codes_list(field(case_, "b"))
  assert_eq(@difflib.ndiff(a, b).to_array(), codes_list(field(case_, "ndiff")))
  assert_eq(
    @difflib.unified_diff(a, b, n=1).to_array(),
    codes_list(field(case_, "unified")),
  )
  guard field(case_, "is_line_junk") is Array(junk) else { fail("bad junk") }
  assert_eq(a.map(@difflib.is_line_junk).map(Json::boolean), junk)
  let wrapcolumn = match field(case_, "wrap") {
    Null => None
    j => Some(int_of(j))
  }
  @difflib.HtmlDiff::reset_prefix_counter()
  assert_eq(
    @difflib.HtmlDiff::new(wrapcolumn?).make_table(a, b),
    from_codes(field(case_, "table")),
  )
  @difflib.HtmlDiff::reset_prefix_counter()
  assert_eq(
    @difflib.HtmlDiff::new().make_file(
      a,
      b,
      charset=str_field(case_, "charset"),
    ),
    from_codes(field(case_, "file")),
  )
}

///|
test "differential corpus from CPython difflib" {
  let counts : Map[String, Int] = Map([])
  for line in corpus.split("\n") {
    let case_ = @json.parse(line)
    let kind = str_field(case_, "kind")
    counts[kind] = counts.get(kind).unwrap_or(0) + 1
    try {
      match kind {
        "matcher" => check_matcher(case_)
        "lines" => check_lines(case_)
        "html" => check_html(case_)
        "close" => check_close(case_)
        "stateful" => check_stateful(case_)
        "items" => check_items(case_)
        "bytes" => check_bytes(case_)
        "close_error" => check_close_error(case_)
        "surrogate" => check_surrogate(case_)
        "line_junk" =>
          assert_eq(
            @difflib.is_line_junk(str_field(case_, "s")),
            bool_field(case_, "result"),
          )
        _ => fail("unknown kind \{kind}")
      }
    } catch {
      err => fail("case \{line}\nfailed: \{err}")
    }
  }
  debug_inspect(
    counts,
    content=(
      #|{
      #|  "matcher": 400,
      #|  "lines": 256,
      #|  "html": 80,
      #|  "close": 120,
      #|  "line_junk": 150,
      #|  "stateful": 150,
      #|  "items": 100,
      #|  "bytes": 120,
      #|  "close_error": 40,
      #|  "surrogate": 40,
      #|}
    ),
  )
}

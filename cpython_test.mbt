// Ports of CPython Lib/test/test_difflib.py test cases.

///|
fn chars(s : String) -> Array[Char] {
  s.to_array()
}

///|
fn opcodes_text(ops : Array[@difflib.Opcode]) -> String {
  ops.map(op => "\{op.tag} \{op.i1} \{op.i2} \{op.j1} \{op.j2}").join("\n")
}

///|
fn approx_eq(x : Double, y : Double, places : Int) -> Bool {
  let mut scale = 1.0
  for _ in 0..<places {
    scale *= 10.0
  }
  ((x - y) * scale).round() == 0.0
}

///|
test "TestWithAscii.test_one_insert" {
  let sm = @difflib.SequenceMatcher::new(
    a=chars("b".repeat(100)),
    b=chars("a" + "b".repeat(100)),
  )
  assert_true(approx_eq(sm.ratio(), 0.995, 3))
  inspect(
    opcodes_text(sm.get_opcodes()),
    content=(
      #|insert 0 0 0 1
      #|equal 0 100 1 101
    ),
  )
  assert_true(sm.bpopular().is_empty())
  let sm = @difflib.SequenceMatcher::new(
    a=chars("b".repeat(100)),
    b=chars("b".repeat(50) + "a" + "b".repeat(50)),
  )
  assert_true(approx_eq(sm.ratio(), 0.995, 3))
  inspect(
    opcodes_text(sm.get_opcodes()),
    content=(
      #|equal 0 50 0 50
      #|insert 50 50 50 51
      #|equal 50 100 51 101
    ),
  )
  assert_true(sm.bpopular().is_empty())
}

///|
test "TestWithAscii.test_one_delete" {
  let sm = @difflib.SequenceMatcher::new(
    a=chars("a".repeat(40) + "c" + "b".repeat(40)),
    b=chars("a".repeat(40) + "b".repeat(40)),
  )
  assert_true(approx_eq(sm.ratio(), 0.994, 3))
  inspect(
    opcodes_text(sm.get_opcodes()),
    content=(
      #|equal 0 40 0 40
      #|delete 40 41 40 40
      #|equal 41 81 40 80
    ),
  )
}

///|
test "TestWithAscii.test_opcode_caching" {
  let sm = @difflib.SequenceMatcher::new(
    a=chars("b".repeat(100)),
    b=chars("a" + "b".repeat(100)),
  )
  let opcode = sm.get_opcodes()
  inspect(
    opcodes_text(opcode),
    content=(
      #|insert 0 0 0 1
      #|equal 0 100 1 101
    ),
  )
  // Implementation detail: opcodes are cached
  assert_true(physical_equal(opcode, sm.get_opcodes()))
}

///|
test "TestWithAscii.test_bjunk" {
  let sm = @difflib.SequenceMatcher::new(
    isjunk=x => x == ' ',
    a=chars("a".repeat(40) + "b".repeat(40)),
    b=chars("a".repeat(44) + "b".repeat(40)),
  )
  debug_inspect(sm.bjunk(), content="[]")
  let sm = @difflib.SequenceMatcher::new(
    isjunk=x => x == ' ',
    a=chars("a".repeat(40) + "b".repeat(40)),
    b=chars("a".repeat(44) + "b".repeat(40) + " ".repeat(20)),
  )
  debug_inspect(sm.bjunk(), content="[' ']")
  let sm = @difflib.SequenceMatcher::new(
    isjunk=x => x == ' ' || x == 'b',
    a=chars("a".repeat(40) + "b".repeat(40)),
    b=chars("a".repeat(44) + "b".repeat(40) + " ".repeat(20)),
  )
  let junk = sm.bjunk()
  junk.sort()
  debug_inspect(junk, content="[' ', 'b']")
}

///|
test "TestAutojunk.test_one_insert_homogenous_sequence" {
  // By default autojunk=true and the heuristic kicks in for a sequence
  // of length 200+
  let seq1 = chars("b".repeat(200))
  let seq2 = chars("a" + "b".repeat(200))
  let sm = @difflib.SequenceMatcher::new(a=seq1, b=seq2)
  assert_true(approx_eq(sm.ratio(), 0.0, 3))
  debug_inspect(sm.bpopular(), content="['b']")
  // Now turn the heuristic off
  let sm = @difflib.SequenceMatcher::new(a=seq1, b=seq2, autojunk=false)
  assert_true(approx_eq(sm.ratio(), 0.9975, 3))
  debug_inspect(sm.bpopular(), content="[]")
}

///|
test "TestAutojunk.test_get_close_matches" {
  let word = "a" + "b".repeat(200)
  let possibilities = ["b".repeat(200)]
  // By default autojunk=true, so 'b' is junk -> ratio ~ 0 -> no matches
  debug_inspect(
    @difflib.get_close_matches(word, possibilities, cutoff=0.6),
    content="[]",
  )
  debug_inspect(
    @difflib.get_close_matches(word, possibilities, cutoff=0.6, autojunk=true),
    content="[]",
  )
  // With autojunk=false, ratio ~ 0.9975 -> match returned
  assert_eq(
    @difflib.get_close_matches(word, possibilities, cutoff=0.6, autojunk=false),
    possibilities,
  )
}

///|
test "TestAutojunk.test_differ_and_ndiff" {
  let lines1 = Array::make(200, "x\n") +
    ["a\n", "b\n", "c\n"] +
    Array::make(50, "x\n")
  let lines2 = ["a\n", "b\n", "c\n"] + Array::make(250, "x\n")
  // Line-level autojunk propagation
  let res_true = @difflib.Differ::new(autojunk=true).compare(lines1, lines2)
  let res_false = @difflib.Differ::new(autojunk=false).compare(lines1, lines2)
  assert_not_eq(res_true, res_false)
  let ndiff_true = @difflib.ndiff(lines1, lines2, autojunk=true)
  let ndiff_false = @difflib.ndiff(lines1, lines2, autojunk=false)
  assert_not_eq(ndiff_true, ndiff_false)
  assert_eq(ndiff_true, res_true)
  assert_eq(ndiff_false, res_false)
  // Character-level autojunk propagation in Differ (fancy_replace)
  let line1 = "x".repeat(200) + "abc" + "x".repeat(50) + "\n"
  let line2 = "abc" + "x".repeat(250) + "\n"
  let fancy_true = @difflib.Differ::new(autojunk=true).compare([line1], [line2])
  let fancy_false = @difflib.Differ::new(autojunk=false).compare([line1], [
    line2,
  ])
  assert_not_eq(fancy_true, fancy_false)
}

///|
test "TestAutojunk.test_unified_and_context_diff" {
  let lines1 = Array::make(200, "x\n") +
    ["a\n", "b\n", "c\n"] +
    Array::make(50, "x\n")
  let lines2 = ["a\n", "b\n", "c\n"] + Array::make(250, "x\n")
  assert_not_eq(
    @difflib.unified_diff(lines1, lines2, autojunk=true),
    @difflib.unified_diff(lines1, lines2, autojunk=false),
  )
  assert_not_eq(
    @difflib.context_diff(lines1, lines2, autojunk=true),
    @difflib.context_diff(lines1, lines2, autojunk=false),
  )
}

///|
test "TestAutojunk.test_htmldiff" {
  let lines1 = Array::make(200, "x\n") +
    ["a\n", "b\n", "c\n"] +
    Array::make(50, "x\n")
  let lines2 = ["a\n", "b\n", "c\n"] + Array::make(250, "x\n")
  @difflib.HtmlDiff::reset_prefix_counter()
  let html_true = @difflib.HtmlDiff::new(autojunk=true).make_file(
    lines1, lines2,
  )
  @difflib.HtmlDiff::reset_prefix_counter()
  let html_false = @difflib.HtmlDiff::new(autojunk=false).make_file(
    lines1, lines2,
  )
  assert_not_eq(html_true, html_false)
}

///|
test "TestSFbugs.test_ratio_for_null_seqn" {
  // Check clearing of SF bug 763023
  let s : @difflib.SequenceMatcher[Int] = @difflib.SequenceMatcher::new(a=[], b=[])
  inspect(s.ratio(), content="1")
  inspect(s.quick_ratio(), content="1")
  inspect(s.real_quick_ratio(), content="1")
}

///|
test "TestSFbugs.test_comparing_empty_lists" {
  // Check fix for bug #979794
  let s : @difflib.SequenceMatcher[String] = @difflib.SequenceMatcher::new(
    a=[],
    b=[],
  )
  assert_true(s.get_grouped_opcodes().is_empty())
  assert_true(@difflib.unified_diff([], []).is_empty())
}

///|
test "TestSFbugs.test_matching_blocks_cache" {
  // Issue #21635
  let s = @difflib.SequenceMatcher::new(a=chars("abxcd"), b=chars("abcd"))
  let _ = s.get_matching_blocks()
  let second = s.get_matching_blocks()
  assert_eq(second[0].size, 2)
  assert_eq(second[1].size, 2)
  assert_eq(second[2].size, 0)
}

///|
test "TestSFbugs.test_added_tab_hint" {
  // Check fix for bug #1488943
  let diff = @difflib.Differ::new().compare(["\tI am a buggy"], [
    "\t\tI am a bug",
  ])
  assert_eq(diff[0], "- \tI am a buggy")
  assert_eq(diff[1], "? \t          --\n")
  assert_eq(diff[2], "+ \t\tI am a bug")
  assert_eq(diff[3], "? +\n")
}

///|
test "TestSFbugs.test_hint_indented_properly_with_tabs" {
  let diff = @difflib.Differ::new().compare(["\t \t \t^"], ["\t \t \t^\n"])
  assert_eq(diff[0], "- \t \t \t^")
  assert_eq(diff[1], "+ \t \t \t^\n")
  assert_eq(diff[2], "? \t \t \t +\n")
}

///|
test "TestSFpatches.test_recursion_limit" {
  // Check if the problem described in patch #1413711 exists.
  let limit = 1000
  let old = Array::makei(limit * 2, i => {
    if i % 2 == 1 {
      "K:\{i}"
    } else {
      "V:A:\{i}"
    }
  })
  let new = Array::makei(limit * 2, i => {
    if i % 2 == 1 {
      "K:\{i}"
    } else {
      "V:B:\{i}"
    }
  })
  let ops = @difflib.SequenceMatcher::new(a=old, b=new).get_opcodes()
  assert_eq(ops.length(), limit * 2)
}

///|
test "TestSFpatches.test_make_file_default_charset" {
  let output = @difflib.HtmlDiff::new().make_file(patch_from1, patch_to1)
  assert_true(output.contains("charset=\"utf-8\""))
}

///|
test "TestSFpatches.test_make_file_iso88591_charset" {
  let output = @difflib.HtmlDiff::new().make_file(
    patch_from1,
    patch_to1,
    charset="iso-8859-1",
  )
  assert_true(output.contains("charset=\"iso-8859-1\""))
}

///|
test "TestSFpatches.test_make_file_usascii_charset_with_nonascii_input" {
  let output = @difflib.HtmlDiff::new().make_file(
    patch_nonascii_from1,
    patch_nonascii_to1,
    charset="us-ascii",
  )
  assert_true(output.contains("charset=\"us-ascii\""))
  assert_true(output.contains("&#305;mpl&#305;c&#305;t"))
}

///|
test "TestSFpatches.test_strip_trailing_newlines_before_diff" {
  // characterization test for the current buggy behavior
  // see: gh-71896
  let from_lines = [
    "Line 1: no newline after", "Line 2: one newline after\n", "Line 3: several newlines after\n\n\n\n\n",
  ]
  let to_lines = [
    "Line 1: no newline after", "Line 2: one newline after", "Line 3: several newlines after",
  ]
  let output = @difflib.HtmlDiff::new().make_table(from_lines, to_lines)
  // we (currently) expect no line change, so all equal
  assert_false(output.contains("class=\"diff_add\""))
  assert_false(output.contains("class=\"diff_chg\""))
  assert_false(output.contains("class=\"diff_sub\""))
  let count = (needle : String) => output.split(needle).count() - 1
  assert_eq(count(">Line&nbsp;1:&nbsp;no&nbsp;newline&nbsp;after<"), 2)
  assert_eq(count(">Line&nbsp;2:&nbsp;one&nbsp;newline&nbsp;after<"), 2)
  assert_eq(count(">Line&nbsp;3:&nbsp;several&nbsp;newlines&nbsp;after<"), 2)
}

///|
test "TestDiffer.test_close_matches_aligned" {
  // Of the 4 closely matching pairs, we want 1 to match with 3,
  // and 2 with 4, to align with a "top to bottom" mental model.
  let a = ["cat\n", "dog\n", "close match 1\n", "close match 2\n"]
  let b = ["close match 3\n", "close match 4\n", "kitten\n", "puppy\n"]
  debug_inspect(
    @difflib.Differ::new().compare(a, b),
    content=(
      #|[
      #|  "- cat\n",
      #|  "- dog\n",
      #|  "- close match 1\n",
      #|  "?             ^\n",
      #|  "+ close match 3\n",
      #|  "?             ^\n",
      #|  "- close match 2\n",
      #|  "?             ^\n",
      #|  "+ close match 4\n",
      #|  "?             ^\n",
      #|  "+ kitten\n",
      #|  "+ puppy\n",
      #|]
    ),
  )
}

///|
test "TestDiffer.test_one_insert" {
  debug_inspect(
    @difflib.Differ::new().compare(["b", "b"], ["a", "b", "b"]),
    content=(
      #|["+ a", "  b", "  b"]
    ),
  )
}

///|
test "TestDiffer.test_one_delete" {
  debug_inspect(
    @difflib.Differ::new().compare(["a", "b", "b"], ["b", "b"]),
    content=(
      #|["- a", "  b", "  b"]
    ),
  )
}

///|
test "TestOutputFormat.test_tab_delimiter" {
  let ud = @difflib.unified_diff(
    ["one"],
    ["two"],
    fromfile="Original",
    tofile="Current",
    fromfiledate="2005-01-26 23:30:50",
    tofiledate="2010-04-02 10:20:52",
    lineterm="",
  )
  assert_eq(ud[0:2].to_owned(), [
    "--- Original\t2005-01-26 23:30:50", "+++ Current\t2010-04-02 10:20:52",
  ])
  let cd = @difflib.context_diff(
    ["one"],
    ["two"],
    fromfile="Original",
    tofile="Current",
    fromfiledate="2005-01-26 23:30:50",
    tofiledate="2010-04-02 10:20:52",
    lineterm="",
  )
  assert_eq(cd[0:2].to_owned(), [
    "*** Original\t2005-01-26 23:30:50", "--- Current\t2010-04-02 10:20:52",
  ])
}

///|
test "TestOutputFormat.test_no_trailing_tab_on_empty_filedate" {
  let ud = @difflib.unified_diff(
    ["one"],
    ["two"],
    fromfile="Original",
    tofile="Current",
    lineterm="",
  )
  assert_eq(ud[0:2].to_owned(), ["--- Original", "+++ Current"])
  let cd = @difflib.context_diff(
    ["one"],
    ["two"],
    fromfile="Original",
    tofile="Current",
    lineterm="",
  )
  assert_eq(cd[0:2].to_owned(), ["*** Original", "--- Current"])
}

///|
test "TestOutputFormat.test_unified_diff_colored_output" {
  let actual = @difflib.unified_diff(
    ["one", "three"],
    ["two", "three"],
    fromfile="Original",
    tofile="Current",
    fromfiledate="2005-01-26 23:30:50",
    tofiledate="2010-04-02 10:20:52",
    lineterm="",
    color=true,
  )
  assert_eq(actual, [
    "\u{1b}[1m--- Original\t2005-01-26 23:30:50\u{1b}[0m", "\u{1b}[1m+++ Current\t2010-04-02 10:20:52\u{1b}[0m",
    "\u{1b}[36m@@ -1,2 +1,2 @@\u{1b}[0m", "\u{1b}[31m-one\u{1b}[0m", "\u{1b}[32m+two\u{1b}[0m",
    "\u{1b}[0m three\u{1b}[0m",
  ])
}

///|
test "TestBytes.test_byte_content" {
  // if we receive byte strings, we return byte strings
  let a : Array[Bytes] = [b"hello", b"andr\xe9"] // iso-8859-1 bytes
  let b : Array[Bytes] = [b"hello", b"andr\xc3\xa9"] // utf-8 bytes
  for format in [@difflib.DiffFormat::Unified, Context] {
    ignore(@difflib.diff_bytes(format, a, a))
    ignore(@difflib.diff_bytes(format, a, b))
    ignore(@difflib.diff_bytes(format, a, a, fromfile=b"a", tofile=b"a"))
    ignore(@difflib.diff_bytes(format, a, b, fromfile=b"a", tofile=b"b"))
    ignore(
      @difflib.diff_bytes(
        format,
        a,
        a,
        fromfile=b"a",
        tofile=b"a",
        fromfiledate=b"2005",
        tofiledate=b"2013",
      ),
    )
    ignore(
      @difflib.diff_bytes(
        format,
        a,
        b,
        fromfile=b"a",
        tofile=b"b",
        fromfiledate=b"2005",
        tofiledate=b"2013",
      ),
    )
  }
  let unified = @difflib.diff_bytes(Unified, a, b, lineterm=b"")
  let expected : Array[Bytes] = [
    b"--- ", b"+++ ", b"@@ -1,2 +1,2 @@", b" hello", b"-andr\xe9", b"+andr\xc3\xa9",
  ]
  assert_eq(unified, expected)
}

///|
test "TestBytes.test_byte_filenames" {
  // somebody renamed a file from ISO-8859-2 to UTF-8
  let fna : Bytes = b"\xb3odz.txt" // "łodz.txt"
  let fnb : Bytes = b"\xc5\x82odz.txt"
  // they transcoded the content at the same time
  let a : Array[Bytes] = [b"\xa3odz is a city in Poland."]
  let b : Array[Bytes] = [b"\xc5\x81odz is a city in Poland."]
  let expect : Array[Bytes] = [
    b"--- \xb3odz.txt", b"+++ \xc5\x82odz.txt", b"@@ -1 +1 @@", b"-\xa3odz is a city in Poland.",
    b"+\xc5\x81odz is a city in Poland.",
  ]
  assert_eq(
    @difflib.diff_bytes(Unified, a, b, fromfile=fna, tofile=fnb, lineterm=b""),
    expect,
  )
  // with dates (plain ASCII)
  let expect : Array[Bytes] = [
    b"--- \xb3odz.txt\t2005-03-18", b"+++ \xc5\x82odz.txt\t2005-03-19", b"@@ -1 +1 @@",
    b"-\xa3odz is a city in Poland.", b"+\xc5\x81odz is a city in Poland.",
  ]
  assert_eq(
    @difflib.diff_bytes(
      Unified,
      a,
      b,
      fromfile=fna,
      tofile=fnb,
      fromfiledate=b"2005-03-18",
      tofiledate=b"2005-03-19",
      lineterm=b"",
    ),
    expect,
  )
  let context = @difflib.diff_bytes(
    Context,
    a,
    b,
    fromfile=fna,
    tofile=fnb,
    lineterm=b"",
  )
  let expect : Array[Bytes] = [
    b"*** \xb3odz.txt", b"--- \xc5\x82odz.txt", b"***************", b"*** 1 ****",
    b"! \xa3odz is a city in Poland.", b"--- 1 ----", b"! \xc5\x81odz is a city in Poland.",
  ]
  assert_eq(context, expect)
}

///|
test "diff_bytes round-trips all 256 byte values" {
  let all = Bytes::makei(256, i => i.to_byte())
  let a = [all]
  let b = [b"x" + all]
  let out = @difflib.diff_bytes(Unified, a, b, lineterm=b"")
  assert_eq(out[3], b"-" + all)
  assert_eq(out[4], b"+x" + all)
}

///|
test "TestInputTypes.test_mixed_types_dates" {
  // if input is str, non-ASCII dates are fine
  let out = @difflib.unified_diff(
    ["foo\n"],
    ["bar\n"],
    fromfile="a",
    tofile="b",
    fromfiledate="1 fév",
    tofiledate="3 fév",
  )
  assert_eq(out[0], "--- a\t1 fév\n")
}

///|
test "TestJunkAPIs.test_is_line_junk_true" {
  for line in ["#", "  ", " #", "# ", " # ", ""] {
    assert_true(@difflib.is_line_junk(line), msg="\{line.escape()}")
  }
}

///|
test "TestJunkAPIs.test_is_line_junk_false" {
  for line in ["##", " ##", "## ", "abc ", "abc #", "Mr. Moose is up!"] {
    assert_false(@difflib.is_line_junk(line), msg="\{line.escape()}")
  }
}

///|
test "TestJunkAPIs.test_is_line_junk_REDOS" {
  let evil_input = "\t".repeat(1000000) + "##"
  assert_false(@difflib.is_line_junk(evil_input))
}

///|
test "TestJunkAPIs.test_is_character_junk" {
  for c in [' ', '\t'] {
    assert_true(@difflib.is_character_junk(c))
  }
  for c in ['a', '#', '\n', '\u{0c}', '\r', '\u{0b}'] {
    assert_false(@difflib.is_character_junk(c))
  }
}

///|
fn longer_match_exists(a : String, b : String, n : Int) -> Bool {
  let b = chars(b)
  for i in 0..<(b.length() - n - 1) {
    let part = String::from_array(b[i:i + n + 1])
    if a.contains(part) {
      return true
    }
  }
  false
}

///|
fn slice(s : String, start : Int, end : Int) -> String {
  String::from_array(chars(s)[start:end])
}

///|
test "TestFindLongest.test_default_args" {
  let a = "foo bar"
  let b = "foo baz bar"
  let sm = @difflib.SequenceMatcher::new(a=chars(a), b=chars(b))
  let m = sm.find_longest_match()
  assert_eq((m.a, m.b, m.size), (0, 0, 6))
  assert_eq(slice(a, m.a, m.a + m.size), slice(b, m.b, m.b + m.size))
  assert_false(longer_match_exists(a, b, m.size))
  let m = sm.find_longest_match(alo=2, blo=4)
  assert_eq((m.a, m.b, m.size), (3, 7, 4))
  assert_eq(slice(a, m.a, m.a + m.size), slice(b, m.b, m.b + m.size))
  assert_false(
    longer_match_exists(
      slice(a, 2, a.length()),
      slice(b, 4, b.length()),
      m.size,
    ),
  )
  let m = sm.find_longest_match(bhi=5, blo=1)
  assert_eq((m.a, m.b, m.size), (1, 1, 4))
  assert_eq(slice(a, m.a, m.a + m.size), slice(b, m.b, m.b + m.size))
  assert_false(longer_match_exists(a, slice(b, 1, 5), m.size))
}

///|
test "TestFindLongest.test_longest_match_with_popular_chars" {
  let a = "dabcd"
  let b = "d".repeat(100) + "abc" + "d".repeat(100) // length over 200 so popular used
  let sm = @difflib.SequenceMatcher::new(a=chars(a), b=chars(b))
  let m = sm.find_longest_match(alo=0, ahi=a.length(), blo=0, bhi=b.length())
  assert_eq((m.a, m.b, m.size), (0, 99, 5))
  assert_eq(slice(a, m.a, m.a + m.size), slice(b, m.b, m.b + m.size))
  assert_false(longer_match_exists(a, b, m.size))
}

///|
test "TestCloseMatches.test_invalid_inputs" {
  let errors = []
  for args in [(0, 0.6), (-1, 0.6), (3, 1.1), (3, -0.1), (3, 0.0 / 0.0)] {
    let (n, cutoff) = args
    try @difflib.get_close_matches("spam", ["egg"], n~, cutoff~) catch {
      err => errors.push(err)
    } noraise {
      _ => fail("expected ValueError for n=\{n}, cutoff=\{cutoff}")
    }
  }
  debug_inspect(
    errors,
    content=(
      #|[
      #|  ValueError("n must be > 0: 0"),
      #|  ValueError("n must be > 0: -1"),
      #|  ValueError("cutoff must be in [0.0, 1.0]: 1.1"),
      #|  ValueError("cutoff must be in [0.0, 1.0]: -0.1"),
      #|  ValueError("cutoff must be in [0.0, 1.0]: NaN"),
      #|]
    ),
  )
}

///|
test "TestRestore.test_invalid_input" {
  for which in [0, 3] {
    try @difflib.restore([], which) catch {
      err =>
        debug_inspect(
          err,
          content=if which == 0 {
            "ValueError(\"unknown delta choice (must be 1 or 2): 0\")"
          } else {
            "ValueError(\"unknown delta choice (must be 1 or 2): 3\")"
          },
        )
    } noraise {
      _ => fail("expected ValueError")
    }
  }
}

///|
test "get_grouped_opcodes doctest" {
  let a = Array::makei(39, i => (i + 1).to_string())
  let b = a.copy()
  b.insert(8, "i") // Make an insertion
  b[20] = b[20] + "x" // Make a replacement
  for _ in 0..<5 {
    ignore(b.remove(23)) // Make a deletion
  }
  b[30] = b[30] + "y" // Make another replacement
  let groups = @difflib.SequenceMatcher::new(a~, b~).get_grouped_opcodes()
  inspect(
    groups.map(opcodes_text).join("\n--\n"),
    content=(
      #|equal 5 8 5 8
      #|insert 8 8 8 9
      #|equal 8 11 9 12
      #|--
      #|equal 16 19 17 20
      #|replace 19 20 20 21
      #|equal 20 22 21 23
      #|delete 22 27 23 23
      #|equal 27 30 23 26
      #|--
      #|equal 31 34 27 30
      #|replace 34 35 30 31
      #|equal 35 38 31 34
    ),
  )
}

///|
test "set_seq1 / set_seq2 doctests" {
  let s = @difflib.SequenceMatcher::new()
  s.set_seqs(chars("abcd"), chars("bcde"))
  inspect(s.ratio(), content="0.75")
  let s = @difflib.SequenceMatcher::new(a=chars("abcd"), b=chars("bcde"))
  inspect(s.ratio(), content="0.75")
  s.set_seq1(chars("bcde"))
  inspect(s.ratio(), content="1")
  let s = @difflib.SequenceMatcher::new(a=chars("abcd"), b=chars("bcde"))
  s.set_seq2(chars("abcd"))
  inspect(s.ratio(), content="1")
  let s = @difflib.SequenceMatcher::new(a=chars("ab"), b=chars("c"))
  debug_inspect(
    s.find_longest_match(alo=0, ahi=2, blo=0, bhi=1),
    content="{ a: 0, b: 0, size: 0 }",
  )
}

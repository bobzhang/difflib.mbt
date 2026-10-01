///|
test "TestSFbugs.test_mdiff_catch_stop_iteration" {
  // Issue #33224
  debug_inspect(
    mdiff(["2"], ["3"], context=1),
    content=(
      #|[
      #|  Row(
      #|    { num: Num(1), text: "\u{00}-2\u{01}" },
      #|    { num: Num(1), text: "\u{00}+3\u{01}" },
      #|    true,
      #|  ),
      #|]
    ),
  )
}

///|
test "TestSFbugs.test_mdiff_lopsided_replace" {
  let blank : SideLine = { num: Blank, text: "\n", }
  let side = (n : Int, text : String) => SideLine::{ num: Num(n), text, }
  assert_eq(mdiff(Array::make(4, "a\n"), ["b\n"]), [
    Row(side(1, "\u{0}-a\n\u{1}"), side(1, "\u{0}+b\n\u{1}"), true),
    Row(side(2, "\u{0}-a\n\u{1}"), blank, true),
    Row(side(3, "\u{0}-a\n\u{1}"), blank, true),
    Row(side(4, "\u{0}-a\n\u{1}"), blank, true),
  ])
  assert_eq(mdiff(["a\n"], Array::make(4, "b\n")), [
    Row(side(1, "\u{0}-a\n\u{1}"), side(1, "\u{0}+b\n\u{1}"), true),
    Row(blank, side(2, "\u{0}+b\n\u{1}"), true),
    Row(blank, side(3, "\u{0}+b\n\u{1}"), true),
    Row(blank, side(4, "\u{0}+b\n\u{1}"), true),
  ])
}

///|
test "mdiff intraline markers" {
  debug_inspect(
    mdiff(["abcDefghiJkl"], ["abcdefGhijkl"]),
    content=(
      #|[
      #|  Row(
      #|    {
      #|      num: Num(1),
      #|      text: "abc\u{00}^D\u{01}ef\u{00}^g\u{01}hi\u{00}^J\u{01}kl",
      #|    },
      #|    {
      #|      num: Num(1),
      #|      text: "abc\u{00}^d\u{01}ef\u{00}^G\u{01}hi\u{00}^j\u{01}kl",
      #|    },
      #|    true,
      #|  ),
      #|]
    ),
  )
}

///|
test "TestOutputFormat.test_range_format_unified" {
  assert_eq(format_range_unified(3, 3), "3,0")
  assert_eq(format_range_unified(3, 4), "4")
  assert_eq(format_range_unified(3, 5), "4,2")
  assert_eq(format_range_unified(3, 6), "4,3")
  assert_eq(format_range_unified(0, 0), "0,0")
}

///|
test "TestOutputFormat.test_range_format_context" {
  assert_eq(format_range_context(3, 3), "3")
  assert_eq(format_range_context(3, 4), "4")
  assert_eq(format_range_context(3, 5), "4,5")
  assert_eq(format_range_context(3, 6), "4,6")
  assert_eq(format_range_context(0, 0), "0")
}

///|
test "Differ._fancy_replace doctest" {
  let out = Differ::new().fancy_replace(
    ["abcDefghiJkl\n"],
    0,
    1,
    ["abcdefGhijkl\n"],
    0,
    1,
  )
  inspect(
    out.join(""),
    content=(
      #|- abcDefghiJkl
      #|?    ^  ^  ^
      #|+ abcdefGhijkl
      #|?    ^  ^  ^
      #|
    ),
  )
}

///|
test "Differ._qformat doctest" {
  let out = qformat(
    "\tabcDefghiJkl\n", "\tabcdefGhijkl\n", "  ^ ^  ^      ", "  ^ ^  ^      ",
  ).to_array()
  debug_inspect(
    out,
    content=(
      #|[
      #|  "- \tabcDefghiJkl\n",
      #|  "? \t ^ ^  ^\n",
      #|  "+ \tabcdefGhijkl\n",
      #|  "? \t ^ ^  ^\n",
      #|]
    ),
  )
}

///|
test "python string helpers" {
  assert_eq(py_expandtabs("a\tb", 8), "a       b")
  assert_eq(py_expandtabs("ab\tc\r\td", 4), "ab  c\r    d")
  assert_eq(py_expandtabs("a\tb", 0), "ab")
  assert_eq(py_rstrip("x \t\u{1c}\u{3000}\n"), "x")
  assert_eq(py_strip("\u{85}\u{a0} # \u{2028}"), "#")
  // U+200B (zero width space) and U+FEFF are not whitespace in Python
  assert_eq(py_strip("\u{200b}"), "\u{200b}")
  assert_true(py_str_compare("b", "ab") > 0)
  assert_true(py_str_compare("\u{ffff}", "\u{1F600}") < 0)
  assert_true(py_str_compare("a", "ab") < 0)
  assert_eq(py_str_compare("ab", "ab"), 0)
  assert_eq(py_float_repr(1.0), "1.0")
  assert_eq(py_float_repr(-0.1), "-0.1")
}

///|
test "xml_charref_replace" {
  assert_eq(
    xml_charref_replace("aé€😀", "us-ascii"),
    "a&#233;&#8364;&#128512;",
  )
  assert_eq(
    xml_charref_replace("aé€😀", "ISO-8859-1"),
    "aé&#8364;&#128512;",
  )
  assert_eq(xml_charref_replace("aé€😀", "utf-8"), "aé€😀")
}

///|
test "py_float_repr matches Python repr" {
  let cases = [
    (1.0e20, "1e+20"),
    (1.0e16, "1e+16"),
    (1.0e15, "1000000000000000.0"),
    (123456789012345680.0, "1.2345678901234568e+17"),
    (0.0001, "0.0001"),
    (0.00001, "1e-05"),
    (1.5e-7, "1.5e-07"),
    (-2.5, "-2.5"),
    (1.1, "1.1"),
    (100.0, "100.0"),
    (0.0, "0.0"),
    (-0.0, "-0.0"),
    (0.0 / 0.0, "nan"),
    (1.0 / 0.0, "inf"),
    (-1.0 / 0.0, "-inf"),
    (1.7976931348623157e308, "1.7976931348623157e+308"),
    (5.0e-324, "5e-324"),
    (12345.678, "12345.678"),
  ]
  for case_ in cases {
    assert_eq(py_float_repr(case_.0), case_.1)
  }
}

///|
test "charset aliases follow Python codecs" {
  for
    name in [
      "ascii", "US-ASCII", "ANSI_X3.4-1968", "csASCII", "646", " us ", "iso646-us",
    ] {
    assert_eq(xml_charref_replace("é", name), "&#233;", msg=name)
  }
  for
    name in [
      "latin-1", "Latin 1", "ISO-8859-1", "iso8859", "iso_8859_1:1987", "cp819",
      "L1",
    ] {
    assert_eq(xml_charref_replace("é😀", name), "é&#128512;", msg=name)
  }
  for name in ["utf-8", "UTF8", "u8", "utf-16", "utf_32_le", "utf-8-sig"] {
    assert_eq(xml_charref_replace("é😀", name), "é😀", msg=name)
  }
  // unknown or unsupported codecs are assumed to cover all of Unicode
  assert_eq(xml_charref_replace("é😀", "cp1252"), "é😀")
}

///|
test "huge context sizes do not overflow" {
  let max = 2147483647
  assert_true(
    unified_diff(["x"], ["x"], n=1073741824, lineterm="").to_array().is_empty(),
  )
  assert_true(
    unified_diff(["x"], ["x"], n=max, lineterm="").to_array().is_empty(),
  )
  assert_eq(
    unified_diff(["a", "x"], ["b", "x"], n=max, lineterm="").to_array(),
    unified_diff(["a", "x"], ["b", "x"], n=2, lineterm="").to_array(),
  )
  assert_eq(
    context_diff(["a", "x"], ["b", "x"], n=max, lineterm="").to_array(),
    context_diff(["a", "x"], ["b", "x"], n=2, lineterm="").to_array(),
  )
  assert_eq(
    mdiff(["a", "x", "y"], ["b", "x", "y"], context=max),
    mdiff(["a", "x", "y"], ["b", "x", "y"], context=3),
  )
}

///|
test "dotted charset names resolve like Python's codec lookup" {
  // "latin.1" and "utf.8" are not codecs in Python (LookupError), so they
  // fall back to "assume all of Unicode" here.
  assert_eq(resolve_codec("latin.1"), None)
  assert_eq(resolve_codec("utf.8"), None)
  assert_eq(resolve_codec("iso8859.1"), Some("latin_1"))
  assert_eq(resolve_codec("iso_646.irv:1991"), Some("ascii"))
  assert_eq(resolve_codec("ANSI_X3.4-1968"), Some("ascii"))
  assert_eq(xml_charref_replace("😀", "latin.1"), "😀")
}

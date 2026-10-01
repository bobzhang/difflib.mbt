// The line generators are lazy, like Python's generator functions.

///|
test "no work happens before the first line is pulled" {
  let calls = Ref(0)
  let linejunk = (_ : String) => {
    calls.val += 1
    false
  }
  let delta = @difflib.Differ::new(linejunk~).compare(["a\n", "b\n"], [
    "a\n", "c\n",
  ])
  let ndiff = @difflib.ndiff(["a\n"], ["b\n"], linejunk~)
  assert_eq(calls.val, 0)
  assert_eq(delta.next(), Some("  a\n"))
  assert_true(calls.val > 0)
  ignore(ndiff)
}

///|
test "fancy_replace produces lines one synch step at a time" {
  // Every line of a 500-line replace block is a close match, so each `j`
  // step of the synch loop compares character sequences and calls `charjunk`.
  let a = Array::makei(500, i => "line number \{i} of the old file\n")
  let b = Array::makei(500, i => "line number \{i} of the new file\n")
  let calls = Ref(0)
  let charjunk = (c : Char) => {
    calls.val += 1
    c == ' '
  }
  let delta = @difflib.ndiff(a, b, charjunk~)
  let first_quad = delta.take(4).to_array()
  assert_eq(first_quad[0], "- line number 0 of the old file\n")
  let partial = calls.val
  let rest = delta.count()
  assert_eq(4 + rest, 500 * 4)
  assert_true(partial * 50 < calls.val, msg="\{partial} vs \{calls.val}")
}

///|
test "unified_diff can be consumed incrementally" {
  // 1000 changes far apart; read the first hunk, then the rest.
  let a = Array::makei(20000, i => "\{i}\n")
  let b = a.copy()
  for k in 0..<1000 {
    b[k * 20] = "changed \{k}\n"
  }
  let diff = @difflib.unified_diff(a, b, lineterm="")
  let head = diff.take(5).to_array()
  debug_inspect(
    head,
    content=(
      #|["--- ", "+++ ", "@@ -1,4 +1,4 @@", "-0\n", "+changed 0\n"]
    ),
  )
  let remaining = diff.count()
  assert_eq(remaining > 1000 * 5, true)
}

///|
test "generators are single-pass, like Python's" {
  let diff = @difflib.unified_diff(["a"], ["b"], lineterm="")
  assert_eq(diff.count(), 5)
  assert_eq(diff.count(), 0)
  let groups = @difflib.SequenceMatcher::new(a=['a', 'b'], b=['a', 'c']).get_grouped_opcodes()
  assert_eq(groups.to_array().length(), 1)
  assert_eq(groups.to_array().length(), 0)
}

///|
test "restore streams from an ndiff delta" {
  let a = ["one\n", "two\n", "three\n"]
  let b = ["ore\n", "tree\n", "emu\n"]
  assert_eq(@difflib.restore(@difflib.ndiff(a, b), 1).to_array(), a)
  assert_eq(@difflib.restore(@difflib.ndiff(a, b), 2).to_array(), b)
}

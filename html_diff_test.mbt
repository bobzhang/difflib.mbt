///|
test "html_diff matches CPython test_difflib_expect.html" {
  @difflib.HtmlDiff::reset_prefix_counter()
  let i = @difflib.HtmlDiff::new()
  let j = @difflib.HtmlDiff::new(tabsize=2)
  let k = @difflib.HtmlDiff::new(wrapcolumn=14)
  let full = i.make_file(
    patch_f1a,
    patch_t1a,
    fromdesc="from",
    todesc="to",
    context=false,
    numlines=5,
  )
  let tables = [
    "<h2>Context (first diff within numlines=5(default))</h2>",
    i.make_table(
      patch_f1a,
      patch_t1a,
      fromdesc="from",
      todesc="to",
      context=true,
    ),
    "<h2>Context (first diff after numlines=5(default))</h2>",
    i.make_table(
      patch_f1b,
      patch_t1b,
      fromdesc="from",
      todesc="to",
      context=true,
    ),
    "<h2>Context (numlines=6)</h2>",
    i.make_table(
      patch_f1a,
      patch_t1a,
      fromdesc="from",
      todesc="to",
      context=true,
      numlines=6,
    ),
    "<h2>Context (numlines=0)</h2>",
    i.make_table(
      patch_f1a,
      patch_t1a,
      fromdesc="from",
      todesc="to",
      context=true,
      numlines=0,
    ),
    "<h2>Same Context</h2>",
    i.make_table(
      patch_f1a,
      patch_f1a,
      fromdesc="from",
      todesc="to",
      context=true,
    ),
    "<h2>Same Full</h2>",
    i.make_table(
      patch_f1a,
      patch_f1a,
      fromdesc="from",
      todesc="to",
      context=false,
    ),
    "<h2>Empty Context</h2>",
    i.make_table([], [], fromdesc="from", todesc="to", context=true),
    "<h2>Empty Full</h2>",
    i.make_table([], [], fromdesc="from", todesc="to", context=false),
    "<h2>tabsize=2</h2>",
    j.make_table(patch_f2, patch_t2),
    "<h2>tabsize=default</h2>",
    i.make_table(patch_f2, patch_t2),
    "<h2>Context (wrapcolumn=14,numlines=0)</h2>",
    k.make_table(patch_f3, patch_t3, context=true, numlines=0),
    "<h2>wrapcolumn=14,splitlines()</h2>",
    k.make_table(patch_f3, patch_t3),
    "<h2>wrapcolumn=14,splitlines(True)</h2>",
    k.make_table(patch_f3_keepends, patch_t3_keepends),
  ].join("\n")
  let actual = full.replace(old="</body>", new="\n\{tables}\n</body>")
  assert_eq(actual, expected_html)
}

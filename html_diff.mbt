///|
/// Counter used to generate unique anchor prefixes so that multiple tables
/// can exist on the same HTML page without conflicts (Python's class-level
/// `HtmlDiff._default_prefix`).
let html_default_prefix : Ref[Int] = { val: 0, }

///|
/// Resets the global anchor-prefix counter shared by all [HtmlDiff]
/// instances (Python's `HtmlDiff._default_prefix = value`). Each call to
/// [HtmlDiff::make_table] or [HtmlDiff::make_file] uses the current value and
/// then increments it.
pub fn HtmlDiff::reset_prefix_counter(value? : Int = 0) -> Unit {
  html_default_prefix.val = value
}

///|
/// Produces an HTML side by side comparison with change highlights.
///
/// The table can be generated in either full or contextual difference mode,
/// either as a complete HTML file ([HtmlDiff::make_file]) or as a table only
/// ([HtmlDiff::make_table]).
///
/// # Example
/// ```mbt check
/// test {
///   @difflib.HtmlDiff::reset_prefix_counter()
///   let table = @difflib.HtmlDiff::new().make_table(["a\n", "b\n"], ["a\n", "c\n"])
///   assert_true(table.contains("<span class=\"diff_sub\">b</span>"))
///   assert_true(table.contains("<span class=\"diff_add\">c</span>"))
/// }
/// ```
pub struct HtmlDiff {
  priv tabsize : Int
  priv wrapcolumn : Int?
  priv linejunk : ((String) -> Bool)?
  priv charjunk : ((Char) -> Bool)?
  priv autojunk : Bool
}

///|
/// Constructs an `HtmlDiff`.
///
/// - `tabsize`: tab stop spacing (default 8).
/// - `wrapcolumn`: column where lines are broken and wrapped; by default
///   (or when 0) lines are not wrapped. Panics if negative (Python recurses
///   without bound).
/// - `linejunk`, `charjunk`, `autojunk`: passed to [ndiff] (`charjunk`
///   defaults to [is_character_junk]).
pub fn HtmlDiff::new(
  tabsize? : Int = 8,
  wrapcolumn? : Int,
  linejunk? : (String) -> Bool,
  charjunk? : (Char) -> Bool = is_character_junk,
  autojunk? : Bool = true,
) -> HtmlDiff {
  if wrapcolumn is Some(w) && w < 0 {
    abort("HtmlDiff: wrapcolumn must be >= 0, got \{w}")
  }
  { tabsize, wrapcolumn, linejunk, charjunk: Some(charjunk), autojunk, }
}

///|
/// Returns a complete HTML file containing a side by side comparison table
/// with change highlights.
///
/// - `fromdesc`, `todesc`: column header strings.
/// - `context`: show contextual differences (default `false`: full).
/// - `numlines`: the number of context lines when `context` is set; otherwise
///   how many lines before a change the "next" anchors are placed. Panics if
///   negative.
/// - `charset`: the document charset. Characters that the charset cannot
///   encode are replaced by XML character references (`&#NNN;`). The ascii,
///   latin-1 and UTF-8/16/32 codecs and their Python aliases are recognised;
///   any other name is assumed to cover all of Unicode.
pub fn HtmlDiff::make_file(
  self : HtmlDiff,
  fromlines : Array[String],
  tolines : Array[String],
  fromdesc? : String = "",
  todesc? : String = "",
  context? : Bool = false,
  numlines? : Int = 5,
  charset? : String = "utf-8",
) -> String {
  let html = html_file_template(
    styles=html_styles,
    legend=html_legend,
    table=self.make_table(
      fromlines,
      tolines,
      fromdesc~,
      todesc~,
      context~,
      numlines~,
    ),
    charset~,
  )
  xml_charref_replace(html, charset)
}

///|
/// Returns from/to line lists with tabs expanded and newlines removed.
///
/// Instead of tab characters being replaced by the number of spaces needed to
/// fill in to the next tab stop, the space is filled with tab characters, so
/// that the difference algorithms can identify changes in a file when tabs
/// are replaced by spaces and vice versa. At the end of the HTML generation,
/// the tab characters are replaced with a nonbreakable space.
fn HtmlDiff::expand_tabs(self : HtmlDiff, line : String) -> String {
  // hide real spaces
  let line = line.replace_all(old=" ", new="\u{0}")
  // expand tabs into spaces
  let line = py_expandtabs(line, self.tabsize)
  // replace spaces from expanded tabs back into tab characters
  // (we'll replace them with markup after we do differencing)
  let line = line.replace_all(old=" ", new="\t")
  let line = line.replace_all(old="\u{0}", new=" ")
  // rstrip('\n')
  let mut end = line.length()
  while end > 0 && line[end - 1] == '\n' {
    end -= 1
  }
  line.unsafe_substring(start=0, end~)
}

///|
/// Splits marked-up text at the wrap column, appending the pieces to
/// `data_list`.
fn HtmlDiff::split_line(
  self : HtmlDiff,
  data_list : Array[SideLine],
  line_num : LineNum,
  text : String,
) -> Unit {
  // if blank line or context separator, just add it to the output list
  if !line_num.is_truthy() {
    data_list.push({ num: line_num, text, })
    return
  }
  // if line text doesn't need wrapping, just add it to the output list
  let chars = text.to_array()
  let size = chars.length()
  let max = self.wrapcolumn.unwrap_or(0)
  let markers = chars.iter().filter(c => c == '\u{0}').count()
  if size <= max || size - markers * 3 <= max {
    data_list.push({ num: line_num, text, })
    return
  }
  // scan text looking for the wrap point, keeping track if the wrap
  // point is inside markers
  let mut i = 0
  let mut n = 0
  let mut mark : Char? = None
  while n < max && i < size {
    if chars[i] == '\u{0}' {
      i += 1
      mark = chars.get(i)
      i += 1
    } else if chars[i] == '\u{1}' {
      i += 1
      mark = None
    } else {
      i += 1
      n += 1
    }
  }
  // wrap point is inside text, break it up into separate lines
  let i = @cmp.minimum(i, size)
  let mut line1 = String::from_array(chars[:i])
  let mut line2 = String::from_array(chars[i:])
  // if wrap point is inside markers, place end marker at end of first
  // line and start marker at beginning of second line because each
  // line will have its own table tag markup around it.
  if mark is Some(mark) {
    line1 = line1 + "\u{1}"
    line2 = "\u{0}\{mark}" + line2
  }
  // tack on first line onto the output list
  data_list.push({ num: line_num, text: line1, })
  // use this routine again to wrap the remaining text
  self.split_line(data_list, Cont, line2)
}

///|
/// Splits (wraps) mdiff text lines.
fn HtmlDiff::line_wrapper(
  self : HtmlDiff,
  diffs : Array[MdiffRow],
) -> Array[MdiffRow] {
  let out : Array[MdiffRow] = []
  let padding : SideLine = { num: Blank, text: " ", }
  for row in diffs {
    guard row is Row(fromdata, todata, flag) else {
      // pass context separators through
      out.push(row)
      continue
    }
    // for each from/to line split it at the wrap column to form
    // list of text lines.
    let fromlist : Array[SideLine] = []
    let tolist : Array[SideLine] = []
    self.split_line(fromlist, fromdata.num, fromdata.text)
    self.split_line(tolist, todata.num, todata.text)
    // yield from/to line in pairs inserting blank lines as
    // necessary when one side has more wrapped lines
    for k in 0..<@cmp.maximum(fromlist.length(), tolist.length()) {
      let f = fromlist.get(k).unwrap_or(padding)
      let t = tolist.get(k).unwrap_or(padding)
      out.push(Row(f, t, flag))
    }
  }
  out
}

///|
/// Returns the HTML markup of a "from" / "to" text line.
fn format_line(
  prefix : String,
  flag : Bool,
  linenum : LineNum,
  text : String,
) -> String {
  let id = match linenum {
    Num(n) => " id=\"\{prefix}\{n}\""
    // blank lines where linenum is '>' or ''
    _ => ""
  }
  // replace those things that would get confused with HTML symbols
  let text = text
    .replace_all(old="&", new="&amp;")
    .replace_all(old=">", new="&gt;")
    .replace_all(old="<", new="&lt;")
  // make space non-breakable so they don't get compressed or line wrapped
  let text = py_rstrip(text.replace_all(old=" ", new="&nbsp;"))
  // add a class to the td tag if there is a difference on the line
  let css_class = if flag { " class=\"diff_changed\" " } else { " " }
  "<td class=\"diff_header\"\{id}>\{linenum.to_column()}</td>" +
  "<td\{css_class}nowrap=\"nowrap\">\{text}</td>"
}

///|
/// Returns an HTML table of a side by side comparison with change
/// highlights.
///
/// The arguments have the same meaning as for [HtmlDiff::make_file].
pub fn HtmlDiff::make_table(
  self : HtmlDiff,
  fromlines : Array[String],
  tolines : Array[String],
  fromdesc? : String = "",
  todesc? : String = "",
  context? : Bool = false,
  numlines? : Int = 5,
) -> String {
  if numlines < 0 {
    // Python fails with IndexError / ZeroDivisionError here.
    abort("HtmlDiff: numlines must be >= 0, got \{numlines}")
  }
  // make unique anchor prefixes so that multiple tables may exist
  // on the same page without conflict.
  let fromprefix = "from\{html_default_prefix.val}_"
  let toprefix = "to\{html_default_prefix.val}_"
  html_default_prefix.val += 1
  // change tabs to spaces before it gets more difficult after we insert
  // markup; this also removes trailing newlines (see gh-71896)
  let fromlines = fromlines.map(line => self.expand_tabs(line))
  let tolines = tolines.map(line => self.expand_tabs(line))
  // create diffs which generate side by side from/to data
  let context_lines = if context { Some(numlines) } else { None }
  let mut diffs = mdiff(
    fromlines,
    tolines,
    context?=context_lines,
    linejunk?=self.linejunk,
    charjunk?=self.charjunk,
    autojunk=self.autojunk,
  )
  // wrap lines that exceed desired width
  if self.wrapcolumn is Some(w) && w != 0 {
    diffs = self.line_wrapper(diffs)
  }
  // collect up from/to lines and flags into lists (also format the lines)
  let mut fromlist : Array[String?] = []
  let mut tolist : Array[String?] = []
  let mut flaglist : Array[Bool?] = []
  for row in diffs {
    match row {
      Row(fromdata, todata, flag) => {
        fromlist.push(
          Some(format_line(fromprefix, flag, fromdata.num, fromdata.text)),
        )
        tolist.push(Some(format_line(toprefix, flag, todata.num, todata.text)))
        flaglist.push(Some(flag))
      }
      Separator => {
        fromlist.push(None)
        tolist.push(None)
        flaglist.push(None)
      }
    }
  }
  // process change flags, generating middle column of next anchors/links
  let mut next_id = Array::make(flaglist.length(), "")
  let mut next_href = Array::make(flaglist.length(), "")
  let mut num_chg = 0
  let mut in_change = false
  let mut last = 0
  for i, flag in flaglist {
    if flag is Some(true) {
      if !in_change {
        in_change = true
        last = i
        // at the beginning of a change, drop an anchor a few lines
        // (the context lines) before the change for the previous link
        let anchor = @cmp.maximum(0, i - numlines)
        next_id[anchor] = " id=\"difflib_chg_\{toprefix}_\{num_chg}\""
        // at the beginning of a change, drop a link to the next change
        num_chg += 1
        next_href[last] = "<a href=\"#difflib_chg_\{toprefix}_\{num_chg}\">n</a>"
      }
    } else {
      in_change = false
    }
  }
  // check for cases where there is no content to avoid exceptions
  if flaglist.is_empty() {
    flaglist = [Some(false)]
    next_id = [""]
    next_href = [""]
    last = 0
    let only = if context {
      "<td></td><td>&nbsp;No Differences Found&nbsp;</td>"
    } else {
      "<td></td><td>&nbsp;Empty File&nbsp;</td>"
    }
    fromlist = [Some(only)]
    tolist = [Some(only)]
  }
  // if not a change on first line, drop a link
  if !(flaglist[0] is Some(true)) {
    next_href[0] = "<a href=\"#difflib_chg_\{toprefix}_0\">f</a>"
  }
  // redo the last link to link to the top
  next_href[last] = "<a href=\"#difflib_chg_\{toprefix}_top\">t</a>"
  let s = StringBuilder()
  for i, flag in flaglist {
    match flag {
      None =>
        // mdiff yields None on separator lines; skip the bogus ones
        // generated for the first line
        if i > 0 {
          s.write_string("        </tbody>        \n        <tbody>\n")
        }
      Some(_) => {
        let from_cell = fromlist[i].unwrap_or("")
        let to_cell = tolist[i].unwrap_or("")
        s.write_string(
          "            <tr><td class=\"diff_next\"\{next_id[i]}>\{next_href[i]}</td>\{from_cell}",
        )
        s.write_string(
          "<td class=\"diff_next\">\{next_href[i]}</td>\{to_cell}</tr>\n",
        )
      }
    }
  }
  let header_row = if fromdesc != "" || todesc != "" {
    "<thead><tr>" +
    "<th class=\"diff_next\"><br /></th>" +
    "<th colspan=\"2\" class=\"diff_header\">\{fromdesc}</th>" +
    "<th class=\"diff_next\"><br /></th>" +
    "<th colspan=\"2\" class=\"diff_header\">\{todesc}</th>" +
    "</tr></thead>"
  } else {
    ""
  }
  let table = html_table_template(
    data_rows=s.to_string(),
    header_row~,
    prefix=toprefix,
  )
  table
  .replace_all(old="\u{0}+", new="<span class=\"diff_add\">")
  .replace_all(old="\u{0}-", new="<span class=\"diff_sub\">")
  .replace_all(old="\u{0}^", new="<span class=\"diff_chg\">")
  .replace_all(old="\u{1}", new="</span>")
  .replace_all(old="\t", new="&nbsp;")
}

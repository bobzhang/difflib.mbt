// Generated from CPython Lib/difflib.py HTML templates; keep byte-identical.

///|
/// Python's `HtmlDiff._styles`.
let html_styles : String =
  #|
  #|        :root {color-scheme: light dark}
  #|        table.diff {
  #|            font-family: Menlo, Consolas, Monaco, Liberation Mono, Lucida Console, monospace;
  #|            border: medium;
  #|        }
  #|        .diff_header {
  #|            background-color: #e0e0e0;
  #|            font-weight: bold;
  #|        }
  #|        td.diff_header {
  #|            text-align: right;
  #|            padding: 0 8px;
  #|        }
  #|        .diff_next {
  #|            background-color: #c0c0c0;
  #|            padding: 4px 0;
  #|        }
  #|        .diff_add {background-color:palegreen}
  #|        .diff_chg {background-color:#ffff77}
  #|        .diff_sub {background-color:#ffaaaa}
  #|        table.diff[summary="Legends"] {
  #|            margin-top: 20px;
  #|            border: 1px solid #ccc;
  #|        }
  #|        table.diff[summary="Legends"] th {
  #|            background-color: #e0e0e0;
  #|            padding: 4px 8px;
  #|        }
  #|        table.diff[summary="Legends"] td {
  #|            padding: 4px 8px;
  #|        }
  #|
  #|        @media (prefers-color-scheme: dark) {
  #|            .diff_header {background-color:#666}
  #|            .diff_next {background-color:#393939}
  #|            .diff_add {background-color:darkgreen}
  #|            .diff_chg {background-color:#847415}
  #|            .diff_sub {background-color:darkred}
  #|            table.diff[summary="Legends"] {border-color:#555}
  #|            table.diff[summary="Legends"] th{background-color:#666}
  #|        }

///|
/// Python's `HtmlDiff._legend`.
let html_legend : String =
  #|
  #|    <table class="diff" summary="Legends">
  #|        <tr> <th colspan="2"> Legends </th> </tr>
  #|        <tr> <td> <table border="" summary="Colors">
  #|                      <tr><th> Colors </th> </tr>
  #|                      <tr><td class="diff_add">&nbsp;Added&nbsp;</td></tr>
  #|                      <tr><td class="diff_chg">Changed</td> </tr>
  #|                      <tr><td class="diff_sub">Deleted</td> </tr>
  #|                  </table></td>
  #|             <td> <table border="" summary="Links">
  #|                      <tr><th colspan="2"> Links </th> </tr>
  #|                      <tr><td>(f)irst change</td> </tr>
  #|                      <tr><td>(n)ext change</td> </tr>
  #|                      <tr><td>(t)op</td> </tr>
  #|                  </table></td> </tr>
  #|    </table>

///|
/// Python's `HtmlDiff._file_template`.
fn html_file_template(
  charset~ : String,
  styles~ : String,
  table~ : String,
  legend~ : String,
) -> String {
  let buf = StringBuilder()
  buf.write_string(
    (
      #|
      #|<!DOCTYPE html>
      #|<html lang="en">
      #|<head>
      #|    <meta charset="
    ),
  )
  buf.write_string(charset)
  buf.write_string(
    (
      #|">
      #|    <meta name="viewport" content="width=device-width, initial-scale=1">
      #|    <title>Diff comparison</title>
      #|    <style>
    ),
  )
  buf.write_string(styles)
  buf.write_string(
    (
      #|
      #|    </style>
      #|</head>
      #|
      #|<body>
      #|    
    ),
  )
  buf.write_string(table)
  buf.write_string(legend)
  buf.write_string(
    (
      #|
      #|</body>
      #|
      #|</html>
    ),
  )
  buf.to_string()
}

///|
/// Python's `HtmlDiff._table_template`.
fn html_table_template(
  data_rows~ : String,
  header_row~ : String,
  prefix~ : String,
) -> String {
  let buf = StringBuilder()
  buf.write_string(
    (
      #|
      #|    <table class="diff" id="difflib_chg_
    ),
  )
  buf.write_string(prefix)
  buf.write_string(
    (
      #|_top"
      #|           cellspacing="0" cellpadding="0" rules="groups" >
      #|        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>
      #|        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>
      #|        
    ),
  )
  buf.write_string(header_row)
  buf.write_string(
    (
      #|
      #|        <tbody>
      #|
    ),
  )
  buf.write_string(data_rows)
  buf.write_string(
    (
      #|        </tbody>
      #|    </table>
    ),
  )
  buf.to_string()
}

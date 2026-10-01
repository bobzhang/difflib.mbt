import sys, re
sys.path.insert(0, sys.argv[1])
src = open(sys.argv[1] + '/difflib.py').read()
ns = {}
for name in ['_file_template', '_styles', '_table_template', '_legend']:
    m = re.search(r'^%s = (""".*?""")' % name, src, re.S | re.M)
    ns[name] = eval(m.group(1))

def mbt_string(s):
    # emit as a #| multiline raw string; s must not contain trailing-newline ambiguity
    lines = s.split('\n')
    out = []
    for l in lines:
        out.append('  #|' + l)
    return '\n'.join(out)

def emit(name, s, doc):
    print('///|')
    print('/// ' + doc)
    print('let %s : String =' % name)
    # #| strings join lines with \n and have no trailing newline unless a final empty #| line
    print(mbt_string(s))
    print()

print('// Generated from CPython Lib/difflib.py HTML templates; keep byte-identical.')
print()
emit('html_styles', ns['_styles'], "Python's `HtmlDiff._styles`.")
emit('html_legend', ns['_legend'], "Python's `HtmlDiff._legend`.")
ft = ns['_file_template']
parts = re.split(r'%\((\w+)\)s', ft)
print('///|')
print("/// Python's `HtmlDiff._file_template`.")
print('fn html_file_template(charset~ : String, styles~ : String, table~ : String, legend~ : String) -> String {')
print('  let buf = StringBuilder()')
for i, p in enumerate(parts):
    if i % 2 == 0:
        if p:
            print('  buf.write_string(\n    (\n' + '\n'.join('      #|' + l for l in p.split('\n')) + '\n    ),\n  )')
    else:
        print('  buf.write_string(%s)' % p)
print('  buf.to_string()')
print('}')
print()
tt = ns['_table_template']
parts = re.split(r'%\((\w+)\)s', tt)
print('///|')
print("/// Python's `HtmlDiff._table_template`.")
print('fn html_table_template(data_rows~ : String, header_row~ : String, prefix~ : String) -> String {')
print('  let buf = StringBuilder()')
for i, p in enumerate(parts):
    if i % 2 == 0:
        if p:
            print('  buf.write_string(\n    (\n' + '\n'.join('      #|' + l for l in p.split('\n')) + '\n    ),\n  )')
    else:
        print('  buf.write_string(%s)' % p)
print('  buf.to_string()')
print('}')

import sys
sys.path.insert(0, sys.argv[2])
from mbtlit import lit, arr, raw
ns = {}
src = open(sys.argv[1] + '/test/test_difflib.py').read()
start = src.index('patch914575_from1 = ')
end = src.index('class TestSFpatches')
exec(src[start:end], ns)
expected = open(sys.argv[1] + '/test/test_difflib_expect.html', encoding='utf-8').read()
f1a = ((ns['patch914575_from1'] + '123\n'*10)*3)
t1a = (ns['patch914575_to1'] + '123\n'*10)*3
f1b = '456\n'*10 + f1a
t1b = '456\n'*10 + t1a
f3 = ns['patch914575_from3']; t3 = ns['patch914575_to3']
P = print
P('// Generated from CPython Lib/test/test_difflib.py (TestSFpatches.test_html_diff)')
P('// and Lib/test/test_difflib_expect.html. Do not edit by hand.')
P()
for name, val in [('f1a', f1a.splitlines()), ('t1a', t1a.splitlines()), ('f1b', f1b.splitlines()),
                  ('t1b', t1b.splitlines()), ('f2', ns['patch914575_from2'].splitlines()),
                  ('t2', ns['patch914575_to2'].splitlines()), ('f3', f3.splitlines()), ('t3', t3.splitlines()),
                  ('f3_keepends', f3.splitlines(True)), ('t3_keepends', t3.splitlines(True)),
                  ('nonascii_from1', ns['patch914575_nonascii_from1'].splitlines()),
                  ('nonascii_to1', ns['patch914575_nonascii_to1'].splitlines()),
                  ('from1', ns['patch914575_from1'].splitlines()),
                  ('to1', ns['patch914575_to1'].splitlines())]:
    P('///|')
    P('let patch_%s : Array[String] = %s' % (name, arr(val, '')))
    P()
P('///|')
P('let expected_html : String = %s' % raw(expected, ''))

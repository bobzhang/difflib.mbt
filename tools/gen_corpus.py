"""Generate a randomized differential corpus from the pinned CPython difflib.

Usage: python3 tools/gen_corpus.py > corpus_fixtures_test.mbt

Each case is one JSON object per line, embedded in a MoonBit raw string.
"""
import json
import random
import sys

sys.path.insert(0, __import__('os').path.dirname(__file__))
from pinned_difflib import load

d = load()
rng = random.Random(20261001)

ALPHABETS = [
    'ab',
    'abc ',
    'abcd \t',
    'xyzéü',
    'ab\U0001F600中',
    'a b　 \x1c\x85',
]

JUNK_CHARS = {
    'none': None,
    'space': lambda c: c == ' ',
    'space_tab': lambda c: c in ' \t',
    'vowel': lambda c: c in 'aeiou',
}


def rand_str(alpha, lo, hi):
    return ''.join(rng.choice(alpha) for _ in range(rng.randint(lo, hi)))


def mutate_str(s, alpha, k):
    s = list(s)
    for _ in range(k):
        op = rng.random()
        if op < 0.33 and s:
            del s[rng.randrange(len(s))]
        elif op < 0.66:
            s.insert(rng.randint(0, len(s)), rng.choice(alpha))
        elif s:
            s[rng.randrange(len(s))] = rng.choice(alpha)
    return ''.join(s)


def opcodes(ops):
    return [list(o) for o in ops]


def matcher_case():
    alpha = rng.choice(ALPHABETS)
    if rng.random() < 0.15:
        a = rand_str(alpha, 150, 260)
        b = mutate_str(a, alpha, rng.randint(1, 30)) if rng.random() < 0.7 else rand_str(alpha, 190, 260)
    else:
        a = rand_str(alpha, 0, 40)
        b = mutate_str(a, alpha, rng.randint(0, 10)) if rng.random() < 0.7 else rand_str(alpha, 0, 40)
    junk = rng.choice(list(JUNK_CHARS))
    autojunk = rng.random() < 0.7
    s = d.SequenceMatcher(JUNK_CHARS[junk], a, b, autojunk=autojunk)
    lm_args = None
    if len(a) and len(b):
        alo = rng.randint(0, len(a))
        ahi = rng.randint(alo, len(a))
        blo = rng.randint(0, len(b))
        bhi = rng.randint(blo, len(b))
        lm_args = [alo, ahi, blo, bhi]
        lm = list(s.find_longest_match(alo, ahi, blo, bhi))
    else:
        lm = None
    n = rng.randint(0, 4)
    return {
        'kind': 'matcher', 'a': a, 'b': b, 'junk': junk, 'autojunk': autojunk,
        'blocks': [list(m) for m in s.get_matching_blocks()],
        'opcodes': opcodes(s.get_opcodes()),
        'n': n,
        'grouped': [opcodes(g) for g in d.SequenceMatcher(JUNK_CHARS[junk], a, b, autojunk=autojunk).get_grouped_opcodes(n)],
        'ratio': s.ratio(), 'quick_ratio': s.quick_ratio(),
        'real_quick_ratio': s.real_quick_ratio(),
        'bjunk': sorted(s.bjunk), 'bpopular': sorted(s.bpopular),
        'lm_args': lm_args, 'lm': lm,
    }


LINE_PIECES = [
    'def foo(x):', 'return x', '    pass', '\tindented', 'x = 1', 'y = 2', '',
    '#', '  # comment', 'café über', 'emoji \U0001F600 here',
    'a\tb\tc', 'the quick brown fox', 'jumps over the lazy dog', '<b>&amp;</b>',
    'tab\t\tend\t', '   ', 'x' * 30, 'longer line that will need wrapping at some point',
]
LINE_ALPHA = 'abcdefgh \t<>&é\U0001F600'


def rand_lines(lo, hi):
    out = []
    for _ in range(rng.randint(lo, hi)):
        if rng.random() < 0.7:
            out.append(rng.choice(LINE_PIECES))
        else:
            out.append(rand_str(LINE_ALPHA, 0, 25))
    return out


def mutate_lines(lines):
    lines = list(lines)
    for _ in range(rng.randint(0, 6)):
        op = rng.random()
        if op < 0.25 and lines:
            del lines[rng.randrange(len(lines))]
        elif op < 0.5:
            lines.insert(rng.randint(0, len(lines)), rng.choice(LINE_PIECES))
        elif lines:
            i = rng.randrange(len(lines))
            lines[i] = mutate_str(lines[i], LINE_ALPHA, rng.randint(1, 3))
    return lines


def with_endings(lines, mode):
    if mode == 'none':
        return lines
    out = [l + '\n' for l in lines]
    if mode == 'mixed' and out:
        out[-1] = out[-1][:-1]
    return out


def lines_case(big=False):
    if big:
        base = ['x\n'] * rng.randint(150, 220) + with_endings(rand_lines(3, 8), 'all')
        a = with_endings(rand_lines(0, 5), 'all') + base
        b = with_endings(mutate_lines(rand_lines(0, 5)), 'all') + base[rng.randint(0, 40):]
    else:
        mode = rng.choice(['none', 'all', 'mixed'])
        a0 = rand_lines(0, 14)
        b0 = mutate_lines(a0) if rng.random() < 0.8 else rand_lines(0, 14)
        a, b = with_endings(a0, mode), with_endings(b0, mode)
    autojunk = rng.random() < 0.7
    linejunk = rng.choice(['none', 'none', 'is_line_junk'])
    charjunk = rng.choice(['default', 'none'])
    lj = d.IS_LINE_JUNK if linejunk == 'is_line_junk' else None
    cj = d.IS_CHARACTER_JUNK if charjunk == 'default' else None
    n = rng.randint(0, 4)
    lineterm = rng.choice(['\n', ''])
    fromfile, tofile = rng.choice([('', ''), ('a.txt', 'b.txt')])
    fromdate, todate = rng.choice([('', ''), ('2005-01-26 23:30:50', '2010-04-02')])
    color = rng.random() < 0.2
    nd = list(d.ndiff(a, b, lj, cj, autojunk=autojunk))
    case = {
        'kind': 'lines', 'a': a, 'b': b, 'autojunk': autojunk,
        'linejunk': linejunk, 'charjunk': charjunk, 'n': n, 'lineterm': lineterm,
        'fromfile': fromfile, 'tofile': tofile, 'fromdate': fromdate, 'todate': todate,
        'color': color,
        'ndiff': nd,
        'differ_plain': list(d.Differ(autojunk=autojunk).compare(a, b)),
        'restore1': list(d.restore(nd, 1)), 'restore2': list(d.restore(nd, 2)),
        'unified': list(d.unified_diff(a, b, fromfile, tofile, fromdate, todate, n, lineterm,
                                       autojunk=autojunk, color=color)),
        'context': list(d.context_diff(a, b, fromfile, tofile, fromdate, todate, n, lineterm,
                                       autojunk=autojunk)),
    }
    return case


def html_case():
    a0 = rand_lines(0, 12)
    b0 = mutate_lines(a0) if rng.random() < 0.8 else rand_lines(0, 12)
    mode = rng.choice(['none', 'all', 'mixed'])
    a, b = with_endings(a0, mode), with_endings(b0, mode)
    tabsize = rng.choice([8, 4, 2, 1, 0])
    wrapcolumn = rng.choice([None, None, 0, 5, 14, 30])
    context = rng.random() < 0.5
    numlines = rng.randint(0, 6)
    charjunk = rng.choice(['default', 'none'])
    cj = d.IS_CHARACTER_JUNK if charjunk == 'default' else None
    fromdesc, todesc = rng.choice([('', ''), ('from', 'to'), ('<old>', '')])
    charset = rng.choice(['utf-8', 'us-ascii', 'iso-8859-1'])
    autojunk = rng.random() < 0.8
    h = d.HtmlDiff(tabsize=tabsize, wrapcolumn=wrapcolumn, charjunk=cj, autojunk=autojunk)
    d.HtmlDiff._default_prefix = 0
    table = h.make_table(a, b, fromdesc, todesc, context=context, numlines=numlines)
    d.HtmlDiff._default_prefix = 0
    html_file = h.make_file(a, b, fromdesc, todesc, context=context, numlines=numlines,
                            charset=charset) if rng.random() < 0.3 else None
    return {
        'kind': 'html', 'a': a, 'b': b, 'tabsize': tabsize, 'wrapcolumn': wrapcolumn,
        'context': context, 'numlines': numlines, 'charjunk': charjunk,
        'fromdesc': fromdesc, 'todesc': todesc, 'charset': charset, 'autojunk': autojunk,
        'table': table, 'file': html_file,
    }


WORDS = ['apple', 'ape', 'apply', 'peach', 'puppy', 'apples', 'appel', 'aple',
         'banana', 'bandana', 'cabana', 'ab', 'ba', 'abc', 'cab', 'bca', 'école',
         'ecole', '\U0001F600x', 'x\U0001F600', 'Apple', 'APPLE', 'pple', 'zebra']


def close_case():
    word = rng.choice(WORDS + [mutate_str(rng.choice(WORDS), 'abcelp', 2)])
    poss = [rng.choice(WORDS) for _ in range(rng.randint(0, 12))]
    n = rng.randint(1, 5)
    cutoff = rng.choice([0.0, 0.3, 0.5, 0.6, 0.75, 1.0])
    autojunk = rng.random() < 0.7
    return {
        'kind': 'close', 'word': word, 'possibilities': poss, 'n': n,
        'cutoff': cutoff, 'autojunk': autojunk,
        'result': d.get_close_matches(word, poss, n, cutoff, autojunk=autojunk),
    }


def junk_case():
    alpha = ' \t\n\r\x0b\x0c\x1c\x1d\x1e\x1f\x85\xa0       　#a​﻿'
    s = rand_str(alpha, 0, 6)
    return {'kind': 'line_junk', 's': s, 'result': d.IS_LINE_JUNK(s)}


cases = []
cases += [matcher_case() for _ in range(400)]
cases += [lines_case() for _ in range(250)]
cases += [lines_case(big=True) for _ in range(6)]
cases += [html_case() for _ in range(80)]
cases += [close_case() for _ in range(120)]
cases += [junk_case() for _ in range(150)]

print('// Generated by tools/gen_corpus.py from the pinned CPython Lib/difflib.py.')
print('// Do not edit by hand.')
print()
print('///|')
print('let corpus : String = (')
for c in cases:
    print('  #|' + json.dumps(c, ensure_ascii=True, separators=(',', ':')))
print(')')

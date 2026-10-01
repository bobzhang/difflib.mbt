def lit(s):
    out = ['"']
    for c in s:
        o = ord(c)
        if c == '\\': out.append('\\\\')
        elif c == '"': out.append('\\"')
        elif c == '\n': out.append('\\n')
        elif c == '\t': out.append('\\t')
        elif c == '\r': out.append('\\r')
        elif o < 32 or o == 127 or (0x80 <= o < 0xa0) or 0xd800 <= o < 0xe000:
            out.append('\\u{%x}' % o)
        else: out.append(c)
    out.append('"')
    return ''.join(out)

def arr(xs, indent='  '):
    if not xs: return '[]'
    return '[\n' + ''.join(indent + '  ' + lit(x) + ',\n' for x in xs) + indent + ']'

def raw(s, indent='  '):
    # multi-line raw string, s must not contain '\r'
    return '(\n' + '\n'.join(indent + '  #|' + l for l in s.split('\n')) + '\n' + indent + ')'

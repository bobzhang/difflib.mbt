"""Load CPython's Lib/difflib.py from .repos/cpython so it runs on older Pythons.

The pinned source uses PEP 810 `lazy from _colorize import ...`, which older
interpreters cannot parse, so that import is replaced with a stub theme that
reproduces the default difflib colors.
"""
import os
import types

_STUB = '''
class _Theme:
    def __init__(self, color):
        if color:
            (self.header, self.hunk, self.added, self.removed, self.context,
             self.reset) = ("\\x1b[1m", "\\x1b[36m", "\\x1b[32m", "\\x1b[31m",
                            "\\x1b[0m", "\\x1b[0m")
        else:
            self.header = self.hunk = self.added = ""
            self.removed = self.context = self.reset = ""
class _T:
    def __init__(self, color):
        self.difflib = _Theme(color)
def can_colorize():
    return True
def get_theme(force_color=False, force_no_color=False):
    return _T(force_color and not force_no_color)
'''

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
CPYTHON = os.path.join(ROOT, '.repos', 'cpython')


def load():
    path = os.path.join(CPYTHON, 'Lib', 'difflib.py')
    src = open(path, encoding='utf-8').read()
    line = 'lazy from _colorize import can_colorize, get_theme'
    if line in src:
        src = src.replace(line, _STUB)
    mod = types.ModuleType('pinned_difflib')
    mod.__file__ = path
    exec(compile(src, path, 'exec'), mod.__dict__)
    return mod

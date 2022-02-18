#!/usr/bin/env python3
# vim: expandtab tabstop=2 shiftwidth=2 nocin

'''
Usage:
  verify_value_string_arrays_are_terminated.py [ROOT_DIR|PATH] [...]

e.g.
libosmocore/contrib/verify_value_string_arrays_are_terminated.py $(find . -name "*.[hc]")
'''

import re
import sys
import codecs
import os.path

value_string_array_re = re.compile(
  r'((\bstruct\s+value_string\b[^{;]*?)\s*=[^{;]*{[^;]*}\s*;)',
  re.MULTILINE | re.DOTALL)

members = r'(\.(value|str)\s*=\s*)?'
terminator_re = re.compile('{\s*}|{\s*0\s*}|{\s*' + members + '(0|NULL)\s*,'
                           '\s*' + members + '(0|NULL)\s*}')
errors_found = 0

def check_file(f):
  global errors_found
  if not (f.endswith('.h') or f.endswith('.c') or f.endswith('.cpp')):
    return
  arrays = value_string_array_re.findall(codecs.open(f, "r", "utf-8", errors='ignore').read())
  for array_def, name in arrays:
    if not terminator_re.search(array_def):
      print('ERROR: file contains unterminated value_string %r: %r'
            % (name, f))
      errors_found += 1

args = sys.argv[1:]
if not args:
  args = ['.']

for f in args:
  if os.path.isdir(f):
    for parent_path, subdirs, files in os.walk(f, None, None):
      for ff in files:
        check_file(os.path.join(parent_path, ff))
  else:
        check_file(f)

sys.exit(errors_found)

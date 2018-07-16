#!/usr/bin/env python3
__doc__ = '''
With regex magic, try to pinpoint all LOG* macro calls that lack a final newline.
Also find those that have non-printable characters or extra newlines.

Usage:

  ./verify_log_statements.py [-d|--debug] [dir] [file] [...]

Without args, default to '.'
'''

import re
import sys
import codecs
import os.path

# This regex matches the entire LOGxx(...) statement over multiple lines.
# It pinpoints the format string by looking for the first arg that contains quotes.
# It then matches any number of separate quoted strings, and accepts 0 or more args after that.
log_statement_re = re.compile(r'^[ \t]*LOG[_A-Z]+\(([^";,]*,)* *(("[^"]*"[^";,]*)*)(,[^;]*|)\);',
			      re.MULTILINE | re.DOTALL)
fmt_re = re.compile(r'("[^"]*".*)*fmt')

errors_found = 0
debug = ('-d' in sys.argv) or ('--debug' in sys.argv)

args = [x for x in sys.argv[1:] if not (x == '-d' or x == '--debug')]
if not args:
  args = ['.']


def check_file(f):
  global errors_found
  if not (f.endswith('.h') or f.endswith('.c') or f.endswith('.cpp')):
    return

  for log in log_statement_re.finditer(codecs.open(f, "r", "utf-8").read()):
    quoted = log.group(2)

    # Skip 'LOG("bla" fmt )' strings that typically appear as #defines.
    if fmt_re.match(quoted):
      if debug:
        print('Skipping define:', f, '\n'+log.group(0))
      continue

    # Drop PRI* parts of 'LOG("bla %"PRIu64" foo")'
    for n in (16,32,64):
      quoted = quoted.replace('PRIu' + str(n), '')
      quoted = quoted.replace('PRId' + str(n), '')

    # Use py eval to join separate string constants: drop any tabs/newlines
    # that are not in quotes, between separate string constants.
    try:
      quoted = eval('(' + quoted + '\n)' )
    except:
      # hopefully eval broke because of some '## args' macro def
      if debug:
        print('Ignoring:', f, '\n'+log.group(0))	
      continue

    # check for errors...

    # final newline
    if not quoted.endswith('\n'):
      print('Missing final newline:', f, '\n'+log.group(0))
      errors_found += 1

    # disallowed chars and extra newlines
    for c in quoted[:-1]:
      if not c.isprintable() and not c == '\t':
        if c == '\n':
          msg = 'Extraneous newline'
        else:
          msg = 'Illegal char'
        print('%s %r in' % (msg, c), f, '\n' + log.group(0))
        errors_found += 1

for f in args:
  if os.path.isdir(f):
    for parent_path, subdirs, files in os.walk(f, None, None):
      for ff in files:
        check_file(os.path.join(parent_path, ff))
  else:
        check_file(f)

sys.exit(errors_found)

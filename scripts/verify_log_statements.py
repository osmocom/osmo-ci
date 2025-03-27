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
log_statement_re = re.compile(r'^[ \t]*LOG[_A-Z]+\(([^";,]*,)*[ \t\r\n]*(("[^"]*"[^";,]*)*)(,[^;]*|)\);',
                              re.MULTILINE | re.DOTALL)
fmt_re = re.compile(r'("[^"]*".*)*fmt')
osmo_stringify_re = re.compile("OSMO_STRINGIFY[_A-Z]*\([^)]*\)")

debug = ('-d' in sys.argv) or ('--debug' in sys.argv)

args = [x for x in sys.argv[1:] if not (x == '-d' or x == '--debug')]
if not args:
  args = ['.']

class error_found:
  def __init__(self, f, charpos, msg, text):
    self.f = f
    self.charpos = charpos
    self.msg = msg
    self.text = text
    self.line = None

def make_line_idx(file_content):
  line_idx = []
  pos = 0
  line_nr = 1
  line_idx.append((pos, line_nr))
  for line in file_content.split('\n'):
    pos += len(line)
    line_nr += 1
    line_idx.append((pos, line_nr))
    pos += 1 # newline char
  return line_idx

def char_pos_2_line(line_idx, sorted_char_positions):
  r = []
  line_i = 0
  for char_pos in sorted_char_positions:
    while (line_i+1) < len(line_idx) and char_pos > line_idx[line_i+1][0]:
      line_i += 1
    r.append(line_idx[line_i][1])
  return r

def check_file(f):
  if not (f.endswith('.h') or f.endswith('.c') or f.endswith('.cpp')):
    return []

  try:
    errors_found = []

    file_content = codecs.open(f, "r", "utf-8", errors='ignore').read()

    for log in log_statement_re.finditer(file_content):
      quoted = log.group(2)

      # Skip 'LOG("bla" fmt )' strings that typically appear as #defines.
      if fmt_re.match(quoted):
        if debug:
          errors_found.append(error_found(f, log.start(), 'Skipping define', log.group(0)))
        continue

      # Drop PRI* parts of 'LOG("bla %"PRIu64" foo")'
      for n in (16,32,64):
        quoted = quoted.replace('PRIu' + str(n), '')
        quoted = quoted.replace('PRId' + str(n), '')
      quoted = ''.join(osmo_stringify_re.split(quoted))

      # Use py eval to join separate string constants: drop any tabs/newlines
      # that are not in quotes, between separate string constants.
      try:
        quoted = eval('(' + quoted + '\n)' )
      except:  # noqa: E722
        # hopefully eval broke because of some '## args' macro def
        if debug:
          errors_found.append(error_found(f, log.start(), 'Ignoring', log.group(0)))
        continue

      # check for errors...

      # final newline
      if not quoted.endswith('\n'):
        errors_found.append(error_found(f, log.start(), 'Missing final newline', log.group(0)))

      # disallowed chars and extra newlines
      for c in quoted[:-1]:
        if not c.isprintable() and not c == '\t':
          if c == '\n':
            msg = 'Extraneous newline'
          else:
            msg = 'Illegal char'
          errors_found.append(error_found(f, log.start(), msg + ' %r' % c, log.group(0)))

    if not error_found:
      return []

    line_idx = make_line_idx(file_content)
    for r, line in zip(errors_found, char_pos_2_line(line_idx, [rr.charpos for rr in errors_found])):
      r.line = line

    return errors_found
  except:  # noqa: E722
    print("ERROR WHILE PROCESSING %r" % f, file=sys.stderr)
    raise

all_errors_found = []
for f in args:
  if os.path.isdir(f):
    for parent_path, subdirs, files in os.walk(f, None, None):
      for ff in files:
        all_errors_found.extend(check_file(os.path.join(parent_path, ff)))
  else:
        all_errors_found.extend(check_file(f))

def print_errors(errs):
  for err in errs:
    print('%s: %s:%d\n%s\n' % (err.msg, err.f, err.line or 0, err.text))

print_errors(all_errors_found)

sys.exit(len(all_errors_found))

# vim: tabstop=2 shiftwidth=2 expandtab

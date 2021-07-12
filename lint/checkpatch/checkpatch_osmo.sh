#!/bin/sh -e
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Excluded paths:
# * \.(ok|err)$: stdout and stderr of regression tests
# * ^lint/checkpatch/: so it does not warn about spelling errors in spelling.txt :)

# Ignored checks:
# * ASSIGN_IN_IF: not followed (e.g. 'if ((u8 = gsup_msg->cause))')
# * AVOID_EXTERNS: we do use externs
# * BLOCK_COMMENT_STYLE: we don't use a trailing */ on a separate line
# * COMPLEX_MACRO: we don't use parentheses when building macros of strings across multiple lines
# * CONSTANT_COMPARISON: not followed: "Comparisons should place the constant on the right side"
# * DEEP_INDENTATION: warns about many leading tabs, not useful if changing existing code without refactoring
# * EMBEDDED_FUNCTION_NAME: often __func__ isn't used, arguably not much benefit in changing this when touching code
# * EXECUTE_PERMISSIONS: not followed, files need to be executable: git-version-gen, some in debian/
# * FILE_PATH_CHANGES: we don't use a MAINTAINERS file
# * FUNCTION_WITHOUT_ARGS: not followed: warns about func() instead of func(void)
# * GLOBAL_INITIALISERS: we initialise globals to NULL for talloc ctx (e.g. *tall_lapd_ctx = NULL)
# * IF_0: used intentionally
# * INITIALISED_STATIC: we use this, see also http://lkml.iu.edu/hypermail/linux/kernel/0808.1/2235.html
# * LINE_CONTINUATIONS: false positives
# * LINE_SPACING: we don't always put a blank line after declarations
# * PREFER_DEFINED_ATTRIBUTE_MACRO: macros like __packed not defined in libosmocore
# * PREFER_FALLTHROUGH: pseudo keyword macro "fallthrough" is not defined in libosmocore
# * REPEATED_WORD: false positives in doxygen descriptions (e.g. '\param[in] data Data passed through...')
# * SPDX_LICENSE_TAG: we don't place it on line 1
# * SPLIT_STRING: we do split long messages over multiple lines
# * STRING_FRAGMENTS: sometimes used intentionally to improve readability

$SCRIPT_DIR/checkpatch.pl \
	--exclude '\.(ok|err)$' \
	--exclude '^lint/checkpatch/' \
	--ignore ASSIGN_IN_IF \
	--ignore AVOID_EXTERNS \
	--ignore BLOCK_COMMENT_STYLE \
	--ignore COMPLEX_MACRO \
	--ignore CONSTANT_COMPARISON \
	--ignore DEEP_INDENTATION \
	--ignore EMBEDDED_FUNCTION_NAME \
	--ignore EXECUTE_PERMISSIONS \
	--ignore FILE_PATH_CHANGES \
	--ignore FUNCTION_WITHOUT_ARGS \
	--ignore GLOBAL_INITIALISERS \
	--ignore IF_0 \
	--ignore INITIALISED_STATIC \
	--ignore LINE_CONTINUATIONS \
	--ignore LINE_SPACING \
	--ignore PREFER_DEFINED_ATTRIBUTE_MACRO \
	--ignore PREFER_FALLTHROUGH \
	--ignore REPEATED_WORD \
	--ignore SPDX_LICENSE_TAG \
	--ignore SPLIT_STRING \
	--ignore STRING_FRAGMENTS \
	--max-line-length 120 \
	--no-signoff \
	--no-tree \
	"$@"

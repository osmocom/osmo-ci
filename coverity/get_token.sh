#!/bin/sh
#
# Usage:
#   get_token.sh ../tokens.txt my-project
#
# Look for coverity token in a text file.
# Text file lines must be of this format:
# <token><single-space><project>
# 
# e.g.
#
# a3Ksd02nfa-Lk28f_cAk3F libosmocore
# b8sdJA_sd43fLS3-2vL24g libosmo-abis
# ...

tokens_file="$1"
project="$2"
grep " $project\$" "$tokens_file" | sed 's/ .*//'

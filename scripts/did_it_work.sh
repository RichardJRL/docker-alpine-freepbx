#!/bin/bash
CONFIG_OUTPUT='/scripts/asterisk_configure_output.txt'
PARSER_OUTPUT='/scripts/configure_output_parser_output.txt'
rm "$CONFIG_OUTPUT" "$PARSER_OUTPUT"
cd /usr/src/asterisk/ || exit 1
make distclean
# --with-gnu-ld
./configure --enable-permanent-dlopen --with-gnu-ld --with-jansson-bundled=yes --with-pjproject-bundled=yes | tee "$CONFIG_OUTPUT"

cd /scripts || exit 1
./configure_output_parser.sh "$CONFIG_OUTPUT" | tee "$PARSER_OUTPUT"
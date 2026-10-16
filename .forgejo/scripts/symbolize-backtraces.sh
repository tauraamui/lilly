#!/bin/sh
# Turns the backtrace in each saved fuzz failure's lilly.log into source
# lines, next to it as backtrace.txt.
#
#   symbolize-backtraces.sh <lilly binary> <addr2line> <failures dir>
#
# A static glibc build, as the release and debug builds are, prints its
# backtrace as bare [0x...] addresses: backtrace_symbols cannot name the
# executable, so V's own addr2line call fails. The addresses still resolve
# against the binary that printed them. Pass the binary's own addr2line, e.g.
# aarch64-linux-gnu-addr2line for an arm64 build.
set -u

binary=$1
addr2line=$2
failures=$3

for log in "$failures"/*/lilly.log; do
	[ -f "$log" ] || continue
	addrs=$(grep -o '^\[0x[0-9a-f]*\]' "$log" | tr -d '[]')
	[ -n "$addrs" ] || continue
	# shellcheck disable=SC2086 # one argument per address
	"$addr2line" -f -i -p -e "$binary" $addrs > "$(dirname "$log")/backtrace.txt"
	echo "$(dirname "$log")/backtrace.txt:"
	cat "$(dirname "$log")/backtrace.txt"
done

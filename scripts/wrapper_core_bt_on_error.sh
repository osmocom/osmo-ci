#!/bin/sh
# Run a program and check for coredumps if it does not exit with 0. If there
# are any coredumps, then show the backtrace.
msg() {
	echo "[wrapper_core_bt_on_error] $@"
}

if [ $# -lt 1 ]; then
	echo "usage: wrapper_core_bt_on_error.sh PROGRAM [ARG1 [ARG2 […]]]"
	exit 1
fi

ulimit -c unlimited

"$@"
RC=$?

if [ "$RC" != 0 ]; then
	for i in $(find -name 'core' -type f); do
		msg "Found coredump: $i"
		execfn="$(file "$i" | grep -P -o "execfn: '.*?'" | cut -d "'" -f 2)"
		if [ -z "$execfn" ] || ! [ -e "$execfn" ]; then
			msg "Failed to get execfn, ignoring..."
			continue
		fi

		echo
		gdb --batch \
			"$execfn" \
			"$i" \
			-ex bt \
			| tee "$i.backtrace"
		echo
	done
	exit $RC
fi

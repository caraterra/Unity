#!/bin/sh
# unity_test_summary.sh

result_file_directory="$PWD"
root_path=""

total_tests=0
failures=0
ignored=0

failure_output=""
ignore_output=""

usage() {
	printf '\nERROR:\n' >& 2

	# printf "$@" lets us pass format parameters to usage just like printf
	# shellcheck disable=SC2059
	if [ "$#" -gt 0 ]
	then
		printf "$@" >& 2
	fi

	cat <<- EOF >& 2
	Usage: unity_test_summary.sh result_file_directory/ root_path/
	    result_file_directory - The location of your results files.
	        Defaults to current directory if not specified.
	    root_path - Helpful for producing more verbose output if using relative paths.
	EOF

	exit 1
}

process_file() {
	target_file="$1"
	file_successes=$(grep '^[^:]\+:[[:digit:]]\+:[^:]\+:PASS:\?[^:]*$' "$target_file")
	file_failures=$(grep '^[^:]\+:[[:digit:]]\+:[^:]\+:FAIL:\?[^:]*$' "$target_file")
	file_ignored=$(grep '^[^:]\+:[[:digit:]]\+:[^:]\+:IGNORE:\?[^:]*$' "$target_file")

	if [ -n "$root_path" ]
	then
		file_successes=$(printf '%s' "$file_successes" | sed "s/^/$root_path\//g")
		file_failures=$(printf '%s' "$file_failures" | sed "s/^/$root_path\//g")
		file_ignored=$(printf '%s' "$file_ignored" | sed "s/^/$root_path\//g")
	fi

	num_file_successes=$(printf '%s' "$file_successes" | grep -c '')
	num_file_failures=$(printf '%s' "$file_failures" | grep -c '')
	num_file_ignored=$(printf '%s' "$file_ignored" | grep -c '')

	total_tests=$((total_tests + num_file_successes + num_file_failures + num_file_ignored))
	failures=$((failures + num_file_failures))
	ignored=$((ignored + num_file_ignored))

	if [ -z "$failure_output" ]
	then
		failure_output="$file_failures"
	else
		failure_output=$(printf '%s\n%s' "$failure_output" "$file_failures")
	fi

	if [ -z "$ignore_output" ]
	then
		ignore_output="$file_ignored"
	else
		ignore_output=$(printf '%s\n%s' "$ignore_output" "$file_ignored")
	fi
}

main() {
	if [ -n "$1" ]
	then
		if [ -d "$1" ]
		then
			result_file_directory="$1"
		else
			usage "%s: No such directory.\n" "$2"
		fi
	fi

	if [ -n "$2" ]
	then
		if [ -d "$2" ]
		then
			# The existance of the directory is already checked.
			# $(cd ... | exit) only exits the subshell anyway.
			# shellcheck disable=SC2164
			root_path=$(cd "$2"; pwd | sed 's/\//\\\//g')
		else
			usage "%s: No such directory.\n" "$2"
		fi
	fi

	targets=$(find "$result_file_directory" -type f -path '*/*.test*')

	if [ -z "$targets" ]
	then
		usage 'No *.testpass, *.testfail, or *.testresults files found in %s\n' "$result_file_directory"
	fi

	while IFS= read -r file
	do
		process_file "$file"
	done <<- EOF
	$targets
	EOF

	printf '\n'
	if [ "$ignored" -gt 0 ]
	then
		cat <<- EOF
		--------------------------
		UNITY IGNORED TEST SUMMARY
		--------------------------
		$ignore_output
		EOF
	fi

	if [ "$failures" -gt 0 ]
	then
		cat <<- EOF
		--------------------------
		UNITY FAILED TEST SUMMARY
		--------------------------
		$failure_output
		EOF
	fi

	cat <<- EOF
	--------------------------
	OVERALL UNITY TEST SUMMARY
	--------------------------
	EOF
	printf '%d TOTAL TESTS %d TOTAL_FAILURES %d IGNORED\n\n' "$total_tests" "$failures" "$ignored"
}

main "$@"

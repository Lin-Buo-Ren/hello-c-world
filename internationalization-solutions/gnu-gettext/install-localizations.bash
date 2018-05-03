#!/usr/bin/env bash
# Install built localization to a specific installation prefix directory
# 林博仁 © 2018

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

## Runtime Dependencies Checking
declare\
	runtime_dependency_checking_result=still-pass\
	required_software

for required_command in \
	basename \
	dirname \
	realpath; do
	if ! command -v "${required_command}" &>/dev/null; then
		runtime_dependency_checking_result=fail

		case "${required_command}" in
			basename \
			|dirname \
			|install \
			|realpath)
				required_software='GNU Coreutils'
				;;
			*)
				required_software="${required_command}"
				;;
		esac

		printf -- \
			'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n' \
			"${required_software}" \
			1>&2
		unset required_software
	fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
	printf -- \
		'Error: Runtime dependency checking fail, the progrom cannot continue.\n' \
		1>&2
	exit 1
fi; unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v 'BASH_SOURCE[0]' ]; then
	RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
	RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	# We intentionally leaves these variables for script developers
	# shellcheck disable=SC2034
	declare -r \
		RUNTIME_EXECUTABLE_PATH \
		RUNTIME_EXECUTABLE_FILENAME \
		RUNTIME_EXECUTABLE_NAME \
		RUNTIME_EXECUTABLE_DIRECTORY \
		RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_ARGUMENTS=("${@}")

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
	local installation_prefix_dir

	if ! process_commandline_arguments \
		installation_prefix_dir; then
		printf -- \
			'Error: Invalid command-line parameters.\n' \
			1>&2

		printf '\n' # separate error message and help message
		print_help
		exit 1
	fi

	local \
		locale_name \
		locale_prefix

	while IFS= read -d '' -r mo_file; do
		locale_name="$(basename --suffix=.mo "${mo_file}")"
		locale_prefix="${installation_prefix_dir}/share/locale/${locale_name}/LC_MESSAGES"
		install \
			--directory \
			"${locale_prefix}"
		install \
			--verbose \
			--mode='u=rw,go=r' \
			"${mo_file}" \
			"${locale_prefix}"
	done < <(
		find \
		"${RUNTIME_EXECUTABLE_DIRECTORY}/localization" \
		-name '*.mo' \
		-print0
	)

	exit 0
}; declare -fr init

print_help(){
	printf \
		'SYNOPSIS: %s prefix_dir\n' \
		"${RUNTIME_COMMANDLINE_BASECOMMAND}" \
		1>&2
	return 0
}; declare -fr print_help;

process_commandline_arguments() {
	local -n installation_prefix_dir_ref="${1}"; shift

	if [ "${#RUNTIME_COMMANDLINE_ARGUMENTS[@]}" -eq 0 ]; then
		print_help
		exit 1
	fi

	# Modifyable parameters for parsing by consuming
	local -a parameters=("${RUNTIME_COMMANDLINE_ARGUMENTS[@]}")

	# Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer its activation till returning(Y: Do debug)
	local enable_debug=N

	local flag_has_prefix=false

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
				--help \
				|-h)
					print_help;
					exit 0
					;;
				--debug \
				|-d)
					enable_debug=Y
					;;
				*)
					if [ "${flag_has_prefix}" = true ]; then
						printf -- \
							'%s: Error: Only allow one installation prefix directory.\n' \
							"${FUNCNAME[0]}" \
							>&2
						return 1
					else
						# We actually used this variable
						# shellcheck disable=SC2034
						installation_prefix_dir_ref="${parameters[0]}"
						flag_has_prefix=true
					fi
					;;
			esac
			# shift array by 1 = unset 1st then repack
			unset 'parameters[0]'
			if [ "${#parameters[@]}" -ne 0 ]; then
				parameters=("${parameters[@]}")
			fi
		fi
	done

	if [ "${flag_has_prefix}" = false ]; then
		print_help;
		exit 0
	fi

	if [ "${enable_debug}" = Y ]; then
		trap 'trap_return "${FUNCNAME[0]}"' RETURN
		set -o xtrace
	fi
	return 0
}; declare -fr process_commandline_arguments

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
	printf \
		'An error occurred and the script is prematurely aborted\n' \
		1>&2
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
	local returning_function="${1}"

	printf \
		'DEBUG: %s: returning from %s\n' \
		"${FUNCNAME[0]}" \
		"${returning_function}" \
		1>&2
}; declare -fr trap_return

trap_interrupt(){
	printf '\n' # Separate previous output
	printf \
		'Recieved SIGINT, script is interrupted.' \
		1>&2
	return 1
}; declare -fr trap_interrupt; trap trap_interrupt INT

init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
## GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v3.0.16-1-g9d1ae36"
## You may rebase your script to incorporate new features and fixes from the template

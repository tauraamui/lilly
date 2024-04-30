#!/bin/sh

#########################################################################################
#                                                                                       #
# This script was auto-generated from a Justfile by just.sh.                            #
#                                                                                       #
# Generated on 2024-04-30 with just.sh version 0.0.2.                                   #
# https://github.com/jstrieb/just.sh                                                    #
#                                                                                       #
# Run `./just.sh --dump` to recover the original Justfile.                              #
#                                                                                       #
#########################################################################################

if sh "set -o pipefail" > /dev/null 2>&1; then
  set -euo pipefail
else
  set -eu
fi


#########################################################################################
# Variables                                                                             #
#########################################################################################

# User-overwritable variables (via CLI)
INVOCATION_DIRECTORY="$(pwd)"
DEFAULT_SHELL='sh'
DEFAULT_SHELL_ARGS='-cu'
LIST_HEADING='Available recipes:
'
LIST_PREFIX='    '
CHOOSER='fzf'
SORTED='true'

# Display colors
SHOW_COLOR='false'
if [ -t 1 ]; then SHOW_COLOR='true'; fi
NOCOLOR="$(test "${SHOW_COLOR}" = 'true' && printf "\033[m" || echo)"
BOLD="$(test "${SHOW_COLOR}" = 'true' && printf "\033[1m" || echo)"
RED="$(test "${SHOW_COLOR}" = 'true' && printf "\033[1m\033[31m" || echo)"
YELLOW="$(test "${SHOW_COLOR}" = 'true' && printf "\033[33m" || echo)"
CYAN="$(test "${SHOW_COLOR}" = 'true' && printf "\033[36m" || echo)"
GREEN="$(test "${SHOW_COLOR}" = 'true' && printf "\033[32m" || echo)"
PINK="$(test "${SHOW_COLOR}" = 'true' && printf "\033[35m" || echo)"
BLUE="$(test "${SHOW_COLOR}" = 'true' && printf "\033[34m" || echo)"
TICK="$(printf '%s' '`')"
DOLLAR="$(printf '%s' '$')"

assign_variables() {
  test -z "${HAS_RUN_assign_variables:-}" || return 0

  # No user-declared variables

  HAS_RUN_assign_variables="true"
}


#########################################################################################
# Recipes                                                                               #
#########################################################################################

FUN_run() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_run:-}" \
    || test "${FORCE_run:-}" = "true" \
    || return 0

  if [ "${FORCE_run:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_run:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -g run ./src .'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -g run ./src .'  \
    || recipe_error "run" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_run:-}" ]; then
    HAS_RUN_run="true"
  fi
}

FUN_run_gui() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_run_gui:-}" \
    || test "${FORCE_run_gui:-}" = "true" \
    || return 0

  if [ "${FORCE_run_gui:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_run_gui:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -g -d gui run ./src .'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -g -d gui run ./src .'  \
    || recipe_error "run-gui" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_run_gui:-}" ]; then
    HAS_RUN_run_gui="true"
  fi
}

FUN_run_debug() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_run_debug:-}" \
    || test "${FORCE_run_debug:-}" = "true" \
    || return 0

  if [ "${FORCE_run_debug:-}" = "true" ]; then
    FORCE_nonprod_compile="true"
  fi
  FUN_nonprod_compile
  if [ "${FORCE_run_debug:-}" = "true" ]; then
    FORCE_nonprod_compile=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line './lilly --debug .'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    './lilly --debug .'  \
    || recipe_error "run-debug" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_run_debug:-}" ]; then
    HAS_RUN_run_debug="true"
  fi
}

FUN_run_gui_debug() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_run_gui_debug:-}" \
    || test "${FORCE_run_gui_debug:-}" = "true" \
    || return 0

  if [ "${FORCE_run_gui_debug:-}" = "true" ]; then
    FORCE_compile_gui="true"
  fi
  FUN_compile_gui
  if [ "${FORCE_run_gui_debug:-}" = "true" ]; then
    FORCE_compile_gui=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line './lillygui --debug .'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    './lillygui --debug .'  \
    || recipe_error "run-gui-debug" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_run_gui_debug:-}" ]; then
    HAS_RUN_run_gui_debug="true"
  fi
}

FUN_experiment() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_experiment:-}" \
    || test "${FORCE_experiment:-}" = "true" \
    || return 0

  if [ "${FORCE_experiment:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_experiment:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -g run ./experiment .'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -g run ./experiment .'  \
    || recipe_error "experiment" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_experiment:-}" ]; then
    HAS_RUN_experiment="true"
  fi
}

FUN_test() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_test:-}" \
    || test "${FORCE_test:-}" = "true" \
    || return 0

  if [ "${FORCE_test:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_test:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -g test ./src'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -g test ./src'  \
    || recipe_error "test" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_test:-}" ]; then
    HAS_RUN_test="true"
  fi
}

FUN_nonprod_compile() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_nonprod_compile:-}" \
    || test "${FORCE_nonprod_compile:-}" = "true" \
    || return 0

  if [ "${FORCE_nonprod_compile:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_nonprod_compile:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -g ./src -o lilly -prod'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -g ./src -o lilly -prod'  \
    || recipe_error "nonprod-compile" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_nonprod_compile:-}" ]; then
    HAS_RUN_nonprod_compile="true"
  fi
}

FUN_prod_compile() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_prod_compile:-}" \
    || test "${FORCE_prod_compile:-}" = "true" \
    || return 0

  if [ "${FORCE_prod_compile:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_prod_compile:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v ./src -o lilly -prod'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v ./src -o lilly -prod'  \
    || recipe_error "prod-compile" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_prod_compile:-}" ]; then
    HAS_RUN_prod_compile="true"
  fi
}

FUN_compile_gui() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_compile_gui:-}" \
    || test "${FORCE_compile_gui:-}" = "true" \
    || return 0

  if [ "${FORCE_compile_gui:-}" = "true" ]; then
    FORCE_generate_git_hash="true"
  fi
  FUN_generate_git_hash
  if [ "${FORCE_compile_gui:-}" = "true" ]; then
    FORCE_generate_git_hash=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'v -d gui ./src -o lillygui'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'v -d gui ./src -o lillygui'  \
    || recipe_error "compile-gui" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_compile_gui:-}" ]; then
    HAS_RUN_compile_gui="true"
  fi
}

FUN_generate_git_hash() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_generate_git_hash:-}" \
    || test "${FORCE_generate_git_hash:-}" = "true" \
    || return 0

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'git log -n 1 --pretty=format:"%h" | tee ./src/.githash'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'git log -n 1 --pretty=format:"%h" | tee ./src/.githash'  \
    || recipe_error "generate-git-hash" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_generate_git_hash:-}" ]; then
    HAS_RUN_generate_git_hash="true"
  fi
}

FUN_build() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_build:-}" \
    || test "${FORCE_build:-}" = "true" \
    || return 0

  if [ "${FORCE_build:-}" = "true" ]; then
    FORCE_prod_compile="true"
  fi
  FUN_prod_compile
  if [ "${FORCE_build:-}" = "true" ]; then
    FORCE_prod_compile=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body


  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_build:-}" ]; then
    HAS_RUN_build="true"
  fi
}

FUN_apply_license_header() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_apply_license_header:-}" \
    || test "${FORCE_apply_license_header:-}" = "true" \
    || return 0

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v'  \
    || recipe_error "apply-license-header" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_apply_license_header:-}" ]; then
    HAS_RUN_apply_license_header="true"
  fi
}

FUN_install_license_tool() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_install_license_tool:-}" \
    || test "${FORCE_install_license_tool:-}" = "true" \
    || return 0

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'go install github.com/google/addlicense@latest'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'go install github.com/google/addlicense@latest'  \
    || recipe_error "install-license-tool" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_install_license_tool:-}" ]; then
    HAS_RUN_install_license_tool="true"
  fi
}

FUN_symlink() {
  # Recipe setup and pre-recipe dependencies
  test -z "${HAS_RUN_symlink:-}" \
    || test "${FORCE_symlink:-}" = "true" \
    || return 0

  if [ "${FORCE_symlink:-}" = "true" ]; then
    FORCE_build="true"
  fi
  FUN_build
  if [ "${FORCE_symlink:-}" = "true" ]; then
    FORCE_build=
  fi

  OLD_WD="$(pwd)"
  cd "${INVOCATION_DIRECTORY}"

  # Recipe body
  echo_recipe_line 'sudo ln -s $PWD/lilly /usr/local/bin'
  env "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} \
    'sudo ln -s $PWD/lilly /usr/local/bin'  \
    || recipe_error "symlink" "${LINENO:-}"

  # Post-recipe dependencies and teardown
  cd "${OLD_WD}"
  if [ -z "${FORCE_symlink:-}" ]; then
    HAS_RUN_symlink="true"
  fi
}


#########################################################################################
# Helper functions                                                                      #
#########################################################################################

# Sane, portable echo that doesn't escape characters like "\n" behind your back
echo() {
  if [ "${#}" -gt 0 ]; then
    printf "%s\n" "${@}"
  else
    printf "\n"
  fi
}

# realpath is a GNU coreutils extension
realpath() {
  # The methods to replicate it get increasingly error-prone
  # TODO: improve
  if type -P realpath > /dev/null 2>&1; then
    "$(type -P realpath)" "${1}"
  elif type python3 > /dev/null 2>&1; then
    python3 -c 'import os.path, sys; print(os.path.realpath(sys.argv[1]))' "${1}"
  elif type python > /dev/null 2>&1; then
    python -c 'import os.path, sys; print os.path.realpath(sys.argv[1])' "${1}"
  elif [ -f "${1}" ] && ! [ -z "$(dirname "${1}")" ]; then
    # We assume the directory exists. For our uses, it always does
    echo "$(
      cd "$(dirname "${1}")";
      pwd -P
    )/$(
      basename "${1}"
    )"
  elif [ -f "${1}" ]; then
    pwd -P
  elif [ -d "${1}" ]; then
  (
    cd "${1}"
    pwd -P
  )
  else
    echo "${1}"
  fi
}

echo_error() {
  echo "${RED}error${NOCOLOR}: ${BOLD}${1}${NOCOLOR}" >&2
}

recipe_error() {
  STATUS="${?}"
  if [ -z "${2:-}" ]; then
      echo_error "Recipe "'`'"${1}"'`'" failed with exit code ${STATUS}"
  else
      echo_error "Recipe "'`'"${1}"'`'" failed on line ${2} with exit code ${STATUS}"
  fi
  exit "${STATUS}"
}

echo_recipe_line() {
  echo "${BOLD}${1}${NOCOLOR}" >&2
}
            
set_var() {
  export "VAR_${1}=${2}"
}
            
summarizefn() {
  while [ "$#" -gt 0 ]; do
    case "${1}" in
    -u|--unsorted)
      SORTED="false"
      ;;
    esac
    shift
  done

  if [ "${SORTED}" = "true" ]; then
    printf "%s " apply-license-header build compile-gui experiment generate-git-hash install-license-tool nonprod-compile prod-compile run run-debug run-gui run-gui-debug symlink test
  else
    printf "%s " run run-gui run-debug run-gui-debug experiment test nonprod-compile prod-compile compile-gui generate-git-hash build apply-license-header install-license-tool symlink
  fi
  echo

}

usage() {
  cat <<EOF
${GREEN}just.sh${NOCOLOR} 0.0.2
Jacob Strieb
    Auto-generated from a Justfile by just.sh - https://github.com/jstrieb/just.sh

${YELLOW}USAGE:${NOCOLOR}
    ./just.sh [FLAGS] [OPTIONS] [ARGUMENTS]...

${YELLOW}FLAGS:${NOCOLOR}
        ${GREEN}--choose${NOCOLOR}      Select one or more recipes to run using a binary. If ${TICK}--chooser${TICK} is not passed the chooser defaults to the value of ${DOLLAR}JUST_CHOOSER, falling back to ${TICK}fzf${TICK}
        ${GREEN}--dump${NOCOLOR}        Print justfile
        ${GREEN}--evaluate${NOCOLOR}    Evaluate and print all variables. If a variable name is given as an argument, only print that variable's value.
        ${GREEN}--init${NOCOLOR}        Initialize new justfile in project root
    ${GREEN}-l, --list${NOCOLOR}        List available recipes and their arguments
        ${GREEN}--summary${NOCOLOR}     List names of available recipes
    ${GREEN}-u, --unsorted${NOCOLOR}    Return list and summary entries in source order
    ${GREEN}-h, --help${NOCOLOR}        Print help information
    ${GREEN}-V, --version${NOCOLOR}     Print version information

${YELLOW}OPTIONS:${NOCOLOR}
        ${GREEN}--chooser <CHOOSER>${NOCOLOR}           Override binary invoked by ${TICK}--choose${TICK}
        ${GREEN}--list-heading <TEXT>${NOCOLOR}         Print <TEXT> before list
        ${GREEN}--list-prefix <TEXT>${NOCOLOR}          Print <TEXT> before each list item
        ${GREEN}--set <VARIABLE> <VALUE>${NOCOLOR}      Override <VARIABLE> with <VALUE>
        ${GREEN}--shell <SHELL>${NOCOLOR}               Invoke <SHELL> to run recipes
        ${GREEN}--shell-arg <SHELL-ARG>${NOCOLOR}       Invoke shell with <SHELL-ARG> as an argument

${YELLOW}ARGS:${NOCOLOR}
    ${GREEN}<ARGUMENTS>...${NOCOLOR}    Overrides and recipe(s) to run, defaulting to the first recipe in the justfile
EOF
}

err_usage() {
  cat <<EOF >&2
USAGE:
    ./just.sh [FLAGS] [OPTIONS] [ARGUMENTS]...

For more information try ${GREEN}--help${NOCOLOR}
EOF
}

listfn() {
  while [ "$#" -gt 0 ]; do
    case "${1}" in
    --list-heading)
      shift
      LIST_HEADING="${1}"
      ;;

    --list-prefix)
      shift
      LIST_PREFIX="${1}"
      ;;

    -u|--unsorted)
      SORTED="false"
      ;;
    esac
    shift
  done

  printf "%s" "${LIST_HEADING}"
  if [ "${SORTED}" = "true" ]; then 
    echo "${LIST_PREFIX}"'apply-license-header'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'build'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'compile-gui'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'experiment'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'generate-git-hash'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'install-license-tool'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'nonprod-compile'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'prod-compile'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-debug'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-gui'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-gui-debug'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'symlink'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'test'"${BLUE}""${NOCOLOR}"
  else
    echo "${LIST_PREFIX}"'run'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-gui'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-debug'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'run-gui-debug'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'experiment'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'test'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'nonprod-compile'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'prod-compile'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'compile-gui'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'generate-git-hash'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'build'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'apply-license-header'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'install-license-tool'"${BLUE}""${NOCOLOR}"
    echo "${LIST_PREFIX}"'symlink'"${BLUE}""${NOCOLOR}"
  fi
}

dumpfn() {
  cat <<"2d3363299fbc31d0"
run: generate-git-hash
    v -g run ./src .

run-gui: generate-git-hash
    v -g -d gui run ./src .

run-debug: nonprod-compile
	./lilly --debug .

run-gui-debug: compile-gui
	./lillygui --debug .

experiment: generate-git-hash
    v -g run ./experiment .

test: generate-git-hash
    v -g test ./src

nonprod-compile: generate-git-hash
    v -g ./src -o lilly -prod

prod-compile: generate-git-hash
    v ./src -o lilly -prod

compile-gui: generate-git-hash
    v -d gui ./src -o lillygui

generate-git-hash:
    git log -n 1 --pretty=format:"%h" | tee ./src/.githash

build: prod-compile

apply-license-header:
	addlicense -c "The Lilly Editor contributors" -y "2023" ./src/*.v

install-license-tool:
	go install github.com/google/addlicense@latest

symlink: build
	sudo ln -s $PWD/lilly /usr/local/bin
2d3363299fbc31d0
}

evaluatefn() {
  assign_variables || exit "${?}"
  if [ "${#}" = "0" ]; then
    true
  else
    case "${1}" in
    # No user-declared variables
    *)
      echo_error 'Justfile does not contain variable `'"${1}"'`.'
      exit 1
      ;;
    esac
  fi
}

choosefn() {
  echo 'run' 'run-gui' 'run-debug' 'run-gui-debug' 'experiment' 'test' 'nonprod-compile' 'prod-compile' 'compile-gui' 'generate-git-hash' 'build' 'apply-license-header' 'install-license-tool' 'symlink' \
    | "${DEFAULT_SHELL}" ${DEFAULT_SHELL_ARGS} "${CHOOSER}"
}


#########################################################################################
# Main entrypoint                                                                       #
#########################################################################################

RUN_DEFAULT='true'
while [ "${#}" -gt 0 ]; do
  case "${1}" in 
  
  # User-defined recipes
  run)
    shift
    assign_variables || exit "${?}"
    FUN_run "$@"
    RUN_DEFAULT='false'
    ;;

  run-gui)
    shift
    assign_variables || exit "${?}"
    FUN_run_gui "$@"
    RUN_DEFAULT='false'
    ;;

  run-debug)
    shift
    assign_variables || exit "${?}"
    FUN_run_debug "$@"
    RUN_DEFAULT='false'
    ;;

  run-gui-debug)
    shift
    assign_variables || exit "${?}"
    FUN_run_gui_debug "$@"
    RUN_DEFAULT='false'
    ;;

  experiment)
    shift
    assign_variables || exit "${?}"
    FUN_experiment "$@"
    RUN_DEFAULT='false'
    ;;

  test)
    shift
    assign_variables || exit "${?}"
    FUN_test "$@"
    RUN_DEFAULT='false'
    ;;

  nonprod-compile)
    shift
    assign_variables || exit "${?}"
    FUN_nonprod_compile "$@"
    RUN_DEFAULT='false'
    ;;

  prod-compile)
    shift
    assign_variables || exit "${?}"
    FUN_prod_compile "$@"
    RUN_DEFAULT='false'
    ;;

  compile-gui)
    shift
    assign_variables || exit "${?}"
    FUN_compile_gui "$@"
    RUN_DEFAULT='false'
    ;;

  generate-git-hash)
    shift
    assign_variables || exit "${?}"
    FUN_generate_git_hash "$@"
    RUN_DEFAULT='false'
    ;;

  build)
    shift
    assign_variables || exit "${?}"
    FUN_build "$@"
    RUN_DEFAULT='false'
    ;;

  apply-license-header)
    shift
    assign_variables || exit "${?}"
    FUN_apply_license_header "$@"
    RUN_DEFAULT='false'
    ;;

  install-license-tool)
    shift
    assign_variables || exit "${?}"
    FUN_install_license_tool "$@"
    RUN_DEFAULT='false'
    ;;

  symlink)
    shift
    assign_variables || exit "${?}"
    FUN_symlink "$@"
    RUN_DEFAULT='false'
    ;;
  
  # Built-in flags
  -l|--list)
    shift 
    listfn "$@"
    RUN_DEFAULT="false"
    break
    ;;
    
  -f|--justfile)
    shift 2
    echo "${YELLOW}warning${NOCOLOR}: ${BOLD}-f/--justfile not implemented by just.sh${NOCOLOR}" >&2
    ;;

  --summary)
    shift
    summarizefn "$@"
    RUN_DEFAULT="false"
    break
    ;;

  --list-heading)
    shift
    LIST_HEADING="${1}"
    shift
    ;;

  --list-prefix)
    shift
    LIST_PREFIX="${1}"
    shift
    ;;

  -u|--unsorted)
    SORTED="false"
    shift
    ;;

  --shell)
    shift
    DEFAULT_SHELL="${1}"
    shift
    ;;

  --shell-arg)
    shift
    DEFAULT_SHELL_ARGS="${1}"
    shift
    ;;
    
  -V|--version)
    shift
    echo "just.sh 0.0.2"
    echo
    echo "https://github.com/jstrieb/just.sh"
    RUN_DEFAULT="false"
    break
    ;;

  -h|--help)
    shift
    usage
    RUN_DEFAULT="false"
    break
    ;;

  --choose)
    shift
    assign_variables || exit "${?}"
    TARGET="$(choosefn)"
    env "${0}" "${TARGET}" "$@"
    RUN_DEFAULT="false"
    break
    ;;
    
  --chooser)
    shift
    CHOOSER="${1}"
    shift
    ;;
    
  *=*)
    assign_variables || exit "${?}"
    NAME="$(
        echo "${1}" | tr '\n' '\r' | sed 's/\([^=]*\)=.*/\1/g' | tr '\r' '\n'
    )"
    VALUE="$(
        echo "${1}" | tr '\n' '\r' | sed 's/[^=]*=\(.*\)/\1/g' | tr '\r' '\n'
    )"
    shift
    set_var "${NAME}" "${VALUE}"
    ;;

  --set)
    shift
    assign_variables || exit "${?}"
    NAME="${1}"
    shift
    VALUE="${1}"
    shift
    set_var "${NAME}" "${VALUE}"
    ;;
    
  --dump)
    RUN_DEFAULT="false"
    dumpfn "$@"
    break
    ;;
    
  --evaluate)
    shift
    RUN_DEFAULT="false"
    evaluatefn "$@"
    break
    ;;
    
  --init)
    shift
    RUN_DEFAULT="false"
    if [ -f "justfile" ]; then
      echo_error "Justfile "'`'"$(realpath "justfile")"'`'" already exists"
      exit 1
    fi
    cat > "justfile" <<EOF
default:
    echo 'Hello, world!'
EOF
    echo 'Wrote justfile to `'"$(realpath "justfile")"'`' 2>&1 
    break
    ;;

  -*)
    echo_error "Found argument '${NOCOLOR}${YELLOW}${1}${NOCOLOR}${BOLD}' that wasn't expected, or isn't valid in this context"
    echo >&2
    err_usage
    exit 1
    ;;

  *)
    assign_variables || exit "${?}"
    echo_error 'Justfile does not contain recipe `'"${1}"'`.'
    exit 1
    ;;
  esac
done

if [ "${RUN_DEFAULT}" = "true" ]; then
  assign_variables || exit "${?}"
  FUN_run "$@" 
fi


#########################################################################################
#                                                                                       #
# This script was auto-generated from a Justfile by just.sh.                            #
#                                                                                       #
# Generated on 2024-04-30 with just.sh version 0.0.2.                                   #
# https://github.com/jstrieb/just.sh                                                    #
#                                                                                       #
# Run `./just.sh --dump` to recover the original Justfile.                              #
#                                                                                       #
#########################################################################################


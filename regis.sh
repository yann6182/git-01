#!/usr/bin/env bash

# Hey ! Don't look at this code, it's private !
# Anyway, you don't want to know how Regis thinks.

# set -x

REGIS_STEP_DIR="./steps"
REGIS_ZIP_PATH="./regis.zip"
STEPS=(init 1 2 3 4 5 6)

GIT_ROOT_DIR=

CURRENT_STEP=
RG_WORKSPACE=
RG_STEPS=
RG_WORKDIR=
DONE_FILE=

BOLD='\033[0;1m'
DIM='\033[0;2m'
UNDERLINED='\033[0;4m'
BLINK='\033[0;5m'
REVERSE='\033[0;7m'
HIDDEN='\033[0;8m'

DEFAULT='\033[0;39m'
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;97m'
NC='\033[0m' # No Color

FORCE="0"

init() {
  assert_is_git
  GIT_ROOT_DIR=$(git rev-parse --show-toplevel)

  RG_WORKDIR="${GIT_ROOT_DIR}/.git/.regis"
  RG_WORKSPACE="${RG_WORKDIR}/workspace/"
  RG_STEPS="${RG_WORKDIR}/steps"
  DONE_FILE="${RG_WORKDIR}/done"
}

main() {
  init
  move_steps_ressources_if_exist
  clean_regis_downloaded_docs_if_exists
  parse_args "$@"
  assert_step_exists "${CURRENT_STEP}"
  exec_step "${CURRENT_STEP}"
}

move_steps_ressources_if_exist(){
  mkdir -p "${RG_STEPS}"
  if [ -d ${REGIS_STEP_DIR} ]; then
    mv ${REGIS_STEP_DIR}/* "${RG_STEPS}"
  fi
}

clean_regis_downloaded_docs_if_exists(){
  rm -rf "${REGIS_STEP_DIR}"
  rm -f "${REGIS_ZIP_PATH}"
}

parse_args () {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--force)
        FORCE="1"
        shift # past value
        ;;
      *)
        CURRENT_STEP="$1" # save positional arg
        shift # past argument
        ;;
    esac
  done
}

array_contains () {
  local seeking=$1; shift
  local in=1
  for element; do
    if [[ ${element} == ${seeking} ]]; then
      in=0
      break
    fi
  done

  return ${in}
}

assert_step_exists() {
  step=$1
  array_contains "${step}" "${STEPS[@]}"

  if [[ $? -ne 0 ]] ; then
    printf "${RED} '${step}' n'est pas supporté. Seules les valeurs suivantes le sont : "
    printf "${STEPS[@]}"
    printf "${NC}\n"

    exit 1
  fi
}

assert_is_git() {
  git status > /dev/null 2>&1
  if [[ $? -ne 0 ]] ; then
    printf "${RED}Aucun repertoire git n'a été trouvé${NC}\n";
    exit 3
  fi;
}



exec_step() {
  STEP="${1}"
  STEP_DIR="${RG_STEPS}/${STEP}"
  touch ${DONE_FILE};
  DONE=$(cat ${DONE_FILE} | grep ${STEP_DIR} | wc -l)

  if [ ${DONE} -gt 0 ] && [ "${FORCE}" != "1" ]; then
    echo "La step ${STEP} a déjà été joué. Utilise l'option --force pour la jouer de nouveau."
  fi;

  STEP_FILE="${STEP_DIR}/step.sh"

  if [ ! -f .git/config ]; then
    touch .git/config
  fi;

  if [ -f ${STEP_FILE} ]; then
    chroot_rg_workspace
    REMOTE=$(git remote)
    git reset --hard > /dev/null
    git symbolic-ref refs/remotes/origin/HEAD > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      git remote set-head ${REMOTE} $(git rev-parse --abbrev-ref HEAD)
    fi;

    MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    # execute the step
    ORIGIN=$REMOTE CWD=${STEP_DIR} MAIN_BRANCH=${MAIN_BRANCH} ${STEP_FILE}

    if [ $? -eq 0 ]; then
      echo ${STEP_DIR} >> ${DONE_FILE}
    fi;

    clean_rg_workspace > /dev/null 2>&1
  fi;

  MESSAGE_FILE="${STEP_DIR}.txt"
  if [ -f ${MESSAGE_FILE} ]; then
    cat ${MESSAGE_FILE}
    echo ""
  fi;

}


chroot_rg_workspace() {

  cd ${GIT_ROOT_DIR}
  rm -rf ${RG_WORKSPACE} .regis-workspace

  files=$(ls -A)
  mkdir .regis-workspace
  cp -r $files .regis-workspace > /dev/null 2>&1
  mv .regis-workspace ${RG_WORKSPACE} > /dev/null 2>&1
  cd ${RG_WORKSPACE}

  # change committer name
  git config --add user.name Regis
  git config --add user.email regis@regis.com
}

clean_rg_workspace() {
  cd ${GIT_ROOT_DIR}
  # rm -rf ${RG_WORKSPACE}
}

main "$@"

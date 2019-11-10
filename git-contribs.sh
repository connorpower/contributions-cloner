#!/bin/bash

set -e

###############################################################################
## Constants
###############################################################################

readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
readonly SCRIPT=$(basename "${0}")
readonly DEFAULT_DESTINATION="${DIR}/git-contribs"

###############################################################################
## Constants
###############################################################################

main() {

    if [ "${1}" = "help" ] || [ "${1}" = "--help" ]; then
        long_usage
        return 0
    fi

    declare -a authors
    destination="${DEFAULT_DESTINATION}"

    while getopts ":ha:d:" o; do
        case "${o}" in
            h)
                long_usage
                return 0
                ;;
            a)
                authors+=("$OPTARG")
                ;;
            d)
                destination=("$OPTARG")
                ;;
            *)
                short_usage
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    repos=$@

    if [ ${#authors[@]} -lt 1 ]; then
        echo -e "At least one author email must be specified.\n" 1>&2
        short_usage
        return 1
    fi

    if [ -z "${repos}" ]; then
        echo -e "At least one source repository must be specified.\n" 1>&2
        short_usage
        return 1
    fi

    if [ ! -d "${destination}/.git" ]; then
        git init "${destination}"
    fi

    author_pattern_string=$(printf '\|%s' "${authors[@]}")
    author_pattern_string=${author_pattern_string:2}

    backup_contributions
}

###############################################################################
## Functions
###############################################################################

short_usage() {
    echo "Usage: ${SCRIPT} [-h|--help] -a email1 [-a email2, -a ...] [-d destination] repo1 [repo2, ...]" 1>&2
}

long_usage() {
    short_usage
    echo ""
    echo "${SCRIPT} creates a backup of contributions made to a repository in order to preserve"
    echo "the GitHub contributions graph when leaving a GitHub Organization. For any commit found"
    echo "by a specified author email, a dummy file will be created and comitted with a timestamp"
    echo "equal to the original commit. Dummy commits corresponding to each of the repositoreis"
    echo "will be created on their own headless branches in the 'destination-repository'. No"
    echo "information will be copied from the source repositories other the date of the commit."
    echo ""
    echo "    Options:"
    echo "        --help | -h"
    echo "            Prints this menu"
    echo "        -a email"
    echo "            A list of author emails which, if responsible for a commit in any of the"
    echo "            listed repositories, will result in a dummy commit being created."
    echo "        -d destination"
    echo "            The repository into which the dummy commits will be made. If not specified,"
    echo "            this will default to './git-contribs'."
    echo ""
    echo "    Arguments:"
    echo "        repo"
    echo "            A list of local git repositories which will be scanned for commits made by"
    echo "            the specified author emails."
}

backup_contributions() {
    for r in ${repos}; do
        repo_name=$(basename "${r}")

        # Find all commits matching the specified authors
        commits=$(
            cd "${r}"
        )

        if [ ! -z "${commits}" ]; then
            # Create a directory for the repository
            (cd "${destination}"; mkdir -p "${repo_name}")
        fi

        ifs_bkp=$IFS
        IFS=$'\n'
        for commit in $commits; do
            author=$(echo "${commit}" | awk '{ print $1 }')
            timestamp=$(echo "${commit}" | awk '{ print $2 }')
            message="${author} committed on ${timestamp}"

            export GIT_COMMITTER_DATE="${timestamp}"
            export GIT_AUTHOR_DATE="${timestamp}"

            (
                cd "${destination}"
                echo "${message}" >> "${repo_name}/${timestamp}.txt"
                git add -f "${repo_name}/${timestamp}.txt"
                git commit --date="${timestamp}" -m "${message}"
            )
        done
        IFS=$ifs_bkp
    done
}


###############################################################################
## Entry Point
###############################################################################

main "${@}"

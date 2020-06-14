#!/bin/bash

set -e

###############################################################################
## Constants
###############################################################################

readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
readonly SCRIPT=$(basename "${0}")
readonly DEFAULT_DESTINATION="${DIR}/contributions"

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
                echo $(short_usage) 1>&2
                return 1
                ;;
        esac
    done
    shift $((OPTIND-1))

    repos=$@

    if [ ${#authors[@]} -lt 1 ]; then
        echo -e "At least one author email must be specified.\n" 1>&2
        echo $(short_usage) 1>&2
        return 1
    fi

    if [ -z "${repos}" ]; then
        echo -e "At least one source repository must be specified.\n" 1>&2
        echo $(short_usage) 1>&2
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
    echo "Usage: ${SCRIPT} [-h|--help] -a email1 [-a email2, -a ...]"
    echo "       [-d destination] repo1 [repo2, ...]"
}

long_usage() {
    short_usage
    echo ""
    echo "${SCRIPT} clones commit timestamps in order to preserve your"
    echo "GitHub contribution graph when leaving a GitHub organization that"
    echo "a repository belongs to. No source code or otherwise identifying"
    echo "information is cloned other than '<your email> comitted on"
    echo "<timestamp>'. This is all the information that the GitHub"
    echo "contributions graph requires."
    echo ""
    echo "${SCRIPT} works by scanning a list of repositoreis for any"
    echo "commits authored by your email and creating a dummy placeholder file"
    echo "in a backup repository in it's place with the same timestamp as the"
    echo "original commit. No information will be copied from the source"
    echo "source repos other the date of the commit."
    echo ""
    echo "    Options:"
    echo "        --help | -h"
    echo "            Prints this menu"
    echo "        -a email"
    echo "            A list of author emails which, if responsible for a"
    echo "            commit in any of the listed repositories, will result in"
    echo "            a dummy commit being created."
    echo "        -d destination"
    echo "            The repository into which the dummy commits will be"
    echo "            made. If not specified, this will default to"
    echo "            './contributions'."
    echo ""
    echo "    Arguments:"
    echo "        repo"
    echo "            A list of local git repositories which will be scanned"
    echo "            for commits made by the specified author emails."
}

backup_contributions() {
    for r in ${repos}; do
        repo_name=$(basename "${r}")

        # Find all commits matching the specified authors
        commits=$(
            cd "${r}"
            git log \
                --author="${author_pattern_string}" \
                --format='format:%ae %aI' \
                --all \
                --reverse
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

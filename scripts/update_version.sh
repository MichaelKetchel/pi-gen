#!/bin/bash -e

REQUEST_BUMP="$1"

setup_version() {
    if [ -f "/tmp/semver" ]; then
	return 0
    fi

    wget -q -O /tmp/semver \
	https://raw.githubusercontent.com/fsaintjacques/semver-tool/master/src/semver
    chmod +x /tmp/semver
}

# Print version with "v" prefix
get_latest_tag() {
    tag="$(git describe --tags --abbrev=0 --match="v[0-9].[0-9].[0-9]*")"
    echo "${tag}"
}

update_version() {
    setup_version

    last_version="${LAST_VERSION}"
    if [ "${GIT_HASH}" == "${LAST_VERSION_HASH}" ]; then
	echo "${last_version}"
	exit 0
    fi

    REQUEST_BUMP="$(echo "${REQUEST_BUMP}" | tr '[:upper:]' '[:lower:]')"

    case "${REQUEST_BUMP}" in
	break|major) is_breaking=1 ;;
	feat|minor) is_feature=1 ;;
	rc) is_rc=1 ;;
	patch) is_patch=1 ;;
	*)
	    # Guess the bump from commit history
	    commits="${COMMITS_FROM_LAST}"

	    is_breaking="$(echo "${commits}" | awk '{ print $2; }' | { grep "BREAK:" || :; })"
	    is_feature="$(echo "${commits}" | awk '{ print $2; }' | { grep "feat:" || :; })"
	    is_rc="$(echo "${last_version}" | { grep -- "-rc" || :; })"
	    ;;
    esac

    if [ -n "${is_breaking}" ]; then
	ver_bump="major"
    elif [ -n "${is_feature}" ]; then
	ver_bump="minor"
    elif [ -n "${is_rc}" ]; then
	ver_bump="prerel rc."
    else
	ver_bump="patch"
    fi

    # Update version according to commit history
    new_version=$(/tmp/semver bump ${ver_bump} "${last_version}")

    # Add -rc to the new version code
    if [ -n "${is_rc}" ] && [ "${ver_bump}" != "prerel rc." ]; then
	new_version=$(/tmp/semver bump ${ver_bump} "${new_version}")
    fi

    echo "v${new_version}"
}

update_version
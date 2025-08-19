#!/bin/bash

# Targeting mdBook version v0.4.52 as of Aug, 2025
# Requires mdBook semantic version input from command line
# For example 'binary-validation.sh v0.1.15'

MDBOOK_VERSION=$1
API_ARRAY=$(mktemp)
declare JSON

json_setup() {

	local JQUERY="
	map(select(.tag_name==\"${MDBOOK_VERSION}\"))
	| .[].assets
	| map(select(.name==\"mdbook-${MDBOOK_VERSION}-x86_64-unknown-linux-gnu.tar.gz\"))
	"
	printf "mdBook Binary script executing..."
	printf "\nQuerying GH API for JSON %s mdBook record...\n\n" "${MDBOOK_VERSION}"

	curl -L \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		https://api.github.com/repos/rust-lang/mdBook/releases >"${API_ARRAY}"

	JSON=$(jq "${JQUERY}" "${API_ARRAY}")
}

api_fetch() {

	local DL_URL
	local API_DIGEST
	local ZIP
	local ZIP_DIGEST

	printf "\nParsing API JSON return data and assigning variables...\n\n"

	DL_URL="$(jq -r '.[].browser_download_url' <<<"${JSON}")"
	API_DIGEST="$(jq -r '.[].digest' <<<"${JSON}" | cut -d: -f2)"
	ZIP="$(jq -r '.[].name' <<<"${JSON}")"

	printf "%3s %s\n" "URL:" "${DL_URL}" "API_DIGEST:" "${API_DIGEST}" "ZIP:" "${ZIP}"
	printf "\nFetching binary...\nCalculating ZIP digest...\n\n"

	curl -LO "$DL_URL"
	ZIP_DIGEST=$(sha256sum "${PWD}/${ZIP}" | awk '{print $1}')

	printf "\nZIP_DIGEST: %s\n" "${ZIP_DIGEST}"

	if [[ "${API_DIGEST}" = "${ZIP_DIGEST}" ]]; then
		printf "\nDigest check succeeded!"
		tar xfz "${ZIP}" && rm -f "${ZIP}" "${API_ARRAY}"
		printf "\nCleaning up...\nmdBook binary unzipped and ready for execution!\n"
		exit 0
	else
		printf "\nThe API digest appears to be different than the downloaded binary digest:\n"
		printf "%2s %s\n" "API sha:" "${API_DIGEST}" "ZIP sha:" "${ZIP_DIGEST}"
		printf "\nDumping JSON and cleaning up...\n\n"
		cat "${JSON}"
		rm -f "${ZIP}" "${API_ARRAY}"
		exit 1
	fi

}

if [[ -n $1 ]]; then

	json_setup
	api_fetch

else
	printf "This script requires an mdBook version as an argument, for example 'binary-validation.sh v0.1.15'"
	exit 1
fi

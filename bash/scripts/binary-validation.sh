#!/bin/bash

# Targeting mdBook version v0.4.52 as of Aug, 2025
# Only requests 5 latest release records, remove ?per_page=5 to fetch all
# Requires mdBook semantic version input from command line
# For example 'binary-validation.sh v0.1.15'

set -euo pipefail

MDBOOK_VERSION=$1
declare json

json_setup() {

	local jquery="
	map(select(.tag_name==\"${MDBOOK_VERSION}\"))
	| .[].assets
	| map(select(.name==\"mdbook-${MDBOOK_VERSION}-x86_64-unknown-linux-gnu.tar.gz\"))
	"
	printf "mdBook Binary script executing..."
	printf "\nQuerying GH API for JSON %s mdBook record..." "${MDBOOK_VERSION}"

	json="$(gh api repos/rust-lang/mdBook/releases?per_page=5 --jq "${jquery}" ||
		{
			printf "\nSomething may have gone wrong with the GH API request."
			exit 1
		} 1>&2)"
}

api_fetch() {

	local dl_url
	local api_digest
	local zip
	local zip_digest

	if [[ -n "${json}" ]]; then
		printf "\nParsing API JSON return data and assigning variables...\n\n"

		dl_url="$(jq -r '.[].browser_download_url' <<<"${json}")"
		api_digest="$(jq -r '.[].digest' <<<"${json}" | cut -d: -f2)"
		zip="$(jq -r '.[].name' <<<"${json}")"

		printf "%3s %s\n" "URL:" "${dl_url}" "API_DIGEST:" "${api_digest}" "ZIP:" "${zip}"
		printf "\nFetching binary...\nCalculating ZIP digest...\n\n"

		curl -LO --progress-bar "$dl_url"
		zip_digest=$(sha256sum "./${zip}" | awk '{print $1}')

		printf "\nZIP_DIGEST: %s\n" "${zip_digest}"

		if [[ "${api_digest}" = "${zip_digest}" ]]; then
			printf "\nDigest check succeeded!\nCleaning up...\nmdBook binary unzipped and ready for execution!"
			tar xfz "${zip}"
			rm -f "${zip}"
			exit 0
		else
			printf "\nThe API digest appears to be different than the downloaded binary digest:"
			printf "\n%2s %s" "API sha:" "${api_digest}" "ZIP sha:" "${zip_digest}"
			printf "\n\nDumping JSON record and cleaning up...\n\n"
			rm -f "${zip}"
			echo "${json}" | jq '.'
			exit 1
		fi

	else
		printf "\nThe processed JSON record appears to be empty, queried version may not exist...\nExiting..."
		exit 1
	fi
}

reg_pattern="^v([[:digit:]]+\.){2}[[:digit:]]+$"

if [[ $1 =~ ${reg_pattern} && -n $1 ]]; then

	json_setup
	api_fetch

else
	printf "This script requires an mdBook version as an argument and to observe mdBook's semantic versioning, for example 'binary-validation.sh v0.4.20'"
	exit 1
fi

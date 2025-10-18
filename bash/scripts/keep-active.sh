#!/bin/bash

declare -a PATHS=(home about join certify verify)
declare CURL_REQ_STRING=
declare BASE_URL=https://prolug.org/

function keep_warm {

	for item in "${PATHS[@]}"; do
		CURL_REQ_STRING+="${BASE_URL}${item} "
	done

	curl -sL --rate 60/m --retry 3 --retry-delay 2 ${CURL_REQ_STRING} >/dev/null
	exit 0
}

keep_warm

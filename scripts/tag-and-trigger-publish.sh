#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o noglob

TAG_NAME="v0.0.1"
git tag -a "${TAG_NAME}" -m "releasing version ${TAG_NAME}"
git push origin "${TAG_NAME}"

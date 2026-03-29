#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="${ROOT_DIR}/statsqr.koplugin"
RELEASE_DIR="${ROOT_DIR}/release"
VERSION="$(grep -E 'version = "' "${PLUGIN_DIR}/_meta.lua" | sed -E 's/.*"([0-9.]+)".*/\1/')"
ZIP_NAME="statsqr.koplugin.v${VERSION}.zip"

mkdir -p "${RELEASE_DIR}"
rm -f "${RELEASE_DIR}/${ZIP_NAME}"

(
  cd "${ROOT_DIR}"
  zip -r "${RELEASE_DIR}/${ZIP_NAME}" "statsqr.koplugin" >/dev/null
)

echo "Created ${RELEASE_DIR}/${ZIP_NAME}"

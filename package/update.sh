#!/usr/bin/env bash
# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

BASE_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb"
SOURCE_JSON=${SOURCE_JSON:-"$(dirname "${BASH_SOURCE[0]}")/source.json"}

get_field() {
  local field="$1"
  local metadata="$2"

  sed -n "s/^$field: //p" <<< "$metadata" | head -n 1
}

fetch_metadata() {
  local architecture="$1"

  curl --fail --location --silent --show-error \
    "$BASE_URL/dists/stable/main/binary-$architecture/Packages.gz" \
    | gzip --decompress --stdout
}

read_source() {
  local system="$1"
  local architecture="$2"
  local prefix="$3"
  local metadata
  local package
  local metadata_architecture
  local version
  local filename
  local sha256
  local hash

  metadata=$(fetch_metadata "$architecture")
  package=$(get_field Package "$metadata")
  metadata_architecture=$(get_field Architecture "$metadata")
  version=$(get_field Version "$metadata")
  filename=$(get_field Filename "$metadata")
  sha256=$(get_field SHA256 "$metadata")

  if [[ "$package" != chatgpt ]]; then
    echo "Expected package 'chatgpt' for $architecture, got '$package'" >&2
    exit 1
  fi

  if [[ "$metadata_architecture" != "$architecture" ]]; then
    echo "Expected architecture '$architecture', got '$metadata_architecture'" >&2
    exit 1
  fi

  if [[ -z "$version" || -z "$filename" || ! "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Incomplete or invalid repository metadata for $architecture" >&2
    exit 1
  fi

  hash=$(nix hash convert --hash-algo sha256 --to sri "$sha256")

  printf -v "${prefix}_SYSTEM" '%s' "$system"
  printf -v "${prefix}_VERSION" '%s' "$version"
  printf -v "${prefix}_URL" '%s' "$BASE_URL/$filename"
  printf -v "${prefix}_HASH" '%s' "$hash"
}

read_source x86_64-linux amd64 AMD64
read_source aarch64-linux arm64 ARM64

sourceDirectory=$(dirname "$SOURCE_JSON")
temporaryFile=$(mktemp "$sourceDirectory/.source.json.XXXXXXXX")
trap 'rm -f -- "$temporaryFile"' EXIT

jq -n \
  --arg amd64_system "$AMD64_SYSTEM" \
  --arg amd64_version "$AMD64_VERSION" \
  --arg amd64_url "$AMD64_URL" \
  --arg amd64_hash "$AMD64_HASH" \
  --arg arm64_system "$ARM64_SYSTEM" \
  --arg arm64_version "$ARM64_VERSION" \
  --arg arm64_url "$ARM64_URL" \
  --arg arm64_hash "$ARM64_HASH" \
  '{
    ($arm64_system): {
      "version": $arm64_version,
      "src": { "url": $arm64_url, "hash": $arm64_hash }
    },
    ($amd64_system): {
      "version": $amd64_version,
      "src": { "url": $amd64_url, "hash": $amd64_hash }
    }
  }' > "$temporaryFile"

if [[ -f "$SOURCE_JSON" ]] && cmp --silent "$temporaryFile" "$SOURCE_JSON"; then
  echo "chatgpt is already up to date" >&2
  exit 0
fi

mv -- "$temporaryFile" "$SOURCE_JSON"
trap - EXIT

echo "updated chatgpt metadata to x86_64=$AMD64_VERSION, aarch64=$ARM64_VERSION" >&2

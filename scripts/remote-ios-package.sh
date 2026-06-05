#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE="${REMOTE:-origin}"
WORKFLOW_BRANCH="${WORKFLOW_BRANCH:-$(git branch --show-current)}"
RELEASE_TAG="${RELEASE_TAG:-latest-unsigned-ipa}"
ASSET_NAME="${ASSET_NAME:-RecordReader-unsigned.ipa}"
OUTPUT_DIR="${OUTPUT_DIR:-build/remote-ios}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-3600}"
POLL_SECONDS="${POLL_SECONDS:-30}"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_clean_worktree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git status --short >&2
    fail "tracked files have uncommitted changes. Commit or stash before remote packaging."
  fi
}

repo_slug() {
  local url slug
  url="$(git config --get "remote.${REMOTE}.url")"
  [[ -n "$url" ]] || fail "remote '${REMOTE}' is not configured."

  case "$url" in
    git@github.com:*)
      slug="${url#git@github.com:}"
      ;;
    https://github.com/*)
      slug="${url#https://github.com/}"
      ;;
    *)
      fail "remote '${REMOTE}' is not a GitHub URL: $url"
      ;;
  esac

  slug="${slug%.git}"
  echo "$slug"
}

remote_tag_sha() {
  git ls-remote --tags "$REMOTE" "refs/tags/${RELEASE_TAG}" "refs/tags/${RELEASE_TAG}^{}" \
    | awk '{print $1}' \
    | tail -n 1
}

download_release_asset() {
  local repo="$1"
  local sha="$2"
  local branch_slug output tmp url

  branch_slug="$(echo "$WORKFLOW_BRANCH" | tr '/ ' '--')"
  output="${OUTPUT_DIR}/RecordReader-${branch_slug}-${sha:0:12}.ipa"
  tmp="${output}.tmp"
  url="https://github.com/${repo}/releases/download/${RELEASE_TAG}/${ASSET_NAME}"

  mkdir -p "$OUTPUT_DIR"
  curl --fail --location --retry 3 --retry-delay 2 "$url" --output "$tmp"
  mv "$tmp" "$output"
  echo "$output"
}

require_clean_worktree

[[ -n "$WORKFLOW_BRANCH" ]] || fail "could not determine current branch."

SHA="$(git rev-parse HEAD)"
REPO="$(repo_slug)"

echo "Pushing ${WORKFLOW_BRANCH} (${SHA}) to ${REMOTE}..."
git push "$REMOTE" "HEAD:${WORKFLOW_BRANCH}"

echo "Waiting for ${RELEASE_TAG} to point at ${SHA}..."
SECONDS_WAITED=0
while (( SECONDS_WAITED <= TIMEOUT_SECONDS )); do
  TAG_SHA="$(remote_tag_sha || true)"
  if [[ "$TAG_SHA" == "$SHA" ]]; then
    echo "Remote build completed for ${SHA}. Downloading ${ASSET_NAME}..."
    ARTIFACT_PATH="$(download_release_asset "$REPO" "$SHA")"
    echo "Downloaded: ${ARTIFACT_PATH}"
    exit 0
  fi

  if [[ -n "${TAG_SHA:-}" ]]; then
    echo "Still waiting: ${RELEASE_TAG} is ${TAG_SHA}, expected ${SHA}."
  else
    echo "Still waiting: ${RELEASE_TAG} is not available yet."
  fi

  sleep "$POLL_SECONDS"
  SECONDS_WAITED=$((SECONDS_WAITED + POLL_SECONDS))
done

fail "timed out waiting for ${RELEASE_TAG}. Check the iOS GitHub Actions workflow for ${WORKFLOW_BRANCH}."

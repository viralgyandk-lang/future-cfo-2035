#!/usr/bin/env bash
# Future CFO_DP — One-command publish to GitHub (Mac/Linux)
# Prerequisites: GitHub CLI  (brew install gh && gh auth login)
#
# Usage:
#   chmod +x publish-episode.sh
#   ./publish-episode.sh /path/to/downloads 2026-09-04-when-operating-profit-changes-meaning
#
set -euo pipefail

SOURCE_DIR="${1:-}"
EPISODE_FOLDER="${2:-}"
YEAR="${3:-$(date +%Y)}"
MONTH="${4:-$(date +%m)}"
REPO="${REPO:-viralgyandk-lang/future-cfo-2035}"
BRANCH="${BRANCH:-main}"

if [[ -z "$SOURCE_DIR" || -z "$EPISODE_FOLDER" ]]; then
  echo "Usage: $0 /path/to/downloads EPISODE-FOLDER-NAME [YYYY] [MM]"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI first: https://cli.github.com/"
  exit 1
fi

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
REMOTE_PATH="episodes/$YEAR/$MONTH/$EPISODE_FOLDER"
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "Source: $SOURCE_DIR"
echo "Target: $REPO/$REMOTE_PATH"

mapfile -t FILES < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( \
  -name 'Future_CFO_DP_Daily_*.pptx' -o \
  -name 'Future_CFO_DP_Daily_*.pdf' -o \
  -name 'Future_CFO_DP_Daily_*_Indian_English.mp3' -o \
  -name 'Future_CFO_DP_Daily_*_Synced.mp4' -o \
  -name 'Future_CFO_Daily_*.pptx' -o \
  -name 'Future_CFO_Daily_*.pdf' -o \
  -name 'Future_CFO_Daily_*_Indian_English.mp3' -o \
  -name 'Future_CFO_Daily_*_Synced.mp4' \
\) | sort -u)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No episode media found in $SOURCE_DIR"
  exit 1
fi

echo "Found ${#FILES[@]} file(s)"
printf '  - %s\n' "${FILES[@]##*/}"

gh repo clone "$REPO" "$TMP" -- --depth 1 --branch "$BRANCH"
mkdir -p "$TMP/$REMOTE_PATH"
for f in "${FILES[@]}"; do
  cp "$f" "$TMP/$REMOTE_PATH/"
done

cd "$TMP"
git config user.email "publisher@future-cfo-dp.local"
git config user.name "Future CFO_DP Publisher"
git add "$REMOTE_PATH"
if git diff --staged --quiet; then
  echo "Nothing new to commit."
else
  git commit -m "Publish media for $EPISODE_FOLDER"
  git push origin "$BRANCH"
  echo "PUSHED. Website index refreshes in 1-2 minutes."
  echo "Site: https://viralgyandk-lang.github.io/future-cfo-2035/"
fi

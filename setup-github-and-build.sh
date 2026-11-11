#!/usr/bin/env bash
# =============================================================================
# alo 2.4.2 — one-command: create repo -> push -> restore models -> run iOS build
# Run this ON YOUR OWN COMPUTER (where YOU are logged in to GitHub).
#
# It automates every programmable step. The ONLY thing it cannot do is sign the
# app with your Apple identity — Apple requires that to happen under your own
# Apple account (free Apple ID via Sideloadly, or a $99 Developer cert).
#
# Prerequisites (install once):
#   - git            https://git-scm.com
#   - GitHub CLI gh  https://cli.github.com   then run:  gh auth login
#
# Usage:
#   ./setup-github-and-build.sh <repo-name> [path/to/alo-release.apk]
#
# Examples:
#   ./setup-github-and-build.sh alo-ios
#   ./setup-github-and-build.sh alo-ios ~/Downloads/alo-2.4.2.apk
# =============================================================================
set -euo pipefail

REPO_NAME="${1:-}"
APK_PATH="${2:-}"

if [[ -z "$REPO_NAME" ]]; then
  echo "Usage: $0 <repo-name> [path/to/alo-release.apk]" >&2
  exit 1
fi

command -v git >/dev/null || { echo "ERROR: install git first." >&2; exit 1; }
command -v gh  >/dev/null || { echo "ERROR: install GitHub CLI (gh) and run 'gh auth login'." >&2; exit 1; }

echo "==> Verifying GitHub login"
gh auth status >/dev/null 2>&1 || { echo "ERROR: run 'gh auth login' first." >&2; exit 1; }
OWNER="$(gh api user -q .login)"
echo "    Logged in as: $OWNER"

cd "$(dirname "$0")"

echo "==> Initializing git repository"
[[ -d .git ]] || git init -q
git add -A
git commit -q -m "alo 2.4.2 iOS — final reviewed source" || echo "    (nothing new to commit)"
git branch -M main

echo "==> Creating PRIVATE GitHub repo '$OWNER/$REPO_NAME' and pushing"
if gh repo view "$OWNER/$REPO_NAME" >/dev/null 2>&1; then
  echo "    Repo already exists — pushing to it."
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
  git push -u origin main
else
  gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
fi

# --- Optional: upload the release APK as a secret so CI restores voice models ---
if [[ -n "$APK_PATH" ]]; then
  [[ -f "$APK_PATH" ]] || { echo "ERROR: APK not found at $APK_PATH" >&2; exit 1; }
  echo "==> Uploading release APK as encrypted secret ALO_RELEASE_APK_B64"
  base64 -i "$APK_PATH" 2>/dev/null > .apk.b64 || base64 "$APK_PATH" > .apk.b64
  gh secret set ALO_RELEASE_APK_B64 --repo "$OWNER/$REPO_NAME" < .apk.b64
  rm -f .apk.b64
  echo "    Secret set. CI will restore + hash-verify the 360 model files."
else
  echo "==> No APK provided: build will compile WITHOUT voice model assets."
  echo "    Re-run with the APK path to get a functional build."
fi

echo "==> Launching the iOS build workflow (unsigned, free macOS runner)"
gh workflow run "ios-build.yml" --repo "$OWNER/$REPO_NAME" --ref main
sleep 6
gh run list --repo "$OWNER/$REPO_NAME" --workflow "ios-build.yml" --limit 1

cat <<EOF

-------------------------------------------------------------------------------
DONE (everything automatable is done).
Watch the build:   gh run watch --repo $OWNER/$REPO_NAME
When it finishes, download the artifact:
    gh run download --repo $OWNER/$REPO_NAME --name alo-ios-unsigned

FINAL STEP — only you can do this (Apple's rule, needs YOUR Apple account):
  * Free route : install 'Sideloadly', plug in iPhone, sign in with your free
                 Apple ID, drag alo-unsigned.ipa onto it. (re-sign every 7 days)
  * Signed IPA : add your Apple cert (.p12)+profile+Team ID as repo secrets,
                 then re-run the workflow with build_signed=true.
-------------------------------------------------------------------------------
EOF

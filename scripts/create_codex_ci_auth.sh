#!/usr/bin/env bash
set -euo pipefail

# Create a CI-only Codex auth.json in an isolated HOME and print its Base64 form.
# Do not reuse your normal ~/.codex/auth.json for CI.

if ! command -v codex >/dev/null 2>&1; then
  echo "codex command not found. Install it first: npm install -g @openai/codex" >&2
  exit 1
fi

WORKDIR="${1:-$(mktemp -d /tmp/codex-ci-auth.XXXXXX)}"
export HOME="$WORKDIR"

mkdir -p "$HOME"

echo "Using isolated HOME: $HOME" >&2
echo "A browser login may open. Complete login with the CI-dedicated account/session." >&2

codex logout >/dev/null 2>&1 || true
codex login

AUTH_PATH="$HOME/.codex/auth.json"
if [ ! -f "$AUTH_PATH" ]; then
  echo "auth.json was not created at $AUTH_PATH" >&2
  exit 1
fi

echo >&2
echo "Created: $AUTH_PATH" >&2
echo "Register the following Base64 value as GitHub Secret CODEX_AUTH_JSON:" >&2
echo >&2
base64 < "$AUTH_PATH" | tr -d '\n'
echo

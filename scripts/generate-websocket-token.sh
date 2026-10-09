#!/usr/bin/env sh
set -eu
umask 077

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: generate-websocket-token.sh NEW_DIRECTORY" >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || { echo "OpenSSL is required" >&2; exit 1; }

case "$1" in
  /*) destination=$1 ;;
  *) destination=./$1 ;;
esac
if ! mkdir -m 700 "$destination" 2>/dev/null; then
  echo "Credential directory must not already exist and its parent must exist" >&2
  exit 1
fi

complete=false
cleanup() {
  exit_code=$?
  trap - EXIT HUP INT TERM
  if [ "$complete" != true ]; then
    rm -f "$destination/token" "$destination/token.sha256"
    rmdir "$destination"
  fi
  exit "$exit_code"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

token=$(openssl rand -hex 32)
[ "${#token}" -eq 64 ]
printf '%s' "$token" > "$destination/token"
unset token
digest=$(openssl dgst -sha256 -r "$destination/token")
digest=${digest%% *}
case "$digest" in
  *[!0-9a-f]*|'') echo "Could not derive credential digest" >&2; exit 1 ;;
esac
[ "${#digest}" -eq 64 ]
printf '%s\n' "$digest" > "$destination/token.sha256"
unset digest
complete=true

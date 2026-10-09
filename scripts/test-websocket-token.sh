#!/usr/bin/env sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
generator="$REPO_ROOT/scripts/generate-websocket-token.sh"

mode() {
  stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
}

umask 022
sh "$generator" "$scratch/first" > "$scratch/stdout"
[ ! -s "$scratch/stdout" ]
[ "$(mode "$scratch/first")" = 700 ]
[ "$(mode "$scratch/first/token")" = 600 ]
[ "$(mode "$scratch/first/token.sha256")" = 600 ]
[ "$(wc -c < "$scratch/first/token" | tr -d ' ')" = 64 ]
expected=$(openssl dgst -sha256 -r "$scratch/first/token" | awk '{print $1}')
[ "$(cat "$scratch/first/token.sha256")" = "$expected" ]

sh "$generator" "$scratch/second" > "$scratch/stdout"
[ ! -s "$scratch/stdout" ]
if cmp -s "$scratch/first/token" "$scratch/second/token"; then exit 1; fi
if cmp -s "$scratch/first/token.sha256" "$scratch/second/token.sha256"; then exit 1; fi
cp "$scratch/first/token" "$scratch/canary"
if sh "$generator" "$scratch/first" > "$scratch/stdout" 2> "$scratch/stderr"; then exit 1; fi
cmp -s "$scratch/first/token" "$scratch/canary"
[ "$(mode "$scratch/first/token")" = 600 ]

ln -s "$scratch/first" "$scratch/link"
if sh "$generator" "$scratch/link" > "$scratch/stdout" 2> "$scratch/stderr"; then exit 1; fi
[ -L "$scratch/link" ]
cmp -s "$scratch/first/token" "$scratch/canary"
printf 'preserve\n' > "$scratch/file"
if sh "$generator" "$scratch/file" > "$scratch/stdout" 2> "$scratch/stderr"; then exit 1; fi
[ "$(cat "$scratch/file")" = preserve ]

# Two writers must not replace one another's credential directory.
sh "$generator" "$scratch/race" > "$scratch/race-1.out" 2> "$scratch/race-1.err" &
first_pid=$!
sh "$generator" "$scratch/race" > "$scratch/race-2.out" 2> "$scratch/race-2.err" &
second_pid=$!
first_rc=0
second_rc=0
wait "$first_pid" || first_rc=$?
wait "$second_pid" || second_rc=$?
[ "$((first_rc + second_rc))" = 1 ]
[ "$(mode "$scratch/race")" = 700 ]
[ "$(mode "$scratch/race/token")" = 600 ]
expected=$(openssl dgst -sha256 -r "$scratch/race/token" | awk '{print $1}')
[ "$(cat "$scratch/race/token.sha256")" = "$expected" ]

mkdir "$scratch/bin"
for utility in mkdir rm rmdir; do
  ln -s "$(command -v "$utility")" "$scratch/bin/$utility"
done
export REAL_OPENSSL
REAL_OPENSSL=$(command -v openssl)
cat > "$scratch/bin/openssl" <<'FAILURE'
#!/bin/sh
if [ "$1" = "$FAIL_OPERATION" ]; then exit 1; fi
exec "$REAL_OPENSSL" "$@"
FAILURE
chmod 755 "$scratch/bin/openssl"
for operation in rand dgst; do
  if FAIL_OPERATION="$operation" PATH="$scratch/bin" /bin/sh "$generator" "$scratch/partial-$operation" > "$scratch/stdout" 2> "$scratch/stderr"; then exit 1; fi
  [ ! -e "$scratch/partial-$operation" ]
  [ ! -s "$scratch/stdout" ]
done
cmp -s "$scratch/first/token" "$scratch/canary"

printf 'private_modes=pass digest_matches=pass independent_tokens=pass overwrite_refusal=pass symlink_refusal=pass canaries_preserved=pass concurrent_creation=pass partial_failure_cleanup=pass\n'

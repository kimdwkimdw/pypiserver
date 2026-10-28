#!/usr/bin/env bash
set -euo pipefail

dockerfile="${1:-$(dirname "$0")/../Dockerfile}"
[[ "$(grep -c -- 'gpgconf --kill all' "$dockerfile")" == 1 ]]
cleanup=$(sed -n '/gpgconf --kill all/{s/[[:space:]]*\\$//;p;}' "$dockerfile")

# Exercise the actual cleanup clause without executing downloads or GPG agents.
for fixture in '0 0 0:1' '1 0 1:0' '0 1 0:1'; do
    read -r verify_status cleanup_status expected <<< "$fixture"
    observed=$(GPG_VERIFY_EXIT="$verify_status" GPG_CLEANUP_EXIT="$cleanup_status" \
        CLEANUP_CMD="$cleanup" bash <<'BASH'
gpgconf() { return "$GPG_CLEANUP_EXIT"; }
verify() { return "$GPG_VERIFY_EXIT"; }
gosu() { executed=1; }
executed=0
eval "verify $CLEANUP_CMD && gosu"
status=$?
printf '%s:%s' "$status" "$executed"
BASH
    )
    [[ "$observed" == "$expected" ]] || {
        printf 'Signature guard failed: expected %s, got %s\n' "$expected" "$observed" >&2
        exit 1
    }
done
printf 'Signature verification failures cannot execute the downloaded binary.\n'

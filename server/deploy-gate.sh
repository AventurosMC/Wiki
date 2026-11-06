#!/usr/bin/env bash
# SSH forced command for the wiki deploy key. Only two commands get through:
#   rsync --server ...   upload, confined by rrsync to $WIKI_ROOT/staging
#   activate <sha>       snapshot staging as releases/<sha>, point current at it
# The key can therefore never write to releases/ or current directly.
set -euo pipefail

WIKI_ROOT="${WIKI_ROOT:-/srv/wiki-dist}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
RRSYNC="${RRSYNC:-/usr/bin/rrsync}"

cmd="${SSH_ORIGINAL_COMMAND:-}"

die() {
    echo "deploy-gate: $*" >&2
    exit 1
}

case "$cmd" in
    "rsync --server "*)
        # -wo: the key can upload but not download. -munge: any symlink in
        # the upload is neutered, so nothing served can point outside.
        exec "$RRSYNC" -wo -munge "$WIKI_ROOT/staging"
        ;;

    "activate "*)
        sha="${cmd#activate }"
        [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid release id"

        cd "$WIKI_ROOT"
        exec 9>.deploy.lock
        flock 9

        [[ -f staging/index.html ]] || die "staging/index.html is missing"

        release="releases/$sha"
        # A release dir is immutable once created: re-deploying the same
        # commit reuses it instead of deleting what current may point at.
        if [[ ! -d "$release" ]]; then
            rm -rf -- "$release.tmp"
            # Hard links, not copies: rsync replaces changed files in
            # staging by rename, so a release never sees later uploads.
            cp -al staging "$release.tmp"
            mv -T -- "$release.tmp" "$release"
        fi
        touch -- "$release"

        ln -sfn -- "$release" current.tmp
        mv -T -- current.tmp current

        live="$(readlink current)"
        # Release names are validated hex SHAs, so parsing ls is safe here.
        # shellcheck disable=SC2012
        ls -1dt releases/*/ | sed 's:/$::' | tail -n "+$((KEEP_RELEASES + 1))" |
            while IFS= read -r old; do
                [[ "$old" == "$live" ]] || rm -rf -- "$old"
            done

        echo "deploy-gate: $release is live"
        ;;

    *)
        die "command not allowed"
        ;;
esac

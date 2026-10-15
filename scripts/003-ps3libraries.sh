#!/usr/bin/env bash

set -Eeuo pipefail

source "$PS3DEV_ROOT_DIR/utils/common.sh"

PS3LIBRARIES_REPOSITORY="${PS3LIBRARIES_REPO_URL:-https://github.com/ps3dev/ps3libraries.git}"
PS3LIBRARIES_REF="${PS3LIBRARIES_REF:-master}"
PS3LIBRARIES_SOURCE_DIR="$PS3DEV_BUILD_DIR/ps3libraries"

require_compiler ppu-gcc
require_compiler spu-gcc

checkout_repository \
    "$PS3LIBRARIES_REPOSITORY" \
    "$PS3LIBRARIES_REF" \
    "$PS3LIBRARIES_SOURCE_DIR"

# cairographics.org is intermittently unavailable to CI for the legacy Pixman
# and Cairo tarballs. Both exact archives are mirrored by FreeDesktop. Keep
# pinned versions, sizes, SHA-256 hashes, and build scripts unchanged; only
# rewrite the release host in the downloaded ps3libraries archive index.
# Set PS3LIBRARIES_RELEASE_MIRROR to use a different compatible mirror.
CAIRO_RELEASE_HOST="https://cairographics.org/releases/"
CAIRO_RELEASE_MIRROR="${PS3LIBRARIES_RELEASE_MIRROR:-https://cairo.freedesktop.org/releases/}"
PS3LIBRARIES_ARCHIVE_LIST="$PS3LIBRARIES_SOURCE_DIR/archives/archives.txt"

if [[ -f "$PS3LIBRARIES_ARCHIVE_LIST" ]] && grep -Fq -- "$CAIRO_RELEASE_HOST" "$PS3LIBRARIES_ARCHIVE_LIST"; then
    ARCHIVE_LIST_TMP="${PS3LIBRARIES_ARCHIVE_LIST}.tmp.$$"

    awk -v old="$CAIRO_RELEASE_HOST" -v new="$CAIRO_RELEASE_MIRROR" '
        {
            for (i = 1; i <= NF; i++) {
                if (index($i, old) == 1) {
                    $i = new substr($i, length(old) + 1)
                }
            }
            print
        }
    ' "$PS3LIBRARIES_ARCHIVE_LIST" > "$ARCHIVE_LIST_TMP"

    mv "$ARCHIVE_LIST_TMP" "$PS3LIBRARIES_ARCHIVE_LIST"
    heading "Using FreeDesktop mirror for legacy Pixman/Cairo releases"
fi

heading "Building ps3libraries"

(
    cd "$PS3LIBRARIES_SOURCE_DIR"

    if [[ -n "${PS3LIBRARIES_STAGES:-}" ]]; then
        # Intentional splitting: each requested library stage becomes
        # one positional argument to libraries.sh.
        # shellcheck disable=SC2086
        ./libraries.sh $PS3LIBRARIES_STAGES
    else
        ./libraries.sh
    fi
)

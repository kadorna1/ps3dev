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

# cairographics.org is intermittently unavailable to CI for legacy Pixman/Cairo
# tarballs. Use the X.Org archive for Pixman and the FreeDesktop mirror for
# Cairo. Keep upstream versions, sizes, SHA-256 hashes, and build scripts
# unchanged; only rewrite source URLs in the downloaded archive index.
# Override the Cairo mirror with PS3LIBRARIES_CAIRO_RELEASE_MIRROR.
PIXMAN_PRIMARY_URL="https://cairographics.org/releases/pixman-0.20.0.tar.gz"
PIXMAN_MIRROR_URL="${PS3LIBRARIES_PIXMAN_URL:-https://xorg.freedesktop.org/archive/individual/lib/pixman-0.20.0.tar.gz}"
CAIRO_RELEASE_HOST="https://cairographics.org/releases/"
CAIRO_RELEASE_MIRROR="${PS3LIBRARIES_CAIRO_RELEASE_MIRROR:-https://cairo.freedesktop.org/releases/}"
PS3LIBRARIES_ARCHIVE_LIST="$PS3LIBRARIES_SOURCE_DIR/archives/archives.txt"

if [[ -f "$PS3LIBRARIES_ARCHIVE_LIST" ]] && grep -Fq -- "$CAIRO_RELEASE_HOST" "$PS3LIBRARIES_ARCHIVE_LIST"; then
    ARCHIVE_LIST_TMP="${PS3LIBRARIES_ARCHIVE_LIST}.tmp.$"

    awk -v pixman_old="$PIXMAN_PRIMARY_URL" -v pixman_new="$PIXMAN_MIRROR_URL" \
        -v cairo_old="$CAIRO_RELEASE_HOST" -v cairo_new="$CAIRO_RELEASE_MIRROR" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == pixman_old) {
                    $i = pixman_new
                } else if (index($i, cairo_old) == 1) {
                    $i = cairo_new substr($i, length(cairo_old) + 1)
                }
            }
            print
        }
    ' "$PS3LIBRARIES_ARCHIVE_LIST" > "$ARCHIVE_LIST_TMP"

    mv "$ARCHIVE_LIST_TMP" "$PS3LIBRARIES_ARCHIVE_LIST"
    heading "Using X.Org/FreeDesktop mirrors for legacy Pixman/Cairo releases"
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

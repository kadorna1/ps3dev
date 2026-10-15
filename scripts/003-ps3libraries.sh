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

# cairographics.org may return 404 in CI even though the release archive is
# available from the FreeDesktop mirror. Keep the pinned Cairo version and the
# existing SHA-256/size checks; only change the source URL in the downloaded
# ps3libraries checkout. Override the mirror with PS3LIBRARIES_CAIRO_URL.
CAIRO_ARCHIVE_LIST="$PS3LIBRARIES_SOURCE_DIR/archives/archives.txt"
CAIRO_PRIMARY_URL="https://cairographics.org/releases/cairo-1.10.0.tar.gz"
CAIRO_MIRROR_URL="${PS3LIBRARIES_CAIRO_URL:-https://cairo.freedesktop.org/releases/cairo-1.10.0.tar.gz}"

if [[ -f "$CAIRO_ARCHIVE_LIST" ]] && grep -Fq -- "$CAIRO_PRIMARY_URL" "$CAIRO_ARCHIVE_LIST"; then
    CAIRO_ARCHIVE_LIST_TMP="${CAIRO_ARCHIVE_LIST}.tmp.$$"

    awk -v old="$CAIRO_PRIMARY_URL" -v new="$CAIRO_MIRROR_URL" '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == old) {
                    $i = new
                }
            }
            print
        }
    ' "$CAIRO_ARCHIVE_LIST" > "$CAIRO_ARCHIVE_LIST_TMP"

    mv "$CAIRO_ARCHIVE_LIST_TMP" "$CAIRO_ARCHIVE_LIST"
    heading "Using FreeDesktop mirror for Cairo 1.10.0"
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

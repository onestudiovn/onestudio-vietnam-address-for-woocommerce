#!/usr/bin/env bash
# Builds the WordPress.org submission package from the current HEAD commit
# via `git archive`, which automatically applies .gitattributes export-ignore
# (dev-only files like .gitignore/.gitattributes/README.md/bin/ never make it
# in - no manual exclusion list to keep in sync). On top of that, this script
# additionally strips the bundled .po/.mo translation files: WordPress.org
# generates and serves these itself via translate.wordpress.org/GlotPress,
# and the .pot template is kept. The GitHub release build (build-github-zip.sh)
# is unaffected - it's the same `git archive` output with translations intact.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLUG="onestudio-vietnam-address-for-woocommerce"
VERSION="$(grep -m1 '^ \* Version:' "$REPO_ROOT/vn-address-woocommerce.php" | sed -E 's/.*Version:[[:space:]]*//')"
OUT_DIR="${1:-$REPO_ROOT/build}"

rm -rf "$OUT_DIR/$SLUG"
mkdir -p "$OUT_DIR/$SLUG"

cd "$REPO_ROOT"
# Piping `git archive` straight into `tar -x` is flaky under `pipefail`: tar
# can close its end of the pipe as soon as it hits the end-of-archive
# padding, before git archive finishes writing, which sends git archive a
# SIGPIPE and aborts this script (exit 141) right before the .po/.mo
# stripping below ever runs - silently, since the extraction itself had
# already fully succeeded. Route through a temp file instead so there's no
# pipe to race.
ARCHIVE_TMP="$(mktemp)"
git archive -o "$ARCHIVE_TMP" HEAD
tar -x -C "$OUT_DIR/$SLUG" -f "$ARCHIVE_TMP"
rm -f "$ARCHIVE_TMP"
rm -rf "$OUT_DIR/$SLUG/bin"
find "$OUT_DIR/$SLUG/languages" \( -name '*.po' -o -name '*.mo' \) -print0 | xargs -0 rm -f

cd "$OUT_DIR"
ZIP_NAME="${SLUG}-${VERSION}-wporg.zip"
rm -f "$ZIP_NAME"
zip -rq "$ZIP_NAME" "$SLUG" -x "*.DS_Store"

echo "Built: $OUT_DIR/$ZIP_NAME"
echo "Contains $(unzip -l "$ZIP_NAME" | tail -1 | awk '{print $2}') files"
echo "Language files included:"
unzip -l "$ZIP_NAME" | grep '/languages/' || echo "  (none)"

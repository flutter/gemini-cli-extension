#!/usr/bin/env bash

set -e

tag_name=${GITHUB_REF#refs/tags/}
archive_name="flutter.tar"
dill_file="flutter_launcher_mcp.dill"
trap 'rm -f "$compile_log"' EXIT
compile_log="$(mktemp --tmpdir compile_log_XXXX)"

function build_dill() (
  CDPATH= cd flutter_launcher_mcp && \
  dart pub get && \
  dart compile kernel bin/flutter_launcher_mcp.dart -o "../$dill_file" 2>&1 > "$compile_log"
)

build_dill || \
  (echo "Failed to compile $dill_file"; \
   cat "$compile_log"; \
   rm -f "$compile_log"; \
   exit 1)

rm -f "$compile_log"

# Create the archive of the extension sources that are in the git ref.
git archive --format=tar -o "$archive_name" "$tag_name" \
  gemini-extension.json \
  commands/ \
  LICENSE \
  README.md \
  flutter.md

# Append the compiled kernel file to the archive.
tar --append --file="$archive_name" "$dill_file"
rm -f "$dill_file"
gzip "$archive_name"

echo "ARCHIVE_NAME=$archive_name.gz"
#!/usr/bin/env bash

set -ex

unset CD_PATH

# Get the directory where the script is located.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The root of the repository.
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

GITHUB_REF=${GITHUB_REF:-refs/tags/HEAD}
tag_name=${GITHUB_REF#refs/tags/}
os=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ $os == 'darwin' ]]; then
  arch=$(uname -m | tr '[:upper:]' '[:lower:]')
else
  arch='x64'
fi

archive_name="$os.$arch.flutter.tar"
exe_file="flutter_launcher_mcp.exe"
trap 'rm -f "$compile_log"' EXIT
compile_log="$(mktemp --tmpdir compile_log_XXXX)"

function build_exe() (
  CDPATH= cd flutter_launcher_mcp && \
  dart pub get && \
  dart compile exe bin/flutter_launcher_mcp.dart -o "../$exe_file" 2>&1 > "$compile_log"
)

build_exe || \
  (echo "Failed to compile $exe_file"; \
   cat "$compile_log"; \
   rm -f "$compile_log"; \
   exit 1)

rm -f "$compile_log" "$archive_name"

# Create the archive of the extension sources that are in the git ref.
git archive --format=tar -o "$archive_name" "$tag_name" \
  gemini-extension.json \
  commands/ \
  LICENSE \
  README.md \
  flutter.md

# Append the compiled kernel file to the archive.
tar --append --file="$archive_name" "$exe_file"
rm -f "$exe_file"
gzip --force "$archive_name"
archive_name="${archive_name}.gz"

if [[ -n $GITHUB_ENV ]]; then
  echo "ARCHIVE_NAME=$archive_name" >> $GITHUB_ENV
else
  echo "Archive written to $archive_name"
fi
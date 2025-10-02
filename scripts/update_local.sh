#!/bin/bash
set -e

unset CD_PATH

# Get the directory where the script is located.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The root of the repository.
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# The name of the archive that will be produced.
os=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ $os == 'darwin' ]]; then
  arch=$(uname -m | tr '[:upper:]' '[:lower:]')
else
  arch='x64'
fi

ARCHIVE_NAME="$os.$arch.flutter.tar.gz"

# The directory where the extension will be installed.
INSTALL_DIR="$HOME/.gemini/extensions/flutter"

# Run the build script.
echo "Building the release..."
"$SCRIPT_DIR/build_release.sh"

# Remove all non-dot files from the install directory.
echo "Clearing the installation directory..."
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"/*
else
  mkdir -p "$INSTALL_DIR"
fi

# Extract the archive to the install directory.
echo "Extracting the archive..."
tar -xzf "$REPO_ROOT/$ARCHIVE_NAME" -C "$INSTALL_DIR"

echo "Installation complete."
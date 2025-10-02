#!/usr/bin/env bash

# Bumps the version number to the given version number.

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <new_version>"
    exit 1
fi

NEW_VERSION="$1"

# Get the absolute path to the directory containing this script.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Update gemini-extension.json
jq --arg version "$NEW_VERSION" '.version = $version' "$REPO_ROOT/gemini-extension.json" > "$REPO_ROOT/gemini-extension.json.tmp" && command mv -f "$REPO_ROOT/gemini-extension.json.tmp" "$REPO_ROOT/gemini-extension.json"

# Update pubspec.yaml
yq -y ".version = \"$NEW_VERSION\"" "$REPO_ROOT/flutter_launcher_mcp/pubspec.yaml" > "$REPO_ROOT/flutter_launcher_mcp/pubspec.yaml.tmp" && mv "$REPO_ROOT/flutter_launcher_mcp/pubspec.yaml.tmp" "$REPO_ROOT/flutter_launcher_mcp/pubspec.yaml"

# Check and update CHANGELOG.md
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"
if ! grep -q "## $NEW_VERSION" "$CHANGELOG_FILE"; then
  echo "Adding version $NEW_VERSION to $CHANGELOG_FILE"
  TEMP_FILE=$(mktemp)
  {
    echo "## $NEW_VERSION"
    echo ""
    echo "- TODO: Describe the changes in this version."
    echo ""
    cat "$CHANGELOG_FILE"
  } > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CHANGELOG_FILE"
fi

# Update README.md
sed -i.bak 's/  flutter_launcher_mcp: \^.*/  flutter_launcher_mcp: ^'"$NEW_VERSION/g" "$REPO_ROOT/flutter_launcher_mcp/README.md" && \
  rm "$REPO_ROOT/flutter_launcher_mcp/README.md.bak"

echo "Version bumped to $NEW_VERSION"
#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building SideSync..."
swift build --product SideSyncApp -c release 2>&1

echo "Creating app bundle..."
bash build-app.sh

echo "Installing to /Applications..."
rm -rf /Applications/SideSync.app
cp -r SideSync.app /Applications/

echo ""
echo "Done! SideSync is installed at /Applications/SideSync.app"
echo "You can launch it from Spotlight or the Applications folder."

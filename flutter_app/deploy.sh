#!/bin/bash

echo "Building Galeno Genie for iPhone 12..."

# Build without code signing
flutter build ios --debug --no-codesign

# Sign with ad-hoc certificate (no keychain access needed)
echo "Signing app with ad-hoc certificate..."
codesign --force --deep --sign - build/ios/Debug-iphoneos/Runner.app

# Install on device
echo "Installing on iPhone 12..."
xcrun devicectl device install app --device 00008101-001D44303C08801E build/ios/Debug-iphoneos/Runner.app

echo "Done! Check your iPhone 12 for the Galeno Genie app."
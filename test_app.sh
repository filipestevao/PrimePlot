#!/bin/bash
# Copyright (C) 2026 Filipe Estevão
# This program is licensed under the GPLv3. See LICENSE for details.

# test_app.sh - Run the PrimePlot desktop application

echo "🚀 Starting PrimePlot..."

# Navigate to the Flutter frontend directory
cd frontend || exit 1

# Fetch dependencies (useful if you just pulled new changes)
flutter pub get

# Run the app. Flutter automatically detects your host OS (Linux, Windows, or macOS).
# If you have multiple devices connected, you might need to append e.g. `-d linux`.
flutter run

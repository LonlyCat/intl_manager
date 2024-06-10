#!/bin/bash

# Check if 'dynamic_online_intl_manager' project has been built in release mode
#if [ ! -f "dynamic_online_intl_manager/build/web/index.html" ]; then
#  # Build 'dynamic_online_intl_manager' project in release mode
#  echo "Building 'dynamic_online_intl_manager' project in release mode..."
#  flutter build web --release
#fi
flutter build web --release

# Run 'dynamic_online_intl_serve' project in background mode
echo "Running 'dynamic_online_intl_serve' project in background mode..."
dart run dynamic_online_intl_serve/bin/dynamic_online_intl_serve.dart --root=$PWD/dynamic_online_intl_serve &
# Judge whether the 'dynamic_online_intl_serve' project is running
if [ $? -ne 0 ]; then
  echo "Failed to run 'dynamic_online_intl_serve' project."
  exit 1
fi

# Start 'dynamic_online_intl_manager' project with python3
echo "Starting 'dynamic_online_intl_manager' project..."
python3 -m http.server --directory dynamic_online_intl_manager/build/web/
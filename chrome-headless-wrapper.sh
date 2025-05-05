#!/bin/bash
# Wrapper script to launch Google Chrome headless for Flutter

# Find the real Chrome executable
REAL_CHROME=$(which google-chrome-stable)

# Add headless flags. --no-sandbox is often required in containers.
# Pass all original arguments ($@) to the real Chrome.
exec "$REAL_CHROME" --headless --disable-gpu --no-sandbox "$@"

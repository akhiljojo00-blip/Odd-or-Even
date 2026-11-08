#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.1"
FLUTTER_DIR="$(pwd)/.flutter_sdk"

echo "=== [ODD OR EVEN] Vercel Build Pipeline Starting ==="

# 1. Enforce mandatory Supabase compile-time configuration
if [ -z "${SUPABASE_URL:-}" ]; then
  echo "FATAL: SUPABASE_URL environment variable is required for production builds, but is missing or empty." >&2
  echo "Configure SUPABASE_URL in Vercel Project Settings -> Environment Variables." >&2
  exit 1
fi

if [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "FATAL: SUPABASE_ANON_KEY environment variable is required for production builds, but is missing or empty." >&2
  echo "Configure SUPABASE_ANON_KEY in Vercel Project Settings -> Environment Variables." >&2
  exit 1
fi

# 2. Idempotent & Cached SDK Setup pinned to verified release
if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing pinned Flutter SDK v${FLUTTER_VERSION}..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  echo "Using cached Flutter SDK from ${FLUTTER_DIR}."
fi

# 3. Safe Directory & PATH Configuration
git config --global --add safe.directory "$FLUTTER_DIR" || true
export PATH="$FLUTTER_DIR/bin:$PATH"

# 4. Environment Diagnostics
flutter config --no-analytics
flutter --version

# 5. Pre-cache Web Engine Artifacts
flutter precache --web

# 6. Production Release Build
echo "Building Flutter Web release bundle..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# 7. Post-Build Output Verification
if [ ! -f "build/web/index.html" ] || [ ! -f "build/web/main.dart.js" ]; then
  echo "FATAL: Build output validation failed. Required web artifacts missing in build/web." >&2
  exit 1
fi

echo "=== [ODD OR EVEN] Build Successful! Output generated in build/web ==="

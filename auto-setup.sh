#!/usr/bin/env bash
set -Eeuo pipefail
echo "[Auto-Setup] Installing One-Click Recovery Toolkit..."

# Copy toolkit to project root
TARGET_DIR="${1:-.}"
mkdir -p "$TARGET_DIR"
cp -r ./* "$TARGET_DIR" 2>/dev/null || true
cd "$TARGET_DIR"

# Set permissions
chmod +x *.sh tools/*.sh 2>/dev/null || true

# Init git hook
mkdir -p .git/hooks
cat > .git/hooks/post-checkout <<'HOOK'
#!/usr/bin/env bash
echo "👉 Hint: run 'make fix' before debugging (Codex trigger)."
HOOK
chmod +x .git/hooks/post-checkout

# Confirm
echo "[Auto-Setup] Complete."
echo "✅ Run 'make fix' to start recovery."

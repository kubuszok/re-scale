#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# SessionStart hook
#   1. ensure the re-scale CLI is on PATH (clone + build on first run)
#   2. auto-start the standalone Metals MCP server for Scala projects
# ─────────────────────────────────────────────────────────────

RESCALE_VERSION="0.1.6"

# Where to find / put the re-scale source tree. Override with RESCALE_HOME.
RESCALE_HOME="${RESCALE_HOME:-$HOME/.local/share/re-scale/$RESCALE_VERSION}"

# Resolve a usable re-scale binary, installing it if necessary.
# Echoes the binary path on success; returns non-zero (degrading silently)
# if it cannot be made available.
ensure_rescale() {
  # Already on PATH at the right version?
  if command -v re-scale >/dev/null 2>&1; then
    local found
    found=$(re-scale --version 2>/dev/null | awk '{print $2}' || true)
    if [ "$found" = "$RESCALE_VERSION" ]; then
      command -v re-scale
      return 0
    fi
    # Wrong version on PATH — fall through to prepend the correct one.
  fi

  # Clone if needed.
  if [ ! -f "$RESCALE_HOME/build.sbt" ]; then
    echo "[re-scale] First-time setup: cloning re-scale $RESCALE_VERSION..." >&2
    git clone --depth 1 --branch "$RESCALE_VERSION" \
      https://github.com/kubuszok/re-scale.git "$RESCALE_HOME" >&2 2>&1 || {
      echo "[re-scale] WARNING: git clone failed — re-scale CLI will not be available." >&2
      return 1
    }
  fi

  # Build if the binary is missing.
  local binary="$RESCALE_HOME/.build/re-scale-bin"
  if [ ! -f "$binary" ]; then
    echo "[re-scale] Building Scala Native binary (first time only — takes ~30s)..." >&2
    if command -v sbt >/dev/null 2>&1; then
      (cd "$RESCALE_HOME" && sbt install) >&2 2>&1 || {
        echo "[re-scale] WARNING: sbt install failed — re-scale CLI will not be available." >&2
        return 1
      }
    else
      echo "[re-scale] WARNING: sbt not on PATH — re-scale CLI will not be available." >&2
      echo "[re-scale] Install sbt (brew install sbt) and restart the session." >&2
      return 1
    fi
  fi

  # Add bin/ to PATH for this session.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"$RESCALE_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  fi
  echo "$RESCALE_HOME/bin/re-scale"
  return 0
}

# Auto-start the standalone Metals MCP server.
#   - Only for Scala / re-scale projects (.rescale dir or build.sbt present).
#   - Idempotent: `re-scale metals start` no-ops if its PID file is live, and
#     the server persists across sessions via nohup.
#   - The port is derived deterministically from the project path so several
#     open projects each get their own stable port instead of colliding on one;
#     metals-mcp regenerates the project-root .mcp.json to match.
start_metals() {
  local rs="$1"
  local proj="${CLAUDE_PROJECT_DIR:-$PWD}"

  [ -d "$proj/.rescale" ] || [ -f "$proj/build.sbt" ] || return 0
  [ -n "$rs" ] && [ -x "$rs" ] || return 0

  local h port
  h="$(printf '%s' "$proj" | cksum | cut -d' ' -f1)"
  port=$(( 7845 + (h % 1000) ))   # 7845..8844, stable per project path

  mkdir -p "$proj/.rescale"
  ( cd "$proj" && "$rs" metals start --port "$port" ) \
    >> "$proj/.rescale/.metals-hook.log" 2>&1 || true
}

RS="$(ensure_rescale || true)"
start_metals "$RS"

exit 0

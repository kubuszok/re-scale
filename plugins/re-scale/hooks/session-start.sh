#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# SessionStart hook: put the re-scale CLI on PATH.
#
# Uses a re-scale already on PATH at the pinned version; otherwise
# installs it with Coursier (`cs`) from Maven Central into
# $RESCALE_INSTALL_DIR (default ~/.local/share/re-scale/<version>/bin):
# the native executable for this OS/architecture, or, where none is
# published, a JVM launcher (needs Java 17+). Never blocks a session:
# every failure is a warning on stderr and exit 0.
# ─────────────────────────────────────────────────────────────
set -uo pipefail

RESCALE_VERSION="0.2.0"
INSTALL_DIR="${RESCALE_INSTALL_DIR:-$HOME/.local/share/re-scale/$RESCALE_VERSION/bin}"
# A Maven Central mirror (or a local repository, file:///...) can replace Central.
REPO="${RESCALE_REPOSITORY:-https://repo1.maven.org/maven2}"

warn() { echo "[re-scale] WARNING: $*" >&2; }

version_of() { "$1" --version 2>/dev/null | awk '{print $2}'; }

put_on_path() {
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  fi
}

# 1. Already on PATH at the pinned version (a manual install or a source checkout).
if command -v re-scale >/dev/null 2>&1 && [ "$(version_of re-scale)" = "$RESCALE_VERSION" ]; then
  exit 0
fi

# 2. Installed by an earlier session.
if [ -x "$INSTALL_DIR/re-scale" ] && [ "$(version_of "$INSTALL_DIR/re-scale")" = "$RESCALE_VERSION" ]; then
  put_on_path
  exit 0
fi

# 3. Install with Coursier.
CS="$(command -v cs || command -v coursier || true)"
if [ -z "$CS" ]; then
  warn "Coursier (cs) is not on PATH, so re-scale $RESCALE_VERSION cannot be installed."
  warn "Install it from https://get-coursier.io/docs/cli-installation and restart the session."
  exit 0
fi

mkdir -p "$INSTALL_DIR" 2>/dev/null || {
  warn "cannot create $INSTALL_DIR; re-scale will not be available."
  exit 0
}
LOG="$INSTALL_DIR/../install.log"

# The executable for this platform; ${version} and ${platform} are filled in by cs.
NATIVE='{"dependencies":["com.kubuszok:re-scale_native0.5_3:'"$RESCALE_VERSION"'"],"repositories":["'"$REPO"'","central"],"launcherType":"prebuilt","prebuilt":"'"$REPO"'/com/kubuszok/re-scale_native0.5_3/${version}/re-scale_native0.5_3-${version}-${platform}.bin"}'
# Fallback: a launcher running the JVM build, heap capped like the executable.
JVM='{"dependencies":["com.kubuszok:re-scale_3:'"$RESCALE_VERSION"'"],"repositories":["'"$REPO"'","central"],"mainClass":"rescale.Main","javaOptions":["-Xmx1g"]}'

# Installed AND runs here (an executable can download fine and still not start, e.g. on an older glibc).
install_with() {
  "$CS" install --install-dir "$INSTALL_DIR" --force "re-scale:$1" >> "$LOG" 2>&1 &&
    [ "$(version_of "$INSTALL_DIR/re-scale")" = "$RESCALE_VERSION" ]
}

echo "[re-scale] Installing re-scale $RESCALE_VERSION with Coursier..." >&2
: > "$LOG"
if install_with "$NATIVE"; then
  put_on_path
elif command -v java >/dev/null 2>&1 && install_with "$JVM"; then
  warn "no native re-scale for this platform; installed the JVM build (each hook call starts a JVM)."
  put_on_path
else
  warn "installing re-scale $RESCALE_VERSION failed; re-scale will not be available. Log: $LOG"
  grep -v -e '^[[:space:]]*at ' -e '^WARNING' "$LOG" 2>/dev/null | tail -n 3 | sed 's/^/[re-scale]   /' >&2
fi
exit 0

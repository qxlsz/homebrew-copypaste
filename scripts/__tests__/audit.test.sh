#!/usr/bin/env bash
# shellcheck disable=SC2250
# Same pattern as qxlsz/copypaste.fyi scripts/__tests__/bump-homebrew.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUDIT="$ROOT/scripts/audit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[[ -x "$AUDIT" ]] || chmod +x "$AUDIT"

expect_fail() {
  local name="$1"
  local file="$2"
  local needle="$3"
  if "$AUDIT" "$file" >"$TMP/out" 2>"$TMP/err"; then
    echo "expected audit to fail: $name" >&2
    cat "$TMP/out" "$TMP/err" >&2
    exit 1
  fi
  if ! grep -q "$needle" "$TMP/err"; then
    echo "expected '$needle' in audit error for $name" >&2
    cat "$TMP/err" >&2
    exit 1
  fi
  echo "caught $name"
}

cp "$ROOT/Formula/copypaste.rb" "$TMP/base.rb"

# House style: em dash (this tap dropped these in the README)
python3 - "$TMP/base.rb" "$TMP/emdash.rb" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1]).read_text()
src = src.replace(
    'desc "Pastebin CLI and self-hostable server"',
    'desc "Pastebin CLI and self-hostable server — share"',
)
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "em dash in desc" "$TMP/emdash.rb" "em or en dashes"

# desc: starts with article
python3 - "$TMP/base.rb" "$TMP/article.rb" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1]).read_text()
src = src.replace(
    'desc "Pastebin CLI and self-hostable server"',
    'desc "A pastebin CLI"',
)
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "article in desc" "$TMP/article.rb" "article"

# desc: trailing period
python3 - "$TMP/base.rb" "$TMP/period.rb" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1]).read_text()
src = src.replace(
    'desc "Pastebin CLI and self-hostable server"',
    'desc "Pastebin CLI."',
)
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "period in desc" "$TMP/period.rb" "full stop"

# FormulaAuditStrict: #{bin}/copypaste
python3 - "$TMP/base.rb" "$TMP/interp.rb" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1]).read_text()
src = src.replace('#{bin/"copypaste"}', "#{bin}/copypaste")
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "#{bin}/ interpolation" "$TMP/interp.rb" "FormulaAuditStrict"

# Cookbook: --help-only test (valid Ruby so ruby -c is not why this fails)
python3 - "$TMP/base.rb" "$TMP/help_only.rb" <<'PY'
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]).read_text()
src = re.sub(
    r"  test do\n.*?  end\n",
    '  test do\n    assert_match "paste", shell_output("#{bin/"copypaste"} --help")\n  end\n',
    src,
    count=1,
    flags=re.S,
)
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "help-only test" "$TMP/help_only.rb" "not only --help"

# Missing rust build dep
python3 - "$TMP/base.rb" "$TMP/no_rust.rb" <<'PY'
import pathlib
import sys

lines = [
    line
    for line in pathlib.Path(sys.argv[1]).read_text().splitlines(keepends=True)
    if 'depends_on "rust"' not in line
]
pathlib.Path(sys.argv[2]).write_text("".join(lines))
PY
expect_fail "missing rust dep" "$TMP/no_rust.rb" "rust"

# Live formula must pass once the audit findings are fixed.
"$AUDIT" "$ROOT/Formula/copypaste.rb"

# CI wiring: official Homebrew test-bot. Sync stays a pointer (no audit gate).
grep -q 'brew test-bot --only-tap-syntax' "$ROOT/.github/workflows/tests.yml"
grep -q 'brew test-bot --only-formulae' "$ROOT/.github/workflows/tests.yml"
if grep -q './scripts/audit.sh Formula/copypaste.rb' "$ROOT/.github/workflows/sync.yml"; then
  echo "sync.yml must not fail the pointer copy on local audit" >&2
  exit 1
fi
grep -q './scripts/audit.sh' "$ROOT/.github/workflows/audit.yml"

echo "audit.test ok"

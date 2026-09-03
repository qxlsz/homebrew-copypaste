#!/usr/bin/env bash
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
  if "$AUDIT" "$file" >"$TMP/out" 2>"$TMP/err"; then
    echo "expected audit to fail: $name" >&2
    cat "$TMP/out" "$TMP/err" >&2
    exit 1
  fi
  echo "caught $name"
}

cp "$ROOT/Formula/copypaste.rb" "$TMP/base.rb"

# desc: em dash (tap house style; last tap commit dropped these)
sed 's/self-hostable server"/self-hostable server — type, get link, share"/' \
  "$TMP/base.rb" >"$TMP/emdash.rb"
# If the live formula already has an em dash, force one in.
if ! grep -q $'—' "$TMP/emdash.rb"; then
  sed 's/desc ".*"/desc "Pastebin CLI and self-hostable server — share"/' \
    "$TMP/base.rb" >"$TMP/emdash.rb"
fi
expect_fail "em dash in desc" "$TMP/emdash.rb"

# desc: starts with article
sed 's/desc ".*"/desc "A pastebin CLI"/' "$TMP/base.rb" >"$TMP/article.rb"
expect_fail "article in desc" "$TMP/article.rb"

# desc: trailing period
sed 's/desc ".*"/desc "Pastebin CLI."/' "$TMP/base.rb" >"$TMP/period.rb"
expect_fail "period in desc" "$TMP/period.rb"

# FormulaAuditStrict: #{bin}/copypaste
sed 's|#{bin/"copypaste"}|#{bin}/copypaste|g' "$TMP/base.rb" >"$TMP/interp.rb"
if ! grep -q '#{bin}/copypaste' "$TMP/interp.rb"; then
  # Live formula still uses the old interpolation; treat that as the fail case.
  expect_fail "old bin interpolation" "$TMP/base.rb"
else
  expect_fail "#{bin}/ interpolation" "$TMP/interp.rb"
fi

# Cookbook: --help-only test
python3 - <<'PY' "$TMP/base.rb" "$TMP/help_only.rb"
import pathlib, sys, re
src = pathlib.Path(sys.argv[1]).read_text()
src = re.sub(
    r"  test do\n.*?  end\n",
    '  test do\n    assert_match "paste", shell_output("#{bin/\\"copypaste\\"} --help")\n  end\n',
    src,
    count=1,
    flags=re.S,
)
pathlib.Path(sys.argv[2]).write_text(src)
PY
expect_fail "help-only test" "$TMP/help_only.rb"

# Missing rust build dep
sed '/depends_on "rust"/d' "$TMP/base.rb" >"$TMP/no_rust.rb"
expect_fail "missing rust dep" "$TMP/no_rust.rb"

# Live formula must pass once the audit findings are fixed.
"$AUDIT" "$ROOT/Formula/copypaste.rb"

# CI wiring: official Homebrew test-bot + local audit on sync.
grep -q 'brew test-bot --only-tap-syntax' "$ROOT/.github/workflows/tests.yml"
grep -q 'brew test-bot --only-formulae' "$ROOT/.github/workflows/tests.yml"
grep -q './scripts/audit.sh Formula/copypaste.rb' "$ROOT/.github/workflows/sync.yml"
grep -q './scripts/audit.sh' "$ROOT/.github/workflows/audit.yml"

echo "audit.test ok"

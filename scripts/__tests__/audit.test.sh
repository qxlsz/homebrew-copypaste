#!/usr/bin/env bash
# Same pattern as qxlsz/copypaste.fyi scripts/__tests__/bump-homebrew.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${0}")/../.." && pwd)"
AUDIT="${ROOT}/scripts/audit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

[[ -x "${AUDIT}" ]] || chmod +x "${AUDIT}"

expect_fail() {
  local name="$1"
  local file="$2"
  local needle="$3"
  if "${AUDIT}" "${file}" >"${TMP}/out" 2>"${TMP}/err"
  then
    echo "expected audit to fail: ${name}" >&2
    cat "${TMP}/out" "${TMP}/err" >&2
    exit 1
  fi
  if ! grep -q "${needle}" "${TMP}/err"
  then
    echo "expected '${needle}' in audit error for ${name}" >&2
    cat "${TMP}/err" >&2
    exit 1
  fi
  echo "caught ${name}"
}

cp "${ROOT}/Formula/copypaste.rb" "${TMP}/base.rb"

# House style: em dash (this tap dropped these in the README)
sed 's/desc "Pastebin CLI and self-hostable server"/desc "Pastebin CLI and self-hostable server — share"/' \
  "${TMP}/base.rb" >"${TMP}/emdash.rb"
expect_fail "em dash in desc" "${TMP}/emdash.rb" "em or en dashes"

# desc: starts with article
sed 's/desc "Pastebin CLI and self-hostable server"/desc "A pastebin CLI"/' \
  "${TMP}/base.rb" >"${TMP}/article.rb"
expect_fail "article in desc" "${TMP}/article.rb" "article"

# desc: trailing period
sed 's/desc "Pastebin CLI and self-hostable server"/desc "Pastebin CLI."/' \
  "${TMP}/base.rb" >"${TMP}/period.rb"
expect_fail "period in desc" "${TMP}/period.rb" "full stop"

# FormulaAuditStrict: #{bin}/copypaste
sed 's|#{bin/"copypaste"}|#{bin}/copypaste|g' \
  "${TMP}/base.rb" >"${TMP}/interp.rb"
expect_fail "#{bin}/ interpolation" "${TMP}/interp.rb" "FormulaAuditStrict"

# Cookbook: --help-only test (valid Ruby so ruby -c is not why this fails)
sed '/^  test do$/,$d' "${TMP}/base.rb" >"${TMP}/help_only.rb"
cat >>"${TMP}/help_only.rb" <<'RUBY'
  test do
    assert_match "paste", shell_output("#{bin/"copypaste"} --help")
  end
end
RUBY
expect_fail "help-only test" "${TMP}/help_only.rb" "not only --help"

# Missing rust build dep
grep -v 'depends_on "rust"' "${TMP}/base.rb" >"${TMP}/no_rust.rb"
expect_fail "missing rust dep" "${TMP}/no_rust.rb" "rust"

# Live formula must pass once the audit findings are fixed.
"${AUDIT}" "${ROOT}/Formula/copypaste.rb"

# CI wiring: official Homebrew test-bot. Sync stays a pointer (no audit gate).
grep -q 'brew test-bot --only-tap-syntax' "${ROOT}/.github/workflows/tests.yml"
grep -q 'brew test-bot --only-formulae' "${ROOT}/.github/workflows/tests.yml"
if grep -q './scripts/audit.sh Formula/copypaste.rb' "${ROOT}/.github/workflows/sync.yml"
then
  echo "sync.yml must not fail the pointer copy on local audit" >&2
  exit 1
fi
grep -q './scripts/audit.sh' "${ROOT}/.github/workflows/audit.yml"

echo "audit.test ok"

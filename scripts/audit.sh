#!/usr/bin/env bash
# Static checks brew style / brew audit --strict apply to this tap's formula.
# Mirrors Homebrew DescHelper + FormulaAuditStrict Text, plus tap house style.
# When brew is installed, also run those commands.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FORMULA="${1:-$ROOT/Formula/copypaste.rb}"

fail() {
  echo "audit: $*" >&2
  exit 1
}

[[ -f "$FORMULA" ]] || fail "missing $FORMULA"
[[ -s "$FORMULA" ]] || fail "empty $FORMULA"

# Homebrew formulae are Ruby; syntax-check when ruby exists.
if command -v ruby >/dev/null 2>&1; then
  ruby -c "$FORMULA" >/dev/null || fail "ruby -c failed"
fi

grep -q '^class Copypaste < Formula$' "$FORMULA" || fail "expected class Copypaste < Formula"

# --- desc (Library/Homebrew/rubocops/shared/desc_helper.rb) ---
desc_line="$(grep -E '^[[:space:]]*desc "' "$FORMULA" | head -n1 || true)"
[[ -n "$desc_line" ]] || fail "formula should have a desc"
desc="$(sed -n 's/^[[:space:]]*desc "\(.*\)"[[:space:]]*$/\1/p' <<<"$desc_line")"
[[ -n "$desc" ]] || fail "desc should not be empty"
[[ "$desc" != [[:space:]]* ]] || fail "desc should not have leading spaces"
[[ "$desc" != *[[:space:]] ]] || fail "desc should not have trailing spaces"
[[ "$desc" != [Tt]he[[:space:]]* && "$desc" != [Aa]n[[:space:]]* && "$desc" != [Aa][[:space:]]* ]] \
  || fail "desc should not start with an article"
[[ "$desc" == [A-Z]* ]] || fail "desc should start with a capital letter"
[[ "$desc" != [Cc]opypaste* ]] || fail "desc should not start with the formula name"
[[ "$desc" != *. ]] || fail "desc should not end with a full stop"
# Unicode Other Symbols (emojis); brew style flags \p{So}
if command -v perl >/dev/null 2>&1; then
  perl -CSD -ne 'exit 2 if /\p{So}/' <<<"$desc" || fail "desc should not contain Unicode emojis or symbols"
fi
# This tap dropped em dashes; brew style does not, but desc should stay ASCII punctuation.
[[ "$desc" != *$'\u2014'* && "$desc" != *$'\u2013'* && "$desc" != *'—'* && "$desc" != *'–'* ]] \
  || fail "desc should not contain em or en dashes"
[[ "${#desc}" -le 80 ]] || fail "desc should be at most 80 characters (got ${#desc})"
grep -qiE 'command ?line' <<<"$desc" && fail "desc should use command-line, not command line"

# --- homepage / license / head ---
grep -q 'homepage "https://www.copypaste.fyi"' "$FORMULA" \
  || fail 'homepage should be https://www.copypaste.fyi'
grep -q 'license "MIT"' "$FORMULA" || fail 'license should be MIT'
grep -q 'head "https://github.com/qxlsz/copypaste.fyi.git", branch: "main"' "$FORMULA" \
  || fail 'head should track qxlsz/copypaste.fyi main'

# --- rust / cargo (Formula Cookbook) ---
grep -q 'depends_on "rust" => :build' "$FORMULA" || fail 'HEAD builds need depends_on "rust" => :build'
grep -q 'system "cargo", "install", \*std_cargo_args' "$FORMULA" \
  || fail 'install should use cargo install *std_cargo_args'

# --- test (FormulaAudit audit_text + FormulaAuditStrict interpolated bin) ---
grep -q 'test do' "$FORMULA" || fail "formula must define test do"

# brew audit_text: shell_output("copypaste ...") is unscoped; bin/"copypaste" is fine.
if grep -Eq '(shell_output|system|pipe_output)[(\s]+["'\'']copypaste[\s"'\'']' "$FORMULA"; then
  fail 'fully scope test calls, e.g. shell_output("#{bin/"copypaste"} --help")'
fi

if grep -q '#{bin}/copypaste' "$FORMULA"; then
  fail 'use #{bin/"copypaste"} instead of #{bin}/copypaste (FormulaAuditStrict)'
fi

grep -q 'bin/"copypaste"' "$FORMULA" || fail 'test should call bin/"copypaste"'

# Cookbook: --help / --version alone is a bad test.
if grep -q 'config init' "$FORMULA"; then
  :
elif grep -qE 'send |serve |healthcheck' "$FORMULA"; then
  :
else
  fail "test should exercise a real subcommand, not only --help"
fi

# --- service ---
grep -q 'service do' "$FORMULA" || fail "formula should declare service do"
grep -q 'copypaste", "serve"' "$FORMULA" || fail 'service should run copypaste serve'

# --- leftover style ---
if grep -q "^require ['\"]formula['\"]" "$FORMULA"; then
  fail '`require "formula"` is unnecessary'
fi
if grep -q '[[:blank:]]$' "$FORMULA"; then
  fail "trailing whitespace"
fi

# --- live brew audit when available ---
if command -v brew >/dev/null 2>&1; then
  brew style --formula "$FORMULA" || fail "brew style failed"
  # HEAD-only is allowed in third-party taps; --new would demand a stable URL.
  brew audit --strict --online --formula "$FORMULA" || fail "brew audit --strict --online failed"
fi

echo "audit ok: $FORMULA"

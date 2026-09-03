# qxlsz/copypaste

This is not a second copy of the app. It is the official Homebrew pointer.

The product is [qxlsz/copypaste.fyi](https://github.com/qxlsz/copypaste.fyi). This formula
heads that `main` branch. Improvements on the main repo are what `brew` compiles.
A workflow copies `Formula/copypaste.rb` from upstream every six hours so this tap cannot rot.

```bash
brew install qxlsz/copypaste/copypaste
brew reinstall --fetch-HEAD qxlsz/copypaste/copypaste   # pick up latest main
```

Local audit (no Homebrew required). CI also runs Homebrew's `brew test-bot`.
The six-hour sync still copies `Formula/copypaste.rb` from upstream as-is.

```bash
./scripts/audit.sh
./scripts/__tests__/audit.test.sh
```

# Synchronization & Verification Rules

Rules for maintaining parity and quality across Msingi's dual-script architecture.

## Dual-Script Parity
- **Byte-Identical**: Mandatory: Every `Build-*` function must produce identical output byte-for-byte between both scripts.
- **Mirrored Logic**: Mandatory: Every logic change in `msingi.ps1` must be mirrored in `msingi.sh` before check-in.

## Versioning & Metadata
- **Bump Version**: Mandatory: Increment the version string in both scripts for every release (see version bump table in `AGENTS.md`).
- **Sync Registry**: Mandatory: Coordinate version bumps with `agents.json` and `skills.json` schema updates.

## Automated Verification
- **Test Suite**: Mandatory: Run `python3 tests/test_suite.py` before committing (when available).
- **Syntax Check**: Mandatory: Run `bash -n msingi.sh` after any Bash edit.
- **Strict Compliance**: Mandatory: Reject any commit with failed tests or syntax warnings.

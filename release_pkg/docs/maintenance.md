# Maintenance Guidelines

Rules for modifying the Msingi codebase safely.

## Safe to Change
- `Build-*Md` function bodies (generated content).
- TUI helper styling (`Write-*`).
- `skills.json` and `agents.json` entries.

## Requires Care
- `Invoke-SkillInference` algorithm.
- Cursor positioning in `Read-*` and `Write-TwoColumn`.

## Never Change Without Review
- The here-string closing pattern.
- CRLF requirements.
- `bootstrap-record.json` schema.
- Anthropic research patterns (Sprint Contract, etc.).

## Pre-Commit Checklist
- [ ] Bash syntax: `bash -n msingi.sh` passes.
- [ ] PS7 here-string closers at column 0.
- [ ] CRLF line endings for `msingi.ps1`.
- [ ] Dual-script parity verified.

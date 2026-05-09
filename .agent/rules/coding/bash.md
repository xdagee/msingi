# Bash Standards (msingi.sh)

Standards for Msingi's mirrored implementation in Bash 4+.

## Error Handling
- **Mode Rule**: Handle errors explicitly with `|| true` — `set -e` is incompatible with Msingi's error handling model.
- **Explicit Handling**: Mandatory: Handle errors explicitly with `|| true` on optional steps.
- **Arithmetic**: Mandatory: All `((i++))` arithmetic must be followed by `|| true`.

```bash
# Good
((i++)) || true

# Bad - will cause exit under some shells
((i++))
```

## Variable Scope
- **Local Scope**: Mandatory: Use `local` for all variables inside functions.
- **Global Scope**: Use plain assignment in the main body.

## Pattern Matching
- **Fallback Logic**: Mandatory: All `grep` operations inside `$()` must have an `|| echo ""` fallback.
- **Flags**: Mandatory: Use `grep -qEi` for silent, case-insensitive matching.

# Quick Validate

Single-command validation cheat sheet for Msingi development. Run these before every commit.

## All-in-One Validation

### PowerShell 7
```powershell
# Full validation suite (run from repo root)
$errors = 0

# 1. Bash syntax
Write-Host "Checking Bash syntax..." -ForegroundColor Cyan
bash -n msingi.sh
if ($LASTEXITCODE -ne 0) { $errors++; Write-Host "FAIL: Bash syntax" -ForegroundColor Red }
else { Write-Host "OK: Bash syntax" -ForegroundColor Green }

# 2. JSON validation
Write-Host "Checking JSON files..." -ForegroundColor Cyan
foreach ($f in @("agents.json", "skills.json")) {
    try { $null = Get-Content $f -Raw | ConvertFrom-Json -ErrorAction Stop; Write-Host "OK: $f" -ForegroundColor Green }
    catch { $errors++; Write-Host "FAIL: $f - $_" -ForegroundColor Red }
}

# 3. CRLF check for PS1
Write-Host "Checking line endings..." -ForegroundColor Cyan
$content = [IO.File]::ReadAllBytes("msingi.ps1")
$lfOnly = 0; for ($i = 0; $i -lt $content.Length; $i++) {
    if ($content[$i] -eq 10 -and ($i -eq 0 -or $content[$i-1] -ne 13)) { $lfOnly++ }
}
if ($lfOnly -gt 0) { $errors++; Write-Host "FAIL: $lfOnly LF-only lines in msingi.ps1" -ForegroundColor Red }
else { Write-Host "OK: CRLF line endings" -ForegroundColor Green }

# 4. Here-string closers
Write-Host "Checking here-string closers..." -ForegroundColor Cyan
$badHere = Select-String -Path msingi.ps1 -Pattern '^\s+"@' | Where-Object { $_.Line -match '^\s+"@' -and $_.Line -notmatch '^"@' }
if ($badHere) { $errors++; Write-Host "FAIL: Here-string closers not at column 0" -ForegroundColor Red }
else { Write-Host "OK: Here-string closers" -ForegroundColor Green }

# Result
Write-Host "`n$($errors -eq 0 ? 'ALL CHECKS PASSED' : "$errors CHECKS FAILED")" -ForegroundColor ($errors -eq 0 ? 'Green' : 'Red')
```

### Bash
```bash
#!/usr/bin/env bash
errors=0

echo "Checking Bash syntax..."
bash -n msingi.sh && echo "OK: Bash syntax" || { echo "FAIL: Bash syntax"; ((errors++)); }

echo "Checking JSON files..."
python3 -c "import json; json.load(open('agents.json'))" && echo "OK: agents.json" || { echo "FAIL: agents.json"; ((errors++)) || true; }
python3 -c "import json; json.load(open('skills.json'))" && echo "OK: skills.json" || { echo "FAIL: skills.json"; ((errors++)) || true; }

echo ""
[ $errors -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$errors CHECKS FAILED"
```

## Individual Checks

| Check | PowerShell 7 | Bash |
|-------|-------------|------|
| Bash syntax | `bash -n msingi.sh` | `bash -n msingi.sh` |
| PS7 syntax | `pwsh -Command "Get-Command -Syntax msingi.ps1"` | N/A |
| agents.json | `Get-Content agents.json \| ConvertFrom-Json \| Out-Null` | `python3 -c "import json; json.load(open('agents.json'))"` |
| skills.json | `Get-Content skills.json \| ConvertFrom-Json \| Out-Null` | `python3 -c "import json; json.load(open('skills.json'))"` |
| CRLF check | See full script above | `file msingi.ps1` |
| Duplicate IDs | See `/data-validation` workflow | See `/data-validation` workflow |
| Test suite | `python3 tests/test_suite.py` | `python3 tests/test_suite.py` |

---
*Part of Msingi Agent Operations*

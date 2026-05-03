# Dry-Run Test

Commands for running both Msingi scripts in dry-run mode and comparing their scaffold output.

## Purpose

Dry-run mode previews all generated files without writing anything. By running both PS7 and Bash in dry-run mode and diffing the results, you verify dual-script parity.

## PowerShell 7 (Windows)

### Basic Dry-Run
```powershell
pwsh -File msingi.ps1 -DryRun
```

### Dry-Run to Specific Path
```powershell
pwsh -File msingi.ps1 -DryRun -Path C:\temp\test-scaffold
```

## Bash (macOS/Linux)

### Basic Dry-Run
```bash
./msingi.sh --dry-run
```

## Cross-Platform Parity Test

### Step 1: Generate PS7 Output
```powershell
pwsh -File msingi.ps1 -DryRun -Path .\test-ps7-output 2>&1 | Out-File ps7-dryrun.log
```

### Step 2: Generate Bash Output
```bash
./msingi.sh --dry-run 2>&1 | tee bash-dryrun.log
```

### Step 3: Compare Generated Files

**PowerShell:**
```powershell
# Compare file listings
$ps7Files = Get-ChildItem .\test-ps7-output -Recurse -File | ForEach-Object { $_.FullName -replace [regex]::Escape("$PWD\test-ps7-output\"), "" }
$bashFiles = Get-ChildItem .\test-bash-output -Recurse -File | ForEach-Object { $_.FullName -replace [regex]::Escape("$PWD\test-bash-output\"), "" }
Compare-Object $ps7Files $bashFiles
```

**Bash:**
```bash
diff -r test-ps7-output test-bash-output --exclude='.git'
```

### Step 4: Compare File Content

For each matching file, ensure byte-identical content:

**PowerShell:**
```powershell
Get-ChildItem .\test-ps7-output -Recurse -File | ForEach-Object {
    $relative = $_.FullName -replace [regex]::Escape("$PWD\test-ps7-output\"), ""
    $bashFile = Join-Path ".\test-bash-output" $relative
    if (Test-Path $bashFile) {
        $ps7Hash = (Get-FileHash $_.FullName).Hash
        $bashHash = (Get-FileHash $bashFile).Hash
        if ($ps7Hash -ne $bashHash) {
            Write-Host "DIFF: $relative" -ForegroundColor Red
        }
    } else {
        Write-Host "MISSING: $relative (not in Bash output)" -ForegroundColor Yellow
    }
}
```

### Step 5: Clean Up
```powershell
Remove-Item -Recurse -Force test-ps7-output, test-bash-output, ps7-dryrun.log -ErrorAction SilentlyContinue
```

```bash
rm -rf test-ps7-output test-bash-output bash-dryrun.log
```

## Expected Behaviour

- Both scripts should list the same files in the same structure
- File content should be byte-identical (excluding timestamps and platform tags)
- No errors or warnings should appear during dry-run

---
*Part of Msingi Agent Operations*

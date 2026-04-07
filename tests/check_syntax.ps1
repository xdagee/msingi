$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot ".." "msingi.ps1"),
    [ref]$tokens,
    [ref]$errors
)

if ($errors.Count -gt 0) {
    Write-Output "FAIL: $($errors.Count) parse errors found"
    foreach ($e in $errors) {
        Write-Output "  Line $($e.Extent.StartLineNumber): $($e.Message)"
    }
    exit 1
} else {
    Write-Output "PASS: msingi.ps1 — 0 parse errors"
    exit 0
}

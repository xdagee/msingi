# Bash Reference Commands

This document maps all critical Msingi development commands to Bash equivalents for macOS/Linux.

## Directory Commands

| Operation | Bash | Notes |
|-----------|------|-------|
| List files | `ls -la` | |
| List recursive | `find . -type f` | |
| Current directory | `pwd` | |
| Create directory | `mkdir -p foo` | |
| Remove directory | `rm -rf foo` | |

## File Operations

| Operation | Bash | Notes |
|-----------|------|-------|
| Read file | `cat file.txt` | |
| Write file | `echo "content" > file.txt` | |
| Append file | `echo "content" >> file.txt` | |
| Copy file | `cp src dst` | |
| Move file | `mv src dst` | |
| Delete file | `rm file.txt` | |
| File exists | `test -f file.txt` | |

## Git Commands

| Operation | Bash | Notes |
|-----------|------|-------|
| Status | `git status` | |
| Diff staged | `git diff --cached` | |
| Diff | `git diff` | |
| Add all | `git add .` | |
| Commit | `git commit -m "msg"` | |
| Log | `git log --oneline -10` | |

## Test Commands

| Operation | Bash | Notes |
|-----------|------|-------|
| Run test suite | `python3 tests/test_suite.py` | Python 3 must be in PATH |
| Bash syntax | `bash -n msingi.sh` | Must return exit code 0 |
| JSON validate (agents) | `python3 -c "import json; d=json.load(open('agents.json')); assert d['schema_version'] == '1.0'"` | |
| JSON validate (skills) | `python3 -c "import json; d=json.load(open('skills.json')); assert d['schema_version'] == '1.0'"` | |

## JSON Validation

| Operation | Bash | Notes |
|-----------|------|-------|
| Validate agents.json | `python3 -c "import json; json.load(open('agents.json'))"` | |
| Validate skills.json | `python3 -c "import json; json.load(open('skills.json'))"` | |
| Pretty print | `python3 -m json.tool file.json` | |
| Check duplicates | `python3 -c "import json; ids=[a['id'] for a in json.load(open('agents.json'))['agents']]; assert len(ids)==len(set(ids)), 'Duplicates found'"` | |

## Msingi Execution

| Operation | Bash | Notes |
|-----------|------|-------|
| Run interactive | `./msingi.sh` | Bash 4.4+ required |
| Dry-run preview | `./msingi.sh --dry-run` | |
| Check Bash version | `bash --version` | Must be 4.0+ |
| Install to PATH | `sudo ln -s "$(pwd)/msingi.sh" /usr/local/bin/msingi` | |

## Line Ending Management

| Operation | Bash | Notes |
|-----------|------|-------|
| Check for CRLF | `file msingi.ps1` | Should report "CRLF" |
| Convert LF to CRLF | `sed -i 's/$/\r/' msingi.ps1` | For PS7 compatibility |
| Convert CRLF to LF | `sed -i 's/\r$//' msingi.sh` | For Bash compatibility |
| Python fix (PS1) | `python3 -c "p='msingi.ps1'; open(p,'wb').write(open(p,'rb').read().replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))"` | Canonical method |

## Environment Variables

| Operation | Bash | Notes |
|-----------|------|-------|
| List all | `env` | |
| Get value | `echo $VAR` | |
| Set value | `export VAR="value"` | Session only |
| Set persistent | Add to `~/.bashrc` or `~/.zshrc` | Requires restart |

## macOS-Specific

| Operation | Command | Notes |
|-----------|---------|-------|
| Check Bash version | `bash --version` | macOS ships Bash 3 |
| Install Bash 4+ | `brew install bash` | Requires Homebrew |
| Set default shell | `chsh -s /opt/homebrew/bin/bash` | After brew install |
| Check Python | `python3 --version` | Required for tests |

## Process Management

| Operation | Bash | Notes |
|-----------|------|-------|
| List processes | `ps aux` | |
| Kill process | `kill -9 PID` | |
| Find process | `pgrep -f msingi` | |

---
*Part of Msingi Agent Operations*

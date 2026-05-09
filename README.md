<div align="center">

# Msingi

**Context engineering infrastructure for AI agent sessions.**

*Msingi* is Swahili for **foundation** — the groundwork you lay before building.

[![License: MIT](https://img.shields.io/badge/license-MIT-teal.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-blue.svg)](msingi.ps1)
[![Platform: macOS/Linux](https://img.shields.io/badge/platform-macOS%20%2F%20Linux-green.svg)](msingi.sh)
[![Version](https://img.shields.io/badge/version-4.0.0-orange.svg)](#)

**Built in Accra. Designed for everywhere.**

</div>

---

## The Problem
The real cost of AI coding tools is the tokens burned on unstructured exploration. Every cold session costs tokens that should go to creation. 

**Msingi generates the foundation in 60 seconds.**

## Quick Links
- [**The Manifesto**](docs/manifesto.md) — Why context engineering matters.
- [**The Scaffold Spec**](docs/scaffold-spec.md) — What files are generated and why.
- [**Supported Agents**](docs/agents-list.md) — Role taxonomy and configuration guide.
- [**Architecture**](docs/architecture.md) — Dual-script structure and reading order.
- [**Roadmap & History**](docs/changelog.md) — Where we're going and where we've been.

## Installation

### Windows (PowerShell 7)
```powershell
git clone https://github.com/xdagee/msingi
cd msingi
.\install.ps1
bootstrap
```

### macOS / Linux (Bash 4+)
```bash
git clone https://github.com/xdagee/msingi
cd msingi
chmod +x msingi.sh
sudo ln -s "$(pwd)/msingi.sh" /usr/local/bin/msingi
msingi
```

## Usage
```bash
msingi              # guided mode — 7 screens, ~60 seconds
msingi --dry-run    # preview every file without writing
msingi --help
```

---

## For AI Agents
If you are an AI agent working on this repository, please start by reading [**AGENTS.md**](AGENTS.md).

---

<div align="center">

*Msingi — the foundation you lay before you build.*

**Built in Accra. Designed for everywhere.**

</div>

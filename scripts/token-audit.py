#!/usr/bin/env python3
"""
token-audit.py — Msingi Context Token Efficiency Auditor

Scans the Msingi repository's agent infrastructure and context files,
estimates per-file token costs, computes signal density, detects cross-file
redundancy, and flags files that exceed configurable thresholds.

Usage:
    python3 scripts/token-audit.py                  # default scan
    python3 scripts/token-audit.py --threshold 800  # custom token threshold
    python3 scripts/token-audit.py --json            # machine-readable output
    python3 scripts/token-audit.py --verbose         # include per-file detail

Exit codes:
    0 — all files within thresholds
    1 — one or more files flagged
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


def _ensure_utf8_stdout() -> None:
    """Reconfigure stdout to UTF-8 on Windows to avoid cp1252 encoding errors."""
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


# Detect whether the terminal can render Unicode box-drawing characters.
# If not, fall back to ASCII equivalents.
def _can_render_unicode() -> bool:
    try:
        "\u2500\u2593\u2591\u2588".encode(sys.stdout.encoding or "ascii")
        return True
    except (UnicodeEncodeError, LookupError):
        return False

_ensure_utf8_stdout()
_UNICODE = _can_render_unicode()

# Drawing characters with ASCII fallbacks
HRULE = "\u2500" if _UNICODE else "-"
BAR_FULL = "\u2588" if _UNICODE else "#"
BAR_EMPTY = "\u2591" if _UNICODE else "."
BAR_MED = "\u2593" if _UNICODE else "#"
ELLIPSIS = "\u2026" if _UNICODE else "..."
DOT = "\u00b7" if _UNICODE else "*"
CHECK = "\u2713" if _UNICODE else "OK"
CROSS = "\u2717" if _UNICODE else "FAIL"
DASH = "\u2014" if _UNICODE else "-"


# ─── Configuration ──────────────────────────────────────────────────────────

# Token estimation: ~4 characters per token is the industry-standard heuristic
# for GPT-family models. This is intentionally conservative (overestimates
# slightly) so that flagged files are genuinely problematic.
CHARS_PER_TOKEN = 4

# Files below this token count are never flagged — they're too small to matter.
MIN_TOKEN_THRESHOLD = 100

# Default thresholds (overridable via CLI flags)
DEFAULT_TOKEN_THRESHOLD = 600       # flag files above this token count...
DEFAULT_DENSITY_THRESHOLD = 0.40    # ...that have signal density below this
DEFAULT_REDUNDANCY_THRESHOLD = 15   # flag files with this many redundant lines
OVERSIZED_THRESHOLD = 2000          # hard cap: always flag above this

# Scan targets: directories and individual files to audit
SCAN_DIRS = [".agent"]
SCAN_ROOT_FILES = [
    "AGENTS.md", "CLAUDE.md", "README.md",
    "agents.json", "skills.json", "skills-lock.json",
]
SCAN_EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".txt"}


# ─── Data Model ─────────────────────────────────────────────────────────────

@dataclass
class FileMetrics:
    """Token efficiency metrics for a single file."""
    path: str
    size_bytes: int = 0
    lines_total: int = 0
    lines_signal: int = 0
    lines_blank: int = 0
    lines_decorative: int = 0
    tokens_estimated: int = 0
    density: float = 0.0
    redundant_lines: int = 0
    flags: list[str] = field(default_factory=list)

    @property
    def category(self) -> str:
        """Classify the file by its role in the context hierarchy."""
        p = self.path.replace("\\", "/")
        if "workflows/" in p:
            return "workflow"
        if "skills/" in p:
            return "skill"
        if "rules/" in p:
            return "rule"
        if "agents/" in p or p.endswith("agents.md"):
            return "agent-config"
        if p.endswith(".json"):
            return "data"
        if "docs/" in p:
            return "guide"
        return "context"


@dataclass
class AgentSession:
    """Real-world token impact from an agent session."""
    agent_id: str
    path: str
    tokens_input: int = 0
    tokens_output: int = 0
    tokens_total: int = 0
    efficiency: float = 0.0  # lines of code / tokens (conceptual)
    last_update: str = ""


@dataclass
class AuditReport:
    """Aggregate audit results."""
    files: list[FileMetrics] = field(default_factory=list)
    sessions: list[AgentSession] = field(default_factory=list)
    total_tokens: int = 0
    total_files: int = 0
    flagged_count: int = 0
    category_totals: dict[str, int] = field(default_factory=dict)
    redundancy_pairs: list[tuple[str, str, int]] = field(default_factory=list)



# ─── Line Classification ───────────────────────────────────────────────────

# Lines that are purely structural / decorative and carry minimal semantic
# signal to an LLM. These still cost tokens but contribute little to
# the agent's understanding.
DECORATIVE_PATTERNS = [
    re.compile(r"^\s*$"),                          # blank
    re.compile(r"^\s*---+\s*$"),                   # horizontal rule
    re.compile(r"^\s*\*{3,}\s*$"),                 # asterisk rule
    re.compile(r"^\s*<!--.*-->\s*$"),               # HTML comment (single-line)
    re.compile(r"^\s*[|]-+[|]"),                   # table separator row
    re.compile(r"^\s*\|\s*-+\s*\|"),               # table separator variant
    re.compile(r"^\s*#{1,6}\s*$"),                 # empty heading
    re.compile(r"^\s*[`]{3,}\s*$"),                # bare code fence
    re.compile(r"^\s*[`]{3,}\w+\s*$"),             # code fence with lang tag only
]

# Lines that are low-signal boilerplate (placeholders, stub entries)
BOILERPLATE_PATTERNS = [
    re.compile(r"^\s*\*\(add as discovered\)\*"),
    re.compile(r"^\s*\*\(define\)\*"),
    re.compile(r"^\s*\|\s*\*\(.*\)\*\s*\|"),       # table row with placeholder
    re.compile(r"^\s*-\s*$"),                       # bare bullet with no content
    re.compile(r"^\s*\|\s*\|\s*$"),                 # empty table row
]


def classify_line(line: str) -> str:
    """Classify a line as 'signal', 'blank', or 'decorative'.

    Returns:
        'blank'      — empty or whitespace-only
        'decorative' — structural formatting with no semantic content
        'boilerplate'— placeholder text that an LLM gains nothing from
        'signal'     — content that contributes to agent understanding
    """
    if not line.strip():
        return "blank"
    for pattern in DECORATIVE_PATTERNS:
        if pattern.match(line):
            return "decorative"
    for pattern in BOILERPLATE_PATTERNS:
        if pattern.match(line):
            return "boilerplate"
    return "signal"


# ─── Redundancy Detection ──────────────────────────────────────────────────

def normalize_line(line: str) -> str:
    """Normalize a line for cross-file comparison.

    Strips whitespace, lowercases, removes markdown formatting characters.
    Lines that normalize to empty are excluded from comparison.
    """
    s = line.strip().lower()
    s = re.sub(r"[#*`_\-|>]", "", s)   # strip markdown formatting
    s = re.sub(r"\s+", " ", s)          # collapse whitespace
    return s


def build_line_index(all_files: dict[str, list[str]]) -> dict[str, set[str]]:
    """Build an index mapping normalized lines to the set of files they appear in.

    Only lines with >= 8 characters after normalization are indexed (shorter
    lines produce too many false positives).

    Returns:
        dict mapping normalized_line -> set of file paths containing it
    """
    index: dict[str, set[str]] = defaultdict(set)
    for filepath, lines in all_files.items():
        for line in lines:
            norm = normalize_line(line)
            if len(norm) >= 8:
                index[norm].add(filepath)
    return index


def count_redundant_lines(
    filepath: str,
    lines: list[str],
    line_index: dict[str, set[str]],
    min_files: int = 3,
) -> int:
    """Count how many lines in this file also appear in min_files or more other files.

    This detects cross-file duplication — the same rule or instruction stated
    in multiple places. A line is 'redundant' if its normalized form appears
    in 3+ files (configurable).
    """
    count = 0
    for line in lines:
        norm = normalize_line(line)
        if len(norm) >= 8 and len(line_index.get(norm, set())) >= min_files:
            count += 1
    return count


# ─── File Analysis ──────────────────────────────────────────────────────────

def analyze_file(filepath: str, content: str) -> FileMetrics:
    """Compute token efficiency metrics for a single file."""
    lines = content.splitlines()
    size_bytes = len(content.encode("utf-8"))
    tokens_estimated = max(1, size_bytes // CHARS_PER_TOKEN)

    lines_blank = 0
    lines_decorative = 0
    lines_signal = 0

    for line in lines:
        cls = classify_line(line)
        if cls == "blank":
            lines_blank += 1
        elif cls in ("decorative", "boilerplate"):
            lines_decorative += 1
        else:
            lines_signal += 1

    lines_total = len(lines)
    density = lines_signal / max(1, lines_total)

    return FileMetrics(
        path=filepath,
        size_bytes=size_bytes,
        lines_total=lines_total,
        lines_signal=lines_signal,
        lines_blank=lines_blank,
        lines_decorative=lines_decorative,
        tokens_estimated=tokens_estimated,
        density=round(density, 3),
    )


# ─── Flag Logic ─────────────────────────────────────────────────────────────

def apply_flags(
    metrics: FileMetrics,
    token_threshold: int,
    density_threshold: float,
    redundancy_threshold: int,
) -> None:
    """Apply efficiency flags to a file's metrics.

    Flags:
        OVERSIZED   — file exceeds hard token cap (always flagged)
        LOW_DENSITY — file above token threshold with density below minimum
        REDUNDANT   — file has too many lines duplicated across other files
    """
    if metrics.tokens_estimated < MIN_TOKEN_THRESHOLD:
        return

    if metrics.tokens_estimated > OVERSIZED_THRESHOLD:
        metrics.flags.append("OVERSIZED")

    if (
        metrics.tokens_estimated > token_threshold
        and metrics.density < density_threshold
    ):
        metrics.flags.append("LOW_DENSITY")

    if metrics.redundant_lines > redundancy_threshold:
        metrics.flags.append("REDUNDANT")


# ─── Session Parsing ─────────────────────────────────────────────────────────

def parse_agent_sessions(repo_root: Path) -> list[AgentSession]:
    """Find and parse SESSION.md files in scratchpads."""
    sessions = []
    scratchpads = repo_root / "scratchpads"
    if not scratchpads.is_dir():
        return []

    for agent_dir in scratchpads.iterdir():
        if not agent_dir.is_dir():
            continue
        
        session_file = agent_dir / "SESSION.md"
        if not session_file.is_file():
            continue

        try:
            content = session_file.read_text(encoding="utf-8")
            # Look for a table like: | Tokens | Input | Output | Total |
            # and extract the last numeric row.
            matches = re.findall(r"\|\s*(\d+[,.]?\d*)\s*\|\s*(\d+[,.]?\d*)\s*\|\s*(\d+[,.]?\d*)\s*\|", content)
            if matches:
                last_row = matches[-1]
                inp = int(last_row[0].replace(",", "").replace(".", ""))
                out = int(last_row[1].replace(",", "").replace(".", ""))
                total = int(last_row[2].replace(",", "").replace(".", ""))
                
                sessions.append(AgentSession(
                    agent_id=agent_dir.name,
                    path=str(session_file.relative_to(repo_root)),
                    tokens_input=inp,
                    tokens_output=out,
                    tokens_total=total,
                    last_update=os.path.getmtime(session_file)
                ))
        except (OSError, ValueError):
            continue
    
    return sessions


# ─── Scanner ────────────────────────────────────────────────────────────────

def discover_files(repo_root: Path) -> list[Path]:
    """Discover all auditable files in the repository."""
    files: list[Path] = []

    # Root-level context files
    for name in SCAN_ROOT_FILES:
        path = repo_root / name
        if path.is_file():
            files.append(path)

    # Directory trees
    for dirname in SCAN_DIRS:
        dirpath = repo_root / dirname
        if not dirpath.is_dir():
            continue
        for root, _dirs, filenames in os.walk(dirpath):
            for fname in filenames:
                fpath = Path(root) / fname
                if fpath.suffix.lower() in SCAN_EXTENSIONS:
                    files.append(fpath)

    return sorted(set(files))


def run_audit(
    repo_root: Path,
    token_threshold: int = DEFAULT_TOKEN_THRESHOLD,
    density_threshold: float = DEFAULT_DENSITY_THRESHOLD,
    redundancy_threshold: int = DEFAULT_REDUNDANCY_THRESHOLD,
) -> AuditReport:
    """Run the full token audit and return a structured report."""
    files = discover_files(repo_root)
    report = AuditReport()

    # Phase 1: Read all files and compute per-file metrics
    all_contents: dict[str, list[str]] = {}
    for fpath in files:
        try:
            content = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        relpath = str(fpath.relative_to(repo_root)).replace("\\", "/")
        metrics = analyze_file(relpath, content)
        report.files.append(metrics)
        all_contents[relpath] = content.splitlines()

    # Phase 2: Cross-file redundancy detection
    line_index = build_line_index(all_contents)
    for metrics in report.files:
        if metrics.path in all_contents:
            metrics.redundant_lines = count_redundant_lines(
                metrics.path,
                all_contents[metrics.path],
                line_index,
            )

    # Phase 3: Agent Session Parsing
    report.sessions = parse_agent_sessions(repo_root)

    # Phase 4: Apply flags
    for metrics in report.files:
        apply_flags(metrics, token_threshold, density_threshold, redundancy_threshold)

    # Phase 5: Aggregate
    report.total_files = len(report.files)
    report.total_tokens = sum(m.tokens_estimated for m in report.files)
    report.flagged_count = sum(1 for m in report.files if m.flags)

    category_totals: dict[str, int] = defaultdict(int)
    for m in report.files:
        category_totals[m.category] += m.tokens_estimated
    report.category_totals = dict(category_totals)

    # Sort: flagged files first, then by token cost descending
    report.files.sort(key=lambda m: (-len(m.flags), -m.tokens_estimated))

    return report



# ─── Output Formatting ─────────────────────────────────────────────────────

# ANSI color codes (disabled if not a TTY)
_USE_COLOR = sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    if not _USE_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"

def _red(text: str) -> str:
    return _c("91", text)

def _yellow(text: str) -> str:
    return _c("93", text)

def _green(text: str) -> str:
    return _c("92", text)

def _dim(text: str) -> str:
    return _c("90", text)

def _bold(text: str) -> str:
    return _c("1", text)

def _cyan(text: str) -> str:
    return _c("96", text)


def density_bar(density: float, width: int = 10) -> str:
    """Render a visual density bar."""
    filled = int(density * width)
    empty = width - filled
    bar = BAR_FULL * filled + BAR_EMPTY * empty
    if density >= 0.60:
        return _green(bar)
    elif density >= 0.40:
        return _yellow(bar)
    else:
        return _red(bar)


def format_flags(flags: list[str]) -> str:
    """Format flag list with color coding."""
    parts = []
    for f in flags:
        if f == "OVERSIZED":
            parts.append(_red("OVERSIZED"))
        elif f == "LOW_DENSITY":
            parts.append(_yellow("LOW_DENSITY"))
        elif f == "REDUNDANT":
            parts.append(_yellow("REDUNDANT"))
        else:
            parts.append(f)
    return " ".join(parts)


def print_dashboard(report: AuditReport) -> None:
    """Print a premium TUI dashboard of context metrics."""
    term_width = 100
    try:
        import shutil
        term_width = shutil.get_terminal_size((100, 20)).columns
    except (ImportError, AttributeError):
        pass

    def box(title: str, lines: list[str], width: int = 50, color_fn=None):
        top = f"\u250c\u2500 {title} " + "\u2500" * (width - len(title) - 4) + "\u2510"
        if not _UNICODE: top = f"+-- {title} " + "-" * (width - len(title) - 4) + "+"
        print(color_fn(top) if color_fn else top)
        for line in lines:
            content = f"  {line}"
            if len(content) > width - 2:
                content = content[:width-5] + "..."
            padding = " " * (width - len(content) - 1)
            side = "\u2502" if _UNICODE else "|"
            print(f"{color_fn(side) if color_fn else side}{content}{padding}{color_fn(side) if color_fn else side}")
        bottom = "\u2514" + "\u2500" * (width - 2) + "\u2518"
        if not _UNICODE: bottom = "+" + "-" * (width - 2) + "+"
        print(color_fn(bottom) if color_fn else bottom)

    print("\n" * 2)
    print(_bold(_cyan("  \u2554" + "\u2550" * 40 + "\u2557")))
    print(_bold(_cyan("  \u2551     Msingi Context Efficiency Hub      \u2551")))
    print(_bold(_cyan("  \u255a" + "\u2550" * 40 + "\u255d")))
    print()

    # 1. Context Budget Gauge
    limit = 32768  # Standard 32k window
    pct = (report.total_tokens / limit) * 100
    gauge_width = 40
    filled = int((pct / 100) * gauge_width)
    gauge = BAR_FULL * filled + BAR_EMPTY * (gauge_width - filled)
    
    color = _green
    if pct > 80: color = _red
    elif pct > 60: color = _yellow

    print(f"  {_bold('Total Context Budget (32k)')}")
    print(f"  {color(gauge)}  {_bold(f'{pct:.1f}%')} ({report.total_tokens:,} / {limit:,} tk)")
    print()

    # 2. Key Metrics Grid
    col1_width = 48
    
    cat_lines = []
    for cat, tokens in sorted(report.category_totals.items(), key=lambda x: -x[1]):
        c_pct = tokens / max(1, report.total_tokens) * 100
        cat_lines.append(f"{cat:<14} {tokens:>6,} tk ({c_pct:>2.0f}%)")
    
    box("Permanent Context Breakdown", cat_lines, col1_width, _cyan)

    print()

    # 3. Agent Efficiency
    if report.sessions:
        session_lines = []
        for s in sorted(report.sessions, key=lambda x: -x.tokens_total):
            session_lines.append(f"{s.agent_id:<14} {s.tokens_total:>7,} tk (In: {s.tokens_input:,} Out: {s.tokens_output:,})")
        box("Active Agent Session Loads", session_lines, 60, _magenta)
    else:
        print(_dim("  (No active agent sessions detected in scratchpads/)"))
    
    print()

    # 4. Top Bloat Offenders
    bloat_lines = []
    flagged = [m for m in report.files if m.flags][:8]
    for m in flagged:
        flags = ",".join(m.flags)
        bloat_lines.append(f"{m.path:<35} {m.tokens_estimated:>5,} tk [{flags}]")
    
    if bloat_lines:
        box("Priority Optimization Targets", bloat_lines, 70, _red)

    print()
    print(f"  {_dim(f'Scan completed: {report.total_files} files audited across {len(report.category_totals)} categories.')}")
    print(f"  {_dim('Maintain 60-80% utilization for optimal agent performance.')}")
    print()


def print_table(report: AuditReport, verbose: bool = False) -> None:

    """Print the audit results as a formatted table."""
    print()
    print(_bold("  Msingi Token Audit"))
    print(_dim(f"  {report.total_files} files {DOT} {report.total_tokens:,} estimated tokens {DOT} {report.flagged_count} flagged"))
    print()

    # Category breakdown
    print(_bold("  Category Breakdown"))
    print(_dim("  " + HRULE * 44))
    for cat, tokens in sorted(report.category_totals.items(), key=lambda x: -x[1]):
        pct = tokens / max(1, report.total_tokens) * 100
        bar_len = int(pct / 100 * 30)
        bar = BAR_MED * bar_len + BAR_EMPTY * (30 - bar_len)
        print(f"  {cat:<14} {_cyan(bar)} {tokens:>6,} tk  ({pct:.0f}%)")
    print()

    # File table
    if verbose:
        file_list = report.files
    else:
        # Show flagged files + top 10 by token cost
        flagged = [m for m in report.files if m.flags]
        unflagged = [m for m in report.files if not m.flags][:10]
        file_list = flagged + unflagged

    # Header
    print(f"  {'File':<45} {'Tokens':>7} {'Lines':>6} {'Signal':>7} {'Density':>12}  {'Flags'}")
    print(_dim("  " + HRULE * 95))

    for m in file_list:
        name = m.path
        if len(name) > 44:
            name = ELLIPSIS + name[-(44 - len(ELLIPSIS)):]

        tok_str = f"{m.tokens_estimated:,}"
        flags_str = format_flags(m.flags) if m.flags else _dim(DASH)
        dbar = density_bar(m.density)

        print(
            f"  {name:<45} {tok_str:>7} {m.lines_total:>6} "
            f"{m.lines_signal:>5}/{m.lines_total:<5}"
            f" {dbar} {m.density:.2f}  {flags_str}"
        )

    if not verbose and len(report.files) > len(file_list):
        remaining = len(report.files) - len(file_list)
        print(_dim(f"  {ELLIPSIS} and {remaining} more files (use --verbose to show all)"))

    print()

    # Redundancy hotspots
    redundant_files = [m for m in report.files if m.redundant_lines > 5]
    if redundant_files:
        print(_bold("  Redundancy Hotspots"))
        print(_dim("  " + HRULE * 44))
        for m in sorted(redundant_files, key=lambda x: -x.redundant_lines)[:8]:
            print(f"  {m.path:<45} {m.redundant_lines:>3} lines shared with 3+ files")
        print()

    # Summary
    if report.flagged_count > 0:
        print(_red(f"  {CROSS} {report.flagged_count} file(s) flagged -- review for optimization"))
    else:
        print(_green(f"  {CHECK} All files within thresholds"))
    print()


def print_json(report: AuditReport) -> None:
    """Print the audit results as machine-readable JSON."""
    output = {
        "total_files": report.total_files,
        "total_tokens": report.total_tokens,
        "flagged_count": report.flagged_count,
        "category_totals": report.category_totals,
        "files": [
            {
                "path": m.path,
                "size_bytes": m.size_bytes,
                "tokens_estimated": m.tokens_estimated,
                "lines_total": m.lines_total,
                "lines_signal": m.lines_signal,
                "density": m.density,
                "redundant_lines": m.redundant_lines,
                "category": m.category,
                "flags": m.flags,
            }
            for m in report.files
        ],
    }
    json.dump(output, sys.stdout, indent=2)
    print()


# ─── CLI ────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Msingi Context Token Efficiency Auditor",
        epilog="Exit code 1 if any file is flagged.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="Repository root (default: auto-detect from script location)",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=DEFAULT_TOKEN_THRESHOLD,
        help=f"Token count above which files are checked for density (default: {DEFAULT_TOKEN_THRESHOLD})",
    )
    parser.add_argument(
        "--density",
        type=float,
        default=DEFAULT_DENSITY_THRESHOLD,
        help=f"Minimum signal density for files above token threshold (default: {DEFAULT_DENSITY_THRESHOLD})",
    )
    parser.add_argument(
        "--redundancy",
        type=int,
        default=DEFAULT_REDUNDANCY_THRESHOLD,
        help=f"Max redundant lines before flagging (default: {DEFAULT_REDUNDANCY_THRESHOLD})",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--dashboard",
        action="store_true",
        help="Display premium TUI metrics dashboard",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show all files, not just flagged + top 10",
    )
    return parser.parse_args()



def find_repo_root(start: Optional[Path] = None) -> Path:
    """Walk up from start directory to find the repo root (contains AGENTS.md)."""
    if start is None:
        start = Path(__file__).resolve().parent
    current = start
    for _ in range(10):
        if (current / "AGENTS.md").is_file():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    sys.exit("Error: could not find repository root (no AGENTS.md found)")


def main() -> int:
    args = parse_args()
    repo_root = args.root or find_repo_root()

    report = run_audit(
        repo_root=repo_root,
        token_threshold=args.threshold,
        density_threshold=args.density,
        redundancy_threshold=args.redundancy,
    )

    if args.json_output:
        print_json(report)
    elif args.dashboard:
        print_dashboard(report)
    else:
        print_table(report, verbose=args.verbose)


    return 1 if report.flagged_count > 0 else 0


if __name__ == "__main__":
    sys.exit(main())

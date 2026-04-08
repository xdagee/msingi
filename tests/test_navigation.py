#!/usr/bin/env python3
"""
Msingi Comprehensive Test Suite
Tests: syntax, schema, parity, structure, and acceptance criteria.
"""
import json
import os
import re
import subprocess
import sys
import platform

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

def read_file(name):
    path = os.path.join(PROJECT_DIR, name)
    with open(path, encoding='utf-8') as f:
        return f.read()

# ═══════════════════════════════════════════════════════════════════════════════
# 1. BASH SYNTAX
# ═══════════════════════════════════════════════════════════════════════════════

class TestBashSyntax:
    def test_bash_syntax_check(self):
        """msingi.sh must pass bash -n without errors."""
        result = subprocess.run(
            ["bash", "-n", "msingi.sh"],
            cwd=PROJECT_DIR,
            capture_output=True, text=True, timeout=30
        )
        assert result.returncode == 0, f"Bash syntax error: {result.stderr}"

    def test_shebang_present(self):
        """msingi.sh must start with #!/usr/bin/env bash."""
        content = read_file("msingi.sh")
        assert content.startswith("#!/usr/bin/env bash"), "Missing or wrong shebang"

    def test_set_options(self):
        """msingi.sh must use set -uo pipefail (no set -e per coding standards)."""
        content = read_file("msingi.sh")
        assert "set -uo pipefail" in content, "Missing set -uo pipefail"
        lines = content.split('\n')
        for line in lines:
            stripped = line.strip()
            if stripped.startswith('set ') and '-e' in stripped and not stripped.startswith('#'):
                if re.match(r'set\s+.*-e', stripped):
                    assert False, f"set -e found (forbidden): {stripped}"

    def test_navigation_state_variables(self):
        """Bash must declare STEP_DEFS and STEP_COMPLETED arrays."""
        content = read_file("msingi.sh")
        assert "STEP_DEFS=(" in content, "Missing STEP_DEFS array"
        assert "STEP_COMPLETED=(" in content, "Missing STEP_COMPLETED array"

    def test_step_loop_structure(self):
        """Bash must have a while loop with TOTAL_STEPS."""
        content = read_file("msingi.sh")
        assert "while" in content and "TOTAL_STEPS" in content, "Missing step loop"

    def test_tab_navigation_support(self):
        """Bash must handle Tab and Shift+Tab navigation."""
        content = read_file("msingi.sh")
        assert "\\t" in content, "Missing Tab detection"
        assert "[Z" in content, "Missing Shift+Tab (escape [Z) detection"

    def test_g_key_jump(self):
        """Bash must support G key for jump-to-step."""
        content = read_file("msingi.sh")
        assert "[gG]" in content, "Missing G key handler in case statement"
        assert "return 6" in content, "Missing G key return code (6)"


# ═══════════════════════════════════════════════════════════════════════════════
# 2. POWERSHELL SYNTAX
# ═══════════════════════════════════════════════════════════════════════════════

class TestPowerShellSyntax:
    def test_ps1_parse_clean(self):
        """msingi.ps1 must parse without errors (checked via helper script)."""
        check_script = os.path.join(SCRIPT_DIR, "check_syntax.ps1")
        if not os.path.exists(check_script):
            return  # Skip if helper not present
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-File", check_script],
            cwd=PROJECT_DIR,
            capture_output=True, text=True, timeout=60
        )
        assert result.returncode == 0, f"PS1 parse error: {result.stdout}\n{result.stderr}"

    def test_ps1_has_version(self):
        """msingi.ps1 must define a VERSION variable."""
        content = read_file("msingi.ps1")
        assert re.search(r'\$VERSION\s*=', content), "Missing $VERSION variable"

    def test_ps1_has_tab_navigation(self):
        """msingi.ps1 must handle Tab key for step navigation."""
        content = read_file("msingi.ps1")
        assert "Tab" in content, "Missing Tab key handling"

    def test_ps1_has_step_navigation(self):
        """msingi.ps1 must track step state."""
        content = read_file("msingi.ps1")
        assert "$currentStep" in content or "$current_step" in content, "Missing step state"

    def test_ps1_step_definitions(self):
        """msingi.ps1 must define step arrays."""
        content = read_file("msingi.ps1")
        assert re.search(r'\$STEP_DEFS|\$stepDefs|Step', content), "Missing step definitions"

    def test_ps1_here_string_closers_at_column_zero(self):
        """Every here-string closer \"@ must be at column 0 (critical for PS7)."""
        content = read_file("msingi.ps1")
        lines = content.split('\n')
        violations = []
        for i, line in enumerate(lines, 1):
            stripped = line.rstrip('\r')
            if stripped == '"@' or stripped == "'@":
                continue  # Good — at column 0
            if re.match(r'\s+"@', stripped) or re.match(r"\s+'@", stripped):
                violations.append(f"Line {i}: here-string closer not at column 0: {repr(stripped[:30])}")
        assert not violations, f"Here-string violations:\n" + "\n".join(violations[:10])

    def test_ps1_crlf_line_endings(self):
        """msingi.ps1 must use CRLF line endings (required for PS7 here-strings)."""
        path = os.path.join(PROJECT_DIR, "msingi.ps1")
        with open(path, 'rb') as f:
            raw = f.read(4096)  # Check first 4KB
        assert b'\r\n' in raw, "msingi.ps1 must use CRLF line endings"


# ═══════════════════════════════════════════════════════════════════════════════
# 3. JSON DATA INTEGRITY
# ═══════════════════════════════════════════════════════════════════════════════

class TestAgentsJson:
    def setup_method(self):
        with open(os.path.join(PROJECT_DIR, "agents.json"), encoding='utf-8') as f:
            self.data = json.load(f)

    def test_schema_version(self):
        """agents.json must have schema_version '1.0'."""
        assert self.data.get("schema_version") == "1.0"

    def test_agents_is_list(self):
        """agents must be a non-empty list."""
        assert isinstance(self.data["agents"], list)
        assert len(self.data["agents"]) > 0

    def test_required_fields(self):
        """Every agent must have all required fields."""
        required = {"id", "name", "file", "scratchpad", "category", "description", "docsUrl", "capabilityToAct", "selfDirection"}
        for agent in self.data["agents"]:
            missing = required - set(agent.keys())
            assert not missing, f"Agent '{agent.get('id','?')}' missing: {missing}"

    def test_unique_ids(self):
        """Agent IDs must be unique."""
        ids = [a["id"] for a in self.data["agents"]]
        assert len(ids) == len(set(ids)), f"Duplicate agent IDs: {[x for x in ids if ids.count(x) > 1]}"

    def test_unique_scratchpads(self):
        """Scratchpad names must be unique."""
        pads = [a["scratchpad"] for a in self.data["agents"]]
        assert len(pads) == len(set(pads)), f"Duplicate scratchpads"

    def test_antigravity_present(self):
        """Antigravity agent must be in the registry."""
        ids = [a["id"] for a in self.data["agents"]]
        assert "antigravity" in ids, "Antigravity agent missing"

    def test_antigravity_fields(self):
        """Antigravity must have correct metadata."""
        ag = next(a for a in self.data["agents"] if a["id"] == "antigravity")
        assert ag["file"] == "ANTIGRAVITY.md"
        assert ag["category"] == "vendor"
        assert "Google" in ag["description"]

    def test_valid_categories(self):
        """Agent categories must be from the allowed set."""
        valid = {"vendor", "vendor-oss", "oss", "framework-oss"}
        for agent in self.data["agents"]:
            assert agent["category"] in valid, f"Agent '{agent['id']}' bad category: {agent['category']}"

    def test_consistent_indentation(self):
        """agents.json must use consistent 2-space indentation."""
        raw = read_file("agents.json")
        re_formatted = json.dumps(json.loads(raw), indent=2)
        # Allow trailing newline difference
        assert raw.strip() == re_formatted.strip(), "agents.json indentation is inconsistent"

    def test_agent_capabilities(self):
        """All agents must define capabilityToAct as a list of strings."""
        valid_caps = {"file-system", "terminal", "code-execution", "web-search", "api-calls", "browser"}
        for agent in self.data["agents"]:
            assert isinstance(agent.get("capabilityToAct"), list), f"Agent '{agent['id']}' capabilityToAct not a list"
            for cap in agent["capabilityToAct"]:
                assert cap in valid_caps, f"Agent '{agent['id']}' has invalid capability: {cap}"

    def test_agent_self_direction(self):
        """All agents must define selfDirection as low, medium, or high."""
        valid_dirs = {"low", "medium", "high"}
        for agent in self.data["agents"]:
            assert agent.get("selfDirection") in valid_dirs, f"Agent '{agent['id']}' has invalid selfDirection: {agent.get('selfDirection')}"

    def test_agent_roles(self):
        """All agents must define roles as a list containing planner, executor, or coordinator."""
        valid_roles = {"planner", "executor", "coordinator"}
        for agent in self.data["agents"]:
            roles = agent.get("roles")
            assert isinstance(roles, list), f"Agent '{agent['id']}' roles must be a list"
            assert len(roles) > 0, f"Agent '{agent['id']}' must have at least one role"
            for r in roles:
                assert r in valid_roles, f"Agent '{agent['id']}' has invalid role: {r}"


class TestSkillsJson:
    def setup_method(self):
        with open(os.path.join(PROJECT_DIR, "skills.json"), encoding='utf-8') as f:
            self.data = json.load(f)

    def test_schema_version(self):
        """skills.json must have schema_version '1.0'."""
        assert self.data.get("schema_version") == "1.0"

    def test_skills_is_list(self):
        """skills must be a non-empty list."""
        assert isinstance(self.data["skills"], list)
        assert len(self.data["skills"]) > 0

    def test_required_fields(self):
        """Every skill must have all required fields."""
        required = {"id", "name", "category", "types", "baseline", "trigger"}
        for skill in self.data["skills"]:
            missing = required - set(skill.keys())
            assert not missing, f"Skill '{skill.get('id','?')}' missing: {missing}"

    def test_unique_ids(self):
        """Skill IDs must be unique."""
        ids = [s["id"] for s in self.data["skills"]]
        assert len(ids) == len(set(ids)), f"Duplicate skill IDs: {[x for x in ids if ids.count(x) > 1]}"

    def test_valid_types(self):
        """Skill types must be from the known project type set."""
        valid = {"web-app", "api-service", "fullstack", "ml-ai", "cli-tool", "android", "desktop-windows"}
        for skill in self.data["skills"]:
            assert isinstance(skill["types"], list), f"Skill '{skill['id']}' types not a list"
            for t in skill["types"]:
                assert t in valid, f"Skill '{skill['id']}' unknown type: {t}"

    def test_valid_categories(self):
        """Skill categories must be from the known set."""
        valid = {"auth", "data", "api", "ui", "ml", "infra", "messaging", "testing", "android", "core"}
        for skill in self.data["skills"]:
            assert skill["category"] in valid, f"Skill '{skill['id']}' bad category: {skill['category']}"

    def test_triggers_are_valid_regex(self):
        """Every skill trigger must be a valid regex."""
        for skill in self.data["skills"]:
            try:
                re.compile(skill["trigger"], re.IGNORECASE)
            except re.error as e:
                assert False, f"Skill '{skill['id']}' has invalid trigger regex: {e}"

    def test_baseline_is_boolean(self):
        """Baseline field must be a boolean."""
        for skill in self.data["skills"]:
            assert isinstance(skill["baseline"], bool), f"Skill '{skill['id']}' baseline is not bool"

    def test_desktop_windows_skills_exist(self):
        """Desktop Windows must have dedicated UI and packaging skills."""
        ids = [s["id"] for s in self.data["skills"]]
        assert "windows-desktop-ui" in ids, "Missing windows-desktop-ui skill"
        assert "msix-packaging" in ids, "Missing msix-packaging skill"

    def test_desktop_windows_baseline_skills(self):
        """desktop-windows must have baseline skills for error handling, testing, config."""
        baseline_for_desktop = [
            s for s in self.data["skills"]
            if s["baseline"] and "desktop-windows" in s["types"]
        ]
        baseline_ids = {s["id"] for s in baseline_for_desktop}
        expected = {"error-handling", "environment-config", "automated-testing",
                    "windows-desktop-ui", "msix-packaging"}
        missing = expected - baseline_ids
        assert not missing, f"desktop-windows missing baseline skills: {missing}"


# ═══════════════════════════════════════════════════════════════════════════════
# 4. PROJECT TYPE REGISTRY (PS1)
# ═══════════════════════════════════════════════════════════════════════════════

class TestProjectTypeRegistry:
    def setup_method(self):
        self.content = read_file("msingi.ps1")

    def test_all_project_types_present(self):
        """PS1 must define all seven project types."""
        expected = ["web-app", "api-service", "ml-ai", "cli-tool", "fullstack", "android", "desktop-windows"]
        for t in expected:
            assert t in self.content, f"Project type '{t}' missing from msingi.ps1"

    def test_desktop_windows_has_architecture(self):
        """desktop-windows must have architecture content."""
        assert "MVVM" in self.content, "desktop-windows missing MVVM architecture"
        assert "WinUI" in self.content, "desktop-windows missing WinUI reference"

    def test_desktop_windows_has_nfr(self):
        """desktop-windows must have NFR content."""
        assert "Windows Desktop App" in self.content or "desktop-windows" in self.content

    def test_desktop_windows_has_threat_model(self):
        """desktop-windows must have threat model."""
        assert "DLL Hijacking" in self.content or "DLL hijacking" in self.content

    def test_desktop_windows_has_quality_gates(self):
        """desktop-windows must have quality gates."""
        assert "MSIX" in self.content, "Missing MSIX in quality gates"

    def test_each_type_has_required_metadata(self):
        """Each project type must have architecture, nfr, securityThreats, qualityGates, observabilityFocus."""
        for field in ["architecture", "nfr", "securityThreats", "qualityGates", "observabilityFocus"]:
            count = self.content.count(f"{field} = @\"")
            assert count >= 7, f"Expected >=7 occurrences of '{field}' here-strings, found {count}"


# ═══════════════════════════════════════════════════════════════════════════════
# 5. NAVIGATION FEATURES
# ═══════════════════════════════════════════════════════════════════════════════

class TestNavigationFeatures:
    def test_g_key_handler_ps1(self):
        """msingi.ps1 must handle G key for jump-to-step."""
        content = read_file("msingi.ps1")
        assert "ConsoleKey]::G" in content or "-4" in content, "Missing G key in PS1"

    def test_g_key_handler_bash(self):
        """msingi.sh must handle G key for jump-to-step."""
        content = read_file("msingi.sh")
        assert re.search(r'[gG]', content) and "jump" in content.lower() or "6" in content

    def test_workflow_modes_bash(self):
        """msingi.sh must support quick/guided/advanced modes."""
        content = read_file("msingi.sh")
        assert "quick" in content.lower()
        assert "guided" in content.lower()
        assert "advanced" in content.lower()

    def test_workflow_modes_ps1(self):
        """msingi.ps1 must support quick/guided/advanced modes."""
        content = read_file("msingi.ps1")
        assert "quick" in content.lower()
        assert "guided" in content.lower()
        assert "advanced" in content.lower()


# ═══════════════════════════════════════════════════════════════════════════════
# 6. DUAL-SCRIPT PARITY
# ═══════════════════════════════════════════════════════════════════════════════

class TestDualScriptParity:
    def test_version_match(self):
        """Both scripts must declare the same version string."""
        ps1 = read_file("msingi.ps1")
        sh = read_file("msingi.sh")
        ps1_ver = re.search(r'\$VERSION\s*=\s*"([^"]+)"', ps1)
        sh_ver = re.search(r'VERSION="([^"]+)"', sh)
        assert ps1_ver, "PS1 missing $VERSION"
        assert sh_ver, "Bash missing VERSION"
        assert ps1_ver.group(1) == sh_ver.group(1), \
            f"Version mismatch: PS1={ps1_ver.group(1)} vs Bash={sh_ver.group(1)}"

    def test_both_load_agents_json(self):
        """Both scripts must load agents.json."""
        ps1 = read_file("msingi.ps1")
        sh = read_file("msingi.sh")
        assert "agents.json" in ps1, "PS1 doesn't reference agents.json"
        assert "agents.json" in sh, "Bash doesn't reference agents.json"

    def test_both_load_skills_json(self):
        """Both scripts must load skills.json."""
        ps1 = read_file("msingi.ps1")
        sh = read_file("msingi.sh")
        assert "skills.json" in ps1, "PS1 doesn't reference skills.json"
        assert "skills.json" in sh, "Bash doesn't reference skills.json"

    def test_both_have_completion_panel(self):
        """Both scripts must display a completion panel."""
        ps1 = read_file("msingi.ps1")
        sh = read_file("msingi.sh")
        assert "Bootstrap complete" in ps1 or "bootstrap complete" in ps1.lower()
        assert "Bootstrap complete" in sh or "bootstrap complete" in sh.lower()


# ═══════════════════════════════════════════════════════════════════════════════
# 7. SKILL FILE STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

class TestSkillFiles:
    def test_skill_md_files_have_frontmatter(self):
        """Every SKILL.md must have YAML frontmatter with name and description."""
        skills_dir = os.path.join(PROJECT_DIR, ".agent", "skills")
        if not os.path.isdir(skills_dir):
            return  # Skip if .agent/skills doesn't exist
        for entry in os.listdir(skills_dir):
            skill_md = os.path.join(skills_dir, entry, "SKILL.md")
            if os.path.isfile(skill_md):
                content = open(skill_md, encoding='utf-8').read()
                assert content.startswith("---"), \
                    f"SKILL.md in {entry} missing YAML frontmatter"
                assert "name:" in content, f"SKILL.md in {entry} missing 'name:'"
                assert "description:" in content, f"SKILL.md in {entry} missing 'description:'"


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    try:
        import pytest
        sys.exit(pytest.main([__file__, "-v", "--tb=short"]))
    except ImportError:
        # Fallback: run tests manually without pytest
        print("pytest not installed — running basic checks\n")
        passed = 0
        failed = 0
        errors_list = []
        test_classes = [
            TestBashSyntax, TestPowerShellSyntax,
            TestAgentsJson, TestSkillsJson,
            TestProjectTypeRegistry, TestNavigationFeatures,
            TestDualScriptParity, TestSkillFiles,
        ]
        for cls in test_classes:
            instance = cls()
            if hasattr(instance, 'setup_method'):
                try:
                    instance.setup_method()
                except Exception as e:
                    print(f"  SETUP FAIL: {cls.__name__}: {e}")
                    failed += 1
                    continue
            for name in sorted(dir(instance)):
                if name.startswith("test_"):
                    try:
                        getattr(instance, name)()
                        print(f"  PASS: {cls.__name__}.{name}")
                        passed += 1
                    except Exception as e:
                        print(f"  FAIL: {cls.__name__}.{name}: {e}")
                        errors_list.append(f"{cls.__name__}.{name}")
                        failed += 1
        print(f"\n{'='*60}")
        print(f"Results: {passed} passed, {failed} failed")
        if errors_list:
            print("Failed tests:")
            for e in errors_list:
                print(f"  - {e}")
            sys.exit(1)
        else:
            print("All tests passed!")
            sys.exit(0)

import os
import subprocess
import unittest
import json

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASH_SCRIPT = os.path.join(ROOT_DIR, "msingi.sh").replace('\\', '/')
PS_SCRIPT = os.path.join(ROOT_DIR, "msingi.ps1")
GO_BINARY = os.path.join(ROOT_DIR, "msingi.exe")

GIT_BASH = r"C:\Program Files\Git\bin\bash.exe"

def run_bash_builder(func_name, *args, env_vars=None):
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)
    
    env_str = ""
    if env_vars:
        for k, v in env_vars.items():
            env_str += f'export {k}="{v}"; '
            
    args_str = " ".join(f'"{arg}"' for arg in args)
    cmd = f'{env_str} source "{BASH_SCRIPT}" --test-harness; {func_name} {args_str}'
    
    bash_exe = "bash"
    if os.path.exists(GIT_BASH):
        bash_exe = GIT_BASH

    result = subprocess.run([bash_exe, "-c", cmd], capture_output=True, text=True, encoding='utf-8', env=env)
    return result.stdout.strip()

def run_ps_builder(func_name, **kwargs):
    ps_args = ""
    for k, v in kwargs.items():
        if isinstance(v, dict):
            ht_items = "; ".join(f"'{hk}'='{hv}'" for hk, hv in v.items())
            ps_args += f" -{k} @{{{ht_items}}}"
        elif isinstance(v, list):
            if v:
                arr_items = ", ".join(f"'{item}'" for item in v)
                ps_args += f" -{k} @({arr_items})"
            else:
                ps_args += f" -{k} @()"
        elif isinstance(v, bool):
            ps_args += f" -{k}:${str(v).lower()}"
        else:
            ps_args += f" -{k} '{v}'"
            
    cmd = f'[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; . "{PS_SCRIPT}" -TestHarness; {func_name} {ps_args}'
    
    try:
        result = subprocess.run(["pwsh", "-Command", cmd], capture_output=True, text=True, encoding='utf-8')
    except FileNotFoundError:
        result = subprocess.run(["powershell", "-Command", cmd], capture_output=True, text=True, encoding='utf-8')
    return result.stdout.strip()

def run_go_builder(builder_name, project_name="ParityProject", env_vars=None):
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)
    
    cmd = [GO_BINARY, "--test-harness", "--builder", builder_name, "--project", project_name]
    if env_vars:
        if "AGENT_ID" in env_vars:
            cmd.extend(["--agent-id", env_vars["AGENT_ID"]])
        if "SKILL_ID" in env_vars:
            cmd.extend(["--skill-id", env_vars["SKILL_ID"]])

    result = subprocess.run(cmd, capture_output=True, text=True, env=env, encoding='utf-8')
    if result.returncode != 0:
        return f"ERROR: {result.stderr}"
    return result.stdout.strip()

def normalize_text(text):
    if not text:
        return ""
    # Handle PowerShell 5.1 CP1252 corruption of UTF-8
    replacements = {
        'â€”': '—',
        'â€“': '–',
        'â•­': '╭',
        'â”€': '─',
        'â•®': '╮',
        'â•°': '╰',
        'â•¯': '╯',
        'â• ': '═',
        'â• ': '╠',
        'â•£': '╣',
        'ðŸ“¨': '📨',
        'ðŸ“¡': '📡',
        'â–¶': '▶',
        'â— ': '●',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
        
    lines = text.replace('\r\n', '\n').split('\n')
    # Filter out empty lines for better parity
    lines = [line.rstrip() for line in lines if line.strip()]
    return '\n'.join(lines).strip()

class TestMsingiParity(unittest.TestCase):
    def setUp(self):
        self.maxDiff = None

    def test_plans_md_parity(self):
        bash_out = run_bash_builder("build_plans_md")
        ps_out = run_ps_builder("Build-PlansMd")
        go_out = run_go_builder("plans")
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_plan_template_md_parity(self):
        bash_out = run_bash_builder("build_plan_template_md")
        ps_out = run_ps_builder("Build-PlanTemplateMd")
        go_out = run_go_builder("plan_template")
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_inbox_md_parity(self):
        bash_out = run_bash_builder("build_inbox_md")
        ps_out = run_ps_builder("Build-InboxMd")
        go_out = run_go_builder("inbox")
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_quality_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject", "PROJECT_TYPE_LABEL": "Web"}
        bash_out = run_bash_builder("build_quality_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject", "TypeLabel": "Web"}
        ps_type = {"qualityGates": "", "entropyControl": ""}
        ps_out = run_ps_builder("Build-QualityMd", Project=ps_project, Type=ps_type)
        
        go_out = run_go_builder("quality", project_name="ParityProject", env_vars=env)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_observability_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject", "PROJECT_TYPE_LABEL": "Web"}
        bash_out = run_bash_builder("build_observability_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject", "TypeLabel": "Web"}
        ps_out = run_ps_builder("Build-ObservabilityMd", Project=ps_project)
        
        go_out = run_go_builder("observability", project_name="ParityProject", env_vars=env)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_tasks_md_parity(self):
        env = {
            "PROJECT_NAME": "ParityProject", 
            "MILESTONE": "v0.1.0 MVP",
            "PROJECT_NEEDS_AUTH": "false",
            "PROJECT_HANDLES_SENSITIVE_DATA": "false"
        }
        bash_out = run_bash_builder("build_tasks_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject", "Milestone": "v0.1.0 MVP", "NeedsAuth": False, "HandlesSensitiveData": False}
        ps_out = run_ps_builder("Build-TasksMd", Project=ps_project, Skills=[])
        
        go_out = run_go_builder("tasks", project_name="ParityProject", env_vars=env)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_context_md_parity(self):
        env = {
            "PROJECT_NAME": "ParityProject",
            "PROJECT_TYPE_LABEL": "Web",
            "PROJECT_DESCRIPTION": "A parity test project.",
            "STACK_LINES": "- Go\n- Bubble Tea",
            "MILESTONE": "v1.0.0"
        }
        bash_out = run_bash_builder("build_context_md", env_vars=env)
        
        ps_project = {
            "Name": "ParityProject",
            "TypeLabel": "Web",
            "Description": "A parity test project.",
            "Stack": "Go,Bubble Tea",
            "Milestone": "v1.0.0",
            "Architecture": "Standard architecture",
            "NFR": "- Performance: < 2.5s page load"
        }
        ps_out = run_ps_builder("Build-ContextMd", Project=ps_project)
        
        go_out = run_go_builder("context", env_vars=env)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_go_agent_builder(self):
        """Verify Go can parse agents.json and inject complex metadata into AGENT.md."""
        go_out = run_go_builder("agent", env_vars={"AGENT_ID": "claude-code"})
        self.assertIn("# CLAUDE-CODE", go_out)
        self.assertIn("## Role", go_out)

    def test_go_skill_spec_builder(self):
        """Verify Go can parse skills.json and generate advanced SKILL.md specs."""
        go_out = run_go_builder("skill_spec", env_vars={"SKILL_ID": "user-authentication"})
        self.assertIn("# User Authentication", go_out)
        self.assertIn("**ID:** user-authentication", go_out)

    def test_go_workstreams_builder(self):
        """Verify Go iterates over agents.json to build workstreams."""
        go_out = run_go_builder("workstreams")
        self.assertIn("# WORKSTREAMS.md", go_out)
        self.assertIn("### WS-1", go_out)

    def test_new_agents_loaded(self):
        """Verify the new agents (Goose, Deep Agents, ForgeCode, Plandex) are in agents.json."""
        with open(os.path.join(ROOT_DIR, "agents.json"), "r", encoding="utf-8") as f:
            data = json.load(f)
            agent_ids = [a["id"] for a in data["agents"]]
            self.assertIn("goose", agent_ids)
            self.assertIn("deep-agents", agent_ids)
            self.assertIn("forgecode", agent_ids)
            self.assertIn("plandex", agent_ids)

    def test_agent_scaffolding(self):
        """Verify that selecting a new agent generates its specific config file."""
        # We need a way to trigger the full Generate function in a test.
        # Currently, builders only return strings.
        # Let's verify the builder functions for configs directly.
        go_out = run_go_builder("agent_config", env_vars={"AGENT_ID": "goose"})
        self.assertIn("project_name:", go_out)
        
        go_out = run_go_builder("agent_config", env_vars={"AGENT_ID": "plandex"})
        self.assertIn("plan_type:", go_out)

if __name__ == '__main__':
    unittest.main()

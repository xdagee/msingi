import os
import subprocess
import unittest
import json

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASH_SCRIPT = os.path.join(ROOT_DIR, "msingi.sh")
PS_SCRIPT = os.path.join(ROOT_DIR, "msingi.ps1")
GO_BINARY = os.path.join(ROOT_DIR, "msingi.exe")

def run_bash_builder(func_name, *args, env_vars=None):
    env_str = ""
    if env_vars:
        for k, v in env_vars.items():
            env_str += f'export {k}="{v}"; '
            
    args_str = " ".join(f'"{arg}"' for arg in args)
    cmd = f'{env_str} source "{BASH_SCRIPT}" --test-harness; {func_name} {args_str}'
    result = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True)
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
            
    cmd = f'. "{PS_SCRIPT}" -TestHarness; {func_name} {ps_args}'
    try:
        result = subprocess.run(["pwsh", "-Command", cmd], capture_output=True, text=True)
    except FileNotFoundError:
        result = subprocess.run(["powershell", "-Command", cmd], capture_output=True, text=True)
    return result.stdout.strip()

def run_go_builder(builder_name, project_name="ParityProject", env_vars=None):
    env = os.environ.copy()
    if env_vars:
        env.update(env_vars)
    
    cmd = [GO_BINARY, "--test-harness", "--builder", builder_name, "--project", project_name]
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        raise RuntimeError(f"Go builder {builder_name} failed:\n{result.stderr}")
    return result.stdout.strip()

def normalize_text(text):
    lines = text.replace('\r\n', '\n').split('\n')
    return '\n'.join(line.rstrip() for line in lines).strip()

class TestMsingiParity(unittest.TestCase):
    def test_plans_md_parity(self):
        bash_out = run_bash_builder("build_plans_md")
        ps_out = run_ps_builder("Build-PlansMd")
        go_out = run_go_builder("plans")
        
        norm_bash = normalize_text(bash_out)
        norm_ps = normalize_text(ps_out)
        norm_go = normalize_text(go_out)
        
        self.assertEqual(norm_bash, norm_ps)
        self.assertEqual(norm_ps, norm_go)

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
        env = {"PROJECT_NAME": "ParityProject"}
        bash_out = run_bash_builder("build_quality_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject", "TypeLabel": "Web"}
        ps_type = {"qualityGates": "", "entropyControl": ""}
        ps_out = run_ps_builder("Build-QualityMd", Project=ps_project, Type=ps_type)
        
        go_out = run_go_builder("quality", project_name="ParityProject")
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_observability_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject"}
        bash_out = run_bash_builder("build_observability_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject"}
        ps_out = run_ps_builder("Build-ObservabilityMd", Project=ps_project)
        
        go_out = run_go_builder("observability", project_name="ParityProject")
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))
        self.assertEqual(normalize_text(ps_out), normalize_text(go_out))

    def test_tasks_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject", "MILESTONE": "v0.1.0 MVP"}
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
        cmd = [GO_BINARY, "--test-harness", "--builder", "agent", "--agent-id", "claude-code"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("# CLAUDE-CODE", result.stdout)
        self.assertIn("## Role", result.stdout)

    def test_go_skill_spec_builder(self):
        """Verify Go can parse skills.json and generate advanced SKILL.md specs."""
        cmd = [GO_BINARY, "--test-harness", "--builder", "skill", "--skill-id", "auth"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("# Authentication", result.stdout)
        self.assertIn("**ID:** auth", result.stdout)

    def test_go_workstreams_builder(self):
        """Verify Go iterates over agents.json to build workstreams."""
        cmd = [GO_BINARY, "--test-harness", "--builder", "workstreams"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("# WORKSTREAMS.md", result.stdout)
        self.assertIn("### WS-1", result.stdout)

if __name__ == '__main__':
    unittest.main()

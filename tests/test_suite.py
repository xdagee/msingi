import os
import subprocess
import unittest

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASH_SCRIPT = os.path.join(ROOT_DIR, "msingi.sh")
PS_SCRIPT = os.path.join(ROOT_DIR, "msingi.ps1")

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
            # Convert python dict to PowerShell hashtable
            ht_items = "; ".join(f"'{hk}'='{hv}'" for hk, hv in v.items())
            ps_args += f" -{k} @{{{ht_items}}}"
        elif isinstance(v, list):
            # Convert python list to PowerShell array
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

def normalize_text(text):
    lines = text.replace('\r\n', '\n').split('\n')
    return '\n'.join(line.rstrip() for line in lines).strip()

class TestMsingiParity(unittest.TestCase):
    def test_plans_md_parity(self):
        bash_out = run_bash_builder("build_plans_md")
        ps_out = run_ps_builder("Build-PlansMd")
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

    def test_plan_template_md_parity(self):
        bash_out = run_bash_builder("build_plan_template_md")
        ps_out = run_ps_builder("Build-PlanTemplateMd")
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

    def test_inbox_md_parity(self):
        bash_out = run_bash_builder("build_inbox_md")
        ps_out = run_ps_builder("Build-InboxMd")
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

    def test_quality_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject"}
        bash_out = run_bash_builder("build_quality_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject", "TypeLabel": "Web"}
        ps_type = {"qualityGates": "", "entropyControl": ""}
        ps_out = run_ps_builder("Build-QualityMd", Project=ps_project, Type=ps_type)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

    def test_observability_md_parity(self):
        env = {"PROJECT_NAME": "ParityProject"}
        bash_out = run_bash_builder("build_observability_md", env_vars=env)
        
        ps_project = {"Name": "ParityProject"}
        ps_out = run_ps_builder("Build-ObservabilityMd", Project=ps_project)
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

    def test_tasks_md_parity(self):
        bash_out = run_bash_builder("build_tasks_md")
        
        ps_project = {"NeedsAuth": False, "HandlesSensitiveData": False}
        ps_out = run_ps_builder("Build-TasksMd", Project=ps_project, Skills=[])
        
        self.assertEqual(normalize_text(bash_out), normalize_text(ps_out))

if __name__ == '__main__':
    unittest.main()

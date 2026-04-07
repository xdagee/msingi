import json
import sys

errors = []

# Validate agents.json
try:
    with open('agents.json', 'r', encoding='utf-8') as f:
        agents = json.load(f)
    assert 'schema_version' in agents, "Missing schema_version"
    assert 'agents' in agents, "Missing agents array"
    assert isinstance(agents['agents'], list), "agents is not a list"
    ids = set()
    for a in agents['agents']:
        for field in ['id', 'name', 'file', 'scratchpad', 'category', 'description', 'docsUrl']:
            assert field in a, f"Agent '{a.get('id','?')}' missing field: {field}"
        assert a['id'] not in ids, f"Duplicate agent id: {a['id']}"
        ids.add(a['id'])
    print(f"PASS: agents.json — {len(agents['agents'])} agents, schema v{agents['schema_version']}")
except Exception as e:
    errors.append(f"FAIL: agents.json — {e}")
    print(errors[-1])

# Validate skills.json
try:
    with open('skills.json', 'r', encoding='utf-8') as f:
        skills = json.load(f)
    assert 'schema_version' in skills, "Missing schema_version"
    assert 'skills' in skills, "Missing skills array"
    assert isinstance(skills['skills'], list), "skills is not a list"
    ids = set()
    valid_types = {'web-app', 'api-service', 'fullstack', 'ml-ai', 'cli-tool', 'android', 'desktop-windows'}
    for s in skills['skills']:
        for field in ['id', 'name', 'category', 'types', 'baseline', 'trigger']:
            assert field in s, f"Skill '{s.get('id','?')}' missing field: {field}"
        assert s['id'] not in ids, f"Duplicate skill id: {s['id']}"
        ids.add(s['id'])
        assert isinstance(s['types'], list), f"Skill '{s['id']}' types is not a list"
        for t in s['types']:
            assert t in valid_types, f"Skill '{s['id']}' has unknown type: {t}"
    print(f"PASS: skills.json — {len(skills['skills'])} skills, schema v{skills['schema_version']}")
except Exception as e:
    errors.append(f"FAIL: skills.json — {e}")
    print(errors[-1])

if errors:
    sys.exit(1)

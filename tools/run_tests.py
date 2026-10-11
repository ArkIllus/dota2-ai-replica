"""Execute the standalone Lua scenario suites in separate Python processes."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
suites = sorted((root / 'tests').glob('test_*.py'))
if not suites:
    raise SystemExit('No test suites found in tests/')
failed = []
for suite in suites:
    print(f'Running {suite.name}', flush=True)
    if subprocess.run([sys.executable, str(suite)], cwd=root).returncode:
        failed.append(suite.name)
print(f'{len(suites) - len(failed)}/{len(suites)} suites passed', flush=True)
if failed:
    raise SystemExit('Failed: ' + ', '.join(failed))

"""Classify completed isolated logs without treating historical matches as acceptance."""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
SUMMARY = Path('/tmp/oct6-full-isolated.txt')
LOGS = Path(str(SUMMARY) + '.logs')
ANSI = re.compile(r'\x1b\[[0-9;]*m')


def failures(path):
    result = {}
    if not path.exists():
        return result
    method = '<load>'
    for line in ANSI.sub('', path.read_text()).splitlines():
        if 'Run Summary' in line:
            break
        if line.startswith('* test_'):
            method = line[2:].strip()
        if '[Failed]' in line or 'SCRIPT ERROR' in line:
            result.setdefault(method, []).append(line.strip())
    return result


rows = []
for line in SUMMARY.read_text().splitlines():
    parts = line.split()
    name = Path(parts[0]).stem
    counts = dict(field.split('=', 1) for field in parts[1:])
    current_path = LOGS / (name + '.log')
    current = failures(current_path)
    passed = (counts.get('tests') not in [None, '?', '0']
              and counts.get('tests') == counts.get('pass')
              and counts.get('fail') == '0' and counts.get('script_errors') == '0'
              and not current)
    row = {'file': parts[0], 'counts': counts, 'passed': passed}
    if not passed:
        historical = {}
        paths = []
        for suffix in ['', '-second', '-third']:
            path = Path('/tmp/town-baseline-comparison' + suffix + '.txt.logs') / (name + '.log')
            if path.exists():
                paths.append(str(path))
                for method, messages in failures(path).items():
                    historical.setdefault(method, []).extend(messages)
        row['historical_logs'] = paths
        row['failures'] = [
            {'method': method, 'messages': messages,
             'historical_text_match': bool(messages) and all(
                 message in historical.get(method, [])
                 and message != '[Failed]:  Unexpected Errors:' for message in messages)}
            for method, messages in current.items()]
        row['classification'] = 'requires review; text matches alone do not establish baseline equivalence'
    rows.append(row)
expected = HERE.joinpath('test-files.txt').read_text().splitlines()
completed = {row['file'] for row in rows}
report = {'completed': len(rows), 'expected': len(expected),
          'passed_files': sum(row['passed'] for row in rows),
          'remaining': [name for name in expected if name not in completed],
          'files': rows}
HERE.joinpath('classification.json').write_text(json.dumps(report, indent=2) + '\n')
print({key: report[key] for key in ['completed', 'expected', 'passed_files']})
for row in rows:
    if not row['passed']:
        print(row['file'], row['counts'])

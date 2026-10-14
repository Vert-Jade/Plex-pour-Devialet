"""Check the exact Git index before publication. Never print matching secrets.

Optional .local/private-terms.json is a JSON array of private strings. It is
read locally only, never added to the index. A clean result is a safeguard,
not proof that an arbitrary image or unrecognised secret is safe to publish.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {'.local', '.tools', '.venv', 'dist', '__pycache__', '.vscode', '.idea'}
PATTERNS = [
    ('private key', re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('GitHub credential', re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})')),
    ('personal home path', re.compile(rb'[A-Za-z]:[\\/]Users[\\/][A-Za-z0-9_-]+')),
    ('email address', re.compile(rb'[A-Za-z0-9._%+-]+@(?:gmail|hotmail|outlook|live|yahoo|free)\.[A-Za-z]{2,}')),
    ('literal Plex token', re.compile(rb'(?i)X-Plex-Token=[A-Za-z0-9_-]{16,}')),
]


def issues(name, data, private_terms=()):
    path = Path(name)
    found = []
    if any(p in FORBIDDEN for p in path.parts) or path.name in ('AGENTS.md', 'AGENTS.override.md') or path.name.startswith('.env') or path.suffix.lower() in ('.log', '.pem', '.key', '.pfx', '.fbxqml', '.pyc'):
        found.append('local-only file')
    for category, pattern in PATTERNS:
        if pattern.search(data): found.append(category)
    for term in private_terms:
        if len(term) >= 4 and term.encode('utf8').lower() in data.lower():
            found.append('private local value');break
    return found


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def main():
    private_file=ROOT/'.local/private-terms.json'
    private_terms=json.loads(private_file.read_text(encoding='utf-8-sig')) if private_file.exists() else []
    names=git('ls-files','-z').decode('utf8').split('\0')
    errors=[];count=0
    for name in filter(None,names):
        count+=1
        data=git('show',':'+name)
        errors.extend((name,issue) for issue in issues(name,data,private_terms))
    for name,issue in errors:print('REJECTED:',name,'—',issue)
    print('Public index:',count,'files;',len(errors),'issue(s). Private values are never printed.')
    return 1 if errors or not count else 0


if __name__=='__main__':sys.exit(main())

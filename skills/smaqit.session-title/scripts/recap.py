import json, sys

path = sys.argv[1]
lines = open(path).readlines()

turns_seen = 0
non_empty_lines = 0

for line in lines:
    line = line.strip()
    if not line:
        continue
    non_empty_lines += 1
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue

    t = obj.get('type')
    if t not in ('user', 'assistant'):
        continue
    if t == 'user' and obj.get('origin', {}).get('kind') != 'human':
        continue

    message = obj.get('message', {})
    content = message.get('content', '')
    if isinstance(content, list):
        text = ''.join(
            block.get('text', '')
            for block in content
            if isinstance(block, dict) and block.get('type') == 'text'
        )
    else:
        text = content or ''

    if not text:
        continue

    turns_seen += 1
    label = 'USER' if t == 'user' else 'ASSISTANT'
    print(f'{label}:', repr(text[:400]))

if non_empty_lines and turns_seen == 0:
    print(
        f"WARNING: recap.py parsed {non_empty_lines} non-empty line(s) from {path} "
        "but extracted zero user/assistant turns — the transcript schema may have "
        "changed and this parser needs updating.",
        file=sys.stderr,
    )
    sys.exit(1)

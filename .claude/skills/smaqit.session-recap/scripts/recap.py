import json, sys

path = sys.argv[1]
lines = open(path).readlines()
for line in lines:
    obj = json.loads(line)
    t = obj.get('type')
    d = obj.get('data', {})
    if t == 'user.message':
        content = d.get('content', '')
        if content:
            print('USER:', repr(content[:400]))
    elif t == 'assistant.message':
        content = d.get('content', '')
        if content:
            print('ASSISTANT:', repr(content[:400]))

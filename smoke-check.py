"""Run inside the search container: Get-Content smoke-check.py | docker compose exec -T search python -"""
import json
import urllib.request
import time


def request(url, body=None, timeout=90):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.load(response)


for attempt in range(3):
    results = request('http://search:8080/search?q=Premier%20League%20FPL%20injury%20news&format=json')
    if results.get('results'):
        break
    time.sleep(5)
print(json.dumps({'upstream_errors': results.get('unresponsive_engines', [])}), flush=True)
print(json.dumps({'search_results': len(results['results']), 'sources': [r['url'] for r in results['results'][:3]]}), flush=True)
bootstrap = request('https://fantasy.premierleague.com/api/bootstrap-static/')
assert bootstrap.get('elements') and bootstrap.get('events'), 'FPL API returned no player/gameweek data'
print(f"FPL API: {len(bootstrap['elements'])} players", flush=True)
models = request('http://ollama:11434/api/tags')['models']
assert any(m['name'] == 'qwen3:8b' for m in models), 'Qwen3 8B not installed'
answer = request('http://ollama:11434/api/chat', {
    'model': 'qwen3:8b', 'think': True, 'stream': False,
    'messages': [{'role': 'user', 'content': 'Reply with exactly the word yes.'}],
    'options': {'num_ctx': 8192, 'num_predict': 256, 'temperature': 0},
}, timeout=600)
assert answer['message']['content'].strip().lower().rstrip('.') == 'yes', 'Reasoning smoke test returned an unexpected answer'
assert answer['message'].get('thinking'), 'Model returned no thinking output'
print('Qwen3 8B: thinking enabled, completed response received', flush=True)
assert results.get('results'), 'Search returned no results'

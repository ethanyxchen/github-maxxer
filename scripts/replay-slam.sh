#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if pgrep -x Hammertime >/dev/null; then
  osascript -e 'quit app "Hammertime"'
  while pgrep -x Hammertime >/dev/null; do sleep 0.2; done
fi
python3 - <<'PY'
import json, os
path = os.path.expanduser('~/Library/Application Support/GitHub Maxxer/state.json')
state = json.load(open(path))
for connection in state['connections']:
    pulls = connection['snapshot']['pullRequests']
    if not pulls:
        continue
    newest = max(pulls, key=lambda pull: pull['mergedAt'])
    connection['snapshot']['pullRequests'] = [pull for pull in pulls if pull['id'] != newest['id']]
    print('Replaying:', newest['title'])
json.dump(state, open(path, 'w'))
PY
open build/Hammertime.app

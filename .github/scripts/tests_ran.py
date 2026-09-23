#!/usr/bin/env python3
"""Fails when a `flutter test --file-reporter json:<path>` run executed no
test, or when any test it executed failed.

A skipped test is reported as passed, so a platform where every proxy and
container test skips itself (unsupported feature, filter matching nothing)
would otherwise go green without having tested anything.
"""
import json
import sys

names, ran, skipped, errors = {}, [], [], {}
with open(sys.argv[1]) as report:
    for line in report:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'testStart':
            names[event['test']['id']] = event['test']['name']
        elif event.get('type') == 'error':
            errors.setdefault(event['testID'], []).append(event.get('error', ''))
        elif event.get('type') == 'testDone' and not event.get('hidden'):
            name = names.get(event['testID'], '?')
            if event.get('skipped'):
                skipped.append(name)
            else:
                ran.append((event.get('result'), name))
                for error in errors.get(event['testID'], []):
                    ran.append(('', '    ' + error.strip().replace('\n', '\n    ')))

for result, name in ran:
    print(f'{result:8} {name}')
for name in skipped:
    print(f'skipped  {name}')
if not any(result for result, _ in ran):
    sys.exit('no test ran: every matching test was skipped, or none matched')
if any(result not in ('success', '') for result, _ in ran):
    sys.exit('a test failed')

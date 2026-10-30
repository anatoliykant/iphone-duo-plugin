"""Reads the probe app's console log for run.sh.

probe_log.py window <log> [from-line]   -> "<width> <height> <orientation> <gate>" of the last window event
probe_log.py touches <log> [from-line]  -> one "<phase> <x> <y> <t>" line per touch event
"""
import json
import sys


def events(path, start):
    with open(path, errors="replace") as log:
        for number, line in enumerate(log, 1):
            line = line.strip().replace("\r", "")
            if number > start and line.startswith("PROBE "):
                try:
                    yield json.loads(line[6:])
                except ValueError:
                    pass


query, path = sys.argv[1], sys.argv[2]
start = int(sys.argv[3]) if len(sys.argv) > 3 else 0
if query == "window":
    last = None
    for event in events(path, start):
        if event.get("event") == "window":
            last = event
    if last:
        print(f'{last["width"]:g} {last["height"]:g} {last["orientation"]} {str(last["gate"]).lower()}')
elif query == "touches":
    for event in events(path, start):
        if event.get("event") == "touch":
            print(f'{event["phase"]} {event["x"]:g} {event["y"]:g} {event.get("t", 0):g}')

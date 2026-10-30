"""Times the presentation (booth3d/lib/talk/presentation.dart) from the
narration's clips: each beat stays on for its clip, started a moment in,
and a breath after it, the breaths even, so that the whole talk, from the
title to the end of the thanks, takes its version's total (variants.py).
A beat whose picture needs longer than its words (the shorter versions'
lines against scenes timed to the talk's) is held for it: at least
[HOLD] of the time the talk's own take gave it. Writes the version's
narration.json.

    python3 tool/narration/timing.py [--variant deep]   (from booth3d/; ffprobe on the PATH)
"""
import json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from variants import VARIANTS, pick  # noqa: E402

VARIANT, BEATS, _, OUT, TOTAL = pick(sys.argv)
LEAD = 0.6  # the voice comes in as the camera sets off
HOLD = 0.6


def seconds(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path], capture_output=True, text=True, check=True)
    return float(out.stdout)


# (What the talk's own timing gave each beat: its scenes were timed to it.)
talk = {}
if VARIANT != 'talk':
    try:
        talk = {c['beat']: c['dwell'] for c in json.load(open(os.path.join(VARIANTS['talk'][1], 'narration.json')))['clips']}
    except (OSError, ValueError, KeyError):
        pass

clips = [(beat, f'{i:02d}.mp3', seconds(os.path.join(OUT, f'{i:02d}.mp3'))) for i, (beat, _) in enumerate(BEATS)]
least = [HOLD * talk.get(beat, 0.0) for beat, _, _ in clips]


def dwells(breath):
    return [max(LEAD + s + (breath if i + 1 < len(clips) else 0), least[i]) for i, (_, _, s) in enumerate(clips)]


# The breath that makes the total (the dwells grow with it: halve the gap).
lo, hi = 0.0, 30.0
for _ in range(60):
    mid = (lo + hi) / 2
    lo, hi = (mid, hi) if sum(dwells(mid)) < TOTAL else (lo, mid)
breath = (lo + hi) / 2
if not 0.8 <= breath <= 4.0:
    spoken = sum(LEAD + s for _, _, s in clips)
    sys.exit(f'{VARIANT}: {spoken:.1f} s spoken: a breath of {breath:.2f} s between beats for {TOTAL / 60:.1f} min; lengthen or shorten the narration, or its total')
held = dwells(breath)
out = {
    'variant': VARIANT,
    'total': TOTAL,
    'clips': [{'beat': beat, 'file': f, 'start': LEAD, 'seconds': round(s, 3), 'dwell': round(held[i], 3)} for i, (beat, f, s) in enumerate(clips)],
}
json.dump(out, open(os.path.join(OUT, 'narration.json'), 'w'), indent=1, ensure_ascii=False)
padded = sum(1 for i, (_, _, s) in enumerate(clips) if held[i] > LEAD + s + breath + 0.01)
print(f'{VARIANT}: {len(clips)} clips, {sum(s for _, _, s in clips):.1f} s of voice, a {breath:.2f} s breath between beats ({padded} held for their scenes): {sum(held) / 60:.3f} min')

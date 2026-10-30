"""Cuts the teaser from the demo clips, to the music: segments cross-faded
at the given output times, each demo's title card, the end card last.

  teaser.py <videos dir> <spec.json> <h|v> <out.mp4>

spec.json: {"music": "music/teaser_music.mp3", "xfade": 0.4,
  "segments": [{"clip": "scrolls", "start": 1.8, "until": 5.0, "card": "scrolls",
                "first": true, "speed": 1.0, "crop": [x, y, w, h]}, …],
  "end": {"until": 32.5}}
"until" is the output time a segment hands over at (the next fades in
from there); "crop" (in the 1920×1080 clip) is for the vertical cut, the
part of the frame that fills the phone's width.
"""
import json, subprocess, sys

videos, spec_path, layout, out = sys.argv[1:5]
spec = json.load(open(spec_path))
segs, xf = spec['segments'], spec.get('xfade', 0.4)
vertical = layout == 'v'
W, H = (1080, 1920) if vertical else (1920, 1080)

# Each segment's own length: from where it starts showing (the last one's
# hand-over) to its own, plus the cross-fade into the next.
bounds, t = [], 0.0
for s in segs:
    bounds.append((t, s['until']))
    t = s['until']
end_until = spec['end']['until']

args, filters, labels, n = ['ffmpeg', '-v', 'error', '-y'], [], [], 0
for i, s in enumerate(segs):
    t0, t1 = bounds[i]
    dur = (t1 - t0) + xf
    speed = s.get('speed', 1.0)
    args += ['-ss', f"{s['start']:.3f}", '-t', f"{dur * speed:.3f}", '-i', f"{videos}/{s['clip']}.mp4"]
    v = n; n += 1
    chain = f"[{v}:v]setpts=(PTS-STARTPTS)/{speed},fps=30"
    if vertical:
        x, y, w, h = s['crop']
        sh = round(h * 1080 / w / 2) * 2
        top = s.get('top', 600 if sh >= 900 else 1920 // 2 - sh // 2 + 40)
        chain += f",crop={w}:{h}:{x}:{y},scale=1080:{sh}:flags=lanczos,pad=1080:1920:0:{top}:color=0x081728"
    chain += ",format=yuv420p,settb=AVTB"
    card = s.get('card')
    show_card = card and (vertical or s.get('first'))
    if show_card:
        png = f"{videos}/overlays/{'v_' if vertical else ''}{card}.png"
        args += ['-loop', '1', '-t', f"{dur:.3f}", '-i', png]
        o = n; n += 1
        if vertical:
            fades = "fade=t=in:st=0:d=0.3:alpha=1" if s.get('first') else "null"
        else:
            fades = f"fade=t=in:st=0.35:d=0.45:alpha=1,fade=t=out:st={max(0.9, dur - 1.0):.2f}:d=0.45:alpha=1"
        filters.append(f"[{o}:v]format=rgba,{fades},setpts=PTS-STARTPTS[o{i}]")
        filters.append(f"{chain}[b{i}]")
        filters.append(f"[b{i}][o{i}]overlay=0:0:shortest=1,format=yuv420p,settb=AVTB[s{i}]")
    else:
        filters.append(f"{chain}[s{i}]")
    labels.append((f"s{i}", dur))

# The end card, to the music's end.
end_dur = end_until - segs[-1]['until']
args += ['-loop', '1', '-t', f"{end_dur + 0.05:.3f}", '-i', f"{videos}/{'v_' if vertical else ''}endcard.png"]
e = n; n += 1
filters.append(f"[{e}:v]setpts=PTS-STARTPTS,fps=30,scale={W}:{H},format=yuv420p,settb=AVTB[se]")
labels.append(("se", end_dur))

cur, total = labels[0][0], labels[0][1]
for k, (lab, d) in enumerate(labels[1:], 1):
    nxt = f"x{k}"
    filters.append(f"[{cur}][{lab}]xfade=transition=fade:duration={xf}:offset={total - xf:.3f}[{nxt}]")
    cur, total = nxt, total + d - xf
filters.append(f"[{cur}]fade=t=in:st=0:d=0.6,trim=duration={end_until:.3f},format=yuv420p[final]")

music = spec.get('music')
if music:
    args += ['-i', f"{videos}/{music}"]
    m = n; n += 1
    filters.append(f"[{m}:a]atrim=duration={end_until:.3f},afade=t=out:st={end_until - 0.8:.3f}:d=0.8[aout]")
args += ['-filter_complex', ';'.join(filters), '-map', '[final]']
if music:
    args += ['-map', '[aout]', '-c:a', 'aac', '-b:a', '256k']
args += ['-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-profile:v', 'high', '-pix_fmt', 'yuv420p',
         '-movflags', '+faststart', '-r', '30', out]
r = subprocess.run(args, capture_output=True, text=True)
if r.returncode:
    sys.exit('ffmpeg failed:\n' + '\n'.join(l for l in r.stderr.splitlines() if 'Parsed' in l or 'rror' in l or 'xfade' in l or 'overlay' in l)[:2500])
print(f"{layout}: {end_until:.1f} s → {out}")

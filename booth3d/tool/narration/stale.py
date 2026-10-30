"""Which narration clips no longer say what script.py has them say: a take
spoken since its line changed, a line that's new, or a take cut from
another (those it can't vouch for). Each take is known by its sound (a hash
of the file), so renumbering the clips doesn't lose track of them;
gen.py remembers each take it makes (assets/narration/takes.json).

    python3 tool/narration/stale.py [--variant deep]     (from booth3d/): the
        beat numbers to speak again, for regen_narration.sh
"""
import hashlib, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from variants import pick  # noqa: E402

VARIANT, BEATS, _, OUT, _ = pick(sys.argv)
TAKES = os.path.join(OUT, 'takes.json')


def _hash(path):
    return hashlib.sha1(open(path, 'rb').read()).hexdigest()


def _said(text):
    return ' '.join(text.split())


def _load():
    try:
        return json.load(open(TAKES))
    except (OSError, ValueError):
        return {}


def remember(path, text):
    """Notes that the take at [path] says [text]."""
    takes = _load()
    takes[_hash(path)] = _said(text)
    json.dump(takes, open(TAKES, 'w'), indent=1, ensure_ascii=False, sort_keys=True)


def said_by(text):
    """A take, in any version's clips, that says [text] already (its
    path), or None: a line two versions share is spoken once."""
    from variants import VARIANTS
    want = _said(text)
    for _, out, _ in VARIANTS.values():
        try:
            takes = json.load(open(os.path.join(out, 'takes.json')))
        except (OSError, ValueError):
            continue
        for name in sorted(os.listdir(out)) if os.path.isdir(out) else []:
            path = os.path.join(out, name)
            if name.endswith('.mp3') and takes.get(_hash(path)) == want:
                return path
    return None


def stale():
    takes = _load()
    out = []
    for i, (_, text) in enumerate(BEATS):
        path = os.path.join(OUT, f'{i:02d}.mp3')
        if not os.path.exists(path) or takes.get(_hash(path)) != _said(text):
            out.append(i)
    return out


if __name__ == '__main__':
    which = stale()
    for i in which:
        print(f'{i:02d} {BEATS[i][0]}', file=sys.stderr)
    print(' '.join(str(i) for i in which))

"""The narration's versions: which script each speaks, where its clips go,
how long the whole talk takes with it. The talk itself (script.py) is
the presentation's default; the others are chosen when it starts
(NAME_CITY_VOICE=deep, the web's ?voice=deep).

    --variant talk|deep|quick     (gen.py, stale.py, timing.py; default talk)
"""
import importlib, os, sys

VARIANTS = {
    'talk': ('script', os.path.join('assets', 'narration'), 30 * 60.0),
    'deep': ('script_deep', os.path.join('assets', 'narration', 'deep'), 35 * 60.0),
    'quick': ('script_quick', os.path.join('assets', 'narration', 'quick'), 21 * 60.0),
}


def rest(argv):
    """[argv]'s arguments without the --variant flag."""
    if '--variant' not in argv:
        return argv[1:]
    i = argv.index('--variant')
    return argv[1:i] + argv[i + 2:]


def pick(argv):
    """The variant named by --variant in [argv], its script's BEATS and
    PAUSES, its clips' folder and its total."""
    name = argv[argv.index('--variant') + 1] if '--variant' in argv else 'talk'
    if name not in VARIANTS:
        sys.exit(f'no variant {name}: {", ".join(VARIANTS)}')
    module, out, total = VARIANTS[name]
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    m = importlib.import_module(module)
    return name, m.BEATS, getattr(m, 'PAUSES', {}), out, total

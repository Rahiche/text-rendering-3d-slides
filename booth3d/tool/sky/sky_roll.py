"""Turns an equirectangular Radiance HDR about the vertical: every row's
pixels shifted [cols] to the right (wrapping), losslessly (the RGBE bytes
moved, never decoded), written back run-length coded as Radiance's new
format. Moves where the panorama's two edges meet (flutter_scene's skybox
draws a hairline there) without moving anything in the sky, once the
measured sun (sky.dart's _skySun) is turned by the same angle.

    python3 tool/sky/sky_roll.py IN.hdr OUT.hdr COLS
"""
import sys


def read_hdr(path):
    data = open(path, 'rb').read()
    # The header: lines up to a blank one, then the resolution line.
    i = data.index(b'\n\n') + 2
    j = data.index(b'\n', i)
    header, res = data[:i], data[i:j]
    parts = res.split()
    assert parts[0] == b'-Y' and parts[2] == b'+X', res
    h, w = int(parts[1]), int(parts[3])
    pos = j + 1
    rows = []
    for _ in range(h):
        assert data[pos] == 2 and data[pos + 1] == 2 and (data[pos + 2] << 8 | data[pos + 3]) == w, 'not new-style RLE'
        pos += 4
        chans = []
        for _c in range(4):
            out = bytearray()
            while len(out) < w:
                n = data[pos]
                pos += 1
                if n > 128:
                    out += bytes([data[pos]]) * (n - 128)
                    pos += 1
                else:
                    out += data[pos:pos + n]
                    pos += n
            assert len(out) == w
            chans.append(bytes(out))
        rows.append(chans)
    assert pos == len(data), (pos, len(data))
    return header, res, w, h, rows


def rle(chan):
    out = bytearray()
    n, i = len(chan), 0
    while i < n:
        # A run of 3 or more the same: (128 + count, value).
        j = i
        while j < n and j - i < 127 and chan[j] == chan[i]:
            j += 1
        if j - i >= 3:
            out += bytes([128 + j - i, chan[i]])
            i = j
            continue
        # Otherwise literal bytes up to the next run (or 128 of them).
        k = i
        while k < n and k - i < 128:
            if k + 2 < n and chan[k] == chan[k + 1] == chan[k + 2]:
                break
            k += 1
        out += bytes([k - i]) + chan[i:k]
        i = k
    return bytes(out)


def main():
    src, dst, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
    header, res, w, h, rows = read_hdr(src)
    k = cols % w
    with open(dst, 'wb') as f:
        f.write(header + res + b'\n')
        for chans in rows:
            f.write(bytes([2, 2, w >> 8, w & 255]))
            for c in chans:
                f.write(rle(c[w - k:] + c[:w - k]))
    # (Checked: read back, each row is the original turned.)
    _, _, w2, h2, back = read_hdr(dst)
    assert (w2, h2) == (w, h)
    for a, b in zip(rows, back):
        for ca, cb in zip(a, b):
            assert cb == ca[w - k:] + ca[:w - k]
    print(f'{dst}: {w}x{h}, turned {k} columns ({360 * k / w:.3f} degrees)')


if __name__ == '__main__':
    main()

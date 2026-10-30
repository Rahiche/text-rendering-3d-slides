#!/usr/bin/env bash
# Records Package Town's demos from the macOS build as 1080p30 MP4s: each
# rendered at 2560×1440 (BOOTH3D_SCALE=1.6) without the talk's overlay,
# scaled down with lanczos, its frames deleted once encoded.
#   record_demos.sh <repo> <out dir> [clip …]
set -uo pipefail
REPO="$1"; OUT="$2"; shift 2
mkdir -p "$OUT"
cd "$REPO" || exit 1
mkdir -p booth3d/build/capture

clip() { # name, talk script, times, extra defines…
  local name="$1" talk="$2" times="$3"; shift 3
  local tag="video_$name" extra=()
  for d in "$@"; do extra+=(--define "$d"); done
  rm -rf "booth3d/build/capture/$tag"
  echo "[$(date +%H:%M:%S)] $name: rendering $times"
  bash booth3d/tool/capture.sh --tag "$tag" --times "$times" \
    --define BOOTH3D_FPS=30 --define BOOTH3D_SCALE=1.6 --define BOOTH3D_OVERLAY=0 \
    --define "BOOTH3D_TALK=$talk" ${extra[@]+"${extra[@]}"} > "booth3d/build/capture/$tag.out" 2>&1
  local n; n=$(ls "booth3d/build/capture/$tag" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n" -lt 10 ]; then echo "[$(date +%H:%M:%S)] $name: FAILED ($n frames)"; tail -5 "booth3d/build/capture/$tag.out"; return; fi
  ffmpeg -v error -y -framerate 30 -i "booth3d/build/capture/$tag/f%05d.png" \
    -vf "scale=1920:1080:flags=lanczos,format=yuv420p" -c:v libx264 -preset slow -crf 15 \
    -profile:v high -movflags +faststart "$OUT/$name.mp4" \
    && echo "[$(date +%H:%M:%S)] $name: $n frames → $OUT/$name.mp4 ($(du -h "$OUT/$name.mp4" | cut -f1))"
  # (The scrolls' frames feed the README's animation too: kept, smaller.)
  if [ "$name" = scrolls ]; then
    mkdir -p "$OUT/frames_scrolls"
    for f in "booth3d/build/capture/$tag"/f*.png; do sips -Z 1280 "$f" --out "$OUT/frames_scrolls/$(basename "$f")" >/dev/null; done
  fi
  rm -rf "booth3d/build/capture/$tag"
}

want() { [ $# -eq 0 ] || [[ " $* " == *" $1 "* ]]; }
ALL=(${@+"$@"})
has() { [ ${#ALL[@]} -eq 0 ] && return 0; for a in ${ALL[@]+"${ALL[@]}"}; do [ "$a" = "$1" ] && return 0; done; return 1; }

has scrolls && clip scrolls "06/scrolls@2,13" "5.5-24" BOOTH3D_SCROLLS_DEMO=1
has fx1 && clip fx1 "06/stroke fx@2,10,18" "3.5-26"
has fx2 && clip fx2 "06/stroke fx@2,10,18,26,34,42" "26-50"
has path && clip path "06/text on path@2,9,15.5,22" "4.5-29.5"
has pen && clip pen "06/handwriting@2,12" "4.5-20"
echo "[$(date +%H:%M:%S)] done"

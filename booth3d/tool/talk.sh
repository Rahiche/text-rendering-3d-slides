#!/usr/bin/env bash
# Opens the talk in the Mac app, Name City, fully offline (everything it
# shows is in the app: fonts, models, textures, the recorded voice). Builds
# and installs the app first only if it isn't installed yet
# (~/Applications/Name City.app); otherwise it just opens it.
#
#   bash booth3d/tool/talk.sh             the talk, from the title
#   bash booth3d/tool/talk.sh 5           from section 05 (1–6)
#   bash booth3d/tool/talk.sh 6 "text on path"   from that stop of 06 (its
#                                         name as on the way along the bottom)
#   bash booth3d/tool/talk.sh --voice     the presentation: told by itself in
#                                         the recorded voice, 30 minutes
#   bash booth3d/tool/talk.sh --voice deep    the deep dive (35 minutes), or
#                                         quick, the shorter talk (21): each
#                                         once its clips are made (tool/narration)
#   bash booth3d/tool/talk.sh --rebuild   build and install it again first
#                                         (after pulling changes)
#
# In the talk: → / Space next, ← back, Home / End the section's first and
# last stop, 0–6 a section, B blanks the screen, Esc leaves the talk (F5
# back into it). Ctrl+Shift+Q quits the app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$HOME/Applications/Name City.app"
ENV=NAME_CITY_TALK=1 REBUILD=0 VOICE=talk STOP=
for a in "$@"; do
  case "$a" in
    --voice) ENV=NAME_CITY_PRESENT=1 ;;
    deep | quick) ENV=NAME_CITY_PRESENT=1 VOICE="$a" ;;
    --rebuild) REBUILD=1 ;;
    [1-6] | 0[1-6]) ENV="NAME_CITY_TALK=0${a: -1}" ;;
    *)
      if [[ "$ENV" == NAME_CITY_TALK=0* && -z "$STOP" ]]; then
        STOP="$a"
      else
        echo "usage: bash booth3d/tool/talk.sh [1-6 [stop]] [--voice [deep|quick]] [--rebuild]" >&2
        exit 64
      fi
      ;;
  esac
done
[ -n "$STOP" ] && ENV="$ENV/$STOP"

if [ "$REBUILD" = 1 ] || [ ! -d "$APP" ]; then
  echo "Building Name City (a few minutes, only this once)…"
  bash tool/build_macos.sh
fi

# (One already open is quit first: the talk opens in a fresh one.)
running() { pgrep -f "Name City.app/Contents/MacOS" >/dev/null; }
if running; then
  osascript -e 'quit app "Name City"' >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do
    running || break
    sleep 0.2
  done
  running && pkill -f "Name City.app/Contents/MacOS" || true
  while running; do sleep 0.2; done
fi
open -a "$APP" --env "$ENV" --env "NAME_CITY_VOICE=$VOICE"
case "$ENV" in
  NAME_CITY_PRESENT=*) echo "Name City: the presentation ($VOICE), in the recorded voice (Space pauses, Esc stops)" ;;
  NAME_CITY_TALK=1) echo "Name City: the talk, from the title (→ next, ← back, Esc leaves)" ;;
  *) echo "Name City: the talk, from section ${ENV#*=} (→ next, ← back, Esc leaves)" ;;
esac

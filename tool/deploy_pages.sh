#!/usr/bin/env bash
# Builds the 3D slides for the web as WebAssembly and force-pushes them to
# this repo's gh-pages branch (https://rahiche.github.io/text-rendering-3d-slides/).
# The page opens straight into the talk (NAME_CITY_TALK=1).
#   bash tool/deploy_pages.sh
# DEPLOY_NOTE adds a paragraph to the deploy commit's message.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${BASE_PATH:-/text-rendering-3d-slides/}"
REMOTE="$(git remote get-url origin)"
SHA=$(git rev-parse --short HEAD)

# (Its physics, Rapier, is a WebAssembly module served beside the page.)
(cd booth3d && flutter build web --wasm --release --base-href "$BASE" \
  --dart-define=FLUTTER_SCENE_RAPIER_WASM_URL=rapier.wasm \
  --dart-define=NAME_CITY_TALK=1 | grep -E "✓|rror" || true)

OUT=build/pages
rm -rf "$OUT"
mkdir -p build
cp -R booth3d/build/web "$OUT"
# (The presenter's voice never ships: the web's presentation plays silent.)
find "$OUT" -name '*.mp3' -delete
n=$(find "$OUT" -path '*flutter_scene_generated*' -type f | wc -l | tr -d ' ')
[ "$n" -gt 5 ] || { echo "scene assets missing ($n)"; exit 1; }
find "$OUT" -name .gitignore -delete
touch "$OUT/.nojekyll"

cd "$OUT"
rm -rf .git
git init -q -b gh-pages
git config http.postBuffer 524288000
git add -A
git commit -q -m "Deploy $SHA" ${DEPLOY_NOTE:+-m "$DEPLOY_NOTE"}
git push -q --force "$REMOTE" gh-pages
echo "pushed $SHA to gh-pages"

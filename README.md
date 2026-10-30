# Inside Flutter's Text Pipeline · the 3D slides

The talk *Inside Flutter's Text Pipeline*, told in **Name City** (名前の街): a 3D city built with Flutter, where every stop of the talk is a place. A word travels from code points to pixels, Japanese scrolls unroll on a rooftop and take your typing, and Dash drives a delivery in for the thank-you.

**Open it in the browser (WebAssembly):** https://rahiche.github.io/text-rendering-3d-slides/

## Presenting

| Key | |
|---|---|
| → · Space · PageDown | next |
| ← · PageUp | back |
| Home · End | the section's first and last stop |
| 0–6 | jump to a section (0 is the title) |
| B or . | blank the screen (any key brings it back) |
| Esc | leave the talk (F5 brings it back) |

The page opens straight into the talk. To open at a section or a stop, add `?talk=05` or `?talk=06/text%20on%20path` to the address.

F6 plays the talk as a presentation, telling itself beat by beat. The presenter's recorded voice isn't in this repo, so on the web it plays silent.

## Running it

```sh
cd booth3d
flutter run -d macos --dart-define=NAME_CITY_TALK=1
```

- **Mac app:** `bash booth3d/tool/build_slides_app.sh [folder]` builds *Inside Flutter's Text Pipeline.app*, opening into the talk.
- **The web page:** `bash tool/deploy_pages.sh` builds it as WebAssembly and pushes it to `gh-pages`.

## What's here

- `booth3d/`: the city and the talk ([flutter_scene](https://pub.dev/packages/flutter_scene), on Flutter GPU).
- `lib/`: only what the 3D app takes from the talk's 2D deck: its theme and font data, and the conference booth's name builder.
- `packages/slug/`: GPU text from glyph outlines, for the talk's Slug stop.

The city shows off the presenter's own packages: [fountain_pen](https://pub.dev/packages/fountain_pen), [text_on_path](https://pub.dev/packages/text_on_path) and [stroke_fx](https://pub.dev/packages/stroke_fx).

The 2D deck and the conference booth live in [text-rendering-slides](https://github.com/Rahiche/text-rendering-slides). This repo was split out of it.

Credits for the models, textures, sky and people are in `booth3d/assets/*/CREDITS.md`. The fonts are open-licensed (SIL Open Font License or Apache 2.0).

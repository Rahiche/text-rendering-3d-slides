# Inside Flutter's Text Pipeline · the 3D slides

The talk *Inside Flutter's Text Pipeline*, told in **Name City** (名前の街): a 3D city built with Flutter, where every stop of the talk is a place. A word travels from code points to pixels, Japanese scrolls unroll on a rooftop and take your typing, and Dash drives a delivery in for the thank-you.

> **Use the native macOS app.** The city is a full 3D scene, and only the macOS build runs it smoothly. The web version is much slower and laggy in the browser: treat it as a quick preview, not a way to watch or present the talk.

## Running it on macOS

```sh
cd booth3d
flutter run -d macos --release --dart-define=NAME_CITY_TALK=1
```

Run it in release mode: a debug build is slow too.

To build the app itself, run `bash booth3d/tool/build_slides_app.sh [folder]`. It builds *Inside Flutter's Text Pipeline.app*, which opens straight into the talk.

## Presenting

| Key | |
|---|---|
| → · Space · PageDown | next |
| ← · PageUp | back |
| Home · End | the section's first and last stop |
| 0–6 | jump to a section (0 is the title) |
| B or . | blank the screen (any key brings it back) |
| Esc | leave the talk (F5 brings it back) |

To open at a section or a stop, launch it with `NAME_CITY_TALK=05` or `NAME_CITY_TALK="06/text on path"`. Pass it as a `--dart-define`, or set it with `open -a "Inside Flutter's Text Pipeline" --env NAME_CITY_TALK=05`.

F6 plays the talk as a presentation, telling itself beat by beat. The presenter's recorded voice isn't in this repo, so it plays silent.

## Web preview (slow)

https://rahiche.github.io/text-rendering-3d-slides/ is the same app built as WebAssembly. Expect a low frame rate and stutter. It opens into the talk; add `?talk=05` or `?talk=06/text%20on%20path` to open at a section or a stop.

`bash tool/deploy_pages.sh` rebuilds it and pushes it to `gh-pages`.

## What's here

- `booth3d/`: the city and the talk ([flutter_scene](https://pub.dev/packages/flutter_scene), on Flutter GPU).
- `lib/`: only what the 3D app takes from the talk's 2D deck: its theme and font data, and the conference booth's name builder.
- `packages/slug/`: GPU text from glyph outlines, for the talk's Slug stop.

The city shows off the presenter's own packages: [fountain_pen](https://pub.dev/packages/fountain_pen), [text_on_path](https://pub.dev/packages/text_on_path) and [stroke_fx](https://pub.dev/packages/stroke_fx).

The 2D deck and the conference booth live in [text-rendering-slides](https://github.com/Rahiche/text-rendering-slides). This repo was split out of it.

Credits for the models, textures, sky and people are in `booth3d/assets/*/CREDITS.md`. The fonts are open-licensed (SIL Open Font License or Apache 2.0).

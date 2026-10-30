# Demo videos and the teaser

1. `bash tool/video/record_demos.sh . build/videos [clip …]`: renders the demos from the macOS app at 2560×1440 (no overlay) and encodes 1080p30 MP4s. Clips: scrolls, fx1, fx2, path, pen. Run one recorder at a time; the captures share the app's container.
2. Music: ElevenLabs, `POST /v1/music` with `music_plan.json` (sections timed to the cuts), key from `ELEVENLABS_API_KEY`.
3. `swiftc -O tool/video/card.swift -o build/card`, then the title cards (`lower`, `vtitle`) and end cards (`end`, `vend`) into `build/videos/overlays/`.
4. `python3 tool/video/teaser.py build/videos tool/video/teaser_spec.json h|v out.mp4`: cuts the 16:9 or 9:16 teaser to the music.

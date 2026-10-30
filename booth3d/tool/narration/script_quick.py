"""The presentation's narration, the shorter talk (about 20 minutes): the
same beats as script.py, in the same order, each told more tightly, but
still with its example and the thing to do about it. For a shorter slot.
Spelled to be spoken, as script.py. (Where a beat's picture needs longer
than its words, timing.py holds it: the scene plays out before the next.)
"""
BEATS = [
    ("title slide", """
Hi everyone, I'm Raouf. Today we're going to follow a piece of text, from a string in memory to pixels on your screen, and see how Flutter handles every step along the way.
I've got my slides ready, so let's get started.
"""),
    ("title why", """
Why text? Because we've had problems with it, and we still do. And they're not Flutter problems, or Android, iOS or Chrome problems. They're the same problems, everywhere.
"""),
    ("title physical", """
For almost all of history, text was made by hand: on a wall, on a tree, on paper. Always in the physical world.
"""),
    ("title rules", """
Over the centuries, we built up thousands of rules for writing well, and passed them on, almost none of them ever written down.
"""),
    ("title computers", """
Then, suddenly, computers: five thousand years of writing by hand, and only sixty of computers. And we want all of those rules inside them.
"""),
    ("title problem", """
That's the real problem: bringing the physical world into the digital one. And to explain it, flat slides won't do.
"""),
    ("title city", """
Except, this isn't a slide deck. That slide was on a laptop, in a city made of text.
So I'll tell this story right here: the pipeline first, then what every script adds to it, then one word through Flutter, other engines, and what you can fix today.
"""),
    ("01 pipeline", """
The big picture: a string goes in, and pixels come out. In between, there are seven stages, and each one is owned by a different library.
The string is Unicode. I.C.U. itemizes it. The font manager handles fallback. HarfBuzz shapes it. I.C.U. finds the line breaks. Bidi reorders right-to-left text. And Skia and the GPU rasterize it.
Each stage is a stop in this city, so let's visit them in order.
"""),
    ("01 string0", """
First stop: a string is not the same thing as text.
For a plain word like hello, every way of counting agrees: five. But in Dart, string dot length counts UTF-16 code units, not what you see.
"""),
    ("01 string1", """
This family, out for a walk, is a single emoji on screen, one grapheme. But under the hood, it's four people, glued together by three invisible zero-width joiners. Flags and skin tones work the same way.
"""),
    ("01 string2", """
Take the joiners out, and the family falls apart into four people.
That one emoji is seven code points, eleven UTF-16 units, and twenty-five bytes in UTF-8.
"""),
    ("01 string3", """
So whenever you count text, ask: count what? To count what users actually see, use the characters package, not string dot length.
"""),
    ("01 itemize", """
Before anything can be shaped, the engine takes the whole paragraph and cuts it into runs.
Take this one: hi, konnichiwa sekai, and a waving hand.
"""),
    ("01 itemize2", """
It reads each character's Unicode script, and cuts wherever the script changes. So even Japanese splits in two: hiragana, then kanji. Spaces stay with the run they're in, and the emoji gets its own run, because it needs another font.
"""),
    ("01 itemize3", """
Out come four runs, each with exactly one script, one direction, and one font. That happens in SkParagraph, before shaping, and from here on, every stage works on runs.
"""),
    ("01 fallback", """
Next, font fallback. Fonts are asked in order, one character at a time: your app's fonts first, from font family and font family fallback, then the platform's.
Dash carries the code points from kiosk to kiosk, and asks each font if it has them.
"""),
    ("01 fallback A", """
A Latin A is found in Space Grotesk, on the first try.
"""),
    ("01 fallback ba", """
An Arabic letter takes two lookups.
"""),
    ("01 fallback zi", """
A Chinese character takes three.
"""),
    ("01 fallback emoji", """
And an emoji, four.
"""),
    ("01 fallback tofu", """
But U plus zero three seven eight isn't assigned to anything, so no font has it. The last font draws its not-def glyph: the empty box we call tofu.
"""),
    ("01 shaping", """
Now, shaping. HarfBuzz turns code points into glyph IDs and positions, and it's not one to one.
Arabic letters join into one connected word. An f and an i merge into a ligature, and in coding fonts, a dash and a greater-than become an arrow. Kerning pulls A and V together. A Devanagari vowel sign moves before its consonant. And five code points of an emoji collapse into a single glyph.
This forge is where letters go in, and glyphs come out.
"""),
    ("01 lines1", """
Then line breaking. Flutter is greedy: it fills each line up to the max width, then starts the next.
Where a line may break depends on the script. English breaks at spaces. Thai has no spaces, so I.C.U. uses a dictionary to find the words. And Japanese can break almost anywhere, except that a closing mark, like the full stop, may never start a line. That rule is called kinsoku.
"""),
    ("01 lines2", """
Here's the same paragraph on a phone. Turn it on its side: a new max width, so the same words flow into new lines.
"""),
    ("01 bidi", """
Next: memory is not the screen. Text is stored in the order you typed it, and the bidi algorithm reorders it for display.
Here's hi, the word Urdu in Urdu, and twenty twenty-six. On screen, the Urdu run is reversed, but the number still reads left to right.
So index i in memory isn't position i on screen. For cursors, selection and hit testing, let TextPainter do that math for you.
"""),
    ("01 raster", """
And the last stage: rasterization. A font stores no pixels, only outlines: points on the curve, and control points that bend it. This a is fifty points in two contours.
"""),
    ("01 raster aliased", """
A screen is a grid of pixels, so each pixel is shaded by how much the outline covers it, and the GPU fills them all in parallel. That's what this pixel farm is growing.
"""),
    ("01 raster subpixel", """
Subpixel rendering uses the red, green and blue thirds of a pixel, but macOS turned it off in version ten fourteen.
"""),
    ("01 raster grayscale", """
Flutter uses grayscale anti-aliasing.
"""),
    ("02 intro", """
That's the pipeline. Now let's see what every script adds to it, in ICU City, named after International Components for Unicode.
Latin lets you assume a lot: left to right, one shape per letter, letters side by side. Every other script breaks at least one of those, and real paragraphs mix them.
"""),
    ("02 unicode ascii", """
Here's the scale of the problem. In nineteen sixty-three, ASCII had a hundred and twenty-eight characters.
"""),
    ("02 unicode 1", """
Unicode one, in ninety-one, had about seven thousand.
"""),
    ("02 unicode 6", """
Emoji arrived with Unicode six, in twenty ten.
"""),
    ("02 unicode 18", """
And Unicode eighteen has a hundred and seventy-two thousand, eight hundred and eight characters, in more than a hundred and seventy scripts. Every version adds more for fonts and renderers to keep up with.
"""),
    ("02 alley", """
Welcome to Script Alley: six things Latin lets you assume, and a script that breaks each one.
We've already met direction, at the bidi stop, and shape and order, at the forge. So let's visit the other three: stacked marks, syllable blocks, and vertical lines.
"""),
    ("02 stacking", """
First, stacking. In Thai, a vowel sits above the consonant, and the tone mark goes above that, raised so they don't collide.
Placing those marks is the font's job, with anchor points, and the shaper applies them.
"""),
    ("02 blocks", """
Next, composition. Korean letters, called jamo, are composed into square syllable blocks. The letters h, a and n become one block, han, a single code point. Unicode has more than eleven thousand of them.
"""),
    ("02 vertical", """
And vertical text. Japanese can be set from top to bottom, with the columns running right to left, and Mongolian runs top to bottom too.
"""),
    ("02 locale", """
Now, one code point, two glyphs. Chinese and Japanese share these code points, but each draws them differently: look at the strokes.
The locale picks the font. So in Flutter, set the locale to Japanese on Japanese text, or your users will see the Chinese forms. It's one of the most common rendering bugs in apps made for Japan.
"""),
    ("02 mixing", """
And mixing multiplies everything. This one paragraph, in English, Arabic, Japanese and emoji, makes six runs in two directions, four fonts with two shapers, and two line breakers.
One mixed paragraph exercises the whole pipeline at once, and it's exactly the kind of text your users type.
"""),
    ("03 map", """
Now let's watch Flutter do it for real, and follow a Text widget saying Flutter, all the way down to pixels.
Layout takes it down into the engine, paint records it, and the GPU draws it, here in the Glyph Works. We'll follow the first letter down the line.
"""),
    ("03 widget", """
It starts with a widget. Text only describes: a string, and a style.
Underneath, it builds a RenderParagraph, whose TextPainter builds the paragraph. Dart keeps the string as UTF-16: Flutter is seven code units.
"""),
    ("03 engine", """
Across dart U.I., the engine's S.K. Paragraph takes the text, as UTF-8.
"""),
    ("03 decode", """
The decoder runs I.C.U.: it marks the graphemes, the line breaks, the direction and the script. For Flutter, that's a single run.
"""),
    ("03 fonts", """
Next, find the glyphs. The font's cmap table maps each code point to a glyph ID, and every letter is found in Space Grotesk, the first font. No fallback needed.
"""),
    ("03 shape", """
HarfBuzz shapes the run into glyphs and their advances. Notice the two t's: they join into one ligature, so seven code points become six glyphs.
"""),
    ("03 line", """
Then layout wraps the run to the max width. Shaping, the expensive part, is done once; wrapping can happen again whenever the width changes.
"""),
    ("03 paint", """
Paint doesn't draw anything yet. It records glyph IDs and positions into a display list, for the raster thread.
"""),
    ("03 outline", """
On the raster thread, each glyph that's not cached yet starts as an outline from the font, scaled to the text's size.
"""),
    ("03 raster", """
Then it's rasterized once, as coverage, into the glyph atlas. The next time this glyph shows up at this size, it's simply reused.
"""),
    ("03 draw", """
And finally, draw. Each glyph becomes a quad pointing into the atlas, the shader multiplies the color by the coverage, and the whole word goes out in one draw call.
And there it is: Flutter, on the board, pixel for pixel.
"""),
    ("04 engines", """
But Flutter isn't the only engine that draws text. Here are five, each somewhere between owning the whole stack and using the platform's.
Chrome, Figma, Android and Flutter all shape with HarfBuzz. Apple has its own shaper. Let's see what each one gets from where it sits.
"""),
    ("04 chrome", """
Chrome first. Text lives in the DOM, so balanced lines, hyphens, vertical text and ruby are a line of CSS away, and you can find, select and translate it. The price: the platform decides how your text looks.
"""),
    ("04 figma", """
Figma is the closest to Flutter: one canvas, its own text engine. Text looks the same on every system, but every feature is theirs to build. Right-to-left only arrived in twenty twenty-two.
"""),
    ("04 macos", """
On macOS, Apple owns the entire stack, shaper included. Justification, hyphenation, vertical text and ruby are all built in, like a book typesetter.
"""),
    ("04 android", """
And Android's Minikin can weigh a whole paragraph before it breaks a line: simple, balanced, or high quality, with hyphens.
Flutter's text stack came from Minikin, but only kept the simple, first-fit breaker.
"""),
    ("05 intro", """
So where does that leave Flutter? It draws every pixel itself. That buys consistency and effects, and it costs the features the platform would give for free. Let's look at both sides.
"""),
    ("05 missing1", """
First, what's missing. Here's Chrome's page, set by Flutter. There's no vertical text, so you need a package like mongol.
"""),
    ("05 missing1b", """
And there's only the greedy line breaker, so lines come out ragged instead of balanced.
"""),
    ("05 missing2", """
There's no ruby, the small reading hints above Japanese, like on this cable car over Tokyo. In Flutter, you build them yourself with widget spans.
"""),
    ("05 missing3", """
And there's no automatic hyphenation: soft hyphens go in by hand. No kashida justification for Arabic either, and no subpixel rendering.
"""),
    ("05 web", """
On the web, Flutter's text is drawn on a canvas, so the browser can't search it: control F finds nothing. And Noto fonts download late, showing tofu until they arrive, unless you preload them. Screen readers still work, through the semantics tree.
"""),
    ("05 only1", """
But owning every pixel buys Flutter things, too. First, it's the same everywhere: one layout engine, so these two phones show exactly the same lines, pixel for pixel.
"""),
    ("05 only2", """
Second, you can paint text however you like: shaders, strokes, variable fonts. In this gym, the font's weight axis animates smoothly, the same on every platform.
"""),
    ("05 only3", """
And third, you get every glyph: a box for each grapheme, so you can animate letters one by one, even in 3D, without any relayout.
"""),
    ("06 intro", """
Some of those gaps, you can close today. Here are five of them, in Package Town, each closed by a small package, with no fork of Flutter.
"""),
    ("06 phrases", """
First: Japanese phrase breaking. Plain Text happily splits a word in the middle of a phrase, and that's hard to read.
"""),
    ("06 phrases fix", """
The kumihan package finds the phrases with Budou X, and glues them with invisible word joiners. So lines only break between phrases.
"""),
    ("06 punctuation", """
Second: punctuation spacing. Full-width marks carry half an em of blank, so where two of them meet, the gap doubles.
"""),
    ("06 punctuation fix", """
Kumihan applies the font's halt feature exactly where the marks meet, and the gap closes.
"""),
    ("06 slug", """
Third: text on the GPU. Glyphs live in an atlas as small bitmaps, so when you zoom in or tilt them, they blur.
"""),
    ("06 slug fix", """
Slug draws them straight from their curves, in a shader, so they stay sharp at any zoom and any angle. And its patent is now in the public domain.
"""),
    ("06 handwriting", """
And fourth: handwriting. A wipe, or even Tegaki, which reveals the font stroke by stroke, only uncovers the font, and always ends as the typeset word.
"""),
    ("06 handwriting fix", """
So I built fountain pen, on pub dot dev. It traces the font into a hand's strokes, and a pen writes them out: heavy downstrokes, fine upstrokes, wet ink, and every letter a little different.
"""),
    ("06 path", """
And fifth: text on a path. Turning each letter whole onto a curve is fine in English.
"""),
    ("06 path cursive", """
Cursive English splits too, on a tight curve.
"""),
    ("06 path arabic", """
And Arabic is always joined: every word comes apart.
"""),
    ("06 path fix", """
Text on path, on pub dot dev, bends only the rows the letters join on, so the joins stay closed.
"""),
    ("06 fx frost", """
A bonus round: Stroke F X, effects along handwritten strokes. Frost Dash freezes the ink.
"""),
    ("06 fx ember", """
Ember Dash: molten ink.
"""),
    ("06 fx neon", """
Neon Dash: strokes light up.
"""),
    ("06 fx ivy", """
Ivy Dash: vines climb them.
"""),
    ("06 fx jelly", """
Jelly Dash: they wobble.
"""),
    ("06 fx sakura", """
And Sakura Dash: they blossom.
"""),
    ("end tradeoff", """
So, the trade-off. On this seesaw, every engine sits between owning the stack and using the platform's: Figma and Flutter on one end, Chrome and macOS on the other.
Flutter chose control, consistency and effects. The price is rebuilding features one package at a time, and a lot of that can be done today, in plain Dart.
"""),
    ("end thanks", """
Before I finish, we have a special delivery from Dash.
That's it from me. Thank you so much for listening. ありがとうございました!
I'd love to hear your questions.
"""),
]

PAUSES = {}

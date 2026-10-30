"""The presentation's narration, the deep dive (about 29 minutes): the same
beats as script.py, in the same order, saying more of how and why at each,
and what to do about it from Dart. For an audience that writes text-heavy
apps. Spelled to be spoken, as script.py.
"""
BEATS = [
    ("title slide", """
Hi everyone, I'm Raouf. For the next half hour, we're going to follow a piece of text, from the moment it's a string in memory to the moment it becomes pixels on your screen.
And at every step, we'll look at which library does the work, what it costs, and what you can control from Dart. I've got my slides ready, so let's get started.
"""),
    ("title why", """
The reason I'm talking about text is that we've had problems with it, and we still have them today.
And they're not Flutter problems. They're not specific to Android or iOS, or to Chrome, or to any other platform. They're the same problems, everywhere.
"""),
    ("title physical", """
For almost all of history, ever since people first started writing, text was made by hand: marks on a wall, letters carved into a tree, ink on a sheet of paper. With a finger, or with a tool. Always in the physical world.
"""),
    ("title rules", """
And over the centuries, we kept refining it, with thousands of little rules about writing well: where to leave a space, where not to break a word, how letters join.
Each generation learned them from the one before, and almost none of them were ever written down.
"""),
    ("title computers", """
Then, suddenly, computers. Five thousand years of writing by hand, and only about sixty years of computers.
And now we want all of those unwritten rules inside a machine that has never heard of any of them.
"""),
    ("title problem", """
So that's the real problem: bringing something from the physical world into the digital one.
And to explain it properly, I'd have to take you into another dimension. Flat slides won't do.
"""),
    ("title city", """
Except, this isn't a slide deck. That slide was on a laptop, on a rooftop, in a city made of text: signs and words, in every script.
So instead of slides, I'll tell this story right here, where every idea has its own place. First the whole pipeline, stage by stage. Then what each writing system adds to it. Then we'll follow one word through Flutter's engine, compare Flutter with four other text engines, and finish with gaps you can close today.
"""),
    ("01 pipeline", """
Let's start with the big picture. A string goes in, and pixels come out. In between, there are seven stages, and each one is owned by a different library.
The string itself is Unicode. Itemizing cuts it into runs, with I.C.U. Font fallback finds a font for every character, through the font manager. Shaping turns characters into positioned glyphs, with HarfBuzz. Line breaking decides where a line may end, again with I.C.U.'s rules. Bidi reorders right-to-left text for display. And rasterization turns outlines into pixels, with Skia and the GPU.
In Flutter, nearly all of this runs in the engine, in C plus plus, behind a single call: paragraph layout. Every stage is a stop in this city, numbered in the order a string goes through them.
"""),
    ("01 string0", """
First stop: a string is not the same thing as text.
Take a plain Latin word: hello. Every way of counting it agrees: five characters, five code points, a length of five, and five bytes. So it's easy to think a string is just text.
But a Dart string is a sequence of UTF-16 code units, and string dot length counts those, not the things you actually see on screen.
"""),
    ("01 string1", """
Look at this family, out for a walk in the park. On screen, it's a single emoji, one grapheme cluster. Under the hood, it's four people, glued together by three invisible zero-width joiners.
And each person sits outside Unicode's basic plane, so in UTF-16 each one takes two code units, a surrogate pair. Accented letters, flags and skin tones are built the same way.
"""),
    ("01 string2", """
Take the joiners out, and the family falls apart into four separate people.
That one emoji is seven code points, eleven UTF-16 units, and twenty-five bytes in UTF-8. And an accented e can be one precomposed code point, or two: an e, plus a combining accent. They look identical, but they compare as different strings unless you normalize them.
"""),
    ("01 string3", """
So whenever you count text, the first question is: count what? Runes give you code points. Length gives you code units, which is right for indexes into a string, and wrong for anything a user sees.
For that, use the characters package. It splits text into extended grapheme clusters, by Unicode's rules, and it's what you want for cursors, for truncating, and for limiting how much someone can type.
"""),
    # (Itemize a press a part: in, read, out.)
    ("01 itemize", """
Before anything can be shaped, the engine takes the paragraph's whole text, all at once, and cuts it into runs.
Take this one: hi, konnichiwa sekai, and a waving hand.
"""),
    ("01 itemize2", """
How does it know where one run ends? Not by language. It reads each character's Unicode script property, and cuts wherever the script changes. So even Japanese splits in two: hiragana, then kanji, which Unicode calls Han.
Spaces and punctuation are Common, with no script of their own, so they stay with the run they're in. And the emoji gets a run of its own, because it needs a different font. Direction can cut a run too, but here, everything goes left to right.
"""),
    ("01 itemize3", """
Out come four runs: Latin, hiragana, Han, and an emoji, all going left to right. Mixing directions comes later.
Each run gets exactly one script, one direction, and one font, because that's what a shaper needs: HarfBuzz shapes one run at a time, with one font and one set of script rules. In Flutter, this happens in the engine, in SkParagraph, before any shaping. And from here on, every stage works on runs, not on the whole string.
"""),
    # (Dash a kiosk a press.)
    ("01 fallback", """
Next, font fallback. Fonts are asked in order, one character at a time. First your app's own fonts: the text style's font family, then its font family fallback list. Only then the platform's fonts.
On Apple platforms, that's Core Text's cascade list, on Android the system's fallback chain, and on the web, Flutter downloads Noto fonts as it needs them. Dash here carries the code points from kiosk to kiosk, and asks each font if it has them.
"""),
    ("01 fallback A", """
A Latin A is found in Space Grotesk, the app's own font, on the very first try.
"""),
    ("01 fallback ba", """
An Arabic letter isn't in Space Grotesk, so it takes two lookups: the next font, Noto Kufi Arabic, has it.
"""),
    ("01 fallback zi", """
A Chinese character takes three. It falls all the way through to the system's C.J.K. font.
"""),
    ("01 fallback emoji", """
And an emoji, four: only the color emoji font has it.
"""),
    ("01 fallback tofu", """
But this code point, U plus zero three seven eight, isn't assigned to anything. No font has it. So the last font draws glyph number zero, its not-def glyph, the empty box we call tofu.
When you see tofu, either a font is missing, or the code point is. Bundling the fonts you need fixes the first one.
"""),
    ("01 shaping", """
Now, my favorite stage: shaping. HarfBuzz turns a run of code points into glyph IDs and positions, using the font's own tables: G-SUB substitutes glyphs, and G-POS positions them. And it's not one to one.
Arabic letters take initial, middle and final forms, so a word joins into one connected shape. An f and an i can merge into a single ligature, and in coding fonts, a dash and a greater-than sign become an arrow. Kerning pulls pairs like A and V closer together. In Devanagari, a vowel sign is drawn before the consonant it follows in memory. And the five code points of a waving hand with a skin tone collapse into one single glyph.
This forge is where letters go in, and glyphs come out.
"""),
    ("01 lines1", """
Then comes line breaking. Flutter's approach is greedy: fill each line up to the max width, then start the next one.
Where a line is allowed to break comes from Unicode's line breaking algorithm, U.A.X. fourteen, implemented in I.C.U.'s break iterator. In English, you break at spaces, and after hyphens. Thai has no spaces between words at all, so I.C.U. finds the words with a dictionary. And Japanese can break between almost any two characters, with one catch: a closing mark, like the full stop or a closing bracket, may never start a line, and an opening one may never end it. That set of rules is called kinsoku.
"""),
    ("01 lines2", """
Here's the same paragraph on a phone. Turn the phone on its side, and you get a new max width. The text isn't shaped again; only the breaking runs again, so the very same glyphs flow into brand new lines.
"""),
    ("01 bidi", """
Next: memory is not the screen. Text is stored in the order you typed it, and Unicode's bidirectional algorithm, U.A.X. nine, reorders it for display.
Here's hi, then the word Urdu, written in Urdu, then the year twenty twenty-six. On screen, the Urdu run is reversed. And look where the number went: digits that follow Arabic letters join the right-to-left run, so the year lands to the left of the Urdu word, while its digits still read left to right.
So index i in memory is not position i on screen. That matters for cursors, for selection, and for hit testing. TextPainter does that math for you: get offset for caret, get boxes for selection, get position for offset. Lean on them, instead of doing it by hand.
"""),
    ("01 raster", """
And the last stage of the pipeline: rasterization. A font doesn't store any pixels. Each glyph is an outline: points on the curve, and control points that bend the curves between them, quadratic curves in a TrueType font. For this a, that's fifty points in two contours, and that's all the font keeps.
"""),
    ("01 raster aliased", """
But a screen is a grid of pixels. So each pixel is shaded by how much of it the outline covers, and the GPU fills them all at once, in parallel, not row by row. That's what this pixel farm is growing. Aliased rendering just turns a pixel on when it's at least half covered, which looks jagged.
"""),
    ("01 raster subpixel", """
Subpixel rendering uses the red, green and blue stripes of each pixel for three times the horizontal detail, but it has to know the background and the panel, and macOS turned it off back in version ten fourteen.
"""),
    ("01 raster grayscale", """
Grayscale anti-aliasing maps the coverage to a shade of grey, and that's what Flutter does.
"""),
    ("02 intro", """
We've seen the whole pipeline. Now let's see what every script adds to it, in ICU City, named after International Components for Unicode, the library that knows all of these rules, and that Flutter's engine ships with.
Latin lets you assume a lot. Letters go from left to right, each letter has one shape, and they simply sit side by side.
Every other script breaks at least one of those assumptions. And a real paragraph doesn't stick to just one script. It mixes them. Let's see how far that goes.
"""),
    # (The archive a press an era.)
    ("02 unicode ascii", """
Here's the scale of the problem. In nineteen sixty-three, ASCII had a hundred and twenty-eight characters: seven bits, and English only.
"""),
    ("02 unicode 1", """
Unicode one, in ninety-one, had about seven thousand.
"""),
    ("02 unicode 6", """
Emoji arrived with Unicode six, in twenty ten.
"""),
    ("02 unicode 18", """
And today, Unicode eighteen has a hundred and seventy-two thousand, eight hundred and eight characters, across more than a hundred and seventy scripts.
Every new version adds characters that fonts and renderers have to keep up with. A brand new emoji shows up as tofu, until a font on the device has it.
"""),
    ("02 alley", """
Welcome to Script Alley. Here are six things Latin lets you assume, and a script that breaks each one, with a stall for each.
Three of them, we've already met: direction, at the bidi stop, and shape and order, at the forge.
So let's visit the other three. Stacked marks, with Thai. Syllable blocks, with Korean. And lines that run from top to bottom, with Japanese.
"""),
    ("02 stacking", """
First, stacking.
Thai marks stack on top of their letter. A vowel sits above the consonant, and the tone mark goes above that, raised so the two of them don't collide.
Vietnamese does something similar, with an e that carries one mark above, and another one below. Placing those marks is the font's job: anchor points in its G-POS table, mark to base, and mark to mark. The shaper only applies them, so if a font has no anchors, marks collide, and no layout code can fix it.
"""),
    ("02 blocks", """
Next, composition.
Korean Hangul letters, called jamo, are composed into square syllable blocks. The letters h, a, and n become one block: han, a single code point.
And the word Hangul itself is two of those blocks, built from six letters. Unicode has precomposed code points for all eleven thousand, one hundred and seventy-two modern syllables, and normalization can take each one apart into its jamo, and put it back together.
"""),
    ("02 vertical", """
And the last stall is vertical text. Japanese can be set from top to bottom, with the columns running from right to left. Chinese can do the same, and Mongolian also runs top to bottom, but with its columns going left to right. Vertical text isn't just rotation. Punctuation and the long vowel mark switch to vertical forms from the font, and Latin words inside are usually turned on their side.
"""),
    ("02 locale", """
Now, one code point, two glyphs. Chinese and Japanese characters were unified in Unicode, so both languages share the same code point for each of these characters.
But each language draws them differently. Look closely at the strokes, they don't match.
The locale picks the font. So in Flutter, set the locale to Japanese on Japanese text, on the text style, or through the app's locale, or your users will see the Chinese forms instead. This is called Han unification, and it's one of the most common rendering bugs in apps made for Japan.
"""),
    ("02 mixing", """
And mixing multiplies everything. Here's one paragraph with English, Arabic, Japanese and emoji.
That's six runs in two directions, four fonts with two shapers, and two different line breakers. Altogether, a hundred and ninety-two combinations.
One mixed paragraph exercises the entire pipeline, all at once. And this is exactly the kind of text your users will type, so it's exactly the kind of text your tests should have.
"""),
    ("03 map", """
We've seen the stages, and how every script complicates them. Now let's watch Flutter do it for real, and follow a Text widget saying Flutter, all the way down to pixels.
Layout takes it down through the framework and dart U.I., into the engine. Paint records it, and the GPU draws it.
And all of it happens right here, in the Glyph Works, next to the plaza where the crew is building names. We'll follow the first letter down the line, and the rest of the word will catch up with it.
"""),
    ("03 widget", """
It starts with a widget. Text only describes: a string, and a style.
Underneath, Text builds a RichText, which creates a RenderParagraph. The RenderParagraph owns a TextPainter, and the TextPainter builds the paragraph. The render object is where layout, painting, hit testing and semantics happen.
At this point, Dart keeps the string as UTF-16 code units, and Flutter is seven of them.
"""),
    ("03 engine", """
Into the engine. Across dart U.I., the engine's paragraph builder hands the text to S.K. Paragraph, which keeps it as UTF-8. It crosses from Dart into C plus plus once for the whole paragraph, not once per character.
"""),
    ("03 decode", """
Here, the bytes come out of the feeder, and go into the decoder. I.C.U. marks the graphemes, the line break opportunities, the direction and the script, and the text is itemized into runs. For Flutter, that's just one run: one script, one direction, one font.
"""),
    ("03 fonts", """
Next, find the glyphs. Each code point is looked up in the style's fonts, in order: the font family, then the fallbacks, then the platform's.
The font's cmap table maps each code point to a glyph ID. And for Flutter, every letter is found in Space Grotesk, the very first font. No fallback needed. If a letter were missing, this is where fallback would kick in, just like we saw at the tofu shop.
"""),
    ("03 shape", """
HarfBuzz shapes the whole run at once, producing glyphs, and how far each one advances.
Notice the two t's. The font joins them into a single ligature glyph, so seven code points become six glyphs. You can't know a word's glyphs, or its width, without shaping it.
"""),
    ("03 line", """
Then layout wraps the run to the max width, and measures each line. Shaping is the expensive part, so it's done once, and the text can be wrapped again as many times as the width changes. That's also why measuring text is not free: every TextPainter layout runs this pipeline.
"""),
    ("03 paint", """
Paint doesn't actually draw anything yet. The paragraph is recorded into a display list, as glyph IDs and positions, a text blob, for the raster thread to draw later.
"""),
    ("03 outline", """
On the raster thread, every glyph that's not in the atlas yet starts as an outline, read from the font: points, joined by lines and curves, then scaled to the text's size.
"""),
    ("03 raster", """
Then each outline is rasterized, once, as coverage: solid pixels inside, and grey pixels along the anti-aliased edges. In Impeller, the glyphs are rasterized on the CPU, by the font engine, and packed into an atlas texture. The atlas is a cache: the next time this glyph shows up at this size, it's simply reused.
"""),
    ("03 draw", """
And finally, draw. Each glyph becomes a quad, two triangles, whose corners point into the atlas.
The shader multiplies the text color by the coverage, and the whole word goes out in a single draw call.
And there it is: Flutter, on the board, pixel for pixel.
"""),
    ("04 engines", """
So that's how Flutter does it. But Flutter isn't the only engine that draws text. Here are five engines, and each one sits somewhere between owning the whole stack, and using the platform's.
Chrome uses LayoutNG, with HarfBuzz and Skia. Figma has its own engine, written in C plus plus and compiled to WebAssembly. macOS has TextKit and Core Text, with Apple's own shaper. Android uses Minikin and HarfBuzz. And Flutter uses RenderParagraph, SkParagraph and Impeller.
Four of the five share the same shaper, HarfBuzz. Apple has its own. Let's look at what each of them gets from where it sits.
"""),
    ("04 chrome", """
Chrome first. In the browser, text lives in the DOM, so the browser gets the rest for free.
CSS can balance lines, hyphenate words, set text vertically, and add ruby annotations, each in a line of CSS. And because it's real text in the page, you can find it, select it and translate it, and screen readers and search engines can read it too. The price is that the platform decides how your text looks, and that can differ from one browser to another.
"""),
    ("04 figma", """
Figma is the closest to Flutter. It's one canvas, with its own text engine, built on HarfBuzz and I.C.U., and its own renderer.
So text looks exactly the same on every operating system, and it re-renders at every zoom level. But every single feature is theirs to build. Right-to-left support only arrived in twenty twenty-two, and vertical text and color fonts are still missing.
"""),
    ("04 macos", """
On macOS, Apple owns the entire stack, including its own shaper. Core Text splits a paragraph into lines, lines into runs, and runs into glyphs.
Justification, hyphenation, vertical text and ruby are all built in, like a book typesetter. It even adjusts the tracking automatically, with San Francisco's optical sizes.
And as we saw earlier, subpixel anti-aliasing has been off since ten fourteen.
"""),
    ("04 android", """
And Android, with Minikin. Minikin can weigh the whole paragraph before it breaks a single line.
It has three strategies. Simple, which is first fit. Balanced, which evens out the lines. And high quality, which finds the best breaks for the whole paragraph, with hyphens, a lot like TeX.
Flutter's text stack actually came from Minikin, through libtxt, to SkParagraph. But along the way, it only kept the simple, first-fit breaker.
"""),
    ("05 intro", """
So where does that leave Flutter? Flutter draws every single pixel itself. That buys it consistency, because text looks the same everywhere, and effects that work the same way on every platform.
But it costs all the features the platform would otherwise have given it for free. Let's look at both sides, here in Trade-off Town.
"""),
    ("05 missing1", """
First, what's not in Flutter. Owning the stack means rebuilding every platform feature yourself.
Here's Chrome's page from before, set by Flutter this time. There's no vertical text, so you need a package like mongol, or you rotate things by hand.
"""),
    ("05 missing1b", """
And there's no optimal line breaking, only the greedy breaker, so the lines come out ragged instead of balanced. Some of these have workarounds, and some of them don't.
"""),
    ("05 missing2", """
There's no ruby either. Those are the small reading hints, furigana, that sit above Japanese characters, like on this cable car riding over Tokyo.
In Flutter, you have to build them yourself, with widget spans. It works, but then the ruby isn't really part of the paragraph anymore: it doesn't break with it, select with it, or get read out with it.
"""),
    ("05 missing3", """
And there's no automatic hyphenation. In this sawmill, a long word gets cut at its soft hyphen, and in Flutter, you have to insert those by hand.
The list goes on: no kashida justification for Arabic, no subpixel rendering, and on the web, no find in page and no SEO. And web fonts can flash as tofu while they load, unless you preload them.
"""),
    ("05 web", """
On the web, Flutter ships its own engine as WebAssembly. That means the text is drawn on a canvas, and the browser can't search it. Press control F, and it finds nothing.
And fonts arrive late. Noto fonts are downloaded from Google's servers, and until they arrive, you see tofu. Even the line breaks there come from the browser's segmenter. For accessibility, Flutter builds a semantics tree, so screen readers still work, but find in page doesn't.
"""),
    ("05 only1", """
But there's another side to this. Owning every pixel buys Flutter a few things, too.
First, it's the same everywhere. There's one layout engine, so the same paragraph breaks into exactly the same lines on iOS, Android, the web and macOS.
Here are two phones. With native text, the result depends on the platform. With Flutter, it's identical, pixel for pixel, which is exactly what a design system wants.
"""),
    ("05 only2", """
Second, you can paint text however you like, with shaders, with strokes, and with variable fonts, and it works the same way on every platform.
In this gym, the letters are lifting weights, and as they do, the font's weight axis goes up and down, smoothly, frame by frame, through font variations on the text style. And because it's all just painting, you can mix text with anything else on screen.
"""),
    ("05 only3", """
And third, you get every glyph. Flutter can give you a box for each grapheme, so you can animate letters one by one, and even turn them in 3D with a matrix, without any relayout. That's how this whole city builds its letters: every glyph is a shape you can move.
"""),
    ("06 intro", """
Some of those gaps, you can close today. Here are five of them, in Package Town, each closed by a small package, in plain Dart, without touching the engine. None of them needs a fork of Flutter.
"""),
    ("06 phrases", """
First: phrase breaking in Japanese. Because Japanese can break almost anywhere, Flutter will happily split a word in the middle of a phrase, and that's hard to read.
"""),
    ("06 phrases fix", """
The kumihan package finds the phrases, using Budou X, a small machine-learned model from Google, and glues each phrase together with invisible word joiners. So lines only break between phrases.
On the left, plain Text. On the right, KumihanText, with lines that break exactly where a Japanese reader expects.
"""),
    ("06 punctuation", """
Second: punctuation spacing. In Japanese, full-width punctuation carries half an em of blank space. So when two marks meet, like a closing bracket and an opening bracket, the gap doubles, and it should close.
"""),
    ("06 punctuation fix", """
The font feature that would do this automatically isn't in Noto Sans Japanese, or in Hiragino. So kumihan applies the font's halt feature, glyph by glyph, exactly where the marks meet, taking half of each one's blank away.
"""),
    ("06 slug", """
And third: text on the GPU. Today, glyphs are rasterized once into an atlas, as small bitmaps at one size. Zoom in, or tilt them in 3D, and those bitmaps blur.
"""),
    ("06 slug fix", """
Slug draws them straight from their curves, in a fragment shader: every pixel works out, from the outline itself, how much of it is covered.
So text stays perfectly sharp at any zoom, any rotation, and any perspective, with no atlas to re-rasterize. And since March twenty twenty-six, the Slug patent is in the public domain, so this is now open to everyone.
"""),
    ("06 handwriting", """
And fourth: handwriting. Animating text as if someone were writing it is a common request, and most ways of doing it just uncover the font.
A wipe slides across the finished word. Tegaki is cleverer: it thins each glyph down to its strokes, and reveals the font's own outline, stroke by stroke, in writing order. But both of them always end as the same typeset word.
"""),
    ("06 handwriting fix", """
So I built fountain pen, and it's on pub dot dev. It traces the font into the strokes a hand would make, in the order a writer makes them, and then a pen model writes them out.
The nib is heavy on the downstrokes and fine on the upstrokes, the pen slows into the turns, the ink is wet for a moment, and every letter comes out a little different. Same font, same word: Tegaki reproduces the font; fountain pen writes it.
"""),
    ("06 path", """
And fifth: text on a path. In English, the usual way works: turn each letter whole onto the curve, and since the letters stand apart, nothing breaks, however hard Dash pulls the strip.
"""),
    ("06 path cursive", """
Even cursive English holds up on a gentle curve: its joins are short strokes near the baseline, overlapping the next letter. But squeeze it into a tight one, about a letter high, and its joins split open too.
"""),
    ("06 path arabic", """
And Arabic is always joined: it's how the script is written, not a style. Put it on a curve the way most packages do, and every word comes apart.
"""),
    ("06 path fix", """
So I built text on path, and it's on pub dot dev. It keeps the letters rigid and bends only the rows they join on, so the joins stay closed, even with two Dashes fighting over it. And the text is still selectable.
"""),
    ("06 fx frost", """
One more, a bonus round. Stroke F X, my newest package: shader effects that live along the strokes of handwriting and on the joints where they meet, as it's written, built on fountain pen. First up: Frost Dash, and the ink freezes as it's written.
"""),
    ("06 fx ember", """
Ember Dash: the ink is molten where the pen just was, and cools behind it.
"""),
    ("06 fx neon", """
Neon Dash: each stroke lights up as the pen reaches it, like a neon tube.
"""),
    ("06 fx ivy", """
Ivy Dash: a vine climbs every stroke, leaf by leaf.
"""),
    ("06 fx jelly", """
Jelly Dash: the pen drags an elastic sheet, and when it lifts, the jelly springs back.
"""),
    ("06 fx sakura", """
And Sakura Dash: the strokes are branches, and cherry blossoms open where they meet.
"""),
    ("end tradeoff", """
So, to wrap up: the trade-off. Every engine picks a point between owning the stack, and using the platform's.
On this seesaw, Figma owns almost everything, and Flutter is right next to it. Android sits in the middle, Chrome leans on the platform, and macOS is the platform.
Flutter chose control, consistency, and effects. And the price is rebuilding what the platform would have given it for free, one package at a time. And as we just saw, a lot of that can be done today, in plain Dart, on top of the engine.
"""),
    ("end thanks", """
Before I finish, we have a special delivery from Dash.
That's it from me. Thank you so much for listening. ありがとうございました!
I'd love to hear your questions.
"""),
]

PAUSES = {}

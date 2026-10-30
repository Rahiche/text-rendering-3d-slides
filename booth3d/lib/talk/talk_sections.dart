import 'package:vector_math/vector_math.dart' as vm;

import '../world/site.dart';
import '../world/v_desk.dart' show DeskScene;
import '../world/v_farm.dart' show PixelFarm;
import '../world/v_package.dart' show PackageTown;
import '../world/v_scrolls.dart' show ScrollLine;
import 'city_section.dart';
import 'intro_slides.dart';
import 'journey_section.dart';
import 'talk_section.dart';

/// The talk's sections, in its order: the title (a plain slide, then the
/// city it was in); 01 the pipeline's stages, from code points to pixels;
/// 02 what every script adds to them; 03 one word through Flutter, for
/// real; 04 how other engines do it; 05 where that leaves Flutter; 06 the
/// gaps you can close today; and the wrap-up (the trade-off; the thanks, a
/// special delivery from Dash). Each stop is the place in the city that
/// shows it, its card a few short lines, big enough for the back of the
/// room.
List<TalkSection> talkSections(Site3D site) {
  CitySection section(String number, String title, List<String> glyphs, List<CityStop> stops) => CitySection(
    number: number,
    title: title,
    glyphs: glyphs,
    cityStops: stops,
    vignettes: site.vignettes,
    alley: site.alley,
    fx: site.fx,
    glyphShapes: () => site.scriptShapes,
  );

  return [
    // (Its card never comes up. It opens on plain slides (intro_slides.dart:
    // the title, then a page a press on how writing was physical until
    // computers came), the camera square on the laptop they're on, on a roof
    // over the plaza (the scene 'desk'); the press after the last pulls back
    // from it to the city.)
    section('', 'Text rendering', const [], [
      CityStop(
        'title',
        const TalkCard('Text rendering', 'from code points to pixels · and how Flutter does it', [], true),
        [
          CityBeat.scene('desk', hold: 0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, slide: Slide.full),
          for (var page = 1; page < IntroSlides.count; page++)
            CityBeat.scene('desk', hold: 0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, slide: Slide.full, page: page),
          CityBeat.scene('desk', hold: DeskScene.reveal, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, slide: Slide.screen),
        ],
      ),
    ]),
    section('01', 'From code points to pixels', const ['A', 'ب', 'क', '文', 'ก', '😀'], [
      CityStop(
        'pipeline',
        const TalkCard(
          'From code points to pixels',
          'A string goes in, pixels come out: seven stages, each a stop in this city.',
          [
            FactCode(
              '1 string    Unicode\n2 itemize   ICU\n3 fallback  font manager\n4 shaping   HarfBuzz\n'
              '5 lines     ICU\n6 bidi      ICU\n7 raster    Skia · GPU',
            ),
          ],
          true,
        ),
        // (Over the city, its stops numbered as a string goes through them.)
        [CityBeat.at(_cityMap, fly: 3.0, shift: 0.3, cardAt: 2.8, chapter: true, pins: _stages)],
      ),
      CityStop(
        'string',
        // (The counts themselves on the board in the park, each as the
        // narration says it. The ways to count, and the package, only once
        // the problem's been walked through: the last press.)
        const TalkCard(
          'A string ≠ text',
          'String.length counts UTF-16 code units, not what you see. So: count what?',
          [
            FactCode(
              "final s = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}';\n"
              's.characters.length   // seen\n'
              's.runes.length        // code points\n'
              's.length              // UTF-16 units\n'
              'utf8.encode(s).length // bytes',
              at: 2.5,
              beat: 3,
            ),
            FactRow('in Flutter', 'package:characters', accent: true, at: 10.4, beat: 3),
          ],
        ),
        // (First what everyone assumes: Hello, every count 5; a press, and
        // the family walks in to break it; a press, and it comes apart, the
        // counts on the board; a press, and the question: count what? Each
        // with its clip of the narration, the scene from where the one
        // before left it.)
        [
          CityBeat.scene('family', hold: 7.5, fly: 2.6, shift: 0.38),
          CityBeat.scene('family', from: 7.5, hold: 32.0, fly: 0.6, lead: 0.6, shift: 0.38),
          CityBeat.scene('family', from: 32.0, hold: 47.0, fly: 0.8, shift: 0.38),
          CityBeat.scene('family', from: 47.0, hold: 64.5, fly: 0.6, lead: 0.6, shift: 0.38),
        ],
      ),
      CityStop(
        'itemize',
        const TalkCard(
          'Itemize',
          "Before shaping, the engine cuts a paragraph's text into runs: one script, direction and font each.",
          [
            FactRow('in', 'one paragraph, all at once', at: 4.6),
            FactRow('reads', "each character's script", at: 0.6, beat: 1),
            FactRow('cuts', 'where the script changes', at: 1.9, beat: 1),
            FactRow('out', 'runs with direction + font', at: 2.6, beat: 2),
            FactRow('where', 'engine: SkParagraph + ICU', at: 5.0, beat: 2),
          ],
        ),
        // (A press a part, v_itemize.dart: the whole text in; each
        // character's script read, the cuts marked, the spaces staying with
        // their run; cut, tagged, out to shaping.)
        [
          CityBeat.scene('itemize', hold: 4.0, fly: 3.0, pull: 1.7, shift: 0.38),
          CityBeat.scene('itemize', from: 4.0, hold: 10.0, fly: 0.6, lead: 0.6, pull: 1.7, shift: 0.38),
          // (Held with the four runs cut and tagged on the belt, as the
          // narration names them: not after they've gone on, the belt empty.)
          CityBeat.scene('itemize', from: 10.0, hold: 14.4, fly: 0.6, lead: 0.6, pull: 1.7, shift: 0.38),
        ],
      ),
      CityStop(
        'fallback',
        const TalkCard(
          'Font fallback',
          "Each character asks the fonts in order: the app's, then the platform's. None has it? Tofu: □",
          // (Each as Dash gets its answer: a press a kiosk.)
          [
            FactRow('A', 'Space Grotesk · 1 try', at: 3.8, beat: 1),
            FactRow('ب', 'Noto Kufi · 2 tries', at: 2.4, beat: 2),
            FactRow('字', 'system CJK · 3 tries', at: 2.4, beat: 3),
            FactRow('😀', 'system emoji · 4 tries', at: 2.4, beat: 4),
            FactRow('U+0378', 'no font → □ tofu', at: 6.8, beat: 5),
          ],
        ),
        // (Dash waiting in front of the kiosks while the narration says what
        // fallback is; then a press a kiosk, Dash walking on to it; then
        // U+0378 to the tofu shop: v_tofu.dart's steps.)
        [
          CityBeat.scene('tofu', hold: 20.4, fly: 2.8, shift: 0.36),
          CityBeat.scene('tofu', from: 20.4, hold: 25.6, fly: 0.6, lead: 0.6, shift: 0.36),
          CityBeat.scene('tofu', from: 25.6, hold: 29.4, fly: 0.6, lead: 0.6, shift: 0.36),
          CityBeat.scene('tofu', from: 29.4, hold: 33.2, fly: 0.6, lead: 0.6, shift: 0.36),
          CityBeat.scene('tofu', from: 33.2, hold: 37.0, fly: 0.6, lead: 0.6, shift: 0.36),
          CityBeat.scene('tofu', from: 37.0, hold: 47.0, fly: 0.6, lead: 0.6, shift: 0.36),
        ],
      ),
      CityStop(
        'shaping',
        const TalkCard(
          'Shaping',
          'HarfBuzz turns code points into positioned glyphs, and not one for one.',
          // (Each as the forge makes it, the narration saying it.)
          [
            FactRow('join', '\u2067ك ت ا ب\u2069 → \u2067كتاب\u2069', at: 9.4),
            FactRow('ligature', 'f + i → ﬁ    - + > → ->', at: 13.6),
            FactRow('kerning', 'A V → AV', at: 22.3),
            FactRow('reorder', 'क + ि → कि', at: 26.5),
            FactRow('emoji', '5 code points → 1 glyph', at: 31.5),
          ],
        ),
        // (On to the end of the narration's clip: the forge's six jobs are
        // timed to it.)
        [CityBeat.scene('forge', hold: 40.0, fly: 2.4, shift: 0.4)],
      ),
      CityStop(
        'lines',
        const TalkCard(
          'Line breaking',
          'Greedy: fill each line up to maxWidth, then start the next. Where it may break depends on the script.',
          [
            FactRow('English', 'at spaces', example: 'the|quick|brown|fox'),
            FactRow('Thai', 'no spaces: a dictionary', example: 'สวัสดี|ครับ'),
            FactRow('Japanese', 'anywhere, not before 。', example: '行|頭|に|来|ま|せ|ん。'),
            FactRow('turned', 'new maxWidth → new lines'),
          ],
          false,
          '',
          // (The board's three columns; then the phone's refill.)
          ['English|Thai|Japanese', 'turned'],
        ),
        [
          // (The line-breaking board over the long path, painted by
          // Flutter's own line breaker: on to the end of the narration's
          // clip, it's timed to it. Then a phone turned on its side: the
          // same words, a new maxWidth, new lines.)
          CityBeat.scene('breaks', hold: 35.8, fly: 3.0, shift: 0.4),
          CityBeat.scene('phones', hold: 8.0, fly: 3.0),
        ],
      ),
      CityStop(
        'bidi',
        const TalkCard(
          'Memory ≠ screen',
          'Text is stored in typing order. The bidi algorithm reorders it for display.',
          [
            FactRow('memory', '\u202DH i ␠ ا ر د و ␠ 2 0 2 6 !\u202C'),
            FactRow('screen', '\u202DH i ␠ 2 0 2 6 ␠ و د ر ا !\u202C', accent: true),
            // (The same characters in typing order, as Flutter lays them
            // out: the screen row's order, joined up.)
            FactRow('you see', 'Hi اردو 2026!'),
            FactRow('so', 'index i ≠ position i'),
          ],
        ),
        [CityBeat.scene('bidi', hold: 9.5, fly: 3.0, shift: 0.36)],
      ),
      CityStop(
        'raster',
        const TalkCard(
          'Rasterization',
          'A font stores outlines: points and curves, no pixels. The GPU shades every pixel at once, by how much of it the outline covers.',
          [
            FactRow('glyph a', '50 points · 2 contours'),
            FactRow('aliased', 'on if half covered', at: 0.6, beat: 1),
            FactRow('subpixel', 'RGB thirds · off on macOS', at: 0.6, beat: 2),
            FactRow('grayscale', 'coverage → grey · Flutter', at: 0.6, beat: 3),
          ],
        ),
        // (What the font keeps for an a: its outline; a press, and the field
        // is pixels, every one worked out at once, aliased; then a press each,
        // subpixel and, last, grayscale, Flutter's: v_farm.dart.)
        [
          CityBeat.scene('farm', hold: PixelFarm.pixels, fly: 3.0, shift: 0.34),
          CityBeat.scene('farm', from: PixelFarm.pixels, hold: PixelFarm.subpixel, fly: 0.6, lead: 0.6, shift: 0.34),
          CityBeat.scene('farm', from: PixelFarm.subpixel, hold: PixelFarm.grayscale, fly: 0.6, lead: 0.6, shift: 0.34),
          CityBeat.scene('farm', from: PixelFarm.grayscale, hold: PixelFarm.hold, fly: 0.6, lead: 0.6, shift: 0.34),
        ],
      ),
    ]),
    section('02', 'Every script adds rules', const ['ع', 'कि', 'ปั่น', '한', '縦', '👋🏽'], [
      CityStop(
        'intro',
        const TalkCard(
          'Every script adds rules',
          'Latin lets you assume a lot. Other scripts break those assumptions, and real text mixes them.',
          [
            FactLetters('', [('ع', '', false), ('कि', '', false), ('ปั่น', '', false), ('한', '', false), ('縦', '', false), ('👋🏽', '', false)]),
          ],
          true,
        ),
        // (Out of Flutter City, west along the avenue, into ICU City
        // (v_icu.dart); its places named once the camera's round over it.)
        [
          CityBeat.scene(
            'icu',
            hold: 12.0,
            fly: 3.0,
            shift: 0,
            cardAt: 12.6,
            chapter: true,
            chapterFor: 4.0,
            pinsAt: 11.0,
            pins: [
              _pin(-280, 1.8, 34, 'ARCHIVE', sub: 'the basement'),
              _pin(-264, 33, 40, 'UNICODE'),
              _pin(-240, 3.8, 12, 'SCRIPT ALLEY'),
              // (The office is under the card: its name under it, by its
              // door.)
              _pin(-295.6, 0.8, 6, 'LOCALE', below: true),
            ],
          ),
        ],
      ),
      CityStop(
        'unicode',
        // (Each count held back until the hall lights its era, its press:
        // v_archive.dart's eras, from where each beat takes the hall up.)
        const TalkCard(
          'The scale of the problem',
          'Every Unicode version adds characters that fonts and renderers must keep up with.',
          [
            FactRow('1963 · ASCII', '128', at: 6.9),
            FactRow('1991 · Unicode 1', '~7,000', at: 1.6, beat: 1),
            FactRow('2010 · Unicode 6', '109,449 · emoji', at: 2.3, beat: 2),
            FactRow('2026 · Unicode 18', '172,808 · 170+ scripts', at: 3.1, beat: 3),
          ],
        ),
        // (Down into the Unicode archive, the scene starting as the camera
        // sets off: ASCII's rack. Then a press an era, the hall held lit
        // between: Unicode 1.0 along the first row, 6.0 and its emoji, 18.)
        [
          CityBeat.scene('archive', hold: 12.5, fly: 3.0, lead: 3.0, shift: 0),
          CityBeat.scene('archive', from: 12.5, hold: 19.2, fly: 0.6, lead: 0.6, shift: 0),
          CityBeat.scene('archive', from: 19.2, hold: 25.6, fly: 0.6, lead: 0.6, shift: 0),
          CityBeat.scene('archive', from: 25.6, hold: 34.6, fly: 0.6, lead: 0.6, shift: 0),
        ],
      ),
      CityStop(
        'alley',
        // (The three met already, at the bidi stop and the forge; the three
        // visited here each as the narration names it.)
        const TalkCard(
          'Script Alley',
          'Six things Latin lets you assume, and a script that breaks each one.',
          [
            FactRow('direction', 'Urdu  \u2067اردو\u2069'),
            FactRow('shape', 'Arabic  بيت'),
            FactRow('order', 'Devanagari  कि'),
            FactRow('marks', 'Thai  ปั่น', at: 17.0),
            FactRow('syllables', 'Korean  한', at: 19.0),
            FactRow('lines', 'Japanese  縦', at: 21.0),
          ],
        ),
        // (Back from the gate: its sign whole, right of the card.)
        // (Down the lane from its gate: AlleyLayout's origin, in ICU City.)
        [CityBeat.at(talkShot(-239.1, 2.6, 8.6, -240.3, 2.5, 21.3, 52, drift: 0.6), fly: 2.6, pull: 1.3, shift: 0.34)],
      ),
      CityStop(
        'stacking',
        const TalkCard(
          'Stacking',
          'Thai marks stack on their letter: a vowel above it, a tone mark above that.',
          [
            FactLetters('ป + ั + ่', [('ป', 'base', false), ('ั', 'vowel', false), ('่', 'tone', true)]),
            FactRow('result', 'ปั่น', accent: true),
            FactRow('also', 'Vietnamese ệ = e + \u25CC\u0302 + \u25CC\u0323'),
          ],
        ),
        [CityBeat.stall(3)],
      ),
      CityStop(
        'blocks',
        const TalkCard(
          'Composition',
          'Korean letters (jamo) are composed into one square syllable block.',
          [
            FactLetters('ㅎ + ㅏ + ㄴ', [('ㅎ', '', false), ('ㅏ', '', false), ('ㄴ', '', false)]),
            FactRow('syllable', '한 · one code point', accent: true),
            FactLetters('한글: two blocks, six letters', [('한', 'ㅎ ㅏ ㄴ', true), ('글', 'ㄱ ㅡ ㄹ', false)]),
          ],
        ),
        [CityBeat.stall(4)],
      ),
      CityStop(
        'vertical',
        const TalkCard(
          'Vertical text',
          'Japanese can be set top to bottom, its columns running right to left.',
          [
            FactRow('also', 'Chinese · Mongolian'),
          ],
        ),
        [CityBeat.stall(5)],
      ),
      CityStop(
        'locale',
        const TalkCard(
          'One code point, two glyphs',
          'Japanese and Chinese share these code points but draw them differently. The locale picks the font.',
          [
            FactLetters('ja · zh-Hans', [('直', 'U+76F4', true), ('角', 'U+89D2', false), ('骨', 'U+9AA8', false), ('写', 'U+5199', false)]),
            FactRow('fix', "locale: Locale('ja')", accent: true),
          ],
        ),
        [CityBeat.scene('locale', hold: 12.5, fly: 3.2, pull: 1.3, shift: 0.38)],
      ),
      CityStop(
        'mixing',
        const TalkCard(
          'Mixing multiplies',
          'One mixed paragraph exercises the whole pipeline at once.',
          [
            FactCode('Hello مرحبا こんにちは世界 👋🏽🌍 world'),
            FactRow('runs × directions', '6 × 2'),
            FactRow('fonts × shapers', '4 × 2'),
            FactRow('line breakers', '2'),
            FactRow('combinations', '192', accent: true),
          ],
        ),
        // (The mixed paragraph itself, hung over the city: its runs, their
        // cuts, their directions.)
        [CityBeat.scene('mix', hold: 8.0, fly: 3.0, shift: 0)],
      ),
    ]),
    // (The stages again, as Flutter runs them on one word.)
    JourneySection(site.works),
    section('04', 'How others do it', const ['Aa', 'ش', 'ह', '字'], [
      CityStop(
        'engines',
        const TalkCard(
          'How others do it',
          "Five engines, from owning the whole stack to using the platform's. Four share one shaper.",
          [
            FactRow('Chrome', 'LayoutNG · HarfBuzz'),
            FactRow('Figma', 'C++ → WASM · HarfBuzz'),
            FactRow('macOS', 'Core Text · own shaper'),
            FactRow('Android', 'Minikin · HarfBuzz'),
            FactRow('Flutter', 'SkParagraph · HarfBuzz', accent: true),
          ],
          true,
        ),
        // (Out of the city along the avenue, past the sign saying you're
        // leaving it, to Engine Town: the four others' headquarters round
        // its square, each with its logo on its front. The chapter's title
        // while the camera comes down to the avenue; the card as it gets
        // there.)
        [CityBeat.scene('town', hold: 12.0, fly: 3.0, shift: 0, cardAt: 12.6, chapter: true, chapterFor: 4.0)],
      ),
      // (The four others, each in its own text rendering room on Engine
      // Town's square: its stack lit on the console, its screen showing
      // what its way of setting text gives it. The camera crosses the
      // square and goes in.)
      CityStop(
        'chrome',
        const TalkCard(
          'Chrome',
          'Text lives in the DOM: CSS sets it, and the page can find, select and translate it.',
          [
            FactRow('CSS', 'vertical · ruby · hyphens', accent: true),
            FactRow('the page', 'find · select · translate'),
            FactRow('but', 'looks vary by browser'),
          ],
        ),
        [CityBeat.scene('town', from: 20, hold: 30, fly: 2.4, shift: 0)],
      ),
      CityStop(
        'figma',
        const TalkCard(
          'Figma',
          'One canvas with its own text engine: the same on every OS, and every feature theirs to build.',
          [
            FactRow('✓', 'the same on every OS'),
            FactRow('RTL', 'only since 2022'),
            FactRow('✕', 'vertical · color fonts'),
            FactRow('≈ Flutter', 'canvas + own engine', accent: true),
          ],
        ),
        [CityBeat.scene('town', from: 32, hold: 42, fly: 2.4, shift: 0)],
      ),
      CityStop(
        'macos',
        const TalkCard(
          'macOS · Core Text',
          'Apple owns the whole stack, its shaper included, with book typesetting built in.',
          [
            FactCode('CTFrame › CTLine › CTRun'),
            FactRow('built in', 'justify · hyphens · ruby', accent: true),
            FactRow('optical size', 'auto tracking · SF Pro'),
          ],
        ),
        [CityBeat.scene('town', from: 44, hold: 54, fly: 2.4, shift: 0)],
      ),
      CityStop(
        'android',
        const TalkCard(
          'Android · Minikin',
          "Minikin weighs the whole paragraph before it breaks a line. Flutter's text came from it, and kept only first fit.",
          [
            FactRow('simple', 'first fit · = Flutter', accent: true),
            FactRow('balanced', 'even lines'),
            FactRow('high quality', 'best breaks + hyphens'),
          ],
        ),
        [CityBeat.scene('town', from: 56, hold: 66, fly: 2.4, shift: 0)],
      ),
    ]),
    section('05', "Flutter's trade-off", const ['✕', '✓'], [
      CityStop(
        'intro',
        const TalkCard(
          "Flutter's trade-off",
          'Flutter draws every pixel itself. That buys consistency and effects, and costs native features.',
          [
            FactLetters('', [('✕', '', false), ('✓', '', true)]),
          ],
          true,
        ),
        // (Out of the city to Trade-off Town (v_tradeoff.dart): what Flutter
        // doesn't have on the canal's west bank, what it has on the east; its
        // places named once the camera's over it.)
        [
          CityBeat.scene(
            'tradeoff',
            hold: 12.0,
            fly: 3.4,
            shift: 0.3,
            cardAt: 2.8,
            chapter: true,
            pinsAt: 5.5,
            pins: [
              // (The west bank's names to the left, the east bank's to the
              // right.)
              _pin(67.5, 8.6, -224, 'PAGE', side: -1),
              _pin(67.5, 4.6, -208, 'RUBY', side: -1),
              _pin(67.5, 4.1, -192, 'HYPHENS', side: -1),
              _pin(66.4, 3.6, -176, 'WEB', side: -1),
              _pin(83.6, 3.6, -176, 'SAME', side: 1),
              _pin(82.5, 4.0, -192, 'PAINT', side: 1),
              _pin(82.5, 6.9, -210, 'GLYPHS', side: 1),
            ],
          ),
        ],
      ),
      CityStop(
        'missing',
        const TalkCard(
          'Not in Flutter',
          'Owning the stack means rebuilding every platform feature. Still missing:',
          [
            FactRow('vertical text', '✕ · mongol package'),
            FactRow('balanced lines', '✕ · greedy only'),
            FactRow('ruby', '✕ · build it: WidgetSpan'),
            FactRow('hyphenation', '✕ · soft hyphens by hand'),
            FactRow('and', 'kashida · subpixel AA'),
          ],
          false,
          '',
          // (One thing a press: the page Flutter sets, no vertical text;
          // then no balanced lines; then ruby, then hyphenation, acted out.)
          ['vertical text', 'balanced lines', 'ruby', 'hyphenation|and'],
        ),
        // (Up the west bank: Chrome's page as Flutter sets it, on a
        // billboard, a thing it can't do a press; then ruby and hyphenation,
        // acted out.)
        [
          CityBeat.scene('engines', hold: 6, fly: 3.0, shift: 0.37),
          CityBeat.scene('engines', from: 6, hold: 12, fly: 0.6, lead: 0.6, shift: 0.37),
          CityBeat.scene('ruby', hold: 6.0, fly: 3.0),
          CityBeat.scene('hyphen', hold: 8.0, fly: 2.6),
        ],
      ),
      CityStop(
        'web',
        const TalkCard(
          'On the web',
          "Flutter ships its own engine as WASM: text on a canvas the browser can't search.",
          [
            FactRow('DOM <p>', 'Ctrl+F finds it ✓'),
            FactRow('<canvas>', 'Ctrl+F finds nothing ✕', accent: true),
            FactRow('fonts', 'tofu until they load'),
            FactRow('a11y', 'semantics tree ✓'),
          ],
        ),
        // (The west bank's last: the store's web table under its canopy, two
        // browsers: the font arriving late, then find on each page.)
        [CityBeat.scene('phones', from: 60, hold: 68.0, fly: 3.2, shift: 0.4)],
      ),
      CityStop(
        'gains',
        const TalkCard(
          'What control buys',
          'Owning every pixel buys Flutter text that looks, and paints, the same everywhere.',
          [
            FactRow('same everywhere', '1 layout, every platform'),
            FactRow('paint', 'shaders · animated weights'),
            FactRow('every glyph', 'a box each, even in 3D'),
          ],
          false,
          '',
          ['same everywhere', 'paint', 'every glyph'],
        ),
        // (Across the water to the east bank, and down it: the same
        // everywhere, two phones, native then Flutter; a variable font;
        // every glyph a box, turned in 3D.)
        [
          CityBeat.scene('phones', from: 20, hold: 31.0, fly: 3.0),
          // (The gym's screen, painted live, right of the card; on to the
          // end of the narration's clip: it paints along with it.)
          CityBeat.scene('gym', hold: 20.6, fly: 3.0, shift: 0.4),
          CityBeat.scene('word', hold: 7.0, fly: 3.0, shift: 0.26),
        ],
      ),
    ]),
    section('06', 'Unsolved → solved', const ['文節', '」「', '◇', '✎', 'ـعـ'], [
      CityStop(
        'intro',
        const TalkCard(
          'Unsolved → solved',
          'Five gaps you can close today, with small packages and no engine fork.',
          [
            FactLetters('', [('文節', '', false), ('」「', '', false), ('◇', '', false), ('✎', '', false), ('ـعـ', '', false)]),
          ],
          true,
        ),
        // (On east to Package Town (v_package.dart): a gap a building round
        // its square, each showing the problem first, the fix a press
        // later; their names once the camera's over it.)
        [
          CityBeat.scene(
            'package',
            hold: 10.0,
            fly: 3.4,
            shift: 0.3,
            cardAt: 2.8,
            chapter: true,
            pinsAt: 5.0,
            pins: [
              TalkPin(PackageTown.pin(0), 'PHRASES', side: -1),
              TalkPin(PackageTown.pin(1), 'PUNCTUATION'),
              TalkPin(PackageTown.pin(2), 'GPU TEXT', side: 1),
            ],
          ),
        ],
      ),
      CityStop(
        'phrases',
        const TalkCard(
          'Phrase breaking',
          'Japanese can break almost anywhere, so Text() splits words in the middle of a phrase.',
          [
            FactRow('Text()', '今日は天気｜です。'),
            FactRow('KumihanText()', '今日は｜天気です。', accent: true, at: 1.0, beat: 1),
            FactRow('how', 'BudouX · word joiners', at: 1.8, beat: 1),
          ],
        ),
        // (The west building's screen: Text()'s sentence, its split
        // phrases in red; then KumihanText()'s beside it.)
        [
          CityBeat.scene('package', from: 20, hold: 24.0, fly: 3.0, shift: 0.38),
          CityBeat.scene('package', from: 30, hold: 31.6, fly: 0.6, lead: 0.6, shift: 0.38),
        ],
      ),
      CityStop(
        'punctuation',
        const TalkCard(
          'Punctuation spacing',
          'Full-width marks carry half an em of blank, so where two meet the gap doubles.',
          [
            FactRow('Text()', '「こんにちは」「世界」。'),
            FactRow('kumihan', '−½ em where 」「 meet', accent: true, at: 1.0, beat: 1),
            FactRow('how', "the font's 'halt'", at: 1.8, beat: 1),
          ],
        ),
        // (The middle building's screen: Text()'s marks, a whole em between
        // 」 and 「; then kumihan's row under it.)
        [
          CityBeat.scene('package', from: 40, hold: 44.0, fly: 2.4, shift: 0.38),
          CityBeat.scene('package', from: 50, hold: 51.6, fly: 0.6, lead: 0.6, shift: 0.38),
        ],
      ),
      CityStop(
        'slug',
        const TalkCard(
          'Slug · GPU text',
          'An atlas keeps each glyph as a bitmap at one size: tilt or zoom it in 3D, and it blurs.',
          [
            FactRow('Text', 'glyph → atlas bitmap'),
            FactRow('SlugText', 'curves → pixels', accent: true, at: 1.2, beat: 1),
            FactRow('patent', 'public domain, 2026', at: 3.0, beat: 1),
          ],
        ),
        // (The word in front of the east building, flat on a board: as a
        // texture, the camera in on the e until it blurs; at the press, the
        // same word from its outlines (Slug, in the scene's own pass), sharp
        // close up and from the side.)
        [
          CityBeat.scene('slug', from: 20, hold: 27.9, fly: 3.0, shift: 0.26),
          CityBeat.scene('slug', from: 27.9, hold: 33.5, fly: 0.6, lead: 0.6, shift: 0.26),
        ],
      ),
      CityStop(
        'handwriting',
        const TalkCard(
          'Handwriting',
          'Most ways of animating handwriting uncover the font. fountain_pen writes it.',
          [
            FactRow('wipe', 'uncovers the text'),
            FactRow('Tegaki', 'uncovers the font, stroke by stroke'),
            FactRow('fountain_pen', 'a pen: nib, wet ink, a hand', accent: true, at: 1.0, beat: 1),
            FactRow('pub.dev', 'fountain_pen', at: 1.8, beat: 1),
          ],
        ),
        // (Across the road from the GPU text, on the south-east block: the
        // word uncovered by a wipe and as Tegaki does it; then, a press
        // later, fountain_pen's row grows in, all three writing again.)
        // (No narration yet: presentation mode holds each beat, silent.)
        [
          CityBeat.scene('package', from: 60, hold: 67.0, fly: 3.0, shift: 0.38, unvoiced: 10),
          CityBeat.scene('package', from: 70, hold: 77.0, fly: 0.6, lead: 0.6, shift: 0.38, unvoiced: 12),
        ],
      ),
      CityStop(
        'text on path',
        const TalkCard(
          'Text on a path',
          'Turn each letter whole onto a curve: fine in English, cursive splits on tight curves, Arabic on any. text_on_path bends only the joins.',
          [
            FactRow('English', 'each letter turned whole: fine'),
            FactRow('cursive', 'on a tight curve: the joins split', at: 1.2, beat: 1),
            FactRow('Arabic', 'every word joined: the joins split', at: 0.3, beat: 2),
            FactRow('text_on_path', 'joins kept · still selectable', accent: true, at: 1.0, beat: 3),
            FactRow('pub.dev', 'text_on_path', at: 1.8, beat: 3),
          ],
        ),
        // (Its twin screen on the south-west block: a word on a strip Dash
        // pulls by a thread, one example a press, each letter turned whole
        // as other packages do: English (fine), English in cursive on the
        // strip squeezed into a tight curve, then Arabic (the joins split);
        // then Arabic text_on_path's own way, the joins closed, a rival Dash
        // flying in to fight over the strip.)
        // (No narration yet: presentation mode holds each beat, silent.)
        [
          CityBeat.scene('package', from: 80, hold: 85.0, fly: 3.0, shift: 0.38, unvoiced: 8),
          CityBeat.scene('package', from: 86, hold: 91.0, fly: 0.6, lead: 0.6, shift: 0.38, unvoiced: 8),
          CityBeat.scene('package', from: 92, hold: 97.0, fly: 0.6, lead: 0.6, shift: 0.38, unvoiced: 8),
          CityBeat.scene('package', from: 98, hold: 104.0, fly: 0.6, lead: 0.6, shift: 0.38, unvoiced: 12),
        ],
      ),
      CityStop(
        'scrolls',
        const TalkCard(
          'Vertical, by hand',
          'Flutter has no vertical layout. It hands you every piece to build one: glyphs, input, selection, shaders.',
          [
            FactRow('paper', 'unrolled in a vertex shader'),
            FactRow('columns', 'every glyph placed by hand', at: 1.2),
            FactRow('input', 'EditableText · IME · undo', accent: true, at: 0.6, beat: 1),
            FactRow('forms', "the font's 'vert': 、 。 ー", at: 1.4, beat: 1),
          ],
          false,
          'FULL CONTROL',
        ),
        // (Up on the south-east block's roof, across the street from
        // stroke_fx's stage (v_scrolls.dart): hanging scrolls on a washing
        // line, unrolling as the camera comes, right to left as they read;
        // then close on the middle one, right of the card, for the
        // presenter to click into and type: it grows. A live demo: the
        // voiced presentation holds the unroll, silent, and passes over the
        // typing.)
        [
          CityBeat.scene('scrolls', hold: ScrollLine.unrolled, fly: 3.0, shift: 0.36, unvoiced: 9),
          CityBeat.scene('scrolls', from: ScrollLine.close, hold: 1e9, fly: 1.6, shift: 0.3, unvoiced: 0),
        ],
      ),
      CityStop(
        'stroke fx',
        const TalkCard(
          'stroke_fx',
          'Shader effects along handwritten strokes and on the joints where they meet, as the text is written. Six of them, as fighters.',
          [
            FactRow('frost', 'the ink freezes as it is written'),
            FactRow('ember', 'molten behind the pen, cooling', at: 1.4, beat: 1),
            FactRow('neon', 'each stroke lights as it is reached', at: 1.4, beat: 2),
            FactRow('ivy', 'a vine climbs every stroke', at: 1.4, beat: 3),
            FactRow('jelly', 'the pen drags it; it springs back', at: 1.4, beat: 4),
            FactRow('sakura', 'blossoms where strokes meet', at: 1.4, beat: 5),
          ],
          false,
          'BONUS ROUND',
        ),
        // (Up on the south-west block's roof, a billboard behind the stage:
        // a fighter a press, each a Dash in its effect's colours, landing,
        // then up to perch on the billboard as the camera closes in on it,
        // its line written there in its effect. No card: the line fills the
        // frame.)
        [
          CityBeat.scene('package', from: 110, hold: 116.0, fly: 3.0, shift: 0, cardAt: 1e9, unvoiced: 8),
          CityBeat.scene('package', from: 118, hold: 124.0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, unvoiced: 7),
          CityBeat.scene('package', from: 126, hold: 132.0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, unvoiced: 7),
          CityBeat.scene('package', from: 134, hold: 140.0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, unvoiced: 7),
          CityBeat.scene('package', from: 142, hold: 148.0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, unvoiced: 7),
          CityBeat.scene('package', from: 150, hold: 156.0, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, unvoiced: 9),
        ],
      ),
    ]),
    section('', 'Wrapping up', const ['control', '⇄', 'native'], [
      CityStop(
        'trade-off',
        const TalkCard(
          'The trade-off',
          "Every engine picks a point between owning the stack and using the platform's.",
          [
            FactScale('owns the stack', 'uses the platform', [
              ('Figma', -0.9, false),
              ('Flutter', -0.72, true),
              ('Android', 0.04, false),
              ('Chrome', 0.62, false),
              ('macOS', 0.88, false),
            ]),
            FactRow('Flutter chose', 'control', accent: true),
            FactRow('for', 'consistency · effects'),
            FactRow('price', 'rebuild native features'),
          ],
          true,
        ),
        // (Dashes on a seesaw in a playground beyond the park, each where
        // the card puts its engine: v_seesaw.dart.)
        [CityBeat.scene('seesaw', hold: 12, fly: 3.4, shift: 0.4, cardAt: 2.8, chapter: true)],
      ),
      CityStop(
        'thanks',
        const TalkCard('Thank you', 'questions?', [], true, 'ありがとうございました'),
        // (Straight on from the trade-off to the finale, on the seesaw as
        // it was, no title, no card: the city dips and comes back as a
        // special delivery from Dash, the booth's demo building ありがとう
        // from its start on the plaza, quickly, then kept, for the
        // questions.)
        [CityBeat.scene('seesaw', from: 12, hold: 12, fly: 0.6, lead: 0.6, shift: 0, cardAt: 1e9, questions: 0)],
      ),
    ]),
  ];
}

TalkPin _pin(double x, double y, double z, String name, {int? order, String? sub, int side = 0, bool below = false}) => TalkPin(vm.Vector3(x, y, z), name, order: order, sub: sub, side: side, below: below);

/// The city from above the avenue, looking north over the plaza and the
/// park: every stop of section 01 in view.
final _cityMap = talkShot(0, 58, -40, 0, 0, 40, 54, drift: 1.0);

/// Section 01's stops as the pipeline's stages, in the order a string goes
/// through them (each with the library that does it).
final _stages = [
  _pin(6.6, 2.4, 15.2, 'STRING', order: 1, sub: 'unicode'),
  _pin(28.4, 6.6, 29.2, 'ITEMIZE', order: 2, sub: 'ICU'),
  _pin(-6.6, 3.6, 48.5, 'FALLBACK', order: 3, sub: 'font manager'),
  _pin(6.4, 3.0, 46.8, 'SHAPING', order: 4, sub: 'HarfBuzz'),
  _pin(1.0, 3.4, 66.6, 'LINES', order: 5, sub: 'ICU'),
  _pin(-28.4, 6.6, 11.2, 'BIDI', order: 6, sub: 'ICU · layout'),
  _pin(-9.0, 1.6, 79.0, 'RASTER', order: 7, sub: 'Skia'),
];

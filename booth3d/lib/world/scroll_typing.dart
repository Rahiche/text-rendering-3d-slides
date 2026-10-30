import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show Camera;

import 'hanging_scrolls.dart';

/// The pointer and the keys on hanging scrolls' writing (hanging_scrolls.dart),
/// over a canvas of [canvas] size that [camera] shows them in: the
/// vertical-text cursor over the writing, a press putting the caret in it,
/// a drag selecting it (a double-click all of it), ⌘C copying it, a
/// right-click (or a control-click) opening Flutter's own desktop text menu.
/// The middle scroll's typed into through an editor nobody sees (its keys,
/// the input method's composing, the clipboard, undo: as any text field's),
/// kept at the caret on the scroll so the input method's window opens
/// there; its arrows turned for a column, Esc to stop. While it has the
/// keys, [HangingScrolls.editorFocused] says so (so the talk's own keys
/// leave them be).
class ScrollTyping extends StatefulWidget {
  const ScrollTyping({super.key, required this.scrolls, required this.camera, required this.canvas, this.keysBack});

  final HangingScrolls scrolls;
  final Camera Function() camera;
  final Size canvas;

  /// Where the keys go when the writing's done (Esc, a press off it); none:
  /// the editor just lets them go.
  final FocusNode? keysBack;

  @override
  State<ScrollTyping> createState() => ScrollTypingState();
}

class ScrollTypingState extends State<ScrollTyping> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _tick());

  /// The pointer over the writing (the vertical-text cursor), what was just
  /// copied (shown a moment), and the last press (for a double-click).
  final _overText = ValueNotifier(false);
  final _copied = ValueNotifier<(String, bool)>(('', false));
  Timer? _copiedOff;
  Duration? _lastPress;
  Offset _lastPressAt = Offset.zero;

  final _editor = TextEditingController();
  final _editFocus = FocusNode(debugLabel: 'scroll editor');
  final _editorKey = GlobalKey<EditableTextState>();
  final _caretAt = ValueNotifier(Offset.zero);

  /// The text menu, where it opens (canvas px).
  final _menu = ValueNotifier<Offset?>(null);

  HangingScrolls get _scrolls => widget.scrolls;
  Size get _size => widget.canvas;

  @override
  void initState() {
    super.initState();
    _editor
      ..text = _scrolls.editableText
      ..addListener(_edited);
    _ticker.start();
  }

  @override
  void dispose() {
    // (The keys the talk's again.)
    _scrolls.editorFocused = false;
    _ticker.dispose();
    _copiedOff?.cancel();
    _overText.dispose();
    _copied.dispose();
    _editor.dispose();
    _editFocus.dispose();
    _caretAt.dispose();
    _menu.dispose();
    super.dispose();
  }

  void _tick() {
    _scrolls.editorFocused = _editFocus.hasFocus;
    if (_scrolls.caretOnScreen(_size, widget.camera()) case final at?) _caretAt.value = at;
  }

  void _down(PointerDownEvent e) {
    _menu.value = null;
    final p = e.localPosition;
    if (e.buttons & kSecondaryButton != 0 || (e.buttons & kPrimaryButton != 0 && HardwareKeyboard.instance.isControlPressed)) {
      openMenu(p);
      return;
    }
    if (e.buttons & kPrimaryButton == 0) return;
    final again = _lastPress != null && e.timeStamp - _lastPress! < const Duration(milliseconds: 350) && (p - _lastPressAt).distance < 6;
    _lastPress = e.timeStamp;
    _lastPressAt = p;
    final camera = widget.camera();
    if (again) {
      _scrolls.selectAllAt(p, _size, camera);
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      _scrolls.selectTo(p, _size, camera);
    } else {
      _scrolls.selectFrom(p, _size, camera);
    }
    _afterPointer();
  }

  void _move(PointerMoveEvent e) {
    if (e.buttons & kPrimaryButton != 0 && _menu.value == null) {
      _scrolls.selectTo(e.localPosition, _size, widget.camera());
      _afterPointer();
    }
    _overText.value = _scrolls.overText(e.localPosition, _size, widget.camera());
  }

  void _hover(PointerHoverEvent e) => _overText.value = _scrolls.overText(e.localPosition, _size, widget.camera());

  /// After the pointer's moved the selection: on the middle scroll, the
  /// editor has it (and the keys); anywhere else, they go back.
  void _afterPointer() {
    if (_scrolls.editing) {
      _editor.value = _editor.value.copyWith(selection: _scrolls.editorSelection, composing: TextRange.empty);
      if (!_editFocus.hasFocus) _editFocus.requestFocus();
    } else if (_editFocus.hasFocus) {
      _done();
    }
  }

  void _done() {
    final back = widget.keysBack;
    if (back != null) {
      back.requestFocus();
    } else {
      _editFocus.unfocus();
    }
    _scrolls.editorFocused = false;
  }

  /// Typed into, or its selection moved by its keys: onto the scroll.
  void _edited() {
    if (_editFocus.hasFocus) _scrolls.edited(_editor.value);
  }

  /// A right-click at [p]: on writing that isn't selected, the caret there
  /// first (as anywhere); then the menu, if there's writing under it.
  void openMenu(Offset p) {
    final camera = widget.camera();
    if (!_scrolls.inSelection(p, _size, camera)) {
      _scrolls.selectFrom(p, _size, camera);
      _afterPointer();
    }
    if (_scrolls.hasSelection) _menu.value = p;
  }

  /// Flutter's own text menu, the desktop one (as a selection in any
  /// Flutter app has it): copy and select all, and in the middle scroll cut
  /// and paste too (through its editor, as its keys).
  Widget _menuAt(Offset at) {
    final editing = _scrolls.editing, some = _scrolls.selectedText.isNotEmpty, editor = _editorKey.currentState;
    void pick(void Function() act) {
      _menu.value = null;
      act();
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: at),
      buttonItems: [
        if (editing && some) ContextMenuButtonItem(type: ContextMenuButtonType.cut, onPressed: () => pick(() => editor?.cutSelection(SelectionChangedCause.toolbar))),
        if (some) ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () => pick(copy)),
        if (editing) ContextMenuButtonItem(type: ContextMenuButtonType.paste, onPressed: () => pick(() => editor?.pasteText(SelectionChangedCause.toolbar))),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () => pick(() => editing ? editor?.selectAll(SelectionChangedCause.toolbar) : _scrolls.selectAll()),
        ),
      ],
    );
  }

  /// What's selected to the clipboard (and said so a moment).
  void copy() {
    final text = _scrolls.selectedText;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _copied.value = (text, true);
    _copiedOff?.cancel();
    _copiedOff = Timer(const Duration(milliseconds: 1800), () => _copied.value = (text, false));
  }

  /// Closes the menu, if it's open; whether it was.
  bool closeMenu() {
    if (_menu.value == null) return false;
    _menu.value = null;
    return true;
  }

  /// The editor's keys turned for a column: up and down go along it, left
  /// and right from one column to the next (left the next, as the writing
  /// goes); Esc stops writing.
  static const _columnKeys = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): ExtendSelectionByCharacterIntent(forward: false, collapseSelection: true),
    SingleActivator(LogicalKeyboardKey.arrowDown): ExtendSelectionByCharacterIntent(forward: true, collapseSelection: true),
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): ExtendSelectionByCharacterIntent(forward: false, collapseSelection: false),
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): ExtendSelectionByCharacterIntent(forward: true, collapseSelection: false),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _ColumnIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowRight): _ColumnIntent(-1),
    SingleActivator(LogicalKeyboardKey.escape): _DoneIntent(),
  };

  /// The editor nobody sees, at the caret on the scroll (the input method's
  /// window opens by it; its text a pixel high, so its own caret stays put).
  Widget _editorField() => ValueListenableBuilder<Offset>(
    valueListenable: _caretAt,
    builder: (_, at, child) => Positioned(left: at.dx, top: at.dy, width: 400, height: 24, child: child!),
    child: IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: Shortcuts(
          shortcuts: _columnKeys,
          child: Actions(
            actions: {
              _ColumnIntent: CallbackAction<_ColumnIntent>(
                onInvoke: (i) {
                  _editor.selection = _scrolls.columnMove(i.next);
                  return null;
                },
              ),
              _DoneIntent: CallbackAction<_DoneIntent>(
                onInvoke: (_) {
                  _done();
                  return null;
                },
              ),
            },
            child: EditableText(
              key: _editorKey,
              controller: _editor,
              focusNode: _editFocus,
              style: const TextStyle(fontSize: 1, color: Color(0x00000000)),
              cursorColor: const Color(0x00000000),
              backgroundCursorColor: const Color(0x00000000),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              // (Two columns at most: what would need a third isn't taken.)
              inputFormatters: [TextInputFormatter.withFunction((old, now) => HangingScrolls.fits(now.text) ? now : old)],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _editorField(),
      Positioned.fill(
        child: ValueListenableBuilder<bool>(
          valueListenable: _overText,
          builder: (_, over, child) => MouseRegion(cursor: over ? SystemMouseCursors.verticalText : SystemMouseCursors.basic, child: child),
          child: Listener(behavior: HitTestBehavior.opaque, onPointerDown: _down, onPointerMove: _move, onPointerHover: _hover, child: const SizedBox.expand()),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 70,
        child: ValueListenableBuilder<(String, bool)>(valueListenable: _copied, builder: (_, c, _) => _Copied(c.$1, shown: c.$2)),
      ),
      ValueListenableBuilder<Offset?>(
        valueListenable: _menu,
        builder: (_, at, _) => at == null ? const SizedBox.shrink() : Positioned.fill(child: _menuAt(at)),
      ),
    ],
  );
}

/// To the next column (+1, to the left) or the one before.
class _ColumnIntent extends Intent {
  const _ColumnIntent(this.next);
  final int next;
}

/// Done writing (Esc).
class _DoneIntent extends Intent {
  const _DoneIntent();
}

/// What was just copied, for a moment.
class _Copied extends StatelessWidget {
  const _Copied(this.text, {required this.shown});
  final String text;
  final bool shown;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: shown ? 1 : 0,
    duration: const Duration(milliseconds: 250),
    child: Center(
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xD914161C), borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('Copied   $text', style: const TextStyle(color: Colors.white, fontSize: 19)),
        ),
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Labelled input: label above, 52 tall, radius 16. 1px border, 2px primary
/// when focused, danger border plus message text when [errorText] is set.
class PawTextField extends StatefulWidget {
  const PawTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helperText,
    this.errorText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helperText;

  /// When non null the field is in its error state and the text is shown below.
  final String? errorText;

  /// Checks the text as the person types. Return a message when it is not right, or null when it is.
  /// The message shows once they pause typing or leave the field, then updates on every key press, so the
  /// error appears and disappears while they fix it. [errorText] (for example from a failed submit) wins.
  final String? Function(String text)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// Trailing widget, for example a dropdown chevron.
  /// Leading icon inside the field (for example the mail or map pin icon).
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PawTextField> createState() => _PawTextFieldState();
}

class _PawTextFieldState extends State<PawTextField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  /// Whether the live message may show yet: after a pause in typing, or after leaving the field.
  bool _touched = false;
  Timer? _pause;
  String _typed = '';

  /// How long to wait after the last key press before judging what was typed.
  static const _pauseBeforeJudging = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _typed = widget.controller?.text ?? '';
    _node.addListener(_onFocus);
    widget.controller?.addListener(_onText);
  }

  void _onText() {
    final t = widget.controller!.text;
    if (t != _typed) {
      _typed = t;
      _restartPause();
    }
  }

  void _restartPause() {
    if (widget.validator == null) return;
    _pause?.cancel();
    if (_touched) {
      setState(() {});
      return;
    }
    _pause = Timer(_pauseBeforeJudging, () {
      if (mounted) setState(() => _touched = true);
    });
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant PawTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onText);
      widget.controller?.addListener(_onText);
      _typed = widget.controller?.text ?? _typed;
    }
  }

  void _onFocus() {
    final focused = _node.hasFocus;
    if (_focused == focused) return;
    setState(() {
      _focused = focused;
      // Leaving the field counts as "done typing", so the message shows even without a pause.
      if (!focused && widget.validator != null) _touched = true;
    });
  }

  void _typedChanged(String v) {
    // Without a controller the field is the only place the text lives.
    if (widget.controller == null) {
      _typed = v;
      _restartPause();
    }
    widget.onChanged?.call(v);
  }

  /// The message to show: a submit error first, then the live check once the person has had a go.
  String? get _liveError {
    final v = widget.validator;
    if (v == null || !_touched) return null;
    return v(_typed);
  }

  @override
  void dispose() {
    _pause?.cancel();
    widget.controller?.removeListener(_onText);
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText ?? _liveError;
    final hasError = error != null;
    final border = hasError
        ? const BorderSide(color: PawColors.danger, width: 1.5)
        : _focused
        ? const BorderSide(color: PawColors.primary, width: 2)
        : const BorderSide(color: PawColors.border);

    final message = error ?? widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: PawText.meta13.copyWith(color: PawColors.ink2),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: widget.label,
          hint: widget.hint,
          child: Container(
            height: PawSize.input,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.enabled ? PawColors.surface : PawColors.subtle,
              borderRadius: BorderRadius.circular(PawRadius.input),
              border: Border.fromBorderSide(border),
            ),
            child: Row(
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _node,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    maxLength: widget.maxLength,
                    inputFormatters: widget.inputFormatters,
                    autofillHints: widget.autofillHints,
                    onChanged: _typedChanged,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: PawColors.primary,
                    style: PawText.body15Strong,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: PawText.body15Strong.copyWith(
                        color: PawColors.muted,
                      ),
                    ).copyWith(counterText: ''),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
              ],
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: hasError,
            child: Text(
              message,
              style: PawText.meta13.copyWith(
                color: hasError ? PawColors.danger : PawColors.muted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

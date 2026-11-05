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

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant PawTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final border = hasError
        ? const BorderSide(color: PawColors.danger, width: 1.5)
        : _focused
        ? const BorderSide(color: PawColors.primary, width: 2)
        : const BorderSide(color: PawColors.border);

    final message = widget.errorText ?? widget.helperText;

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
                    onChanged: widget.onChanged,
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
          Text(
            message,
            style: PawText.meta13.copyWith(
              color: hasError ? PawColors.danger : PawColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

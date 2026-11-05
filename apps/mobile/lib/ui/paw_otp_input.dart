import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Six boxes for a one time code, driven by one real text field so paste, autofill from the
/// email or SMS ("one time code") and the number keyboard all work. Screen readers meet a single
/// field labelled "6 digit code", not six separate ones.
class PawOtpInput extends StatefulWidget {
  const PawOtpInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.length = 6,
    this.errorText,
    this.enabled = true,
    this.autofocus = true,
    this.controller,
  });

  final ValueChanged<String> onChanged;

  /// Called once when all digits are in.
  final ValueChanged<String>? onCompleted;
  final int length;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final TextEditingController? controller;

  @override
  State<PawOtpInput> createState() => _PawOtpInputState();
}

class _PawOtpInputState extends State<PawOtpInput> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());
  final _focus = FocusNode();
  var _completedFor = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _own?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    final v = _controller.text;
    widget.onChanged(v);
    if (v.length == widget.length && v != _completedFor) {
      _completedFor = v;
      widget.onCompleted?.call(v);
    }
    if (v.length < widget.length) _completedFor = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final hasError = widget.errorText != null;
    final activeIndex = _focus.hasFocus
        ? text.length.clamp(0, widget.length - 1)
        : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '${widget.length} digit code',
          textField: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focus.requestFocus : null,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _Box(
                            digit: i < text.length ? text[i] : '',
                            active: i == activeIndex,
                            error: hasError,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // The real field sits on top, invisible, and takes the typing.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: widget.length,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration.collapsed(hintText: '')
                          .copyWith(counterText: ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: PawText.meta13.copyWith(color: PawColors.danger),
          ),
        ],
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.error});
  final String digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final side = error
        ? const BorderSide(color: PawColors.danger, width: 1.5)
        : active
        ? const BorderSide(color: PawColors.primary, width: 2)
        : const BorderSide(color: PawColors.border);
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PawColors.surface,
        borderRadius: BorderRadius.circular(PawRadius.input),
        border: Border.fromBorderSide(side),
      ),
      child: Text(digit, style: PawText.title28.copyWith(fontSize: 24)),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../domain/models.dart';

/// The frame every onboarding step shares: back button and progress on top, a title, the form, and
/// the main action pinned to the bottom (it scrolls with the form when the keyboard is up).
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.form,
    this.subtitle,
    this.step,
    this.totalSteps = 6,
    this.showBack = true,
    this.onBack,
    this.trailing,
    this.error,
    this.footer = const [],
    this.gap = 20,
  });

  final String title;
  final String? subtitle;

  /// 1 based step in the progress bar; null hides the bar.
  final int? step;
  final int totalSteps;
  final bool showBack;
  final VoidCallback? onBack;

  /// For example "Skip".
  final Widget? trailing;
  final List<Widget> form;
  final String? error;

  /// Buttons at the bottom.
  final List<Widget> footer;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.onboardingSide,
                  12,
                  PawSpace.onboardingSide,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showBack) PawBackButton(onPressed: onBack),
                        if (step != null) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: PawStepProgress(
                              step: step!,
                              total: totalSteps,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (trailing != null) ...[
                          const SizedBox(width: 14),
                          trailing!,
                        ],
                      ],
                    ),
                    SizedBox(height: gap + 2),
                    Semantics(
                      header: true,
                      child: Text(title, style: PawText.title30),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: PawText.body15.copyWith(color: PawColors.muted),
                      ),
                    ],
                    for (final c in form) ...[SizedBox(height: gap), c],
                    const SizedBox(height: 24),
                    const Spacer(),
                    if (error != null) ...[
                      ErrorNote(error!),
                      const SizedBox(height: 12),
                    ],
                    for (var i = 0; i < footer.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      footer[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A message the person can read and act on. Announced to screen readers when it appears.
class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PawColors.dangerSoft,
          borderRadius: BorderRadius.circular(PawRadius.input),
        ),
        child: Text(
          message,
          style: PawText.body14Strong.copyWith(color: PawColors.danger),
        ),
      ),
    );
  }
}

/// A text link style button with a 44 point tap area.
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = PawColors.primary,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(PawSize.touch, PawSize.touch),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          foregroundColor: color,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: Text(label, style: PawText.body14Strong.copyWith(color: color)),
      ),
    );
  }
}

/// A read only field that opens a picker when tapped (date of birth, breed).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.hint = 'Choose',
    this.trailing,
    this.errorText,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: PawText.meta13.copyWith(color: PawColors.ink2),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: has ? '$label, $value' : '$label, $hint',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: PawColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PawRadius.input),
              side: BorderSide(
                color: errorText == null ? PawColors.border : PawColors.danger,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PawRadius.input),
              ),
              child: Container(
                height: PawSize.input,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        has ? value! : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PawText.body15Strong.copyWith(
                          color: has ? PawColors.ink : PawColors.muted,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: PawText.meta13.copyWith(color: PawColors.danger),
          ),
        ],
      ],
    );
  }
}

/// The dashed square or circle where a photo goes. Shows the chosen photo once there is one.
class PhotoPickerButton extends StatelessWidget {
  const PhotoPickerButton({
    super.key,
    required this.photo,
    required this.onTap,
    required this.semanticLabel,
    this.size = 80,
    this.circle = false,
    this.label,
  });

  final PickedPhoto? photo;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;
  final bool circle;

  /// Text under the camera icon (the big profile photo button).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final radius = circle ? size / 2 : 22.0;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PawColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: photo == null
                ? Border.all(color: PawColors.outline, width: 2)
                : null,
          ),
          child: photo == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PawIcon(
                      PawIconData.camera,
                      size: 26,
                      color: PawColors.muted,
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        label!,
                        style: PawText.meta12.copyWith(
                          color: PawColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                )
              : Image.memory(photo!.bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Take a photo, choose one, or remove the current one. Returns null if dismissed; a result with
/// `removed: true` means "clear it".
Future<({PickedPhoto? photo, bool removed})?> choosePhoto(
  BuildContext context, {
  required Future<PickedPhoto?> Function() fromCamera,
  required Future<PickedPhoto?> Function() fromGallery,
  required bool hasPhoto,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: PawColors.surface,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetRow('Take a photo', () => Navigator.pop(ctx, 'camera')),
          _SheetRow(
            'Choose from your photos',
            () => Navigator.pop(ctx, 'gallery'),
          ),
          if (hasPhoto)
            _SheetRow('Remove photo', () => Navigator.pop(ctx, 'remove')),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  return switch (choice) {
    'camera' => (photo: await fromCamera(), removed: false),
    'gallery' => (photo: await fromGallery(), removed: false),
    'remove' => (photo: null, removed: true),
    _ => null,
  };
}

class _SheetRow extends StatelessWidget {
  const _SheetRow(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: PawSpace.onboardingSide,
        ),
        child: Text(label, style: PawText.body15Strong),
      ),
    );
  }
}

/// Opens the date picker in the app theme.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  DateTime? initial,
  String? help,
}) {
  var start = initial ?? last;
  if (start.isBefore(first)) start = first;
  if (start.isAfter(last)) start = last;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first,
    lastDate: last,
    helpText: help,
  );
}

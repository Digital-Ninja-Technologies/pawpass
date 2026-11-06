import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';

/// A multi line text box that matches [PawTextField]'s look (which is one line only).
class PawNoteField extends StatelessWidget {
  const PawNoteField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLength = 600,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(PawRadius.input),
      borderSide: const BorderSide(color: PawColors.outline, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PawText.body14Strong),
        if (helper != null) ...[
          const SizedBox(height: 2),
          Text(helper!, style: PawText.meta13.copyWith(color: PawColors.muted)),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 6,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          style: PawText.body15,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PawText.body15.copyWith(color: PawColors.muted),
            filled: true,
            fillColor: PawColors.surface,
            contentPadding: const EdgeInsets.all(16),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: PawColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// The round tinted tile that stands for a provider (initials), since providers have no photo yet.
class ProviderMark extends StatelessWidget {
  const ProviderMark(this.name, {super.key, this.size = 52});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'^[A-Za-z]').hasMatch(w))
        .toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PawColors.primarySoft,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Text(
          initials,
          style: PawText.body15Strong.copyWith(color: PawColors.primaryText),
        ),
      ),
    );
  }
}

/// A provider in the Services list.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.provider,
    required this.now,
    required this.onTap,
  });
  final ProviderSummary provider;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final meta = [
      ratingLabel(p.ratingAvg, p.ratingCount),
      if (p.distanceM != null)
        distanceLabel(p.distanceM)
      else if (p.area != null)
        p.area!,
      if (p.homeVisits)
        'Home visits'
      else if (openLabel(p).isNotEmpty)
        openLabel(p),
    ].join(' · ');
    final next = p.nextSlot == null
        ? 'No times this fortnight'
        : 'Next: ${nextLabel(p.nextSlot!, now)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PawCard(
        radius: PawRadius.cardSmall,
        onTap: onTap,
        semanticLabel: '${p.name}. $meta. $next. ${fromPrice(p.fromPriceKobo)}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProviderMark(p.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: PawText.body15Strong),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        next,
                        style: PawText.meta13.copyWith(
                          color: PawColors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.fromPriceKobo != null)
                        Text(
                          fromPrice(p.fromPriceKobo),
                          style: PawText.meta13.copyWith(color: PawColors.ink2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five tappable stars (or five plain ones when [onChanged] is null).
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 40,
  });
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: onChanged != null,
            selected: i == value,
            label: '$i of 5 stars',
            excludeSemantics: true,
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(i),
              child: SizedBox(
                width: size + 8,
                height: size + 4,
                child: Center(
                  child: Text(
                    '★',
                    style: TextStyle(
                      fontSize: size,
                      height: 1,
                      color: i <= value ? PawColors.dot : PawColors.disabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A radio style row: the whole row taps, with a ring at the left.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        label: [title, ?subtitle, ?trailing].join(', '),
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: selected ? PawColors.primarySoft : PawColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
            side: BorderSide(
              color: selected ? PawColors.primary : PawColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? PawColors.primary
                              : PawColors.outline,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Center(
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: PawColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: PawText.body15Strong),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: PawText.meta13.copyWith(
                                color: PawColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      Text(trailing!, style: PawText.body15Strong),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back arrow and a heading.
class BookingHeader extends StatelessWidget {
  const BookingHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PawBackButton(),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: PawText.heading22,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

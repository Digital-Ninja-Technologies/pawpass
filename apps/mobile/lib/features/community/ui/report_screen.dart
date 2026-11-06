import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart' show SectionLabel;
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';

/// Report content (design/screens/ReportContent.dc.html).
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.target, required this.targetId});
  final ReportTarget target;
  final String targetId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportReason? _reason;
  var _block = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).community;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      12,
                      PawSpace.screenSide,
                      24,
                    ),
                    children: [
                      const BookingHeader('Report this'),
                      const SizedBox(height: 8),
                      Text(
                        'Reports are anonymous. Our team reviews them within 24 hours.',
                        style: PawText.meta13.copyWith(
                          color: PawColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Reason'),
                      const SizedBox(height: 10),
                      for (final r in ReportReason.values)
                        ChoiceRow(
                          title: r.label,
                          subtitle: r.hint.isEmpty ? null : r.hint,
                          selected: _reason == r,
                          onTap: () => setState(() => _reason = r),
                        ),
                      const SizedBox(height: 8),
                      PawToggleRow(
                        label: 'Also block this account',
                        value: _block,
                        onChanged: (v) => setState(() => _block = v),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'If an animal is in danger right now, also contact local authorities.',
                        style: PawText.meta13.copyWith(
                          color: PawColors.muted,
                          height: 1.5,
                        ),
                      ),
                      if (c.reportError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.reportError!,
                            style: PawText.body14.copyWith(
                              color: PawColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: 'Send report',
                      loading: c.reporting,
                      onPressed: _reason == null || c.reporting
                          ? null
                          : () async {
                              final ok = await c.report(
                                widget.target,
                                widget.targetId,
                                _reason!,
                                block: _block,
                              );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Thank you. We will look into it.',
                                    ),
                                  ),
                                );
                                context.pop();
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

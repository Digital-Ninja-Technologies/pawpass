import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';

/// Report a problem within the vet check window: both payments are held until PawPass decides.
class ProblemScreen extends StatefulWidget {
  const ProblemScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen> {
  OrderProblem? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).adopt;
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
                      const BookingHeader('Report a problem'),
                      const SizedBox(height: 16),
                      Text('What went wrong?', style: PawText.body14Strong),
                      const SizedBox(height: 10),
                      for (final r in OrderProblem.values)
                        ChoiceRow(
                          title: r.label,
                          selected: _reason == r,
                          onTap: () => setState(() => _reason = r),
                        ),
                      const SizedBox(height: 10),
                      PawNoteField(
                        label: 'Tell us what happened',
                        controller: _details,
                        maxLength: 2000,
                        hint: 'What did the vet find, and when?',
                      ),
                      const SizedBox(height: 16),
                      PawCard(
                        color: PawColors.primarySoft,
                        radius: PawRadius.cardSmall,
                        child: Text(
                          'Both payments stay on hold. The OurPawPass team reviews both sides and decides within 72 hours. You can report a problem only inside the 72 hour vet check window.',
                          style: PawText.meta13.copyWith(
                            color: PawColors.primaryText,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (c.problemError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.problemError!,
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
                      label: 'Send to OurPawPass',
                      loading: c.reporting,
                      onPressed: _reason == null || c.reporting
                          ? null
                          : () async {
                              final ok = await c.reportProblem(
                                widget.orderId,
                                _reason!,
                                details: _details.text.trim().isEmpty
                                    ? null
                                    : _details.text.trim(),
                              );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'We got your report. The payments stay on hold.',
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

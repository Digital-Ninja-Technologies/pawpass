import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';

/// An adoption handover: the shelter has handed the pet over; the adopter accepts the passport.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.transferId});
  final String transferId;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.openTransfer(widget.transferId),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final t = c.transfer;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: t == null || t.id != widget.transferId
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PawBackButton(),
                        ),
                      ),
                      Expanded(
                        child: c.transferError != null
                            ? LoadError(
                                message: c.transferError!,
                                onRetry: () =>
                                    c.openTransfer(widget.transferId),
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  )
                : Column(
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
                            const BookingHeader('Passport transfer'),
                            const SizedBox(height: 18),
                            Semantics(
                              header: true,
                              child: Text(
                                t.completedAt != null
                                    ? '${t.petName} is home'
                                    : '${t.petName} is coming home',
                                style: PawText.title28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.completedAt != null
                                  ? 'The passport is yours.'
                                  : '${t.partnerName} confirmed the handover. Accept the passport to make ${t.petName} yours in OurPawPass.',
                              style: PawText.body15.copyWith(
                                color: PawColors.muted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const SectionLabel('What you receive'),
                            const SizedBox(height: 8),
                            for (final line in [
                              '${t.records} health record${t.records == 1 ? '' : 's'}${t.verifiedRecords > 0 ? ', ${t.verifiedRecords} vet verified' : ''}',
                              'QR tag ID and reminder schedule',
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const PawIcon(
                                      PawIconData.check,
                                      size: 16,
                                      color: PawColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(line, style: PawText.body14),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${t.partnerName} keeps a read-only record of the transfer.',
                              style: PawText.meta13.copyWith(
                                color: PawColors.muted,
                              ),
                            ),
                            if (c.acceptError != null) ...[
                              const SizedBox(height: 14),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  c.acceptError!,
                                  style: PawText.body14.copyWith(
                                    color: PawColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (t.completedAt == null && t.isReceiver)
                        PawStickyFooter(
                          children: [
                            PawButton(
                              label: 'Accept passport',
                              loading: c.accepting,
                              onPressed: c.accepting
                                  ? null
                                  : () async {
                                      final ok = await c.acceptPassport(t.id);
                                      if (ok && context.mounted) {
                                        scope.health.load();
                                        ScaffoldMessenger.of(context)
                                          ..hideCurrentSnackBar()
                                          ..showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "${t.petName}'s passport is yours.",
                                              ),
                                            ),
                                          );
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

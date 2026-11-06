import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/booking_logic.dart';

/// Booked (design/screens/Booked.dc.html): the confirmation after paying.
class BookedScreen extends StatelessWidget {
  const BookedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.booking;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final b = c.booked;
        if (b == null) {
          // Nothing was just booked (for example the screen was reopened): go to the list.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/bookings');
          });
          return const Scaffold(backgroundColor: PawColors.ground);
        }
        final booking = c.bookingById(b.bookingId);
        final petName =
            booking?.petName ?? scope.health.selected?.name ?? 'Your pet';
        final address = booking?.partnerAddress;
        final rows = <(String, String)>[
          ('Service', b.serviceName),
          ('When', whenLabel(b.startsAt)),
          ('Pet', petName),
          ('Paid', nairaFromKobo(b.amountKobo)),
        ];
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      32,
                      PawSpace.screenSide,
                      24,
                    ),
                    children: [
                      Center(
                        child: ExcludeSemantics(
                          child: Container(
                            width: 76,
                            height: 76,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: PawColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const PawIcon(
                              PawIconData.check,
                              size: 38,
                              color: PawColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text(
                          "You're booked",
                          textAlign: TextAlign.center,
                          style: PawText.title28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Booking confirmed',
                        textAlign: TextAlign.center,
                        style: PawText.body15.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 22),
                      PawCard(
                        radius: PawRadius.cardSmall,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.partnerName, style: PawText.body15Strong),
                            if (address != null)
                              Text(
                                address,
                                style: PawText.meta13.copyWith(
                                  color: PawColors.muted,
                                ),
                              ),
                            const SizedBox(height: 12),
                            for (final r in rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 76,
                                      child: Text(
                                        r.$1,
                                        style: PawText.meta13.copyWith(
                                          color: PawColors.muted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        r.$2,
                                        style: PawText.body14Strong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your payment is held until you confirm the visit. Free cancellation up to 2 hours before.',
                        textAlign: TextAlign.center,
                        style: PawText.meta13.copyWith(
                          color: PawColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: PawButton(
                              label: 'Add to calendar',
                              variant: PawButtonVariant.secondary,
                              onPressed: () => scope.services.links.open(
                                _calendarUri(
                                  b.serviceName,
                                  b.partnerName,
                                  b.startsAt,
                                  address,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PawButton(
                              label: 'Directions',
                              variant: PawButtonVariant.secondary,
                              onPressed: () => scope.services.links.open(
                                _directionsUri(
                                  booking?.partnerLat,
                                  booking?.partnerLng,
                                  b.partnerName,
                                  address,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: 'View my bookings',
                      onPressed: () {
                        c.booked = null;
                        context.go('/bookings');
                      },
                    ),
                    PawButton(
                      label: 'Back to home',
                      variant: PawButtonVariant.secondary,
                      onPressed: () {
                        c.booked = null;
                        context.go('/home');
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

String _stamp(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
}

Uri _calendarUri(
  String service,
  String place,
  DateTime start,
  String? address,
) => Uri.https('calendar.google.com', '/calendar/render', {
  'action': 'TEMPLATE',
  'text': '$service at $place',
  'dates': '${_stamp(start)}/${_stamp(start.add(const Duration(minutes: 45)))}',
  'location': ?address,
});

Uri _directionsUri(double? lat, double? lng, String name, String? address) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': lat != null && lng != null
          ? '$lat,$lng'
          : (address ?? name),
    });

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../../adopt/domain/adopt_logic.dart' show shortDay;
import '../../booking/domain/booking_logic.dart' show nairaFromKobo;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart' show PickerField;
import '../domain/models.dart';
import '../domain/partner_logic.dart';
import 'partner_widgets.dart';

/// Earnings (design/screens/PartnerEarnings.dc.html): next payout, what is held, what was paid.
class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadEarnings());
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final e = p.earnings;
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: p.loadEarnings,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                16,
                PawSpace.screenSide,
                24,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text('Earnings', style: PawText.title28),
                ),
                const SizedBox(height: 14),
                if (e == null && p.loadingEarnings)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (e == null)
                  LoadError(
                    message:
                        p.earningsError ?? 'We could not load your earnings.',
                    onRetry: p.loadEarnings,
                  )
                else ...[
                  PawCard(
                    color: PawColors.primary,
                    radius: PawRadius.card,
                    semanticLabel:
                        'Next payout ${nairaFromKobo(e.nextPayoutKobo)}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT PAYOUT · ${shortDay(e.nextPayoutOn).toUpperCase()}',
                          style: PawText.overline12.copyWith(
                            color: const Color(0xFFCFE6E1),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nairaFromKobo(e.nextPayoutKobo),
                          style: PawText.display36.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.accountLast4 == null
                              ? 'Add a payout account in Business'
                              : 'To your bank account ending ${e.accountLast4}',
                          style: PawText.meta13.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Figure(
                          'Held until owners confirm',
                          nairaFromKobo(e.heldKobo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Figure(
                          'Paid out in ${_month(p.now)}',
                          nairaFromKobo(e.paidMonthKobo),
                        ),
                      ),
                    ],
                  ),
                  const SectionHeading('Recent'),
                  if (e.recent.isEmpty)
                    const EmptyNote('Payments show here once an owner pays.')
                  else
                    for (final r in e.recent)
                      DashRow(
                        leading: const SizedBox.shrink(),
                        title: r.title,
                        subtitle: r.payout
                            ? '${shortDay(r.at)} · ${earningLabel(r.state)}'
                            : '${shortDay(r.at)} · ${earningLabel(r.state)}',
                        trailing: Text(
                          nairaFromKobo(r.amountKobo),
                          style: PawText.body15Strong,
                        ),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    'Amounts are after the PawPass fee. If an owner reports a problem, that payment pauses until the PawPass team decides.',
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _month(DateTime d) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][d.month - 1];
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => PawCard(
    radius: PawRadius.cardSmall,
    semanticLabel: '$label, $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PawText.meta12.copyWith(color: PawColors.muted)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: PawText.heading22),
        ),
      ],
    ),
  );
}

// ----------------------------------------------------------------------- help

class HelpArticle {
  const HelpArticle(this.title, this.body);
  final String title;
  final String body;
}

const helpArticles = <HelpArticle>[
  HelpArticle(
    'How escrow protects you',
    'When you book or pay a deposit, the money goes to PawPass, not straight to the other person. We hold it until you confirm the visit, or until the check window after a handover has passed with no problem. If something is wrong, report it and the payment pauses until the PawPass team decides.',
  ),
  HelpArticle(
    'Refunds & cancellations',
    'If a provider or seller cancels, you are refunded in full. If you cancel a booking in time, you are refunded too. A refund goes back to the card or bank you paid with and can take a few days to show.',
  ),
  HelpArticle(
    "Sharing your pet's passport",
    "Open your pet's passport and choose Share with vet. You get a link and a QR code that stop working after the time you choose. You can switch what a vet sees before you share.",
  ),
  HelpArticle(
    'Lost pet alerts & QR tags',
    'If a pet goes missing, report it from Community. People near the area are told, without your phone number. A QR tag on the collar lets anyone who finds your pet reach you through PawPass.',
  ),
  HelpArticle(
    'Buying a puppy safely',
    'Pay a deposit into escrow, collect your puppy, pay the balance, then accept the passport. You have 72 hours after the handover to get a vet check and report a problem before the seller is paid.',
  ),
  HelpArticle(
    'Becoming a partner',
    'Vets, groomers, trainers, boarding, breeders and shelters can verify their business in about ten minutes. The team reviews it within 48 hours. Open Me, then Become a partner.',
  ),
];

/// Help & support (design/screens/HelpSupport.dc.html).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  final _message = TextEditingController();
  var _topic = SupportTopic.payments;
  var _started = false;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  void _openArticle(HelpArticle a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.screenSide,
            0,
            PawSpace.screenSide,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title, style: PawText.title28),
              const SizedBox(height: 10),
              Text(
                a.body,
                style: PawText.body15.copyWith(color: PawColors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTopic() async {
    final t = await showModalBottomSheet<SupportTopic>(
      context: context,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in SupportTopic.values)
              ListTile(
                title: Text(t.label, style: PawText.body15),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (t != null && mounted) {
      setState(() => _topic = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadTickets());
    }
    return ListenableBuilder(
      listenable: Listenable.merge([p, _search]),
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();
        final articles = [
          for (final a in helpArticles)
            if (q.isEmpty ||
                a.title.toLowerCase().contains(q) ||
                a.body.toLowerCase().contains(q))
              a,
        ];
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                12,
                PawSpace.screenSide,
                32,
              ),
              children: [
                const BookingHeader('Help & support'),
                const SizedBox(height: 16),
                PawTextField(
                  label: 'Search help',
                  controller: _search,
                  hint: 'Search help articles',
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 18),
                const SectionLabel('Popular topics'),
                const SizedBox(height: 8),
                if (articles.isEmpty)
                  const EmptyNote(
                    'Nothing matches that. Send us a message below.',
                  )
                else
                  for (final a in articles)
                    PawListRow(title: a.title, onTap: () => _openArticle(a)),
                const SizedBox(height: 18),
                const SectionLabel('Your requests'),
                const SizedBox(height: 8),
                if (p.tickets.isEmpty)
                  Text(
                    p.loadingTickets
                        ? 'Loading…'
                        : 'You have not written to us yet.',
                    style: PawText.body14.copyWith(color: PawColors.muted),
                  )
                else
                  for (final t in p.tickets)
                    PawListRow(
                      title: t.subject,
                      subtitle: '${t.label} · opened ${shortDay(t.createdAt)}',
                      trailing: StatusTag(switch (t.state) {
                        TicketState.open => 'Open',
                        TicketState.replied => 'Replied',
                        TicketState.closed => 'Closed',
                      }, highlight: t.state == TicketState.replied),
                    ),
                const SizedBox(height: 22),
                const SectionLabel('Contact the PawPass team'),
                const SizedBox(height: 10),
                PickerField(
                  label: 'Topic',
                  value: _topic.label,
                  onTap: _pickTopic,
                ),
                const SizedBox(height: 14),
                PawNoteField(
                  label: 'Message',
                  controller: _message,
                  maxLength: 2000,
                  hint: 'How can we help?',
                  onChanged: (_) => setState(() {}),
                ),
                if (p.ticketError != null) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      p.ticketError!,
                      style: PawText.body14.copyWith(color: PawColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                PawButton(
                  label: 'Send · we reply within a day',
                  loading: p.sendingTicket,
                  onPressed: _message.text.trim().length < 5
                      ? null
                      : () async {
                          final ok = await p.sendTicket(_topic, _message.text);
                          if (ok && context.mounted) {
                            _message.clear();
                            setState(() {});
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sent. We will reply within a day.',
                                  ),
                                ),
                              );
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

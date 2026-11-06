import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

/// Share with a vet (design/screens/ShareVet.dc.html): a QR code and link that expire in 24 hours.
class ShareVetScreen extends StatefulWidget {
  const ShareVetScreen({super.key});

  @override
  State<ShareVetScreen> createState() => _ShareVetScreenState();
}

class _ShareVetScreenState extends State<ShareVetScreen> {
  var _scopes = {...ShareScope.values};
  ShareLink? _link;
  var _busy = true;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh "expires in ..." every half minute.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _make());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Makes a fresh link for the chosen scopes, stopping the old one first so only one is ever live.
  Future<void> _make() async {
    if (!mounted) return;
    final h = AppScope.of(context).health;
    final old = _link;
    setState(() {
      _busy = true;
      _error = null;
      _link = null;
    });
    if (old != null) {
      await h.revokeShare(old.id);
    }
    if (_scopes.isEmpty) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final link = await h.createShare(_scopes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _link = link;
      _error = link == null ? h.error : null;
    });
  }

  Future<void> _stop() async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final old = _link;
    if (old != null) await scope.health.revokeShare(old.id);
    if (!mounted) return;
    context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sharing stopped. The link no longer works.'),
        ),
      );
  }

  String _url(BuildContext context, ShareLink link) =>
      shareUrl(AppScope.of(context).services.shareBaseUrl, link.token);

  Future<void> _copy(ShareLink link) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await scope.services.links.copy(_url(context, link));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied.')));
  }

  Future<void> _whatsApp(ShareLink link, String petName) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = whatsAppShareText(petName: petName, url: _url(context, link));
    final opened = await scope.services.links.open(whatsAppUri(text));
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('We could not open WhatsApp. Use Copy link instead.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final pet = scope.health.selected;
    final link = _link;
    final now = scope.health.now;
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        bottom: false,
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
                  Row(
                    children: [
                      RoundIconButton(
                        icon: PawIconData.close,
                        semanticLabel: 'Close',
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            pet == null
                                ? 'Share passport'
                                : "Share ${pet.name}'s passport",
                            style: PawText.heading22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PawCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: _busy
                              ? const Center(child: CircularProgressIndicator())
                              : link == null
                              ? Center(
                                  child: Text(
                                    _scopes.isEmpty
                                        ? 'Choose at least one thing to share.'
                                        : 'No link yet.',
                                    textAlign: TextAlign.center,
                                    style: PawText.meta13.copyWith(
                                      color: PawColors.muted,
                                    ),
                                  ),
                                )
                              : PawQrCode(
                                  data: _url(context, link),
                                  semanticLabel:
                                      "QR code for ${pet?.name ?? 'your pet'}'s passport",
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ask the clinic to scan this, or send the link.',
                          textAlign: TextAlign.center,
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (link != null)
                          PawBadge(
                            expiryText(link.expiresAt, now),
                            tone: PawBadgeTone.upcoming,
                          ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorNote(_error!),
                    TextLinkButton(label: 'Try again', onPressed: _make),
                  ],
                  const SizedBox(height: 16),
                  Semantics(
                    container: true,
                    label: 'What the vet can see',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What the vet can see',
                          style: PawText.body15Strong,
                        ),
                        const SizedBox(height: 10),
                        for (final s in ShareScope.values) ...[
                          if (s != ShareScope.values.first)
                            const SizedBox(height: 8),
                          PawToggleRow(
                            label: s.label,
                            value: _scopes.contains(s),
                            onChanged: _busy
                                ? null
                                : (on) {
                                    setState(
                                      () => _scopes = on
                                          ? {..._scopes, s}
                                          : ({..._scopes}..remove(s)),
                                    );
                                    _make();
                                  },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Anyone with this link or QR code can see these things until it expires. Changing a switch makes a new link and the old one stops working.',
                    style: PawText.meta12.copyWith(
                      color: PawColors.muted,
                      height: 1.5,
                    ),
                  ),
                  if (link != null)
                    TextLinkButton(
                      label: 'Stop sharing now',
                      color: PawColors.danger,
                      onPressed: _stop,
                    ),
                ],
              ),
            ),
            PawStickyFooter(
              children: [
                // The WhatsApp label is longer, so it gets the bigger share of the row.
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: PawButton(
                        label: 'Copy link',
                        variant: PawButtonVariant.secondary,
                        onPressed: link == null ? null : () => _copy(link),
                      ),
                    ),
                    const SizedBox(width: PawSpace.s10),
                    Expanded(
                      flex: 5,
                      child: PawButton(
                        label: 'Send on WhatsApp',
                        onPressed: link == null || pet == null
                            ? null
                            : () => _whatsApp(link, pet.name),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

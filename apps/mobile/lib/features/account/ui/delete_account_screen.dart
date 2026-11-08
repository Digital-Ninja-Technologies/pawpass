import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../state/delete_account_controller.dart';

/// Delete my account. Says what goes and what stays, shows anything in the way, then asks for the word DELETE.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  DeleteAccountController? _c;
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    var c = _c;
    if (c == null) {
      final made = c = _c = DeleteAccountController(scope.services);
      WidgetsBinding.instance.addPostFrameCallback((_) => made.load());
    }
    final ctl = c;
    return ListenableBuilder(
      listenable: Listenable.merge([ctl, _word]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: ctl.loading && !ctl.loaded
                ? const Center(child: CircularProgressIndicator())
                : !ctl.loaded && ctl.loadError != null
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: BookingHeader('Delete my account'),
                      ),
                      Expanded(
                        child: PawErrorState(
                          title: 'We could not check your account',
                          message: ctl.loadError!,
                          onAction: ctl.load,
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      12,
                      PawSpace.screenSide,
                      32,
                    ),
                    children: [
                      const BookingHeader('Delete my account'),
                      const SizedBox(height: 16),
                      Text(
                        'This cannot be undone. You will be signed out and can never sign in to this account again.',
                        style: PawText.body15.copyWith(
                          color: PawColors.ink2,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('What is deleted'),
                      const SizedBox(height: 8),
                      const _Bullets([
                        'Your name, area, phone number and photo',
                        'Your pets, their health records and photos, where nothing else depends on them',
                        'Your posts, comments, likes and follows',
                        'Your messages (the other person keeps theirs)',
                        'Your sign in',
                      ]),
                      const SizedBox(height: 14),
                      const SectionLabel('What we have to keep'),
                      const SizedBox(height: 8),
                      const _Bullets([
                        'Payment, booking and order records, with your name replaced by "Deleted user". The law and other people\'s money need these.',
                      ]),
                      const SizedBox(height: 18),
                      if (ctl.blockers.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PawColors.warmSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Finish these first',
                                  style: PawText.body15Strong.copyWith(
                                    color: PawColors.warmText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final b in ctl.blockers)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    b,
                                    style: PawText.body14.copyWith(
                                      color: PawColors.warmText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        PawButton(
                          label: 'Check again',
                          variant: PawButtonVariant.secondary,
                          onPressed: ctl.load,
                        ),
                      ] else ...[
                        PawTextField(
                          label: 'Type $deleteWord to confirm',
                          controller: _word,
                          enabled: !ctl.deleting,
                          errorText: ctl.deleteError,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 14),
                        PawButton(
                          label: 'Delete my account',
                          variant: PawButtonVariant.danger,
                          loading: ctl.deleting,
                          onPressed: isDeleteConfirmed(_word.text) && ctl.canDelete
                              ? () async {
                                  final ok = await ctl.delete(_word.text);
                                  if (ok) await ctl.finish();
                                }
                              : null,
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 10),
                child: SizedBox(
                  width: 5,
                  height: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PawColors.ink2,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  i,
                  style: PawText.body14.copyWith(
                    color: PawColors.ink2,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

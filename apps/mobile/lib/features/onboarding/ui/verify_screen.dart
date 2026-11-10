import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../state/app_scope.dart';
import 'onboarding_page.dart';

/// How long before another code can be requested.
const resendSeconds = 60;

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  var _left = resendSeconds;
  String? _codeError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _left = resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  String get _clock {
    final m = _left ~/ 60;
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify(String code) async {
    final ob = AppScope.of(context).onboarding;
    if (code.length != 6) {
      setState(() => _codeError = 'Enter all 6 digits.');
      return;
    }
    setState(() => _codeError = null);
    final ok = await ob.verify(code);
    if (!ok && mounted) {
      final message = ob.error;
      // Clear first: emptying the boxes counts as typing, which would wipe the message.
      _code.clear();
      setState(() => _codeError = message);
    }
    // On success the session changes and the router moves on by itself.
  }

  Future<void> _resend() async {
    final ob = AppScope.of(context).onboarding;
    final ok = await ob.sendCode(ob.email);
    if (!mounted) return;
    if (ok) {
      _code.clear();
      setState(() {
        _codeError = null;
        _notice = 'We sent a new code.';
      });
      _startCountdown();
    } else {
      setState(() => _notice = null);
    }
  }

  Future<void> _openMail() async {
    final opened = await AppScope.of(context).services.emailApp.open();
    if (!opened && mounted) {
      setState(
        () => _notice = 'Open your email app and look for the OurPawPass code.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) => OnboardingPage(
        step: 2,
        title: 'Enter the code',
        gap: 22,
        error: _codeError == null ? ob.error : null,
        form: [
          Text.rich(
            TextSpan(
              style: PawText.body15.copyWith(
                color: PawColors.muted,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Sent to '),
                TextSpan(
                  text: ob.email,
                  style: const TextStyle(
                    color: PawColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '. '),
              ],
            ),
          ),
          PawOtpInput(
            controller: _code,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
              ob.clearError();
            },
            onCompleted: _verify,
            errorText: _codeError,
            enabled: !ob.busy,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Check spam if it's not there.",
                  style: PawText.body14.copyWith(color: PawColors.muted),
                ),
              ),
              TextLinkButton(
                label: _left > 0 ? 'Resend in $_clock' : 'Resend code',
                color: _left > 0 ? PawColors.muted : PawColors.primary,
                onPressed: _left > 0 || ob.busy ? null : _resend,
                alignment: Alignment.centerRight,
              ),
            ],
          ),
          if (AppScope.of(context).services.demoHint != null)
            Text(
              AppScope.of(context).services.demoHint!,
              style: PawText.meta13.copyWith(color: PawColors.warmText),
            ),
          if (_notice != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _notice!,
                style: PawText.body14Strong.copyWith(
                  color: PawColors.primaryText,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: _OpenMailButton(onPressed: _openMail),
          ),
          TextLinkButton(
            label: 'Use a different email',
            onPressed: () => context.pop(),
          ),
        ],
        footer: [
          PawButton(
            label: 'Verify',
            loading: ob.busy,
            onPressed: () => _verify(_code.text),
          ),
        ],
      ),
    );
  }
}

class _OpenMailButton extends StatelessWidget {
  const _OpenMailButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: 'Open email app',
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: PawColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: PawColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: const SizedBox(
            height: 44,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PawIcon(PawIconData.mail, size: 18),
                  SizedBox(width: 8),
                  Text('Open email app', style: PawText.body14Strong),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

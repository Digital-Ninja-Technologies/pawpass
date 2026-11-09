import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../domain/validators.dart';
import '../state/app_scope.dart';
import 'onboarding_page.dart';

/// Google and Apple sign in are in the design but need provider setup in Supabase and each store.
/// They stay hidden until that is done: build with --dart-define=SOCIAL_SIGN_IN=true to review them.
const kSocialSignIn = bool.fromEnvironment('SOCIAL_SIGN_IN');

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final _email = TextEditingController(
    text: AppScope.of(context).onboarding.email,
  );
  String? _fieldError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ob = AppScope.of(context).onboarding;
    if (!isValidEmail(_email.text)) {
      setState(
        () =>
            _fieldError = 'Enter a valid email address, like name@example.com.',
      );
      return;
    }
    setState(() => _fieldError = null);
    final ok = await ob.sendCode(_email.text);
    if (ok && mounted) context.push('/verify');
  }

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) => OnboardingPage(
        step: 1,
        title: "What's your email?",
        subtitle:
            "We'll email you a 6 digit code to sign in. No password needed.",
        gap: 22,
        error: ob.error,
        form: [
          PawTextField(
            label: 'Email address',
            controller: _email,
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            errorText: _fieldError,
            validator: (t) => t.trim().isEmpty
                ? 'Enter your email address.'
                : isValidEmail(t)
                ? null
                : 'That does not look right. Use an email like name@example.com.',
            prefix: const PawIcon(
              PawIconData.mail,
              size: 20,
              color: PawColors.muted,
            ),
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
              ob.clearError();
            },
            onSubmitted: (_) => _send(),
          ),
          PawButton(label: 'Send code', loading: ob.busy, onPressed: _send),
          if (kSocialSignIn) const _SocialSignIn(),
        ],
        footer: const [_Terms()],
      ),
    );
  }
}

class _SocialSignIn extends StatelessWidget {
  const _SocialSignIn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: PawColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: PawText.meta13.copyWith(color: PawColors.muted),
              ),
            ),
            const Expanded(child: Divider(color: PawColors.border)),
          ],
        ),
        const SizedBox(height: 10),
        PawButton(
          label: 'Google',
          variant: PawButtonVariant.secondary,
          onPressed: () {},
        ),
        const SizedBox(height: 10),
        PawButton(label: 'Apple', onPressed: () {}),
      ],
    );
  }
}

/// Plain text until the Terms and Privacy pages exist at a public address to link to.
class _Terms extends StatelessWidget {
  const _Terms();

  @override
  Widget build(BuildContext context) {
    final base = PawText.meta12.copyWith(color: PawColors.muted, height: 1.5);
    final strong = base.copyWith(
      color: PawColors.ink,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(text: 'Terms', style: strong),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: strong),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

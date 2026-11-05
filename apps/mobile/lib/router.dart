import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/onboarding/state/onboarding_controller.dart';
import 'features/onboarding/state/session_controller.dart';
import 'features/onboarding/ui/account_type_screen.dart';
import 'features/onboarding/ui/add_pet_screen.dart';
import 'features/onboarding/ui/all_set_screen.dart';
import 'features/onboarding/ui/pet_health_screen.dart';
import 'features/onboarding/ui/profile_setup_screen.dart';
import 'features/onboarding/ui/reminders_screen.dart';
import 'features/onboarding/ui/sign_up_screen.dart';
import 'features/onboarding/ui/verify_screen.dart';
import 'features/onboarding/ui/welcome_screen.dart';
import 'gallery/component_gallery_screen.dart';
import 'theme/tokens.dart';

/// Screens a signed out person may see.
const _signedOutRoutes = {'/welcome', '/sign-in', '/verify'};

/// Screens that only make sense before setup is finished (a signed in, finished person is sent home).
const _firstRunRoutes = {
  '/',
  '/splash',
  '/welcome',
  '/sign-in',
  '/verify',
  '/account-type',
  '/profile',
};

/// Decides where a person belongs from who they are:
///  - not signed in: the welcome, email and code screens only;
///  - signed in but setup unfinished: onboarding (they resume at "account type");
///  - signed in and finished: home. The pet steps stay open so "add another pet" works.
String? redirectFor({
  required SessionController session,
  required OnboardingController onboarding,
  required String location,
}) {
  if (session.status == SessionStatus.loading) {
    return location == '/splash' ? null : '/splash';
  }
  if (!session.signedIn) {
    return _signedOutRoutes.contains(location) ? null : '/welcome';
  }
  if (session.onboarded) {
    if (_firstRunRoutes.contains(location)) return '/home';
    if (location == '/all-set' && onboarding.createdPet == null) return '/home';
    return null;
  }
  const beforeSetup = {
    '/',
    '/splash',
    '/welcome',
    '/sign-in',
    '/verify',
    '/home',
    '/all-set',
  };
  return beforeSetup.contains(location) ? '/account-type' : null;
}

GoRouter buildRouter({
  required SessionController session,
  required OnboardingController onboarding,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: (context, state) => redirectFor(
      session: session,
      onboarding: onboarding,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/splash'),
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(
          backgroundColor: PawColors.primary,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyScreen()),
      GoRoute(
        path: '/account-type',
        builder: (_, _) => const AccountTypeScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileSetupScreen()),
      GoRoute(path: '/add-pet', builder: (_, _) => const AddPetScreen()),
      GoRoute(path: '/pet-health', builder: (_, _) => const PetHealthScreen()),
      GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
      GoRoute(path: '/all-set', builder: (_, _) => const AllSetScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      if (kDebugMode)
        GoRoute(
          path: '/gallery',
          builder: (_, _) => const ComponentGalleryScreen(),
        ),
    ],
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/adopt/ui/adopt_screen.dart';
import 'features/adopt/ui/apply_screen.dart';
import 'features/adopt/ui/checkout_screen.dart';
import 'features/adopt/ui/listing_screen.dart';
import 'features/adopt/ui/order_screen.dart';
import 'features/adopt/ui/problem_screen.dart';
import 'features/adopt/ui/transfer_screen.dart';
import 'features/booking/ui/booked_screen.dart';
import 'features/community/domain/models.dart';
import 'features/community/ui/chat_screen.dart';
import 'features/community/ui/community_screen.dart';
import 'features/community/ui/create_post_screen.dart';
import 'features/community/ui/lost_alert_screen.dart';
import 'features/community/ui/lost_pet_screen.dart';
import 'features/community/ui/pet_profile_screen.dart';
import 'features/community/ui/report_screen.dart';
import 'features/booking/ui/bookings_screen.dart';
import 'features/booking/ui/dispute_screen.dart';
import 'features/booking/ui/provider_screen.dart';
import 'features/booking/ui/review_screen.dart';
import 'features/booking/ui/services_screen.dart';
import 'features/health/ui/add_record_screen.dart';
import 'features/health/ui/emergency_screen.dart';
import 'features/health/ui/home_screen.dart';
import 'features/health/ui/main_shell.dart';
import 'features/health/ui/notifications_screen.dart';
import 'features/health/ui/passport_screen.dart';
import 'features/health/ui/schedule_screen.dart';
import 'features/health/ui/share_vet_screen.dart';
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
import 'ui/ui.dart' show PawIconData;

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
  // Not finished yet: only the setup screens are open.
  const setupRoutes = {
    '/account-type',
    '/profile',
    '/add-pet',
    '/pet-health',
    '/reminders',
    '/all-set',
  };
  return setupRoutes.contains(location) ? null : '/account-type';
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
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passport',
                builder: (_, _) => const PassportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/book', builder: (_, _) => const ServicesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, _) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/adopt', builder: (_, _) => const AdoptScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (_, state) =>
            ListingScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/checkout/:id',
        builder: (_, state) =>
            CheckoutScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderScreen(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'problem',
            builder: (_, state) =>
                ProblemScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/apply/:id',
        builder: (_, state) =>
            ApplyScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transfer/:id',
        builder: (_, state) =>
            TransferScreen(transferId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen()),
      GoRoute(
        path: '/provider/:id',
        builder: (_, state) =>
            ProviderScreen(providerId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/booked', builder: (_, _) => const BookedScreen()),
      GoRoute(
        path: '/review/:id',
        builder: (_, state) =>
            ReviewScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dispute/:id',
        builder: (_, state) =>
            DisputeScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(path: '/add-record', builder: (_, _) => const AddRecordScreen()),
      GoRoute(path: '/share', builder: (_, _) => const ShareVetScreen()),
      GoRoute(path: '/emergency', builder: (_, _) => const EmergencyScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/post/new', builder: (_, _) => const CreatePostScreen()),
      GoRoute(
        path: '/pet/:id',
        builder: (_, state) =>
            PetProfileScreen(petId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/report/:type/:id',
        builder: (_, state) {
          final target = ReportTarget.parse(state.pathParameters['type']);
          if (target == null) {
            return const ComingSoonScreen(
              title: 'Report',
              body: 'That cannot be reported from here.',
              icon: PawIconData.alertTriangle,
              showBack: true,
            );
          }
          return ReportScreen(
            target: target,
            targetId: state.pathParameters['id']!,
          );
        },
      ),
      GoRoute(path: '/lost-report', builder: (_, _) => const LostPetScreen()),
      GoRoute(
        path: '/lost/:id',
        builder: (_, state) =>
            LostAlertScreen(alertId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) =>
            ChatScreen(conversationId: state.pathParameters['id']!),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/gallery',
          builder: (_, _) => const ComponentGalleryScreen(),
        ),
    ],
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/analytics.dart';
import 'core/offline_cache.dart';
import 'core/push.dart';
import 'core/push_firebase.dart';
import 'features/account/data/supabase_account.dart';
import 'features/courses/data/supabase_courses.dart';
import 'features/adopt/data/supabase_adopt.dart';
import 'features/booking/data/supabase_bookings.dart';
import 'features/community/data/supabase_community.dart';
import 'features/health/data/supabase_health.dart';
import 'features/onboarding/data/device_services.dart';
import 'features/onboarding/data/in_memory.dart';
import 'features/onboarding/data/repositories.dart';
import 'features/onboarding/data/supabase_repositories.dart';
import 'features/partner/data/supabase_partner.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
    final client = Supabase.instance.client;
    final cache = OfflineCache(PrefsKeyValueStore());
    // Push needs the Firebase files for this build; without them this is a platform that does nothing.
    final pushPlatform = await FirebasePushPlatform.create();
    runApp(
      PawPassApp(
        services: AppServices(
          auth: SupabaseAuthRepository(client),
          profiles: SupabaseProfileRepository(client, cache: cache),
          pets: SupabasePetRepository(client, cache: cache),
          photos: ImagePickerPhotoPicker(),
          emailApp: DeviceEmailAppLauncher(),
          health: SupabaseHealthRepository(client, cache: cache),
          notifications: SupabaseNotificationsRepository(client, cache: cache),
          vets: SupabaseVetsRepository(client),
          location: GeolocatorLocationService(),
          links: UrlLinkLauncher(),
          bookings: SupabaseBookingsRepository(client),
          payments: SupabasePaymentsRepository(client),
          community: SupabaseCommunityRepository(client),
          adopt: SupabaseAdoptRepository(client),
          partner: SupabasePartnerRepository(client),
          account: SupabaseAccountRepository(client),
          courses: SupabaseCoursesRepository(client),
          cache: cache,
          analytics: SupabaseAnalytics(client),
          push: PushService(
            platform: pushPlatform,
            repository: SupabasePushRepository(client),
            store: PrefsKeyValueStore(),
          ),
        ),
      ),
    );
    return;
  }

  if (kDebugMode) {
    // No Supabase project configured: run on in memory stand ins so the screens can be reviewed.
    final base = inMemoryServices();
    runApp(
      PawPassApp(
        demo: true,
        services: AppServices(
          auth: base.auth,
          profiles: base.profiles,
          pets: base.pets,
          photos: ImagePickerPhotoPicker(),
          emailApp: DeviceEmailAppLauncher(),
          health: base.health,
          notifications: base.notifications,
          vets: base.vets,
          location: GeolocatorLocationService(),
          links: UrlLinkLauncher(),
          bookings: base.bookings,
          payments: base.payments,
          community: base.community,
          adopt: base.adopt,
          partner: base.partner,
          account: base.account,
          courses: base.courses,
          demoHint: 'Demo mode: nothing is sent. Use the code 123456.',
        ),
      ),
    );
    return;
  }

  runApp(const MissingConfigApp());
}

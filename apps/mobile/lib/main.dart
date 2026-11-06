import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/booking/data/supabase_bookings.dart';
import 'features/community/data/supabase_community.dart';
import 'features/health/data/supabase_health.dart';
import 'features/onboarding/data/device_services.dart';
import 'features/onboarding/data/in_memory.dart';
import 'features/onboarding/data/repositories.dart';
import 'features/onboarding/data/supabase_repositories.dart';

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
    runApp(
      PawPassApp(
        services: AppServices(
          auth: SupabaseAuthRepository(client),
          profiles: SupabaseProfileRepository(client),
          pets: SupabasePetRepository(client),
          photos: ImagePickerPhotoPicker(),
          emailApp: DeviceEmailAppLauncher(),
          health: SupabaseHealthRepository(client),
          notifications: SupabaseNotificationsRepository(client),
          vets: SupabaseVetsRepository(client),
          location: GeolocatorLocationService(),
          links: UrlLinkLauncher(),
          bookings: SupabaseBookingsRepository(client),
          payments: SupabasePaymentsRepository(client),
          community: SupabaseCommunityRepository(client),
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
          demoHint: 'Demo mode: nothing is sent. Use the code 123456.',
        ),
      ),
    );
    return;
  }

  runApp(const MissingConfigApp());
}

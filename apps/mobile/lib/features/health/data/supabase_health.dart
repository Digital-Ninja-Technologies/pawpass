import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dates.dart';
import '../../../core/offline_cache.dart';
import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'health_repositories.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) return e;
  if (isNetworkError(e)) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException && e.code == '22023') {
    // Our own checks (dates, scopes) carry a message meant to be read.
    return AppFailure(e.message);
  }
  return AppFailure(fallback);
}

class SupabaseHealthRepository implements HealthRepository {
  SupabaseHealthRepository(this._client, {this._cache});
  final SupabaseClient _client;
  final OfflineCache? _cache;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<HealthRecord>> records(String petId) async {
    try {
      return await cachedRead(
        _cache,
        '$_uid/records/$petId',
        () => _client
            .from('health_records')
            .select(
              '*, verifier:partner_accounts!verified_by_partner_id(business_name)',
            )
            .eq('pet_id', petId)
            .order('given_on', ascending: false, nullsFirst: false),
        (j) => [
          for (final r in (j as List))
            HealthRecord.fromRow(Map<String, dynamic>.from(r as Map), me: _uid),
        ],
      );
    } catch (e) {
      throw _failure(e, 'We could not load the health records.');
    }
  }

  @override
  Future<List<Reminder>> reminders(List<Pet> pets) async {
    if (pets.isEmpty) return const [];
    final names = {for (final p in pets) p.id: p.name};
    try {
      return await cachedRead(
        _cache,
        '$_uid/reminders',
        () => _client
            .from('reminders')
            .select('*, health_records(type, name, given_on, next_due_on)')
            .inFilter('pet_id', names.keys.toList())
            .inFilter('status', ['scheduled', 'snoozed'])
            .order('due_on'),
        (j) => [
          for (final r in (j as List))
            Reminder.fromRow(
              Map<String, dynamic>.from(r as Map),
              petName: names[r['pet_id']] ?? '',
            ),
        ],
      );
    } catch (e) {
      throw _failure(e, 'We could not load the schedule.');
    }
  }

  @override
  Future<HealthRecord> addRecord({
    required String petId,
    required RecordType type,
    required String name,
    required DateTime givenOn,
    DateTime? nextDueOn,
    String? value,
    String? givenByName,
    PickedPhoto? attachment,
  }) async {
    HealthRecord saved;
    try {
      final row = await _client
          .from('health_records')
          .insert({
            'pet_id': petId,
            'type': type.value,
            'name': name.trim(),
            'given_on': isoDate(givenOn),
            'next_due_on': nextDueOn == null ? null : isoDate(nextDueOn),
            'value': value,
            'given_by_name': (givenByName ?? '').trim().isEmpty
                ? null
                : givenByName!.trim(),
            'added_by_user_id': _uid,
          })
          .select()
          .single();
      saved = HealthRecord.fromRow(row, me: _uid);
    } catch (e) {
      throw _failure(e, 'We could not save the record. Nothing was saved.');
    }
    if (attachment == null) return saved;

    // Best effort: the record exists either way.
    try {
      final path = '$_uid/$petId/${saved.id}.${attachment.extension}';
      await _client.storage
          .from('health-attachments')
          .uploadBinary(
            path,
            attachment.bytes,
            fileOptions: FileOptions(
              contentType: attachment.contentType,
              upsert: true,
            ),
          );
      await _client
          .from('health_records')
          .update({'attachment_path': path})
          .eq('id', saved.id);
    } catch (_) {}
    return saved;
  }

  @override
  Future<HealthRecord?> completeReminder(
    String reminderId, {
    DateTime? givenOn,
  }) async {
    try {
      final row = await _client.rpc(
        'complete_reminder',
        params: {
          'p_reminder': reminderId,
          'p_given_on': givenOn == null ? null : isoDate(givenOn),
        },
      );
      if (row == null) return null;
      return HealthRecord.fromRow(
        Map<String, dynamic>.from(row as Map),
        me: _uid,
      );
    } catch (e) {
      throw _failure(e, 'We could not mark that as done. Try again.');
    }
  }

  @override
  Future<ShareLink> createShare({
    required String petId,
    required Set<ShareScope> scopes,
    int hours = 24,
  }) async {
    try {
      final json = await _client.rpc(
        'create_passport_share',
        params: {
          'p_pet': petId,
          'p_scopes': [for (final s in scopes) s.value],
          'p_hours': hours,
        },
      );
      return ShareLink.fromJson(Map<String, dynamic>.from(json as Map));
    } catch (e) {
      throw _failure(e, 'We could not make a share link. Try again.');
    }
  }

  @override
  Future<void> revokeShare(String shareId) async {
    try {
      await _client.rpc('revoke_passport_share', params: {'p_share': shareId});
    } catch (e) {
      throw _failure(e, 'We could not stop sharing. Try again.');
    }
  }

  @override
  Future<PetDetails> petDetails(Pet pet) async {
    try {
      final row = await cachedRead(
        _cache,
        '$_uid/details/${pet.id}',
        () => _client
            .from('pets')
            .select(
              'origin:partner_accounts!origin_partner_id(business_name, verified_at), '
              'mother:pets!mother_pet_id(name), father:pets!father_pet_id(name)',
            )
            .eq('id', pet.id)
            .single(),
        (j) => Map<String, dynamic>.from(j as Map),
      );
      final origin = row['origin'];
      return PetDetails(
        originName: origin is Map ? origin['business_name'] as String? : null,
        originVerified: origin is Map && origin['verified_at'] != null,
        motherName: row['mother'] is Map
            ? (row['mother'] as Map)['name'] as String?
            : null,
        fatherName: row['father'] is Map
            ? (row['father'] as Map)['name'] as String?
            : null,
      );
    } catch (_) {
      return const PetDetails();
    }
  }
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client, {this._cache});
  final SupabaseClient _client;
  final OfflineCache? _cache;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<AppNotification>> load() async {
    try {
      // Announce anything newly due first. If that fails the list is still worth showing.
      try {
        await _client.rpc('generate_my_reminder_notifications');
      } catch (_) {}
      return await cachedRead(
        _cache,
        '$_uid/notifications',
        () => _client
            .from('notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(60),
        (j) => [
          for (final r in (j as List))
            AppNotification.fromRow(Map<String, dynamic>.from(r as Map)),
        ],
      );
    } catch (e) {
      throw _failure(e, 'We could not load your notifications.');
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw _failure(e, 'We could not update that notification.');
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .isFilter('read_at', null);
    } catch (e) {
      throw _failure(e, 'We could not mark them as read.');
    }
  }
}

class SupabaseVetsRepository implements VetsRepository {
  SupabaseVetsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<EmergencyVet>> emergencyVets({double? lat, double? lng}) async {
    try {
      final rows = await _client.rpc(
        'emergency_vets',
        params: {'p_lat': lat, 'p_lng': lng, 'p_limit': 10},
      );
      return [
        for (final r in (rows as List))
          EmergencyVet.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(
        e,
        'We could not load the clinics. Call a vet you know, or try again.',
      );
    }
  }
}

/// Coarse position only (about a few hundred metres), asked for when the person opens Emergency.
class GeolocatorLocationService implements LocationService {
  @override
  Future<({double lat, double lng})?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }
}

class UrlLinkLauncher implements LinkLauncher {
  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

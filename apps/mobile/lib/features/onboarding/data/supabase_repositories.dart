import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline_cache.dart';
import '../domain/models.dart';
import '../domain/reminder_schedule.dart';
import '../domain/validators.dart';
import 'repositories.dart';

AppFailure _failure(Object e, {required String fallback}) {
  if (e is AppFailure) return e;
  if (isNetworkError(e)) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is AuthException) {
    final code = e.code ?? '';
    if (code.contains('rate_limit') || e.statusCode == '429') {
      return const AppFailure('Too many tries. Wait a minute, then try again.');
    }
    if (code == 'otp_expired') {
      return const AppFailure(
        'That code is wrong or has expired. Check it, or ask for a new one.',
      );
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return const AppFailure('Check the email address and try again.');
    }
  }
  return AppFailure(fallback);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  bool get signedIn => _client.auth.currentSession != null;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((s) => s.session != null);

  @override
  Future<void> sendCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
    } catch (e) {
      throw _failure(e, fallback: 'We could not send the code. Try again.');
    }
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    if (!isValidOtp(code)) {
      throw const AppFailure('Enter the 6 digit code from the email.');
    }
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
    } catch (e) {
      throw _failure(e, fallback: 'We could not check that code. Try again.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client, {this._cache});
  final SupabaseClient _client;
  final OfflineCache? _cache;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Profile> load() async {
    try {
      return await cachedRead(
        _cache,
        '$_uid/profile',
        () => _client
            .from('profiles')
            .select(
              'first_name, last_name, area, phone, avatar_path, account_types, onboarded_at',
            )
            .eq('user_id', _uid)
            .single(),
        (j) => Profile.fromRow(Map<String, dynamic>.from(j as Map)),
      );
    } catch (e) {
      throw _failure(e, fallback: 'We could not load your profile.');
    }
  }

  @override
  Future<void> save({
    String? firstName,
    String? lastName,
    String? area,
    String? phone,
    Set<AccountType>? accountTypes,
  }) async {
    final values = <String, dynamic>{
      'first_name': ?firstName,
      'last_name': ?lastName,
      'area': ?area,
      if (phone != null) 'phone': phone.isEmpty ? null : phone,
      if (accountTypes != null)
        'account_types': [for (final t in accountTypes) t.value],
    };
    if (values.isEmpty) return;
    try {
      await _client.from('profiles').update(values).eq('user_id', _uid);
    } catch (e) {
      throw _failure(e, fallback: 'We could not save your details. Try again.');
    }
  }

  @override
  Future<String> uploadAvatar(PickedPhoto photo) async {
    final path = '$_uid/avatar.${photo.extension}';
    try {
      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(
              contentType: photo.contentType,
              upsert: true,
            ),
          );
      await _client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('user_id', _uid);
      return path;
    } catch (e) {
      throw _failure(e, fallback: 'We could not upload that photo.');
    }
  }
}

class SupabasePetRepository implements PetRepository {
  SupabasePetRepository(this._client, {this._cache});
  final SupabaseClient _client;
  final OfflineCache? _cache;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Pet> createPassport({
    required PetInput pet,
    required List<HealthRecordDraft> records,
    required Set<ReminderChannel> channels,
    PickedPhoto? photo,
  }) async {
    final Pet created;
    try {
      final row = await _client.rpc(
        'create_pet_passport',
        params: {
          'p_pet': {
            'name': pet.name,
            'species': pet.species.value,
            'breed': pet.breed,
            'sex': pet.sex.value,
            'date_of_birth': pet.dateOfBirth?.toIso8601String().substring(
              0,
              10,
            ),
          },
          'p_records': [for (final r in records) r.toJson()],
          'p_channels': [for (final c in channels) c.value],
        },
      );
      created = Pet.fromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw _failure(
        e,
        fallback: 'We could not create the passport. Nothing was saved.',
      );
    }
    if (photo == null) return created;

    // Best effort: the passport exists either way.
    try {
      final path = '$_uid/${created.id}/photo.${photo.extension}';
      await _client.storage
          .from('pet-photos')
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(
              contentType: photo.contentType,
              upsert: true,
            ),
          );
      await _client
          .from('pets')
          .update({'photo_path': path})
          .eq('id', created.id);
      return Pet(
        id: created.id,
        name: created.name,
        species: created.species,
        breed: created.breed,
        sex: created.sex,
        dateOfBirth: created.dateOfBirth,
        tagCode: created.tagCode,
        photoPath: path,
      );
    } catch (_) {
      return created;
    }
  }

  @override
  Future<String?> photoUrl(Pet pet) async {
    final path = pet.photoPath;
    if (path == null) return null;
    try {
      return await _client.storage
          .from('pet-photos')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Pet>> myPets() async {
    try {
      return await cachedRead(
        _cache,
        '$_uid/pets',
        () => _client
            .from('pets')
            .select()
            .eq('owner_user_id', _uid)
            .order('created_at'),
        (j) => [
          for (final r in (j as List))
            Pet.fromRow(Map<String, dynamic>.from(r as Map)),
        ],
      );
    } catch (e) {
      throw _failure(e, fallback: 'We could not load your pets.');
    }
  }
}

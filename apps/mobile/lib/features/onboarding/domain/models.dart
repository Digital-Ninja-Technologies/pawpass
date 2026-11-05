import 'dart:typed_data';

/// What the owner picked on "How will you use PawPass?". The value is what the database stores.
enum AccountType {
  owner('owner', 'Pet owner', 'Track health, book care, join the community'),
  provider(
    'provider',
    'Vet or service provider',
    'Clinics, groomers, trainers, boarding',
  ),
  breeder('breeder', 'Breeder', 'List litters with verified passports'),
  shelter('shelter', 'Shelter or rescue', 'Rehome pets and screen adopters');

  const AccountType(this.value, this.title, this.subtitle);
  final String value;
  final String title;
  final String subtitle;

  static AccountType? fromValue(String v) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

enum Species {
  dog('dog', 'Dog'),
  cat('cat', 'Cat'),
  other('other', 'Other');

  const Species(this.value, this.label);
  final String value;
  final String label;

  static Species fromValue(String v) =>
      values.firstWhere((s) => s.value == v, orElse: () => Species.other);
}

enum PetSex {
  male('male', 'Male'),
  female('female', 'Female'),
  unknown('unknown', 'Unknown');

  const PetSex(this.value, this.label);
  final String value;
  final String label;

  static PetSex fromValue(String v) =>
      values.firstWhere((s) => s.value == v, orElse: () => PetSex.unknown);
}

/// Where reminders are sent. The value is what `reminders.channels` stores.
enum ReminderChannel {
  push('push', 'App notifications'),
  whatsapp('whatsapp', 'WhatsApp'),
  email('email', 'Email');

  const ReminderChannel(this.value, this.label);
  final String value;
  final String label;
}

/// A photo chosen on the device, not yet uploaded.
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.extension = 'jpg'});
  final Uint8List bytes;
  final String extension;

  String get contentType => extension == 'png' ? 'image/png' : 'image/jpeg';
}

/// The signed in user's profile row.
class Profile {
  const Profile({
    this.firstName = '',
    this.lastName = '',
    this.area,
    this.phone,
    this.avatarPath,
    this.accountTypes = const {AccountType.owner},
    this.onboardedAt,
  });

  final String firstName;
  final String lastName;
  final String? area;
  final String? phone;
  final String? avatarPath;
  final Set<AccountType> accountTypes;
  final DateTime? onboardedAt;

  bool get onboarded => onboardedAt != null;

  factory Profile.fromRow(Map<String, dynamic> row) {
    final types = <AccountType>{
      for (final v in (row['account_types'] as List? ?? const ['owner']))
        ?AccountType.fromValue(v as String),
    };
    return Profile(
      firstName: row['first_name'] as String? ?? '',
      lastName: row['last_name'] as String? ?? '',
      area: row['area'] as String?,
      phone: row['phone'] as String?,
      avatarPath: row['avatar_path'] as String?,
      accountTypes: types.isEmpty ? const {AccountType.owner} : types,
      onboardedAt: row['onboarded_at'] == null
          ? null
          : DateTime.parse(row['onboarded_at'] as String),
    );
  }
}

/// A pet as it comes back from the database.
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.sex = PetSex.unknown,
    this.dateOfBirth,
    this.tagCode,
    this.photoPath,
  });

  final String id;
  final String name;
  final Species species;
  final String? breed;
  final PetSex sex;
  final DateTime? dateOfBirth;
  final String? tagCode;
  final String? photoPath;

  factory Pet.fromRow(Map<String, dynamic> row) => Pet(
    id: row['id'] as String,
    name: row['name'] as String,
    species: Species.fromValue(row['species'] as String),
    breed: row['breed'] as String?,
    sex: PetSex.fromValue(row['sex'] as String? ?? 'unknown'),
    dateOfBirth: row['date_of_birth'] == null
        ? null
        : DateTime.parse(row['date_of_birth'] as String),
    tagCode: row['tag_code'] as String?,
    photoPath: row['photo_path'] as String?,
  );
}

/// What the owner types on "Add your first pet".
class PetInput {
  const PetInput({
    required this.name,
    required this.species,
    this.breed,
    this.sex = PetSex.unknown,
    this.dateOfBirth,
  });

  final String name;
  final Species species;
  final String? breed;
  final PetSex sex;
  final DateTime? dateOfBirth;
}

/// Something went wrong that the person can read: shown as is on screen.
class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

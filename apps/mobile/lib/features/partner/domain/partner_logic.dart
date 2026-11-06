import '../../booking/domain/booking_logic.dart' show lagos;
import '../../onboarding/domain/models.dart';
import 'models.dart';

/// A Nigerian bank the applicant can be paid at. The code is the Paystack bank code.
class Bank {
  const Bank(this.code, this.name);
  final String code;
  final String name;
}

const banks = <Bank>[
  Bank('044', 'Access Bank'),
  Bank('023', 'Citibank Nigeria'),
  Bank('050', 'Ecobank Nigeria'),
  Bank('070', 'Fidelity Bank'),
  Bank('011', 'First Bank of Nigeria'),
  Bank('214', 'First City Monument Bank'),
  Bank('058', 'Guaranty Trust Bank'),
  Bank('030', 'Heritage Bank'),
  Bank('082', 'Keystone Bank'),
  Bank('999991', 'PalmPay'),
  Bank('076', 'Polaris Bank'),
  Bank('221', 'Stanbic IBTC Bank'),
  Bank('068', 'Standard Chartered Bank'),
  Bank('232', 'Sterling Bank'),
  Bank('100', 'Suntrust Bank'),
  Bank('032', 'Union Bank of Nigeria'),
  Bank('033', 'United Bank for Africa'),
  Bank('215', 'Unity Bank'),
  Bank('035', 'Wema Bank'),
  Bank('057', 'Zenith Bank'),
  Bank('50515', 'Moniepoint'),
  Bank('999992', 'OPay'),
];

String? validateBusinessName(String raw) {
  final v = raw.trim();
  if (v.length < 2) {
    return 'Enter your business name';
  }
  if (v.length > 60) {
    return 'Keep it under 60 characters';
  }
  return null;
}

String? validateArea(String raw) {
  final v = raw.trim();
  if (v.length < 2) {
    return 'Enter the area your business is in';
  }
  if (v.length > 60) {
    return 'Keep it under 60 characters';
  }
  return null;
}

String? validateAccountNumber(String raw) {
  if (!RegExp(r'^\d{10}$').hasMatch(raw.trim())) {
    return 'An account number has 10 digits';
  }
  return null;
}

String? validateAccountName(String raw) {
  final v = raw.trim();
  if (v.length < 2) {
    return 'Enter the name on the account';
  }
  if (v.length > 80) {
    return 'That name is too long';
  }
  return null;
}

/// The title of a step. The same words as the design.
String stepTitle(StepKey key) => switch (key) {
  StepKey.business => 'Business details',
  StepKey.ownerId => 'Owner ID',
  StepKey.cac => 'CAC registration',
  StepKey.licence => 'Vet practising licence',
  StepKey.facilityPayout => 'Facility photos & payout account',
};

/// The grey line under a step: what is done, or what is needed.
String stepDetail(PartnerApplication app, VerifyStep s) {
  switch (s.key) {
    case StepKey.business:
      return s.done ? '${app.type.shortLabel} · ${app.area}' : 'Name and area';
    case StepKey.ownerId:
      return s.done ? 'NIN slip uploaded' : 'A photo of your NIN slip or ID';
    case StepKey.cac:
      return s.done
          ? 'Certificate uploaded'
          : 'Your CAC registration certificate';
    case StepKey.licence:
      return s.done ? 'Licence uploaded' : 'Required for vet clinics';
    case StepKey.facilityPayout:
      if (s.done) {
        return '${s.photos} photos and ${app.payout?.bankName ?? 'your bank account'}';
      }
      final parts = <String>[
        if (s.photos < 3)
          '${3 - s.photos} more photo${3 - s.photos == 1 ? '' : 's'}',
        if (!s.hasPayout) 'your bank account',
      ];
      return parts.isEmpty
          ? '3 photos and your bank account'
          : parts.join(' and ');
  }
}

/// A short sentence for each state of the application, shown on the status screen.
String statusHeadline(PartnerApplication app) => switch (app.status) {
  PartnerStatus.draft => 'Finish verifying your business',
  PartnerStatus.submitted => 'We are reviewing your application',
  PartnerStatus.needsInfo => 'One thing needed',
  PartnerStatus.approved => 'You are verified',
  PartnerStatus.rejected => 'Your application was not approved',
  PartnerStatus.suspended => 'Your partner account is paused',
};

/// What each tab in the partner bar is called, by partner type.
class PartnerTabs {
  const PartnerTabs(this.second, this.fourth);
  final String second;
  final String fourth;
}

PartnerTabs tabsFor(PartnerType type) => switch (type) {
  PartnerType.vet ||
  PartnerType.service => const PartnerTabs('Calendar', 'Earnings'),
  PartnerType.breeder => const PartnerTabs('Listings', 'Earnings'),
  PartnerType.shelter => const PartnerTabs('Pets', 'Applications'),
};

/// "₦184.5k" for big numbers, whole naira under ten thousand. Kobo in.
String compactNaira(int kobo) {
  final naira = kobo / 100;
  if (naira >= 1000000) {
    return '₦${_trim(naira / 1000000)}m';
  }
  if (naira >= 10000) {
    return '₦${_trim(naira / 1000)}k';
  }
  final digits = naira.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₦$grouped';
}

String _trim(double v) {
  final one = v.toStringAsFixed(1);
  return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
}

/// "2:00" and "4:30" style time with am/pm omitted, as in the schedule design; pass 12 hour.
String visitTime(DateTime t) {
  final l = lagos(t);
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')}';
}

String visitMeridiem(DateTime t) => lagos(t).hour < 12 ? 'am' : 'pm';

/// The state of a payment as a plain label. Never colour alone.
String earningLabel(EarningState s) => switch (s) {
  EarningState.held => 'held until the owner confirms',
  EarningState.ready => 'ready · in the next payout',
  EarningState.paused => 'paused · a problem was reported',
  EarningState.released => 'paid out',
  EarningState.refunded => 'refunded',
  EarningState.sent => 'sent',
  EarningState.other => '',
};

/// Parses a price typed as "450,000" or "450000" into kobo, or null if it is not a number.
int? parsePriceKobo(String raw) {
  final digits = raw.replaceAll(RegExp(r'[,\s₦]'), '');
  if (digits.isEmpty || !RegExp(r'^\d{1,10}$').hasMatch(digits)) {
    return null;
  }
  return int.parse(digits) * 100;
}

String? validateListingName(String raw) {
  final v = raw.trim();
  if (v.isEmpty) {
    return 'Give the pet a name';
  }
  if (v.length > 40) {
    return 'Keep it under 40 characters';
  }
  return null;
}

/// A breeder price has to be at least ₦1,000.
String? validatePrice(String raw) {
  final kobo = parsePriceKobo(raw);
  if (kobo == null) {
    return 'Enter a price in naira';
  }
  if (kobo < 100000) {
    return 'The price must be at least ₦1,000';
  }
  return null;
}

String? validateSupportMessage(String raw) {
  final v = raw.trim();
  if (v.length < 5) {
    return 'Tell us a little more';
  }
  if (v.length > 2000) {
    return 'That is too long. Keep it under 2000 characters';
  }
  return null;
}

/// A first letter for the account circle.
String initialOf(Profile? p) {
  final n = p?.firstName.trim() ?? '';
  return n.isEmpty ? '?' : n[0].toUpperCase();
}

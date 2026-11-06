import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'partner_repository.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) {
    return e;
  }
  if (e is SocketException || e is HttpException) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException) {
    if (e.code == 'P0001' || e.code == '22023') {
      return AppFailure(e.message);
    }
    if (e.code == 'P0002' || e.code == '42501') {
      return const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
  }
  return AppFailure(fallback);
}

int _int(Object? v) => v is num ? v.toInt() : 0;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) Map<String, dynamic>.from(e),
];

/// Reads the jsonb the `partner_application` function returns.
PartnerApplication? parseApplication(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final r = Map<String, dynamic>.from(raw);
  final type = PartnerType.parse(r['type'] as String?);
  if (type == null) {
    return null;
  }
  final payout = r['payout'];
  return PartnerApplication(
    partnerId: r['partner_id'] as String,
    type: type,
    status: PartnerStatus.parse(r['status'] as String?),
    businessName: (r['business_name'] as String?) ?? '',
    area: (r['area'] as String?) ?? '',
    verified: r['verified'] == true,
    submittedAt: _date(r['submitted_at']),
    decisionNote: _str(r['decision_note']),
    steps: [
      for (final s in _list(r['steps']))
        if (StepKey.parse(s['key'] as String?) case final key?)
          VerifyStep(
            key: key,
            done: s['done'] == true,
            photos: _int(s['photos']),
            hasPayout: s['payout'] == true,
          ),
    ],
    payout: payout is Map
        ? PayoutSummary(
            bankName: (payout['bank_name'] as String?) ?? '',
            last4: (payout['last4'] as String?) ?? '',
            accountName: (payout['account_name'] as String?) ?? '',
          )
        : null,
  );
}

PartnerDashboard parseDashboard(Map<String, dynamic> r) {
  final p = _map(r['partner']);
  final s = _map(r['stats']);
  return PartnerDashboard(
    partner: PartnerSummary(
      id: p['id'] as String,
      type: PartnerType.parse(p['type'] as String?) ?? PartnerType.service,
      name: (p['name'] as String?) ?? '',
      area: _str(p['area']),
    ),
    visitsToday: _int(s['visits_today']),
    weekKobo: _int(s['week_kobo']),
    rating: s['rating'] is num ? (s['rating'] as num).toDouble() : null,
    reviewCount: _int(s['review_count']),
    nextPayoutKobo: _int(s['next_payout_kobo']),
    liveListings: _int(s['live_listings']),
    newEnquiries: _int(s['new_enquiries']),
    inEscrowKobo: _int(s['in_escrow_kobo']),
    petsListed: _int(s['pets_listed']),
    newApplications: _int(s['new_applications']),
    adoptedMonth: _int(s['adopted_month']),
    stalePets: _int(s['stale_pets']),
    schedule: [
      for (final v in _list(r['schedule']))
        VisitItem(
          bookingId: v['booking_id'] as String,
          startsAt: _date(v['starts_at']) ?? DateTime.now(),
          service: (v['service'] as String?) ?? '',
          petName: (v['pet_name'] as String?) ?? '',
          petId: (v['pet_id'] as String?) ?? '',
          breed: _str(v['breed']),
          ownerName: (v['owner_name'] as String?) ?? 'Owner',
          status: (v['status'] as String?) ?? '',
          passportShared: v['passport_shared'] == true,
        ),
    ],
    listings: [
      for (final l in _list(r['listings']))
        PartnerListing(
          listingId: l['listing_id'] as String,
          petId: l['pet_id'] as String,
          petName: (l['pet_name'] as String?) ?? '',
          photoPath: _str(l['photo_path']),
          status: (l['status'] as String?) ?? 'live',
          sale: l['kind'] == 'sale',
          priceKobo: l['price_kobo'] is num ? _int(l['price_kobo']) : null,
          handoverBy: _date(l['handover_by']),
          enquiries: _int(l['enquiries']),
          applications: _int(l['applications']),
          orderId: _str(l['order_id']),
          orderStatus: _str(l['order_status']),
          buyerName: _str(l['buyer_name']),
        ),
    ],
    enquiries: [
      for (final e in _list(r['enquiries']))
        Enquiry(
          conversationId: e['conversation_id'] as String,
          listingId: e['listing_id'] as String,
          petName: (e['pet_name'] as String?) ?? '',
          otherName: (e['other_name'] as String?) ?? 'Someone',
          lastBody: _str(e['last_body']),
          lastAt: _date(e['last_at']),
          unread: _int(e['unread']),
        ),
    ],
    applications: [
      for (final a in _list(r['applications']))
        ShelterApplication(
          id: a['application_id'] as String,
          listingId: a['listing_id'] as String,
          petName: (a['pet_name'] as String?) ?? '',
          photoPath: _str(a['photo_path']),
          applicantName: (a['applicant_name'] as String?) ?? 'Someone',
          state: ApplicationState.parse(a['status'] as String?),
          createdAt: _date(a['created_at']) ?? DateTime.now(),
          homeType: _str(a['home_type']),
          otherPets: _str(a['other_pets']),
          daytime: _str(a['daytime']),
          why: _str(a['why']),
          petsTotal: _int(a['pets_total']),
          petsVaccinated: _int(a['pets_vaccinated']),
          transferId: _str(a['transfer_id']),
        ),
    ],
  );
}

Earnings parseEarnings(Map<String, dynamic> r) => Earnings(
  nextPayoutOn:
      DateTime.tryParse(r['next_payout_on'] as String? ?? '') ?? DateTime.now(),
  nextPayoutKobo: _int(r['next_payout_kobo']),
  heldKobo: _int(r['held_kobo']),
  paidMonthKobo: _int(r['paid_month_kobo']),
  bankName: _str(r['bank_name']),
  accountLast4: _str(r['account_last4']),
  recent: [
    for (final e in _list(r['recent']))
      EarningItem(
        title: (e['title'] as String?) ?? '',
        state: switch (e['state']) {
          'held' => EarningState.held,
          'ready' => EarningState.ready,
          'paused' => EarningState.paused,
          'released' => EarningState.released,
          'refunded' || 'partially_refunded' => EarningState.refunded,
          'sent' => EarningState.sent,
          _ => EarningState.other,
        },
        amountKobo: _int(e['amount_kobo']),
        at: _date(e['at']) ?? DateTime.now(),
        payout: e['source'] == 'payout',
      ),
  ],
);

class SupabasePartnerRepository implements PartnerRepository {
  SupabasePartnerRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<Map<String, dynamic>> _json(
    String fn, [
    Map<String, dynamic>? params,
  ]) async =>
      Map<String, dynamic>.from(await _client.rpc(fn, params: params) as Map);

  @override
  Future<PartnerApplication?> application() async {
    try {
      return parseApplication(await _client.rpc('partner_application'));
    } catch (e) {
      throw _failure(e, 'We could not load your application. Try again.');
    }
  }

  @override
  Future<String> start({
    required PartnerType type,
    required String businessName,
    required String area,
  }) async {
    try {
      return await _client.rpc(
        'partner_start',
        params: {'p_type': type.value, 'p_name': businessName, 'p_area': area},
      ) as String;
    } catch (e) {
      throw _failure(e, 'We could not save that. Try again.');
    }
  }

  @override
  Future<void> addDocument(
    String partnerId,
    DocumentKind kind,
    PickedPhoto photo,
  ) async {
    final path =
        '$_uid/${kind.value}-${DateTime.now().microsecondsSinceEpoch}.${photo.extension}';
    try {
      await _client.storage
          .from('partner-documents')
          .uploadBinary(
            path,
            photo.bytes,
            fileOptions: FileOptions(contentType: photo.contentType),
          );
      await _client.rpc(
        'partner_add_document',
        params: {'p_partner': partnerId, 'p_kind': kind.value, 'p_path': path},
      );
    } catch (e) {
      throw _failure(e, 'We could not upload that. Try again.');
    }
  }

  @override
  Future<void> savePayout(
    String partnerId, {
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      await _client.rpc(
        'partner_save_payout_account',
        params: {
          'p_partner': partnerId,
          'p_bank_code': bankCode,
          'p_bank_name': bankName,
          'p_account_number': accountNumber,
          'p_account_name': accountName,
        },
      );
    } catch (e) {
      throw _failure(e, 'We could not save your account. Try again.');
    }
  }

  @override
  Future<void> submit(String partnerId) async {
    try {
      await _client.rpc(
        'submit_partner_for_review',
        params: {'p_partner': partnerId},
      );
    } catch (e) {
      throw _failure(e, 'We could not submit your application. Try again.');
    }
  }

  @override
  Future<PartnerDashboard> dashboard(String partnerId) async {
    try {
      return parseDashboard(
        await _json('partner_dashboard', {'p_partner': partnerId}),
      );
    } catch (e) {
      throw _failure(
        e,
        'We could not load your dashboard. Pull down to try again.',
      );
    }
  }

  @override
  Future<PartnerCalendar> calendar(
    String partnerId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final r = await _json('partner_calendar', {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_partner': partnerId,
      });
      return PartnerCalendar(
        visits: [
          for (final v in _list(r['visits']))
            VisitItem(
              bookingId: v['booking_id'] as String,
              startsAt: _date(v['starts_at']) ?? DateTime.now(),
              service: (v['service'] as String?) ?? '',
              petName: (v['pet_name'] as String?) ?? '',
              petId: (v['pet_id'] as String?) ?? '',
              breed: _str(v['breed']),
              ownerName: (v['owner_name'] as String?) ?? 'Owner',
              status: (v['status'] as String?) ?? '',
              passportShared: v['passport_shared'] == true,
            ),
        ],
        open: [
          for (final s in _list(r['open']))
            OpenSlot(
              slotId: s['slot_id'] as String,
              startsAt: _date(s['starts_at']) ?? DateTime.now(),
              endsAt: _date(s['ends_at']) ?? DateTime.now(),
            ),
        ],
      );
    } catch (e) {
      throw _failure(e, 'We could not load your calendar. Pull down to try again.');
    }
  }

  @override
  Future<int> blockTimes(String partnerId, DateTime from, DateTime to) async {
    try {
      final n = await _client.rpc(
        'partner_block_slots',
        params: {
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
          'p_partner': partnerId,
        },
      );
      return n is num ? n.toInt() : 0;
    } catch (e) {
      throw _failure(e, 'We could not block that time. Please try again.');
    }
  }

  @override
  Future<Earnings> earnings(String partnerId) async {
    try {
      return parseEarnings(
        await _json('partner_earnings', {'p_partner': partnerId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not load your earnings. Try again.');
    }
  }

  @override
  Future<List<CreatedListing>> createListings(
    String partnerId,
    NewListing l, {
    PickedPhoto? photo,
  }) async {
    final List<CreatedListing> created;
    try {
      final res = await _client.rpc(
        'partner_create_listings',
        params: {
          'p_partner': partnerId,
          'p_input': {
            'name': l.name.trim(),
            'species': l.species.value,
            'breed': ?l.breed,
            'sex': l.sex.value,
            if (l.bornOn != null)
              'born_on':
                  '${l.bornOn!.year.toString().padLeft(4, '0')}-${l.bornOn!.month.toString().padLeft(2, '0')}-${l.bornOn!.day.toString().padLeft(2, '0')}',
            if (l.priceKobo != null) 'price_kobo': l.priceKobo.toString(),
            'count': l.count.toString(),
            'mother_pet_id': ?l.motherPetId,
            'father_pet_id': ?l.fatherPetId,
            if (l.handoverBy != null)
              'handover_by': l.handoverBy!.toUtc().toIso8601String(),
          },
        },
      );
      created = [
        for (final e in _list(res))
          CreatedListing(
            listingId: e['listing_id'] as String,
            petId: e['pet_id'] as String,
          ),
      ];
    } catch (e) {
      throw _failure(e, 'We could not publish the listing. Nothing was saved.');
    }
    if (photo != null) {
      // Best effort: the listing is live either way, and the photo can be added from the passport.
      for (final c in created) {
        try {
          final path = '$_uid/${c.petId}/photo.${photo.extension}';
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
              .eq('id', c.petId);
        } catch (_) {}
      }
    }
    return created;
  }

  @override
  Future<void> setListingLive(String listingId, {required bool live}) async {
    try {
      await _client.rpc(
        'partner_set_listing_status',
        params: {'p_listing': listingId, 'p_status': live ? 'live' : 'removed'},
      );
    } catch (e) {
      throw _failure(e, 'We could not update that listing. Try again.');
    }
  }

  @override
  Future<void> decide(
    String applicationId,
    ApplicationDecision decision,
  ) async {
    try {
      await _client.rpc(
        'decide_application',
        params: {'p_application': applicationId, 'p_decision': decision.value},
      );
    } catch (e) {
      throw _failure(e, 'We could not save that decision. Try again.');
    }
  }

  @override
  Future<String> openApplicationChat(String applicationId) async {
    try {
      return await _client.rpc(
        'open_application_chat',
        params: {'p_application': applicationId},
      ) as String;
    } catch (e) {
      throw _failure(e, 'We could not open the chat. Try again.');
    }
  }

  @override
  Future<String> completeAdoption(String applicationId) async {
    try {
      return await _client.rpc(
        'shelter_complete_adoption',
        params: {'p_application': applicationId},
      ) as String;
    } catch (e) {
      throw _failure(e, 'We could not confirm the handover. Try again.');
    }
  }

  @override
  Future<void> confirmHandover(String orderId) async {
    try {
      await _client.rpc(
        'partner_confirm_handover',
        params: {'p_order': orderId},
      );
    } catch (e) {
      throw _failure(e, 'We could not confirm the handover. Try again.');
    }
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    try {
      await _client.rpc(
        'partner_cancel_order',
        params: {'p_order': orderId, 'p_reason': reason},
      );
    } catch (e) {
      throw _failure(e, 'We could not cancel the order. Try again.');
    }
  }

  @override
  Future<List<SupportTicket>> tickets() async {
    try {
      final res = await _client.rpc('my_support_tickets') as List;
      return [
        for (final r in res)
          if (r is Map)
            SupportTicket(
              id: r['ticket_id'] as String,
              number: _int(r['number']),
              topic: (r['topic'] as String?) ?? 'other',
              subject: (r['subject'] as String?) ?? '',
              state: switch (r['status']) {
                'waiting_user' => TicketState.replied,
                'closed' => TicketState.closed,
                _ => TicketState.open,
              },
              createdAt: _date(r['created_at']) ?? DateTime.now(),
            ),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load your requests. Try again.');
    }
  }

  @override
  Future<void> createTicket(SupportTopic topic, String message) async {
    try {
      await _client.rpc(
        'create_support_ticket',
        params: {'p_topic': topic.value, 'p_message': message.trim()},
      );
    } catch (e) {
      throw _failure(e, 'We could not send that. Try again.');
    }
  }
}

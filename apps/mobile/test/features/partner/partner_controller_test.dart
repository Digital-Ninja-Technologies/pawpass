import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/partner/data/partner_repository.dart';
import 'package:pawpass/features/partner/domain/models.dart';
import 'package:pawpass/features/partner/domain/partner_logic.dart';
import 'package:pawpass/features/partner/state/partner_controller.dart';

final _today = DateTime.utc(2026, 11, 5, 8);
final _photo = PickedPhoto(Uint8List.fromList([1, 2, 3]));

class _Rig {
  _Rig() {
    services = inMemoryServices(
      now: () => _today,
      signedInAs: 'tolu@example.com',
    );
    repo = services.partner as InMemoryPartnerRepository;
    session = SessionController(services);
    c = PartnerController(services, session);
  }

  late final AppServices services;
  late final InMemoryPartnerRepository repo;
  late final SessionController session;
  late final PartnerController c;

  /// Every step done for a breeder (no licence), ready to submit.
  Future<void> fillBreeder() async {
    expect(
      await c.saveBusiness(
        type: PartnerType.breeder,
        name: 'Tolu Kennels',
        area: 'Lekki',
      ),
      isTrue,
    );
    expect(await c.addDocument(DocumentKind.ownerId, _photo), isTrue);
    expect(await c.addDocument(DocumentKind.cac, _photo), isTrue);
    for (var i = 0; i < 3; i++) {
      expect(await c.addDocument(DocumentKind.facilityPhoto, _photo), isTrue);
    }
    expect(
      await c.savePayout(
        bank: banks.first,
        accountNumber: '0123456789',
        accountName: 'Tolu Adeyemi',
      ),
      isTrue,
    );
  }
}

void main() {
  group('applying', () {
    test('there is no application until one is started', () async {
      final r = _Rig();
      await r.c.loadApplication();
      expect(r.c.application, isNull);
      expect(r.c.applicationLoaded, isTrue);
      expect(r.c.isApprovedPartner, isFalse);
    });

    test('the business details start a draft with one step done', () async {
      final r = _Rig();
      await r.c.saveBusiness(
        type: PartnerType.vet,
        name: 'Paws',
        area: 'Lekki',
      );
      final a = r.c.application!;
      expect(a.status, PartnerStatus.draft);
      expect(a.stepsTotal, 5, reason: 'a vet also needs a licence');
      expect(a.stepsDone, 1);
      expect(a.canSubmit, isFalse);
    });

    test('a bad name or area is explained and nothing is saved', () async {
      final r = _Rig();
      expect(
        await r.c.saveBusiness(type: PartnerType.vet, name: 'P', area: 'Lekki'),
        isFalse,
      );
      expect(r.c.saveError, 'Enter your business name');
      expect(r.repo.calls, isEmpty);
      expect(
        await r.c.saveBusiness(type: PartnerType.vet, name: 'Paws', area: ''),
        isFalse,
      );
      expect(r.c.saveError, 'Enter the area your business is in');
    });

    test('a licence is only for vets', () async {
      final r = _Rig();
      await r.c.saveBusiness(
        type: PartnerType.breeder,
        name: 'Tolu Kennels',
        area: 'Lekki',
      );
      expect(await r.c.addDocument(DocumentKind.licence, _photo), isFalse);
      expect(r.c.saveError, contains('only needed for vet clinics'));
      expect(r.c.application!.stepsTotal, 4);
    });

    test('the payout account must have ten digits', () async {
      final r = _Rig();
      await r.c.saveBusiness(
        type: PartnerType.breeder,
        name: 'Tolu Kennels',
        area: 'Lekki',
      );
      expect(
        await r.c.savePayout(
          bank: banks.first,
          accountNumber: '123',
          accountName: 'Tolu',
        ),
        isFalse,
      );
      expect(r.c.saveError, 'An account number has 10 digits');
      expect(r.c.application!.payout, isNull);
    });

    test(
      'three facility photos and a payout account finish the last step',
      () async {
        final r = _Rig();
        await r.fillBreeder();
        final a = r.c.application!;
        expect(a.step(StepKey.facilityPayout)!.done, isTrue);
        expect(a.payout!.last4, '6789');
        expect(a.canSubmit, isTrue);
      },
    );

    test('an unfinished application cannot be submitted', () async {
      final r = _Rig();
      await r.c.saveBusiness(
        type: PartnerType.breeder,
        name: 'Tolu Kennels',
        area: 'Lekki',
      );
      expect(await r.c.submit(), isFalse);
      expect(r.c.saveError, 'Finish every step before you submit');
      expect(r.c.application!.status, PartnerStatus.draft);
    });

    test('submitting locks it until the team decides', () async {
      final r = _Rig();
      await r.fillBreeder();
      expect(await r.c.submit(), isTrue);
      expect(r.c.application!.status, PartnerStatus.submitted);
      expect(await r.c.addDocument(DocumentKind.cac, _photo), isFalse);
      expect(
        await r.c.saveBusiness(
          type: PartnerType.breeder,
          name: 'Other',
          area: 'Yaba',
        ),
        isFalse,
      );
      expect(r.c.saveError, 'Your application is already being reviewed');
    });

    test(
      'more info needed: the note shows, the partner fixes it and resubmits',
      () async {
        final r = _Rig();
        await r.fillBreeder();
        await r.c.submit();
        r.repo.review(
          PartnerStatus.needsInfo,
          note: 'Your CAC photo is blurry',
        );
        await r.c.loadApplication();
        expect(r.c.application!.decisionNote, 'Your CAC photo is blurry');
        expect(r.c.application!.canSubmit, isTrue);
        expect(await r.c.addDocument(DocumentKind.cac, _photo), isTrue);
        expect(await r.c.submit(), isTrue);
        expect(r.c.application!.status, PartnerStatus.submitted);
      },
    );

    test('a rejected application can start again', () async {
      final r = _Rig();
      await r.fillBreeder();
      await r.c.submit();
      r.repo.review(
        PartnerStatus.rejected,
        note: 'We could not verify the business',
      );
      await r.c.loadApplication();
      expect(r.c.application!.status, PartnerStatus.rejected);
      expect(
        await r.c.saveBusiness(
          type: PartnerType.shelter,
          name: 'Rescue',
          area: 'Yaba',
        ),
        isTrue,
      );
      expect(r.c.application!.status, PartnerStatus.draft);
      expect(r.c.application!.type, PartnerType.shelter);
      expect(
        r.c.application!.stepsDone,
        1,
        reason: 'a new application starts clean',
      );
    });

    test('an approved partner cannot start another', () async {
      final r = _Rig();
      r.repo.approveAs(PartnerType.vet, 'Paws & Claws');
      await r.c.loadApplication();
      expect(r.c.isApprovedPartner, isTrue);
      expect(
        await r.c.saveBusiness(
          type: PartnerType.breeder,
          name: 'More',
          area: 'Yaba',
        ),
        isFalse,
      );
      expect(r.c.saveError, 'You already have a partner account');
    });
  });

  group('dashboards', () {
    test('a vet sees today, the week and the rating', () async {
      final r = _Rig();
      r.repo
        ..approveAs(PartnerType.vet, 'Paws & Claws')
        ..rating = 4.8
        ..weekKobo = 18450000
        ..visits = [
          VisitItem(
            bookingId: 'b1',
            startsAt: _today,
            service: 'Consultation',
            petName: 'Rex',
            petId: 'p',
            ownerName: 'Chidi',
            status: 'completed',
            passportShared: false,
          ),
        ];
      await r.c.refresh();
      expect(r.c.dashboard!.visitsToday, 1);
      expect(r.c.dashboard!.weekKobo, 18450000);
      expect(r.c.dashboard!.rating, 4.8);
      expect(r.c.dashboard!.schedule.single.done, isTrue);
    });

    test('a pending partner cannot open a dashboard', () async {
      final r = _Rig();
      await r.fillBreeder();
      await r.c.refresh();
      expect(r.c.dashboard, isNull);
      await r.c.loadDashboard();
      expect(r.c.dashboardError, 'Your partner account is not approved yet');
    });

    test('a breeder publishes a puppy and a litter', () async {
      final r = _Rig();
      r.repo.approveAs(PartnerType.breeder, 'Royal Paws');
      await r.c.refresh();
      expect(
        await r.c.publish(
          const NewListing(
            name: 'Duke',
            species: Species.dog,
            priceKobo: 45000000,
          ),
        ),
        isTrue,
      );
      expect(
        await r.c.publish(
          const NewListing(
            name: 'Bella',
            species: Species.dog,
            priceKobo: 30000000,
            count: 3,
          ),
        ),
        isTrue,
      );
      expect(r.c.dashboard!.listings.map((l) => l.petName), [
        'Bella 1',
        'Bella 2',
        'Bella 3',
        'Duke',
      ]);
      expect(r.c.dashboard!.liveListings, 4);
    });

    test('a puppy needs a price; a shelter listing is free', () async {
      final r = _Rig();
      r.repo.approveAs(PartnerType.breeder, 'Royal Paws');
      await r.c.refresh();
      expect(
        await r.c.publish(
          const NewListing(name: 'Duke', species: Species.dog, priceKobo: 500),
        ),
        isFalse,
      );
      expect(r.c.publishError, contains('at least 1,000 naira'));

      final s = _Rig();
      s.repo.approveAs(PartnerType.shelter, 'Lagos Paws Rescue');
      await s.c.refresh();
      expect(
        await s.c.publish(const NewListing(name: 'Kofi', species: Species.dog)),
        isTrue,
      );
      expect(s.c.dashboard!.listings.single.priceKobo, isNull);
      expect(s.c.dashboard!.listings.single.sale, isFalse);
    });

    test(
      'taking a listing down removes it, and a reserved one cannot be touched',
      () async {
        final r = _Rig();
        r.repo.approveAs(PartnerType.breeder, 'Royal Paws');
        r.repo.listings = [
          const PartnerListing(
            listingId: 'a',
            petId: 'pa',
            petName: 'Duke',
            status: 'live',
            sale: true,
            priceKobo: 45000000,
          ),
          const PartnerListing(
            listingId: 'b',
            petId: 'pb',
            petName: 'Nala',
            status: 'reserved',
            sale: true,
            priceKobo: 38000000,
            orderId: 'o1',
          ),
        ];
        await r.c.refresh();
        expect(await r.c.setListingLive('a', live: false), isTrue);
        expect(r.c.dashboard!.listings.map((l) => l.petName), ['Nala']);
        expect(await r.c.setListingLive('b', live: false), isFalse);
        expect(r.c.actionError, contains('middle of a sale'));
      },
    );

    test(
      'a shelter decides applications and hands over an approved pet',
      () async {
        final r = _Rig();
        r.repo.approveAs(PartnerType.shelter, 'Lagos Paws Rescue');
        r.repo.applications = [
          ShelterApplication(
            id: 'a1',
            listingId: 'l1',
            petName: 'Ada',
            applicantName: 'Tolu',
            state: ApplicationState.submitted,
            createdAt: _today,
            petsTotal: 2,
            petsVaccinated: 2,
          ),
          ShelterApplication(
            id: 'a2',
            listingId: 'l2',
            petName: 'Kofi',
            applicantName: 'Seun',
            state: ApplicationState.submitted,
            createdAt: _today,
          ),
        ];
        await r.c.refresh();
        expect(r.c.dashboard!.newApplications, 2);
        expect(r.c.dashboard!.applications.first.petsVaccinatedAll, isTrue);
        expect(r.c.dashboard!.applications.last.petsVaccinatedAll, isFalse);

        expect(await r.c.decide('a1', ApplicationDecision.homeVisit), isTrue);
        expect(
          r.c.dashboard!.applications.first.state,
          ApplicationState.homeVisit,
        );
        expect(
          await r.c.completeAdoption('a1'),
          isNull,
          reason: 'approve first',
        );
        expect(r.c.actionError, 'Approve the application before handing over');
        expect(await r.c.decide('a1', ApplicationDecision.approve), isTrue);
        expect(await r.c.decide('a1', ApplicationDecision.decline), isFalse);
        expect(r.c.actionError, 'This application has already been decided');
        expect(await r.c.completeAdoption('a1'), isNotNull);
        expect(await r.c.decide('a2', ApplicationDecision.decline), isTrue);
        expect(r.c.dashboard!.applications, isEmpty);
      },
    );

    test('the chat with an applicant', () async {
      final r = _Rig();
      r.repo.approveAs(PartnerType.shelter, 'Lagos Paws Rescue');
      expect(await r.c.chatWith('a1'), 'conv-a1');
    });
  });

  group('support', () {
    test('a ticket needs a real message and is listed once sent', () async {
      final r = _Rig();
      expect(await r.c.sendTicket(SupportTopic.payments, 'hi'), isFalse);
      expect(r.c.ticketError, 'Tell us a little more');
      expect(
        await r.c.sendTicket(
          SupportTopic.payments,
          'My refund has not arrived',
        ),
        isTrue,
      );
      expect(r.c.tickets.single.state, TicketState.open);
      expect(r.c.tickets.single.label, '#S-2201');
    });

    test('too many requests are slowed down', () async {
      final r = _Rig();
      for (var i = 0; i < 5; i++) {
        expect(
          await r.c.sendTicket(SupportTopic.other, 'Request number $i'),
          isTrue,
        );
      }
      expect(
        await r.c.sendTicket(SupportTopic.other, 'One more request'),
        isFalse,
      );
      expect(r.c.ticketError, contains('a few requests already'));
    });
  });

  group('the seller on an order', () {
    test('confirming and cancelling are passed on', () async {
      final r = _Rig();
      await r.c.confirmHandover('o1');
      await r.c.cancelOrder('o2');
      expect(r.repo.calls, containsAll(['confirm:o1', 'cancel:o2']));
    });
  });

  group('modes and sign out', () {
    test('the mode switches and is forgotten on sign out', () async {
      final r = _Rig();
      r.repo.approveAs(PartnerType.vet, 'Paws & Claws');
      await r.c.refresh();
      r.c.enterPartnerMode();
      expect(r.c.inPartnerMode, isTrue);
      r.c.leavePartnerMode();
      expect(r.c.inPartnerMode, isFalse);
      r.c.enterPartnerMode();
      r.c.reset();
      expect(r.c.inPartnerMode, isFalse);
      expect(r.c.application, isNull);
      expect(r.c.dashboard, isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

/// Add a record (design/screens/AddRecord.dc.html).
class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _givenBy = TextEditingController();
  var _type = RecordType.vaccine;
  DateTime? _given;
  DateTime? _next;

  /// Once the person picks or clears the next due date themselves, we stop filling it in.
  var _nextTouched = false;
  PickedPhoto? _photo;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _givenBy.dispose();
    super.dispose();
  }

  DateTime _today(BuildContext c) => AppScope.of(c).health.today;

  /// Recomputes the suggested next due date unless the person set it.
  void _refreshNext(BuildContext context) {
    if (_nextTouched) return;
    final given = _given ?? _today(context);
    _next = _type == RecordType.weight || _type == RecordType.allergy
        ? null
        : suggestedNextDue(_type, _name.text, given);
  }

  bool get _hasNext =>
      _type != RecordType.weight && _type != RecordType.allergy;

  String get _nameLabel => switch (_type) {
    RecordType.vaccine => 'Vaccine',
    RecordType.deworming => 'Product',
    RecordType.treatment => 'Treatment',
    RecordType.vetVisit => 'Reason for the visit',
    RecordType.weight => 'Weight (kg)',
    RecordType.allergy => 'Allergy',
  };

  Future<void> _pickGiven() async {
    final scope = AppScope.of(context);
    final today = _today(context);
    final pet = scope.health.selected;
    final d = await pickDate(
      context,
      first: pet?.dateOfBirth ?? DateTime(today.year - 30),
      last: today,
      initial: _given ?? today,
      help: 'Date given',
    );
    if (d != null) {
      setState(() {
        _given = d;
        _problem = null;
        _refreshNext(context);
      });
    }
  }

  Future<void> _pickNext() async {
    final today = _today(context);
    final given = _given ?? today;
    final d = await pickDate(
      context,
      first: given.add(const Duration(days: 1)),
      last: DateTime(today.year + 10),
      initial: _next ?? given.add(const Duration(days: 30)),
      help: 'Next due',
    );
    if (d != null) {
      setState(() {
        _next = d;
        _nextTouched = true;
        _problem = null;
      });
    }
  }

  Future<void> _attach() async {
    final scope = AppScope.of(context);
    try {
      final result = await choosePhoto(
        context,
        fromCamera: scope.services.photos.fromCamera,
        fromGallery: scope.services.photos.fromGallery,
        hasPhoto: _photo != null,
      );
      if (result == null) return;
      setState(() => _photo = result.removed ? null : (result.photo ?? _photo));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _save() async {
    final h = AppScope.of(context).health;
    final pet = h.selected;
    if (pet == null) return;
    final given = _given ?? _today(context);
    final isWeight = _type == RecordType.weight;
    final problem = recordProblem(
      type: _type,
      name: _name.text,
      givenOn: given,
      nextDueOn: _hasNext ? _next : null,
      today: _today(context),
      petBirthDate: pet.dateOfBirth,
      weightText: _weight.text,
    );
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() => _problem = null);
    final ok = await h.addRecord(
      type: _type,
      name: isWeight ? 'Weight' : _name.text,
      givenOn: given,
      nextDueOn: _hasNext ? _next : null,
      value: isWeight ? kgText(parseWeightKg(_weight.text)!) : null,
      givenByName: _givenBy.text,
      attachment: _photo,
    );
    if (!mounted) return;
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      final nextText = _hasNext && _next != null
          ? ' Next due ${formatDate(_next!)}.'
          : '';
      context.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Record saved.$nextText')));
    } else {
      setState(() => _problem = h.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final h = scope.health;
    final pet = h.selected;
    final today = _today(context);
    final given = _given ?? today;
    _refreshNextOnce(context);
    final suggestions = nameSuggestions(_type, pet?.species ?? Species.dog);
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) => Scaffold(
        backgroundColor: PawColors.ground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    12,
                    PawSpace.screenSide,
                    24,
                  ),
                  children: [
                    Row(
                      children: [
                        RoundIconButton(
                          icon: PawIconData.close,
                          semanticLabel: 'Close',
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              pet == null
                                  ? 'Add a record'
                                  : 'Add a record for ${pet.name}',
                              style: PawText.heading22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      container: true,
                      label: 'Type',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type',
                            style: PawText.meta13.copyWith(
                              color: PawColors.ink2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in RecordType.values)
                                PawChip(
                                  label: t.label,
                                  selected: _type == t,
                                  onTap: () => setState(() {
                                    _type = t;
                                    _problem = null;
                                    _name.clear();
                                    _nextTouched = false;
                                    _refreshNext(context);
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_type == RecordType.weight)
                      PawTextField(
                        label: _nameLabel,
                        controller: _weight,
                        hint: 'For example 41',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() => _problem = null),
                      )
                    else ...[
                      PawTextField(
                        label: _nameLabel,
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 60,
                        onChanged: (_) => setState(() {
                          _problem = null;
                          _refreshNext(context);
                        }),
                      ),
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in suggestions)
                              PawChip(
                                label: s,
                                selected: _name.text.trim() == s,
                                onTap: () => setState(() {
                                  _name.text = s;
                                  _problem = null;
                                  _refreshNext(context);
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PickerField(
                            label: 'Date given',
                            value: formatDate(given),
                            onTap: _pickGiven,
                          ),
                        ),
                        if (_hasNext) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: PickerField(
                              label: 'Next due',
                              value: _next == null ? null : formatDate(_next!),
                              hint: 'None',
                              onTap: _pickNext,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_hasNext) ...[
                      const SizedBox(height: 8),
                      Text(
                        _next == null
                            ? 'No reminder will be set. Pick a date if you want one.'
                            : (_nextTouched
                                  ? 'You set this date. We will remind you before it.'
                                  : 'Next due is set automatically. You can change it.'),
                        style: PawText.meta12.copyWith(color: PawColors.muted),
                      ),
                      if (_next != null)
                        TextLinkButton(
                          label: 'Remove next due date',
                          color: PawColors.muted,
                          onPressed: () => setState(() {
                            _next = null;
                            _nextTouched = true;
                          }),
                        ),
                    ],
                    const SizedBox(height: 16),
                    PawTextField(
                      label: 'Given by (optional)',
                      controller: _givenBy,
                      hint: 'Clinic or vet',
                      textCapitalization: TextCapitalization.words,
                      maxLength: 80,
                      helperText: 'A vet can mark it as verified when you share your passport with them.',
                    ),
                    const SizedBox(height: 16),
                    _AttachButton(photo: _photo, onTap: _attach),
                  ],
                ),
              ),
              // Pinned above the button so it is never hidden below the form.
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    0,
                    PawSpace.screenSide,
                    12,
                  ),
                  child: ErrorNote(_problem!),
                ),
              PawStickyFooter(
                children: [
                  PawButton(
                    label: 'Save record',
                    loading: h.busy,
                    onPressed: pet == null ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  var _seeded = false;

  /// Fills in the first suggested next due date once the context is available.
  void _refreshNextOnce(BuildContext context) {
    if (_seeded) return;
    _seeded = true;
    _refreshNext(context);
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.photo, required this.onTap});
  final PickedPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: photo == null ? 'Attach a photo' : 'Change the attached photo',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: photo == null ? 52 : 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PawRadius.input),
            border: Border.all(color: PawColors.outline, width: 1.5),
          ),
          child: photo == null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PawIcon(
                      PawIconData.paperclip,
                      size: 20,
                      color: PawColors.ink2,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Attach a photo',
                      style: PawText.body14Strong.copyWith(
                        color: PawColors.ink2,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        photo!.bytes,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Photo attached. Tap to change.',
                        style: PawText.body14Strong,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

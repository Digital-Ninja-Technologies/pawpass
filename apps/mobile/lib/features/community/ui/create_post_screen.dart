import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';

/// New post (design/screens/CreatePost.dc.html): pick a pet, add photos, write a caption, choose who sees it.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _photos = <PickedPhoto>[];
  String? _petId;
  var _petChosen = false;
  var _visibility = PostVisibility.everyone;
  var _showArea = true;
  String? _photoError;

  static const maxPhotos = 4;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = await AppScope.of(context).services.photos.fromGallery();
    if (photo == null || !mounted) {
      return;
    }
    if (photo.bytes.length > 8 * 1024 * 1024) {
      setState(
        () => _photoError = 'That photo is too large. Choose one under 8 MB.',
      );
      return;
    }
    setState(() {
      _photoError = null;
      _photos.add(photo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.community;
    final pets = scope.health.pets;
    if (!_petChosen) {
      _petChosen = true;
      _petId = scope.health.selected?.id;
    }
    final area = scope.session.profile?.area;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final hasContent =
            _caption.text.trim().isNotEmpty || _photos.isNotEmpty;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    8,
                    PawSpace.screenSide,
                    0,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(PawSize.touch, PawSize.touch),
                        ),
                        child: Text(
                          'Cancel',
                          style: PawText.body15Strong.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'New post',
                            textAlign: TextAlign.center,
                            style: PawText.heading22,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: PawButton(
                          label: 'Post',
                          height: 40,
                          loading: c.posting,
                          onPressed: hasContent && !c.posting ? _submit : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      16,
                      PawSpace.screenSide,
                      24,
                    ),
                    children: [
                      if (pets.isNotEmpty) ...[
                        const SectionLabel('Posting as'),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final p in pets) ...[
                                PawChip(
                                  label: p.name,
                                  selected: _petId == p.id,
                                  onTap: () => setState(() => _petId = p.id),
                                ),
                                const SizedBox(width: 8),
                              ],
                              PawChip(
                                label: 'Me',
                                selected: _petId == null,
                                onTap: () => setState(() {
                                  _petId = null;
                                  if (_visibility == PostVisibility.followers) {
                                    _visibility = PostVisibility.everyone;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < _photos.length; i++)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _photos[i].bytes,
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    semanticLabel: 'Photo ${i + 1}',
                                    errorBuilder: (_, _, _) => Container(
                                      width: 84,
                                      height: 84,
                                      color: PawColors.subtle,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: RoundIconButton(
                                    icon: PawIconData.close,
                                    semanticLabel: 'Remove photo ${i + 1}',
                                    onPressed: () =>
                                        setState(() => _photos.removeAt(i)),
                                  ),
                                ),
                              ],
                            ),
                          if (_photos.length < maxPhotos)
                            Semantics(
                              button: true,
                              label: 'Add photo',
                              excludeSemantics: true,
                              onTap: _addPhoto,
                              child: GestureDetector(
                                key: const Key('add-photo'),
                                onTap: _addPhoto,
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: PawColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: PawColors.outline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      PawIcon(
                                        PawIconData.camera,
                                        color: PawColors.muted,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add photo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: PawColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_photoError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _photoError!,
                          style: PawText.meta13.copyWith(
                            color: PawColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PawNoteField(
                        label: 'Caption',
                        controller: _caption,
                        maxLength: 500,
                        hint: 'What is your pet up to?',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Who can see this'),
                      const SizedBox(height: 10),
                      PawSegmented<PostVisibility>(
                        segments: [
                          for (final v in PostVisibility.values)
                            PawSegment(v, v.label),
                        ],
                        value: _visibility,
                        onChanged: (v) => setState(() => _visibility = v),
                      ),
                      const SizedBox(height: 14),
                      PawToggleRow(
                        label: area == null || area.isEmpty
                            ? 'Show area on post'
                            : 'Show area ($area) on post',
                        value: _showArea,
                        onChanged: (v) => setState(() => _showArea = v),
                      ),
                      if (c.postError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.postError!,
                            style: PawText.body14.copyWith(
                              color: PawColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final c = AppScope.of(context).community;
    final ok = await c.createPost(
      petId: _petId,
      body: _caption.text,
      visibility: _visibility,
      showArea: _showArea,
      photos: _photos,
    );
    if (ok && mounted) {
      context.pop();
    }
  }
}

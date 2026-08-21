import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/feedback_service.dart';
import '../theme/tokens.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.platform = const FeedbackPlatform()});

  final FeedbackPlatform platform;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _maxImages = 3;
  final _description = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;
  final _images = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _description.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining == 0) return;
    try {
      final picked = await widget.platform.pickImages(remaining);
      if (!mounted) return;
      setState(() {
        for (final path in picked) {
          if (!_images.contains(path) && _images.length < _maxImages) {
            _images.add(path);
          }
        }
      });
    } on PlatformException {
      if (mounted) _showFailure("Couldn't open the photo picker.");
    }
  }

  Future<void> _send() async {
    final description = _description.text.trim();
    if (description.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final message = buildFeedbackMessage(
        category: _category,
        description: description,
        context: await widget.platform.context(),
        imagePaths: _images,
      );
      if (!await widget.platform.send(message) && mounted) {
        _showFailure("Couldn't open an email app.");
      }
    } on PlatformException {
      if (mounted) _showFailure("Couldn't open an email app.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _description
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.lg),
          children: [
            Text('What are you reporting?', style: text.titleMedium),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final category in FeedbackCategory.values)
                  ChoiceChip(
                    key: ValueKey('feedback-category-${category.name}'),
                    label: Text(category.label),
                    selected: category == _category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Text('What happened?', style: text.titleMedium),
            const SizedBox(height: Gap.sm),
            TextField(
              key: const Key('feedback-description'),
              controller: _description,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What happened? What did you expect instead?',
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text('Screenshots (optional)', style: text.titleMedium),
            const SizedBox(height: Gap.sm),
            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                  itemBuilder: (context, index) => _ScreenshotPreview(
                    path: _images[index],
                    onRemove: () => setState(() => _images.removeAt(index)),
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
            ],
            OutlinedButton.icon(
              key: const Key('feedback-add-screenshots'),
              onPressed: _images.length == _maxImages ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _images.isEmpty
                    ? 'Add screenshots'
                    : 'Add screenshots · ${_images.length}/$_maxImages',
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Screenshots may contain personal or trip information. '
              'Review them before sending.',
              style: text.bodySmall?.copyWith(
                color: FoxColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton.icon(
              key: const Key('feedback-send'),
              onPressed: _description.text.trim().isEmpty || _busy
                  ? null
                  : _send,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.field),
          child: Image.file(
            File(path),
            key: ValueKey('feedback-image-$path'),
            width: 72,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 72,
              height: 88,
              color: FoxColors.bgSurface2,
              child: const Icon(Icons.image_outlined),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton.filled(
            key: ValueKey('feedback-remove-$path'),
            tooltip: 'Remove screenshot',
            onPressed: onRemove,
            iconSize: 16,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

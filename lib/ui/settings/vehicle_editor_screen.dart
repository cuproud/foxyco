import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_badge.dart';
import 'garage_controller.dart';

/// Full-screen vehicle editor (spec M6 §4.3). Local draft state only —
/// NOTHING touches the garage until Save; Cancel/back discards. The live
/// badge preview re-tints/re-shapes as the driver edits. Delete (existing
/// vehicles only) confirms first; the controller handles the active-fallback.
class VehicleEditorScreen extends ConsumerStatefulWidget {
  const VehicleEditorScreen({super.key, this.initial});

  /// The vehicle being edited, or null for add-new.
  final Vehicle? initial;

  @override
  ConsumerState<VehicleEditorScreen> createState() =>
      _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends ConsumerState<VehicleEditorScreen> {
  late final _make = TextEditingController(text: widget.initial?.make ?? '');
  late final _model = TextEditingController(text: widget.initial?.model ?? '');
  late final _year = TextEditingController(text: widget.initial?.year ?? '');
  late final _plate = TextEditingController(text: widget.initial?.plate ?? '');
  late int _color = widget.initial?.colorValue ?? 0xFFF5F5F5;
  late VehicleType _body = widget.initial?.bodyType ?? VehicleType.sedan;
  late FuelType _fuel = widget.initial?.fuelType ?? FuelType.gas;
  final _colorAnchor = GlobalKey();
  final _bodyAnchor = GlobalKey();

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Year is optional; when present it must be plausible for a working car.
  bool get _yearOk {
    final y = _year.text.trim();
    if (y.isEmpty) return true;
    final value = int.tryParse(y);
    return value != null && value >= 1980 && value <= DateTime.now().year + 1;
  }

  bool get _modelOk {
    final make = _make.text.trim();
    final model = _model.text.trim();
    return make.isEmpty ||
        model.isEmpty ||
        make.toLowerCase() != model.toLowerCase();
  }

  /// Save needs a make OR model, plus a valid year.
  bool get _canSave =>
      (_make.text.trim().isNotEmpty || _model.text.trim().isNotEmpty) &&
      _yearOk &&
      _modelOk;

  Future<void> _save() async {
    final v = Vehicle(
      id: widget.initial?.id ?? 'v${DateTime.now().millisecondsSinceEpoch}',
      make: _make.text.trim(),
      model: _model.text.trim(),
      year: _year.text.trim(),
      plate: _plate.text.trim(),
      colorValue: _color,
      bodyType: _body,
      fuelType: _fuel,
    );
    await ref.read(garageProvider.notifier).saveVehicle(v);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text(
          'Delete ${widget.initial!.title}? It disappears from the garage. '
          'Offer history is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: VerdictColors.bad),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await ref.read(garageProvider.notifier).deleteVehicle(widget.initial!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add vehicle' : 'Edit vehicle'),
        actions: [
          if (widget.initial != null)
            IconButton(
              key: const ValueKey('editor-delete'),
              onPressed: _confirmDelete,
              tooltip: 'Delete vehicle',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: VerdictColors.bad,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          // Live preview re-renders on every draft edit (spec M6 §4.3).
          Container(
            margin: const EdgeInsets.symmetric(vertical: Gap.lg),
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FoxColors.inkSoft, FoxColors.ink],
              ),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            // Big art filling the card — a 1.7:1 box so wide bodies span it and
            // the vehicle reads large (autocropped PNGs leave no dead margin).
            child: AspectRatio(
              aspectRatio: 1.7,
              child: VehicleBadge(
                bodyType: _body,
                color: Color(_color),
                fuelType: _fuel,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('editor-make'),
                  controller: _make,
                  onChanged: (_) => setState(() {}),
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Make',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: TextField(
                  key: const ValueKey('editor-model'),
                  controller: _model,
                  onChanged: (_) => setState(() {}),
                  maxLength: 30,
                  decoration:
                      const InputDecoration(
                        labelText: 'Model',
                        isDense: true,
                        counterText: '',
                      ).copyWith(
                        errorText: _modelOk
                            ? null
                            : 'Model must differ from make',
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('editor-year'),
                  controller: _year,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Year',
                    isDense: true,
                    counterText: '',
                    errorText: _yearOk
                        ? null
                        : '1980–${DateTime.now().year + 1}',
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: TextField(
                  key: const ValueKey('editor-plate'),
                  controller: _plate,
                  onChanged: (_) => setState(() {}),
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Plate number (optional)',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Color · optional', style: text.labelSmall),
                    const SizedBox(height: Gap.sm),
                    _SelectorField(
                      key: const ValueKey('editor-color'),
                      anchorKey: _colorAnchor,
                      label: DriverProfile.palette[_color] ?? 'Choose color',
                      swatch: Color(_color),
                      onTap: _pickColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Vehicle type', style: text.labelSmall),
                    const SizedBox(height: Gap.sm),
                    _SelectorField(
                      key: const ValueKey('editor-body'),
                      anchorKey: _bodyAnchor,
                      label: _body.label,
                      onTap: _pickBody,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('FUEL', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final f in FuelType.values)
                ChoiceChip(
                  label: Text(switch (f) {
                    FuelType.gas => 'Gas',
                    FuelType.hybrid => 'Hybrid',
                    FuelType.ev => 'EV',
                  }),
                  selected: _fuel == f,
                  onSelected: (_) => setState(() => _fuel = f),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor() async {
    final picked = await _showMenu<int>(
      anchor: _colorAnchor,
      items: [
        for (final entry in DriverProfile.palette.entries)
          PopupMenuItem(
            value: entry.key,
            child: _MenuRow(
              label: entry.value,
              swatch: Color(entry.key),
              selected: entry.key == _color,
            ),
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _color = picked);
  }

  Future<void> _pickBody() async {
    final picked = await _showMenu<VehicleType>(
      anchor: _bodyAnchor,
      items: [
        for (final type in VehicleType.values)
          if (type != VehicleType.motorbike || type == _body)
            PopupMenuItem(
              value: type,
              child: _MenuRow(label: type.label, selected: type == _body),
            ),
      ],
    );
    if (picked != null && mounted) setState(() => _body = picked);
  }

  Future<T?> _showMenu<T>({
    required GlobalKey anchor,
    required List<PopupMenuEntry<T>> items,
  }) {
    FocusScope.of(context).unfocus();
    final anchorBox = anchor.currentContext!.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = anchorBox.localToGlobal(
      anchorBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final rect = Rect.fromPoints(topLeft, bottomRight);
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlayBox.size),
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.cardSm),
      ),
      items: items,
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    super.key,
    required this.label,
    required this.onTap,
    required this.anchorKey,
    this.swatch,
  });
  final String label;
  final VoidCallback onTap;
  final GlobalKey anchorKey;
  final Color? swatch;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Radii.field),
    child: InputDecorator(
      key: anchorKey,
      decoration: const InputDecoration(
        isDense: true,
        suffixIcon: Icon(Icons.expand_more),
      ),
      child: Row(
        children: [
          if (swatch != null) ...[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
            ),
            const SizedBox(width: Gap.sm),
          ],
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.selected, this.swatch});

  final String label;
  final bool selected;
  final Color? swatch;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (swatch != null) ...[
        Container(
          key: swatch == null ? null : ValueKey('vehicle-color-swatch-$label'),
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
      ],
      Expanded(child: Text(label)),
      if (selected) const Icon(Icons.check_rounded, size: 18),
    ],
  );
}

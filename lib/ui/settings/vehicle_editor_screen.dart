import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Year is optional; when present it must be exactly four digits.
  bool get _yearOk {
    final y = _year.text.trim();
    return y.isEmpty || RegExp(r'^\d{4}$').hasMatch(y);
  }

  /// Save needs a make OR model, plus a valid year.
  bool get _canSave =>
      (_make.text.trim().isNotEmpty || _model.text.trim().isNotEmpty) &&
      _yearOk;

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
        content: const Text('It disappears from the garage. '
            'Offer history is not affected.'),
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
      await ref
          .read(garageProvider.notifier)
          .deleteVehicle(widget.initial!.id);
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
              icon: const Icon(Icons.delete_outline_rounded,
                  color: VerdictColors.bad),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [FoxColors.inkSoft, FoxColors.ink],
              ),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: FoxColors.borderSoft),
            ),
            child: Center(
              child: VehicleBadge(
                bodyType: _body,
                color: Color(_color),
                fuelType: _fuel,
                size: 72,
              ),
            ),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('editor-make'),
                controller: _make,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Make', isDense: true),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('editor-model'),
                controller: _model,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Model', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Gap.md),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('editor-year'),
                controller: _year,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Year',
                  isDense: true,
                  errorText: _yearOk ? null : '4 digits',
                ),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: TextField(
                key: const ValueKey('editor-plate'),
                controller: _plate,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Plate', isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: Gap.lg),
          Text('COLOR', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final entry in DriverProfile.palette.entries)
                GestureDetector(
                  onTap: () => setState(() => _color = entry.key),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(entry.key),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == entry.key ? 3 : 1,
                        color: _color == entry.key
                            ? FoxColors.brandFox
                            : FoxColors.border,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text('BODY', style: text.labelSmall),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final t in VehicleType.values)
                ChoiceChip(
                  label: Text(t.name),
                  selected: _body == t,
                  onSelected: (_) => setState(() => _body = t),
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
}

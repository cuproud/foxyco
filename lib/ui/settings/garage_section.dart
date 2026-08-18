import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/driver_profile.dart';
import '../../domain/garage.dart';
import '../theme/tokens.dart';
import '../theme/vehicle_badge.dart';
import 'garage_controller.dart';

// The Garage group's body: who's driving and what they're driving. Sits beside
// reminder_section.dart, the other half of that same group.

class DriverNameCard extends ConsumerStatefulWidget {
  const DriverNameCard({super.key});

  @override
  ConsumerState<DriverNameCard> createState() => DriverNameCardState();
}

class DriverNameCardState extends ConsumerState<DriverNameCard> {
  late final _name = TextEditingController();
  bool _seeded = false;
  bool _editing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(driverNameProvider.notifier).setName(_name.text.trim());
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(driverNameProvider);
    // Seed once from the async-loaded name — after that the field owns its text.
    if (!_seeded && saved.isNotEmpty) {
      _name.text = saved;
      _seeded = true;
    }
    final dirty = _name.text.trim() != saved.trim();

    // Two modes (device feedback 2026-07-20 — a saved name should not look
    // permanently editable): display row (name + pencil) ↔ edit row
    // (TextField + Save while dirty). Empty saved name starts in edit mode
    // so first-run still has an obvious field.
    if (!_editing && saved.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FoxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(saved, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('edit-name'),
            onPressed: () => setState(() {
              _name.text = saved; // discard any stale draft
              _editing = true;
            }),
            icon: Icon(
              Icons.edit_outlined,
              color: FoxColors.textSecondary,
              size: 18,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            autofocus: _editing, // pencil tap → keyboard up immediately
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            // Greeting shows this name — cap it so it can't dominate Home.
            maxLength: 20,
            onSubmitted: (_) {
              if (_name.text.trim() != saved.trim()) {
                _save();
              } else {
                setState(() => _editing = false);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Name',
              isDense: true,
              counterText: '',
            ),
          ),
        ),
        if (dirty) ...[
          const SizedBox(width: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('save-name'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: FoxColors.brandFox,
              foregroundColor: Colors.white,
              // Theme default is Size.fromHeight(52) → infinite width, which
              // can't sit in this Row next to the field.
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.field),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

/// Vehicle list — premium mini car-cards + a "+ Add vehicle" affordance (spec
/// M6 §4.2). Tap sets active (instant, persisted). The edit icon opens the
/// editor.
class GarageList extends ConsumerWidget {
  const GarageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    return Column(
      children: [
        for (final v in garage.vehicles) ...[
          VehicleCard(
            vehicle: v,
            active: garage.active?.id == v.id,
            onTap: () => ref.read(garageProvider.notifier).setActive(v.id),
            onEdit: () => context.push('/vehicle-editor', extra: v),
          ),
          const SizedBox(height: Gap.sm),
        ],
        // "+ Add vehicle" card.
        InkWell(
          key: const ValueKey('add-vehicle'),
          borderRadius: BorderRadius.circular(Radii.cardSm),
          onTap: () => context.push('/vehicle-editor'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Gap.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.cardSm),
              border: Border.all(color: FoxColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: FoxColors.brandFox, size: 20),
                SizedBox(width: Gap.sm),
                Text(
                  'Add vehicle',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FoxColors.brandFox,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One vehicle card: a big body illustration (~45% of the card) beside the
/// title + plate + active state. Tap sets active; **long-press edits** (no more
/// corner edit icon / check tick — the border and "Active" pill carry state).
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.active,
    required this.onTap,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${vehicle.title.isEmpty ? 'Unnamed vehicle' : vehicle.title}'
          '${active ? ', active' : ''}. Tap to activate, long-press to edit.',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.cardSm),
        onTap: onTap,
        onLongPress: onEdit,
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: FoxColors.bgSurface,
            borderRadius: BorderRadius.circular(Radii.cardSm),
            border: Border.all(
              color: active ? FoxColors.brandFox : FoxColors.borderSoft,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active ? Shadows.glowSoft : Shadows.soft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Art fills ~45% of the card width; a 1.4:1 box keeps landscape
              // bodies wide while leaving portrait ones (bikes) room to breathe.
              Expanded(
                flex: 45,
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: VehicleBadge(
                    bodyType: vehicle.bodyType,
                    color: Color(vehicle.colorValue),
                    fuelType: vehicle.fuelType,
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                flex: 55,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.title.isEmpty ? 'Unnamed vehicle' : vehicle.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: FoxColors.textPrimary,
                      ),
                    ),
                    Text(
                      vehicle.bodyType.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FoxColors.textSecondary,
                      ),
                    ),
                    if (vehicle.plate.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FoxColors.bgSurface2,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: FoxColors.border),
                        ),
                        child: Text(
                          vehicle.plate,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: FoxColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FoxColors.brandFox.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: FoxColors.brandFox,
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
      ),
    );
  }
}

/// "How to read the pill" legend under the live preview — a quick walkthrough
/// for new installs. Each row = one colored key + what it means, mirroring the
/// sample pill exactly (active verdict rate, neutral total distance, GPS target).

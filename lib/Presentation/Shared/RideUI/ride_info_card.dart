// Shared Ride UI — grouped info card.
//
// Icon-beside-each-row layout for anything that would otherwise be a large
// text block (package details, trip summary, etc.) — generic label/value
// pairs plus an optional chip row, no ride-type-specific fields baked in.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

class RideInfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const RideInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });
}

class RideInfoChip {
  final String text;
  final Color foreground;
  final Color background;

  const RideInfoChip({
    required this.text,
    required this.foreground,
    required this.background,
  });
}

class RideInfoCard extends StatelessWidget {
  final String? title;
  final List<RideInfoRow> rows;
  final List<RideInfoChip>? chips;

  const RideInfoCard({super.key, this.title, required this.rows, this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: RideUI.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: RideUI.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(row: rows[i]),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
          if (chips != null && chips!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips!)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: chip.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chip.text,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: chip.foreground,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final RideInfoRow row;
  const _InfoRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 16, color: row.iconColor ?? RideUI.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: RideUI.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            row.value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: RideUI.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

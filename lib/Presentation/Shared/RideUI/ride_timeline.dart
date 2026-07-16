// Shared Ride UI — vertical timeline.
//
// Generic step-state timeline: nothing here knows about parcel statuses.
// Callers map their own status enum to RideTimelineStepState and pass
// plain labels — reusable for a package's 6 statuses today, a solo/shared
// ride's fewer statuses tomorrow.

import 'package:flutter/material.dart';
import 'ride_ui_theme.dart';

enum RideTimelineStepState { completed, active, pending, failed }

class RideTimelineStep {
  final String label;
  final RideTimelineStepState state;
  final String? timestamp;

  const RideTimelineStep({
    required this.label,
    required this.state,
    this.timestamp,
  });
}

class RideTimeline extends StatelessWidget {
  final List<RideTimelineStep> steps;
  final Color activeColor;

  const RideTimeline({
    super.key,
    required this.steps,
    this.activeColor = RideUI.brandGreen,
  });

  Color _dotColor(RideTimelineStepState state) {
    switch (state) {
      case RideTimelineStepState.completed:
        return activeColor;
      case RideTimelineStepState.active:
        return activeColor;
      case RideTimelineStepState.failed:
        return const Color(0xFFDC2626);
      case RideTimelineStepState.pending:
        return RideUI.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            dotColor: _dotColor(steps[i].state),
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final RideTimelineStep step;
  final Color dotColor;
  final bool isLast;

  const _StepRow({
    required this.step,
    required this.dotColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final completed = step.state == RideTimelineStepState.completed;
    final active = step.state == RideTimelineStepState.active;
    final failed = step.state == RideTimelineStepState.failed;
    final emphasized = completed || active || failed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: RideUI.motionFast,
                curve: RideUI.motionCurve,
                width: active ? 14 : 11,
                height: active ? 14 : 11,
                decoration: BoxDecoration(
                  color: completed || failed ? dotColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: active ? 3 : 2),
                ),
                child:
                    completed
                        ? const Icon(Icons.check, size: 8, color: Colors.white)
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color:
                        completed ? dotColor.withOpacity(0.4) : RideUI.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            emphasized ? FontWeight.w800 : FontWeight.w600,
                        color:
                            emphasized ? RideUI.textPrimary : RideUI.textMuted,
                      ),
                    ),
                  ),
                  if (step.timestamp != null && step.timestamp!.isNotEmpty)
                    Text(
                      step.timestamp!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: RideUI.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/utils/map/navigation_assist.dart';

class _K {
  static const bg = Color(0xFFF4F4F4);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const sub = Color(0xFF666666);
  static const muted = Color(0xFF8A8A8A);
  static const border = Color(0xFFE5E5E5);
  static const dark = Color(0xFF1E1E1E);
  static const darkSoft = Color(0xFF333333);
  static const shadow = Color(0x14000000);

  static const req = Color(0xFF2F5EB9);
  static const reqBg = Color(0xFFE9F0FF);
  static const acc = Color(0xFF0B9B3C);
  static const accBg = Color(0xFFE7F7EE);
  static const dec = Color(0xFFC46A00);
  static const decBg = Color(0xFFFFF2E5);
  static const can = Color(0xFFE74700);
  static const canBg = Color(0xFFFFEDE6);
}

class DriverAnalyticsScreen extends StatelessWidget {
  const DriverAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = Get.find<DriverAnalyticsController>();

    return Scaffold(
      backgroundColor: _K.bg,
      body: SafeArea(
        child: Obx(() {
          final requests = analytics.offers.value;
          final accepted = analytics.accepts.value;
          final declined = analytics.declines.value;
          final cancelled = analytics.cancellations.value;
          final acceptanceRate = analytics.acceptanceRate;
          final declineRate = analytics.declineRate;
          final cancelRate = analytics.cancellationRate;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Driver Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _K.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: _K.sub,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _hero(requests, accepted, declined, cancelled),
              const SizedBox(height: 12),
              _metricsGrid(requests, accepted, declined, cancelled),
              const SizedBox(height: 12),
              _performanceCard(
                acceptanceRate,
                declineRate,
                cancelRate,
                requests: requests,
                accepted: accepted,
                declined: declined,
                cancelled: cancelled,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _hero(int requests, int accepted, int declined, int cancelled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_K.dark, _K.darkSoft],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: _K.shadow, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ride Requests',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$requests',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Accepted $accepted  •  Declined $declined  •  Cancelled $cancelled',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(int requests, int accepted, int declined, int cancelled) {
    Widget card(String label, int value, IconData icon, Color tone, Color bg) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _K.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: tone),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: tone,
                height: 1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _K.sub,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        card('Requests', requests, Icons.campaign_rounded, _K.req, _K.reqBg),
        card(
          'Accepted',
          accepted,
          Icons.check_circle_rounded,
          _K.acc,
          _K.accBg,
        ),
        card(
          'Declined',
          declined,
          Icons.thumb_down_alt_rounded,
          _K.dec,
          _K.decBg,
        ),
        card('Cancelled', cancelled, Icons.cancel_rounded, _K.can, _K.canBg),
      ],
    );
  }

  Widget _performanceCard(
    double acceptanceRate,
    double declineRate,
    double cancelRate, {
    required int requests,
    required int accepted,
    required int declined,
    required int cancelled,
  }) {
    String title;
    String subtitle;
    List<String> quotes;
    if (acceptanceRate >= 80 && cancelRate <= 10) {
      title = 'Strong Performance';
      subtitle = 'Keep this consistency.';
      quotes = const [
        'You are setting the standard. Stay sharp and keep the streak alive.',
        'Strong focus brings strong results. Keep your rhythm.',
        'Top discipline. Small consistency today builds big success tomorrow.',
      ];
    } else if (acceptanceRate >= 60) {
      title = 'Good Progress';
      subtitle = 'Reduce decline and cancel rates.';
      quotes = const [
        'You are close to the next level. Push one more step.',
        'Good effort. Convert more requests and climb higher.',
        'Momentum is building. Keep pressure and improve every trip.',
      ];
    } else {
      title = 'Needs Attention';
      subtitle = 'Improve acceptance for better results.';
      quotes = const [
        'Reset your focus. One better hour can change your whole day.',
        'Don\'t stop now. Improve the next request and build from there.',
        'Every strong driver starts with a comeback. Start with this trip.',
      ];
    }
    final quoteSeed =
        requests + (accepted * 3) + (declined * 5) + (cancelled * 7);
    final quote = quotes[quoteSeed % quotes.length];

    Widget row(String label, double value, Color tone) {
      final safe = value.isFinite ? value.clamp(0, 100).toDouble() : 0.0;
      return Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _K.sub,
                ),
              ),
              const Spacer(),
              Text(
                '${safe.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: safe / 100,
              backgroundColor: _K.border,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _K.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _K.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _K.muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _K.dark.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _K.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: _K.dark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _K.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          row('Accept', acceptanceRate, _K.acc),
          const SizedBox(height: 10),
          row('Decline', declineRate, _K.dec),
          const SizedBox(height: 10),
          row('Cancel', cancelRate, _K.can),
        ],
      ),
    );
  }
}

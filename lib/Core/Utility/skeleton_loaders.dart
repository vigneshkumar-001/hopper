import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:hopper/Core/Constants/Colors.dart';

/// Layout-matched shimmer skeletons used while a driver screen's data loads.
/// Each builder mirrors the real card so the loading state has the same shape
/// as the loaded content (no spinner -> list jump).
class SkeletonLoaders {
  SkeletonLoaders._();

  // --------------------------- RIDE / TRIP HISTORY ------------------------
  static Widget rideHistory({int items = 4}) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        itemCount: items,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.rideShareContainerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // id + status pill + amount/date
              Row(
                children: const [
                  Text('#RD000000',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                  Spacer(),
                  Text('  Status  ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 10),
                  Text('0000', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              // customer avatar + name + stars
              Row(
                children: [
                  const CircleAvatar(radius: 18),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Customer name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                      SizedBox(height: 4),
                      Text('★ ★ ★ ★ ★', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // pickup / drop timeline
              _timelineRow(),
              const SizedBox(height: 10),
              _timelineRow(),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _timelineRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _box(12, 12, radius: 6),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Address label',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Address placeholder line goes here',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------- WALLET HISTORY ---------------------------
  /// Non-scrollable column of transaction rows. The wallet screen uses a
  /// CustomScrollView, so wrap this in a SliverToBoxAdapter at the call site.
  static Widget walletHistory({int items = 6}) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: List.generate(
          items,
          (_) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction title',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          )),
                      SizedBox(height: 4),
                      Text('Description line', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Text('00th Mon 0000', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Text('0000.00',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------- EARNINGS -------------------------------
  static Widget earnings({int items = 4}) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          // balance card
          _box(double.infinity, 150, radius: 24),
          const SizedBox(height: 24),
          const Text('Recent Activity',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ...List.generate(
            items,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x0D111827)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(42, 42, radius: 16),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Expanded(
                              child: Text('Earning title',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  )),
                            ),
                            SizedBox(width: 8),
                            Text('0000',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                )),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text('#BK000000 • Ride',
                            style: TextStyle(fontSize: 12)),
                      ],
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

  // ----------------------------- NOTIFICATIONS ----------------------------
  static Widget notifications({int items = 7}) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        itemCount: items,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.rideShareContainerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  CircleAvatar(radius: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notification title placeholder',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                        SizedBox(height: 4),
                        Text('Notification description line here',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('00th Mon 0000 • 00:00 AM',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------- SUPPORT --------------------------------
  static Widget support({int items = 6}) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: items,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            children: [
              _box(54, 54, radius: 14),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support ticket subject placeholder line',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: 6),
                    Text('Created on 00 Mon 0000',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------- helpers --------------------------------
  static Widget _box(double w, double h, {double radius = 12}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

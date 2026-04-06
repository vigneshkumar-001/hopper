import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Presentation/Drawer/controller/notification_controller.dart';
import 'package:hopper/Presentation/Drawer/screens/notification_screen.dart';
import 'package:hopper/Presentation/Drawer/screens/ride_activity.dart';
import 'package:hopper/Presentation/Drawer/screens/settings_screen.dart';
import 'package:hopper/Presentation/Drawer/screens/wallet_screen.dart';
import 'package:hopper/Presentation/CustomerSupport/screens/customer_support_list_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_analytics_screen.dart';
import 'package:hopper/Presentation/DriverScreen/screens/driver_main_screen.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';

class DrawerScreen extends StatefulWidget {
  const DrawerScreen({super.key});

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  late final ChooseServiceController getDetails;
  final NotificationController sharedCtrl = Get.put(
    NotificationController(),
    permanent: true,
  );
  late final DriverStatusController statusController;

  @override
  void initState() {
    super.initState();
    getDetails =
        Get.isRegistered<ChooseServiceController>()
            ? Get.find<ChooseServiceController>()
            : Get.put(ChooseServiceController());

    statusController =
        Get.isRegistered<DriverStatusController>()
            ? Get.find<DriverStatusController>()
            : Get.put(DriverStatusController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFCFCFD), Color(0xFFF5F7FA)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Row(
                          children: [
                            _CircleButton(
                              icon: Icons.close_rounded,
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Get.offAll(() => const DriverMainScreen());
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        _MenuTile(
                          title: 'Ride Activity',
                          onTap:
                              () => Get.to(() => RideAndPackageHistoryScreen()),
                        ),
                        const _MenuDivider(),
                        _MenuTile(
                          title: 'Wallet',
                          onTap: () => Get.to(() => WalletScreen()),
                        ),
                        const _MenuDivider(),
                        _MenuTile(
                          title: 'Driver Analytics',
                          onTap:
                              () => Get.to(() => const DriverAnalyticsScreen()),
                        ),
                        const _MenuDivider(),
                        _MenuTile(
                          title: 'Notifications',
                          onTap: () => Get.to(() => NotificationScreen()),
                        ),
                        const _MenuDivider(),
                        _MenuTile(
                          title: 'Support',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => const CustomerSupportListScreen(),
                              ),
                            );
                          },
                        ),
                        const _MenuDivider(),
                        _MenuTile(
                          title: 'Settings',
                          onTap: () => Get.to(() => const SettingsScreen()),
                        ),
                        const _MenuDivider(),
                        const SizedBox(height: 10),
                        Obx(() {
                          final profileServiceType =
                              (getDetails.userProfile.value?.serviceType ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();

                          final isBike =
                              profileServiceType == 'bike' ||
                              statusController.isBike;
                          final isCar =
                              profileServiceType == 'car' ||
                              statusController.isCar;

                          if (isBike || !isCar) {
                            return const SizedBox.shrink();
                          }
                          final loading =
                              sharedCtrl.isSharedToggleLoading.value;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Shared Booking',
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Switch(
                                    value: sharedCtrl.isSharedEnabled.value,
                                    onChanged:
                                        loading
                                            ? null
                                            : (value) async {
                                              await HapticFeedback.selectionClick();
                                              await sharedCtrl.setSharedEnabled(
                                                value,
                                              );
                                            },
                                    activeThumbColor: AppColors.drkGreen,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Obx(() {
                    final profile = getDetails.userProfile.value;
                    return Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: _ProfileImage(profile?.profilePic),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _drawerName(
                                        profile?.firstName,
                                        profile?.lastName,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 15,
                                          color: Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (profile
                                                      ?.DriverStarRating
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? profile!.DriverStarRating!
                                              : '0.0',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profile?.countryCode ?? ''} ${profile?.mobileNumber ?? 'Loading...'}'
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, color: const Color(0xFF111827)),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: Color(0x14000000), thickness: 1.5),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        height: 52,
        width: 52,
        fit: BoxFit.cover,
        placeholder:
            (_, __) => const SizedBox(
              height: 52,
              width: 52,
              child: Center(child: HopprCircularLoader(radius: 12)),
            ),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      height: 52,
      width: 52,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person_rounded, color: Color(0xFF667085)),
    );
  }
}

String _drawerName(String? firstName, String? lastName) {
  final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
  return full.isEmpty ? 'Guest User' : full;
}

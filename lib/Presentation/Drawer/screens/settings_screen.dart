import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Presentation/Authentication/screens/GetStarted_Screens.dart';
import 'package:hopper/utils/map/navigation_assist.dart';
import 'package:hopper/utils/session/logout_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
import 'package:hopper/Presentation/Drawer/controller/notification_controller.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/models/getuserdetails_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ChooseServiceController profileController;
  late final NotificationController sharedController;
  DriverStatusController? statusController;

  @override
  void initState() {
    super.initState();
    profileController = Get.isRegistered<ChooseServiceController>()
        ? Get.find<ChooseServiceController>()
        : Get.put(ChooseServiceController());
    sharedController = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController(), permanent: true);
    if (Get.isRegistered<DriverStatusController>()) {
      statusController = Get.find<DriverStatusController>();
    }
    if (profileController.userProfile.value == null &&
        !profileController.isGetLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profileController.getUserDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Obx(() {
          final profile = profileController.userProfile.value;
          final isLoading = profileController.isGetLoading.value;
          final online = statusController?.isOnline.value ?? false;
          final shared = sharedController.isSharedEnabled.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: const Color(0xFFF0F0F3),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, size: 30),
                          ),
                          const Expanded(
                            child: Text(
                              'Settings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => profileController.getUserDetails(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName(profile),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _phone(profile),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _SettingsAvatar(profile?.profilePic),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _rating(profile),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _SettingsRowTile(
                  icon: Icons.badge_outlined,
                  title: 'Documents',
                  subtitle: 'Aadhaar, license, profile photo and status',
                  onTap: () => Get.to(() => _DocumentsDetailsScreen(profile: profile)),
                ),
                _SettingsRowTile(
                  icon: Icons.directions_car_filled_outlined,
                  title: 'Vehicles',
                  subtitle: 'Brand, model, plate and registration',
                  onTap: () => Get.to(() => _VehicleDetailsScreen(profile: profile)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _StatusCards(
                    online: online,
                    shared: shared,
                    serviceType: profile?.serviceType ?? 'NA',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _DetailsCard(
                    title: 'Basic Details',
                    children: [
                      _detailRow('Phone', _phone(profile)),
                      _detailRow('Email', _text(profile?.email)),
                      _detailRow('Address', _address(profile)),
                      _detailRow('Gender', _text(profile?.gender)),
                      _detailRow('DOB', _text(profile?.dob)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _SettingsLogoutCard(
                    onTap: () => _showSettingsLogoutDialog(context),
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

  void _showSettingsLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE5E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFB42318),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Log out now?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You will need to sign in again to access your driver account on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFFD0D5DD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _settingsLogout(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB42318),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

class _SettingsLogoutCard extends StatelessWidget {
  const _SettingsLogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF6D0CC)),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFB42318)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB42318),
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFB42318)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    final child = (url != null && url!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: url!,
            height: 68,
            width: 68,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _fallback(),
          )
        : _fallback();
    return ClipOval(child: child);
  }

  Widget _fallback() {
    return Container(
      height: 68,
      width: 68,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person_rounded, color: Color(0xFF667085)),
    );
  }
}

class _SettingsRowTile extends StatelessWidget {
  const _SettingsRowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
          ),
          child: Row(
        children: [
          Icon(icon, color: const Color(0xFF111827), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        ],
      ),
        ),
      ),
    );
  }
}

class _StatusCards extends StatelessWidget {
  const _StatusCards({
    required this.online,
    required this.shared,
    required this.serviceType,
  });

  final bool online;
  final bool shared;
  final String serviceType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallStatusCard(
            title: 'Driver',
            value: online ? 'Online' : 'Offline',
            color: online ? const Color(0xFF067647) : const Color(0xFFB42318),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallStatusCard(
            title: 'Shared',
            value: shared ? 'Enabled' : 'Disabled',
            color: shared ? const Color(0xFF1D4ED8) : const Color(0xFF667085),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallStatusCard(
            title: 'Service',
            value: serviceType.isEmpty ? 'NA' : serviceType,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _SmallStatusCard extends StatelessWidget {
  const _SmallStatusCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.title,
    required this.urls,
    required this.emptyLabel,
  });

  final String title;
  final List<String?> urls;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final cleanUrls = urls
        .map((e) => e?.trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (cleanUrls.isEmpty)
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cleanUrls.map((url) => _PhotoThumb(url)).toList(),
            ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 86,
        width: 86,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 55,
          width: 55,
          color: const Color(0xFFF2F4F7),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 86,
          width: 86,
          color: const Color(0xFFF2F4F7),
          child:  Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _statusRow(String label, bool approved) {
  final color = approved ? const Color(0xFF067647) : const Color(0xFFB54708);
  final bg = approved ? const Color(0xFFE7F6EC) : const Color(0xFFFFF0D5);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(
            approved ? 'Verified' : 'Pending',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _fullName(GetUserProfileModel? profile) {
  final full = '${profile?.firstName ?? ''} ${profile?.lastName ?? ''}'.trim();
  return full.isEmpty ? 'Guest Driver' : full;
}

String _rating(GetUserProfileModel? profile) {
  final rating = profile?.DriverStarRating?.trim() ?? '';
  return rating.isEmpty ? '0.0' : rating;
}

String _phone(GetUserProfileModel? profile) {
  final value = '${profile?.countryCode ?? ''} ${profile?.mobileNumber ?? ''}'.trim();
  return value.isEmpty ? 'Not available' : value;
}

String _address(GetUserProfileModel? profile) {
  final values = [profile?.address, profile?.city, profile?.state]
      .map((e) => e?.trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
  return values.isEmpty ? 'Not available' : values.join(', ');
}

String _vehicleName(GetUserProfileModel? profile) {
  final values = (profile?.serviceType ?? '').toLowerCase() == 'bike'
      ? [profile?.bikeBrand, profile?.bikeModel]
      : [profile?.carBrand, profile?.carModel];
  final clean = values.map((e) => e?.trim() ?? '').where((e) => e.isNotEmpty).toList();
  return clean.isEmpty ? 'Not available' : clean.join(' ');
}

String _registration(GetUserProfileModel? profile) {
  final values = [
    profile?.carRegistrationNumber,
    profile?.bikeRegistrationNumber,
    profile?.carPlateNumber,
    profile?.bikePlateNumber,
  ].map((e) => e?.trim() ?? '');
  for (final item in values) {
    if (item.isNotEmpty) return item;
  }
  return 'Not available';
}

String _ownerName(GetUserProfileModel? profile) {
  final value = (profile?.serviceType ?? '').toLowerCase() == 'bike'
      ? profile?.bikeOwnerName
      : profile?.carOwnerName;
  return _text(value);
}

String _text(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? 'Not available' : text;
}

bool _approved(StatusModel? status) => (status?.status ?? 0) >= 3;





class _DocumentsDetailsScreen extends StatelessWidget {
  const _DocumentsDetailsScreen({required this.profile});

  final GetUserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7FA),
        surfaceTintColor: const Color(0xFFF7F7FA),
        elevation: 0,
        title: const Text(
          'Documents',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            _DetailsCard(
              title: 'Verification Status',
              children: [
                _statusRow('Profile Photo', _approved(profile?.profilePhotoStatus)),
                _statusRow('Aadhaar / NIN', _approved(profile?.ninVerificationStatus)),
                _statusRow('Driver License', _approved(profile?.driversLicenseStatus)),
                _statusRow('Address', _approved(profile?.driverAddressStatus)),
              ],
            ),
            const SizedBox(height: 16),
            _DetailsCard(
              title: 'Document Numbers',
              children: [
                _detailRow('National ID', _text(profile?.nationalIdNumber)),
                _detailRow('License No', _text(profile?.driverLicenseNumber)),
                _detailRow('BVN', _text(profile?.bankVerificationNumber)),
              ],
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Aadhaar / NIN Photos',
              urls: [profile?.frontIdCardNin, profile?.backIdCardNin],
              emptyLabel: 'No Aadhaar / NIN photos uploaded yet',
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Driving License Photos',
              urls: [profile?.frontIdCardDln, profile?.backIdCardDln],
              emptyLabel: 'No driving license photos uploaded yet',
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Profile Photo',
              urls: [profile?.profilePic],
              emptyLabel: 'No profile photo uploaded yet',
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleDetailsScreen extends StatelessWidget {
  const _VehicleDetailsScreen({required this.profile});

  final GetUserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7FA),
        surfaceTintColor: const Color(0xFFF7F7FA),
        elevation: 0,
        title: const Text(
          'Vehicles',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            _DetailsCard(
              title: 'Vehicle Status',
              children: [
                _statusRow('Vehicle Details', _approved(profile?.carDetailsStatus)),
                _statusRow('Ownership', _approved(profile?.carOwnershipStatus)),
                _statusRow('Exterior Photos', _approved(profile?.carExteriorPhotosStatus)),
                _statusRow('Interior Photos', _approved(profile?.carInteriorPhotosStatus)),
              ],
            ),
            const SizedBox(height: 16),
            _DetailsCard(
              title: 'Vehicle Details',
              children: [
                _detailRow('Service', _text(profile?.serviceType)),
                _detailRow('Brand / Model', _vehicleName(profile)),
                _detailRow('Year', profile?.carYear?.toString() ?? profile?.bikeYear?.toString() ?? 'Not available'),
                _detailRow('Color', _text(profile?.carColor)),
                _detailRow('Owner', _ownerName(profile)),
                _detailRow('Plate', _text(profile?.carPlateNumber ?? profile?.bikePlateNumber)),
                _detailRow('Registration', _registration(profile)),
              ],
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Vehicle Document Photos',
              urls: [
                profile?.carInsuranceDocument,
                profile?.carRoadWorthinessCertificate,
                profile?.bikeInsuranceDocument,
                profile?.bikeRoadWorthinessCertificate,
              ],
              emptyLabel: 'No vehicle document photos uploaded yet',
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Exterior Photos',
              urls: profile?.carExteriorPhotos ?? profile?.bikePhotos ?? const [],
              emptyLabel: 'No exterior photos uploaded yet',
            ),
            const SizedBox(height: 16),
            _PhotoSection(
              title: 'Interior Photos',
              urls: profile?.carInteriorPhotos ?? const [],
              emptyLabel: 'No interior photos uploaded yet',
            ),
          ],
        ),
      ),
    );
  }
}


Future<void> _settingsLogout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await performLogoutCleanup();
  await prefs.clear();
  if (Get.isRegistered<DriverAnalyticsController>()) {
    await Get.find<DriverAnalyticsController>().reset(clearPersisted: false);
  }
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const GetStartedScreens()),
    (route) => false,
  );
}


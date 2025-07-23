import 'dart:async';
import 'package:action_slider/action_slider.dart';
import 'package:flutter/services.dart';
import 'package:hopper/Presentation/DriverScreen/screens/verify_rider_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import '../../../Core/Constants/Colors.dart';
import '../../../Core/Constants/log.dart';
import '../../../Core/Utility/Buttons.dart';
import '../../../utils/map/google_map.dart';
import '../../../utils/map/route_info.dart';
import '../../../utils/netWorkHandling/network_handling_screen.dart';
import 'cash_collected_screen.dart';

class RideStatsScreen extends StatefulWidget {
  const RideStatsScreen({super.key});

  @override
  State<RideStatsScreen> createState() => _RideStatsScreenState();
}

class _RideStatsScreenState extends State<RideStatsScreen> {
  LatLng origin = LatLng(9.9303, 78.0945);
  LatLng destination = LatLng(9.9342, 78.1824);
  GoogleMapController? _mapController;
  bool driverReached = false;
  bool arrivedAtPickup = true;
  bool driverCompletedRide = false;
  String directionText = '';
  String distance = '';
  List<LatLng> polylinePoints = [];
  StreamSubscription<Position>? positionStream;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 100), () {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    positionStream = Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        origin = LatLng(position.latitude, position.longitude);
      });
    });

    loadRoute();
  }

  @override
  void dispose() {
    positionStream?.cancel();

    super.dispose();
  }

  Future<void> loadRoute() async {
    final result = await getRouteInfo(origin: origin, destination: destination);

    setState(() {
      directionText = result['direction'];
      distance = result['distance'];
      polylinePoints = decodePolyline(result['polyline']);
    });
  }

  String parseHtmlString(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  String maneuver = '';
  void _goToCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latLng = LatLng(position.latitude, position.longitude);

    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  String getManeuverIcon(maneuver) {
    switch (maneuver) {
      case "turn-right":
        return 'assets/images/straight.png';
      case "turn-left":
        return 'assets/images/straight.png';
      case "straight":
        return 'assets/images/straight.png';
      case "merge":
        return 'assets/images/straight.png';
      case "roundabout-left":
        return 'assets/images/straight.png';
      case "roundabout-right":
        return 'assets/images/straight.png';
      default:
        return 'assets/images/straight.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoInternetOverlay(
      child: Scaffold(
        body: Stack(
          children: [
            //  CommonGoogleMap(
            //   initialPosition: origin,
            //   markers: {
            //     Marker(markerId: MarkerId('start'), position: origin),
            //     Marker(markerId: MarkerId('end'), position: destination),
            //   },
            //   polylines: {
            //     Polyline(
            //       polylineId: PolylineId("route"),
            //       color: AppColors.commonBlack,
            //       width: 5,
            //       points: polylinePoints,
            //     ),
            //   },
            // ),
            SizedBox(
              height: 650,
              child: CommonGoogleMap(
                // onMapCreated: () {
                //   String style = await DefaultAssetBundle.of(
                //     context,
                //   ).loadString('assets/map_style/map_style.json');
                //   _mapController!.setMapStyle(style);
                // },
                onMapCreated: (controller) async {
                  _mapController = controller;

                  // Optional: apply custom map style
                  String style = await DefaultAssetBundle.of(
                    context,
                  ).loadString('assets/map_style/map_style1.json');
                  _mapController!.setMapStyle(style);

                  // Wait briefly to ensure map is ready
                  await Future.delayed(const Duration(milliseconds: 300));

                  // Fit bounds (auto zoom)
                  LatLngBounds bounds = LatLngBounds(
                    southwest: LatLng(
                      origin.latitude < destination.latitude
                          ? origin.latitude
                          : destination.latitude,
                      origin.longitude < destination.longitude
                          ? origin.longitude
                          : destination.longitude,
                    ),
                    northeast: LatLng(
                      origin.latitude > destination.latitude
                          ? origin.latitude
                          : destination.latitude,
                      origin.longitude > destination.longitude
                          ? origin.longitude
                          : destination.longitude,
                    ),
                  );

                  // Apply bounds with padding
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      bounds,
                      70,
                    ), // 70 is padding in pixels
                  );
                },

                initialPosition: origin,
                markers: {
                  Marker(markerId: MarkerId('start'), position: origin),
                  Marker(markerId: MarkerId('end'), position: destination),
                },
                polylines: {
                  Polyline(
                    polylineId: PolylineId("route"),
                    color: AppColors.commonBlack,
                    width: 5,
                    points: polylinePoints,
                  ),
                },
              ),
            ),
            // Existing FAB
            Positioned(
              top: driverCompletedRide ? 550 : 450,
              right: 10,
              child: Column(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    onPressed: _goToCurrentLocation,
                    child: const Icon(Icons.my_location, color: Colors.black),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 45,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 100,

                      color: AppColors.directionColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              getManeuverIcon(maneuver),
                              height: 32,
                              width: 32,
                            ),

                            SizedBox(height: 5),
                            CustomTextfield.textWithStyles600(
                              distance,
                              color: AppColors.commonWhite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 100,
                      color: AppColors.directionColor1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomTextfield.textWithStyles600(
                              maxLine: 2,
                              '${parseHtmlString(directionText)}',
                              fontSize: 13,
                              color: AppColors.commonWhite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: driverCompletedRide ? 0.28 : 0.75,
              minChildSize: driverCompletedRide ? 0.25 : 0.40,
              maxChildSize:
                  driverCompletedRide
                      ? 0.30
                      : 0.75, // Can expand up to 95% height
              // initialChildSize:  0.80, // Start with 80% height
              // minChildSize: 0.5, // Can collapse to 40%
              // maxChildSize: 0.80, // Can expand up to 95% height
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // borderRadius: BorderRadius.only(
                    //   topLeft: Radius.circular(30),
                    //   topRight: Radius.circular(30),
                    // ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 5,

                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      if (!driverCompletedRide) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.rideInProgress.withOpacity(0.1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Center(
                              child: CustomTextfield.textWithStyles600(
                                fontSize: 14,
                                color: AppColors.rideInProgress,
                                'Ride in Progress',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomTextfield.textWithStyles600(
                              '16 min',
                              fontSize: 20,
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.circle,
                              color: AppColors.drkGreen,
                              size: 10,
                            ),
                            SizedBox(width: 10),
                            CustomTextfield.textWithStyles600(
                              '2.3 Km',
                              fontSize: 20,
                            ),
                          ],
                        ),

                        Center(
                          child: CustomTextfield.textWithStylesSmall(
                            'Dropping off Rebecca',
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                child: CustomTextfield.textWithStyles600(
                                  'Ride Details',
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(40),
                                      color: AppColors.commonBlack.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.circle,
                                        color: AppColors.grey,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CustomTextfield.textWithStyles600(
                                        color: AppColors.commonBlack
                                            .withOpacity(0.5),
                                        fontSize: 16,
                                        'Pickup',
                                      ),
                                      CustomTextfield.textWithStylesSmall(
                                        colors: AppColors.textColorGrey,
                                        '4, Gana Street, Maitama, Abuja, FCTLagos',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(40),
                                      color: AppColors.commonBlack.withOpacity(
                                        0.1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.circle,
                                        color: AppColors.commonBlack,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CustomTextfield.textWithStyles600(
                                        fontSize: 16,
                                        'Drop off - Constitution Ave',
                                      ),
                                      CustomTextfield.textWithStylesSmall(
                                        colors: AppColors.textColorGrey,
                                        '143, Constitution Ave, Abuja',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    driverCompletedRide = !driverCompletedRide;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Image.asset(
                                      AppImages.dummyImg,
                                      height: 45,
                                      width: 45,
                                    ),
                                    SizedBox(width: 15),
                                    CustomTextfield.textWithStyles600(
                                      'Rebecca Davis',
                                      fontSize: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.containerColor1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      CustomTextfield.textWithImage(
                                        colors: AppColors.commonBlack,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        text: 'Get Help',
                                        imagePath: AppImages.getHelp,
                                      ),
                                      SizedBox(
                                        height: 20,
                                        child: VerticalDivider(),
                                      ),
                                      CustomTextfield.textWithImage(
                                        colors: AppColors.commonBlack,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        text: 'Share Trip Status',
                                        imagePath: AppImages.share,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Buttons.button(
                                borderColor: AppColors.buttonBorder,
                                buttonColor: AppColors.commonWhite,
                                borderRadius: 8,

                                textColor: AppColors.commonBlack,

                                onTap: () {
                                  Buttons.showDialogBox(context: context);
                                },
                                text: Text('Stop New Ride Request'),
                              ),
                              SizedBox(height: 10),
                              Buttons.button(
                                borderRadius: 8,

                                buttonColor: AppColors.red,

                                onTap: () {
                                  Buttons.showCancelRideBottomSheet(
                                    context,
                                    onConfirmCancel: (reason) {},
                                  );
                                },
                                text: Text('Cancel this Ride'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: AppColors.drkGreen,
                                  size: 13,
                                ),
                                SizedBox(width: 10),
                                CustomTextfield.textWithStyles600(
                                  '1 min away',
                                  fontSize: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            CustomTextfield.textWithStylesSmall(
                              fontWeight: FontWeight.w500,
                              'Dropping off Rebecca',
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: ActionSlider.standard(
                                action: (controller) async {
                                  controller.loading();

                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  ); // optional loading delay

                                  controller.success();

                                  // Delay to let success animation finish before navigating
                                  await Future.delayed(
                                    const Duration(milliseconds: 300),
                                  );

                                  // Navigate to the next screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => CashCollectedScreen(),
                                    ), // replace with your widget
                                  );
                                },

                                height: 50,
                                backgroundColor: AppColors.drkGreen,
                                toggleColor: Colors.white,
                                icon: Icon(
                                  Icons.double_arrow,
                                  color: AppColors.drkGreen,
                                  size: 28,
                                ),
                                child: const Text(
                                  'Complete Ride',
                                  style: TextStyle(
                                    color: AppColors.commonWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // action: (controller) async {
                                //   controller.loading();
                                //   await Future.delayed(
                                //     const Duration(seconds: 3),
                                //   );
                                //   controller.success();
                                // },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

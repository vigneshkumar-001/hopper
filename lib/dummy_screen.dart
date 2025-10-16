// import 'dart:async';
// import 'package:http/http.dart' as http;
// import 'dart:ui' as ui;
//
// import 'dart:typed_data';
// import 'dart:math' as math;
// import 'package:action_slider/action_slider.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:hopper/Presentation/DriverScreen/controller/driver_status_controller.dart';
// import 'package:hopper/utils/sharedprefsHelper/local_data_store.dart';
// import 'package:hopper/utils/websocket/socket_io_client.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
// import '../../../Core/Constants/Colors.dart';
// import '../../../Core/Constants/log.dart';
// import '../../../Core/Utility/Buttons.dart';
// import '../../../utils/map/google_map.dart';
// import '../../../utils/map/route_info.dart';
// import '../../../utils/netWorkHandling/network_handling_screen.dart';
//
// import 'package:get/get.dart';
//
// class RideStatsScreens extends StatefulWidget {
//   final String bookingId;
//   const RideStatsScreens({super.key, required this.bookingId});
//
//   @override
//   State<RideStatsScreens> createState() => _RideStatsScreensState();
// }
//
// class _RideStatsScreensState extends State<RideStatsScreens> {
//   LatLng origin = LatLng(9.9303, 78.0945);
//   LatLng destination = LatLng(9.9342, 78.1824);
//   GoogleMapController? _mapController;
//   final DriverStatusController driverStatusController = Get.put(
//     DriverStatusController(),
//   );
//   String customerFrom = '';
//   String customerTo = '';
//   Marker? _movingMarker;
//   double _currentMapBearing = 0.0;
//
//   LatLng? _lastDriverPosition;
//   late SocketService socketService;
//   bool driverCompletedRide = false;
//   String directionText = '';
//   String distance = '';
//   bool _cameraInitialized = false;
//   String driverName = '';
//   String custName = '';
//   List<LatLng> polylinePoints = [];
//   StreamSubscription<Position>? positionStream;
//   LatLng? bookingFromLocation;
//   LatLng? bookingToLocation;
//   late BitmapDescriptor carIcon;
//   Timer? _autoFollowTimer;
//   bool _userInteractingWithMap = false;
//   bool _autoFollowEnabled = true;
//
//   @override
//   void initState() {
//     super.initState();
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//       ),
//     );
//     driverReachedDestination();
//     _loadMarkerIcons();
//     _initSocketAndLocation();
//     loadRoute();
//
//     positionStream = Geolocator.getPositionStream(
//       locationSettings: LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 5,
//       ),
//     ).listen((Position position) async {
//       final currentLatLng = LatLng(position.latitude, position.longitude);
//
//       if (_lastDriverPosition == null) {
//         _lastDriverPosition = currentLatLng;
//         return;
//       }
//
//       final rotation = getRotation(_lastDriverPosition!, currentLatLng);
//
//       await animateMarker(currentLatLng);
//
//       setState(() {
//         origin = currentLatLng;
//         _currentMapBearing = rotation;
//       });
//
//       // 🎯 Animate map with rotation like Google Maps/Uber/Ola
//       if (_autoFollowEnabled && _mapController != null) {
//         _mapController!.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: currentLatLng,
//               zoom: 18,
//               tilt: 60, // More tilt for 3D effect
//               bearing: rotation, // Rotate map with vehicle
//             ),
//           ),
//         );
//       }
//
//       _lastDriverPosition = currentLatLng;
//       await updateRoute();
//     });
//   }
//
//   double getRotation(LatLng start, LatLng end) {
//     final lat1 = start.latitude * math.pi / 180;
//     final lon1 = start.longitude * math.pi / 180;
//     final lat2 = end.latitude * math.pi / 180;
//     final lon2 = end.longitude * math.pi / 180;
//
//     final dLon = lon2 - lon1;
//
//     final y = math.sin(dLon) * math.cos(lat2);
//     final x =
//         math.cos(lat1) * math.sin(lat2) -
//         math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
//
//     final bearing = math.atan2(y, x);
//     return (bearing * 180 / math.pi + 360) % 360;
//   }
//
//   Future<void> animateMarker(LatLng newPosition) async {
//     if (_mapController == null || carIcon == null) return;
//     if (_lastDriverPosition == null) {
//       _lastDriverPosition = newPosition;
//       return;
//     }
//
//     final distanceMoved = Geolocator.distanceBetween(
//       _lastDriverPosition!.latitude,
//       _lastDriverPosition!.longitude,
//       newPosition.latitude,
//       newPosition.longitude,
//     );
//
//     if (distanceMoved < 2) return; // Skip jitter
//
//     final rotation = getRotation(_lastDriverPosition!, newPosition);
//
//     setState(() {
//       _movingMarker = Marker(
//         markerId: const MarkerId("moving_car"),
//         position: newPosition,
//         icon: carIcon,
//         anchor: const Offset(0.5, 0.5),
//         rotation: rotation, // rotate independently if auto-follow off
//         flat: true,
//       );
//     });
//
//     _lastDriverPosition = newPosition;
//   }
//
//   Future<void> _loadMarkerIcons() async {
//     final ByteData data = await rootBundle.load(AppImages.movingCar);
//
//     final codec = await ui.instantiateImageCodec(
//       data.buffer.asUint8List(),
//       targetWidth: 150, // Increase size here
//       targetHeight: 150,
//     );
//
//     final frame = await codec.getNextFrame();
//     final byteData = await frame.image.toByteData(
//       format: ui.ImageByteFormat.png,
//     );
//
//     if (byteData != null) {
//       final resizedBytes = byteData.buffer.asUint8List();
//       carIcon = BitmapDescriptor.fromBytes(resizedBytes);
//     } else {
//       throw Exception("Failed to convert car image to bytes");
//     }
//   }
//
//   Future<void> _initSocketAndLocation() async {
//     final joinedData = JoinedBookingData().getData();
//     if (joinedData != null) {
//       final customerLoc = joinedData['customerLocation'];
//       final fromLat = customerLoc['fromLatitude'];
//       final fromLng = customerLoc['fromLongitude'];
//       final toLat = customerLoc['toLatitude'];
//       final toLng = customerLoc['toLongitude'];
//       final String driverFullName = joinedData['driverName'] ?? '';
//       final String customerName = joinedData['customerName'] ?? '';
//
//       bookingFromLocation = LatLng(fromLat, fromLng);
//       bookingToLocation = LatLng(toLat, toLng);
//
//       final fromAddress = await getAddressFromLatLng(fromLat, fromLng);
//       final toAddress = await getAddressFromLatLng(toLat, toLng);
//
//       setState(() {
//         customerFrom = fromAddress;
//         customerTo = toAddress;
//         driverName = driverFullName;
//         custName = customerName;
//       });
//     }
//   }
//
//   Future<void> driverReachedDestination() async {
//     socketService = SocketService();
//     socketService.on('driver-reached-destination', (data) {
//       if (data['status'] == true) {
//         setState(() => driverCompletedRide = true);
//       }
//     });
//
//     socketService.on('driver-location', (data) {
//       if (data != null) {
//         driverStatusController.dropDistanceInMeters.value =
//             (data['dropDistanceInMeters'] ?? 0).toDouble();
//         driverStatusController.dropDurationInMin.value =
//             (data['dropDurationInMin'] ?? 0).toDouble();
//       }
//     });
//
//     socketService.socket.onAny((event, data) {
//       CommonLogger.log.i('📦 [onAny] $event: $data');
//     });
//
//     if (!socketService.connected) {
//       socketService.connect();
//       socketService.onConnect(() {
//         CommonLogger.log.i("✅ Socket connected");
//       });
//     }
//   }
//
//   Future<String> getAddressFromLatLng(double lat, double lng) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
//       Placemark place = placemarks[0];
//       return "${place.name}, ${place.locality}, ${place.administrativeArea}";
//     } catch (e) {
//       return "Location not available";
//     }
//   }
//
//   Future<void> updateRoute() async {
//     final result = await getRouteInfo(
//       origin: origin,
//       destination: bookingToLocation!,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       polylinePoints = decodePolyline(result['polyline']);
//     });
//   }
//
//   Future<void> loadRoute() async {
//     if (bookingFromLocation == null || bookingToLocation == null) return;
//
//     final result = await getRouteInfo(
//       origin: bookingFromLocation!,
//       destination: bookingToLocation!,
//     );
//
//     setState(() {
//       directionText = result['direction'];
//       distance = result['distance'];
//       polylinePoints = decodePolyline(result['polyline']);
//     });
//   }
//
//   @override
//   void dispose() {
//     positionStream?.cancel();
//     _autoFollowTimer?.cancel();
//     super.dispose();
//   }
//
//   String parseHtmlString(String htmlText) {
//     return htmlText
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&');
//   }
//
//   String maneuver = '';
//   void _goToCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//
//     final latLng = LatLng(position.latitude, position.longitude);
//
//     _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
//   }
//
//   String getManeuverIcon(maneuver) {
//     switch (maneuver) {
//       case "turn-right":
//         return 'assets/images/straight.png';
//       case "turn-left":
//         return 'assets/images/straight.png';
//       case "straight":
//         return 'assets/images/straight.png';
//       case "merge":
//         return 'assets/images/straight.png';
//       case "roundabout-left":
//         return 'assets/images/straight.png';
//       case "roundabout-right":
//         return 'assets/images/straight.png';
//       default:
//         return 'assets/images/straight.png';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return NoInternetOverlay(
//       child: Scaffold(
//         body: Stack(
//           children: [
//             SizedBox(
//               height: 650,
//               child: CommonGoogleMap(
//                 onCameraMove:
//                     (position) => _currentMapBearing = position.bearing,
//                 myLocationEnabled: false,
//                 onCameraMoveStarted: () {
//                   _userInteractingWithMap = true;
//                   _autoFollowEnabled = false;
//
//                   _autoFollowTimer?.cancel(); // cancel any existing timers
//
//                   // Start 10-second timer to re-enable auto-follow
//                   _autoFollowTimer = Timer(Duration(seconds: 10), () {
//                     _autoFollowEnabled = true;
//                     _userInteractingWithMap = false;
//                   });
//                 },
//
//                 // onMapCreated: () {
//                 //   String style = await DefaultAssetBundle.of(
//                 //     context,
//                 //   ).loadString('assets/map_style/map_style.json');
//                 //   _mapController!.setMapStyle(style);
//                 // },
//                 onMapCreated: (controller) async {
//                   _mapController = controller;
//
//                   String style = await DefaultAssetBundle.of(
//                     context,
//                   ).loadString('assets/map_style/map_style1.json');
//                   _mapController!.setMapStyle(style);
//
//                   // Wait briefly to ensure map is ready
//                   await Future.delayed(const Duration(milliseconds: 600));
//
//                   // Fit bounds (auto zoom)
//                   LatLngBounds bounds = LatLngBounds(
//                     southwest: LatLng(
//                       origin.latitude < destination.latitude
//                           ? origin.latitude
//                           : destination.latitude,
//                       origin.longitude < destination.longitude
//                           ? origin.longitude
//                           : destination.longitude,
//                     ),
//                     northeast: LatLng(
//                       origin.latitude > destination.latitude
//                           ? origin.latitude
//                           : destination.latitude,
//                       origin.longitude > destination.longitude
//                           ? origin.longitude
//                           : destination.longitude,
//                     ),
//                   );
//                   _mapController!.animateCamera(
//                     CameraUpdate.newLatLngBounds(bounds, 60),
//                   );
//                 },
//
//                 // initialPosition: origin,
//                 // markers: {
//                 //   Marker(markerId: MarkerId('start'), position: origin),
//                 //   Marker(markerId: MarkerId('end'), position: destination),
//                 // },
//                 initialPosition: bookingFromLocation ?? LatLng(0, 0),
//                 markers: {
//                   if (_movingMarker != null)
//                     _movingMarker!
//                   else if (bookingFromLocation != null)
//                     Marker(
//                       markerId: MarkerId('start'),
//                       position: bookingFromLocation!,
//                       icon: carIcon,
//                     ),
//                   if (bookingToLocation != null)
//                     Marker(
//                       markerId: MarkerId('end'),
//                       position: bookingToLocation!,
//                     ),
//                 },
//                 polylines: {
//                   Polyline(
//                     polylineId: PolylineId("route"),
//                     color: AppColors.commonBlack,
//                     width: 5,
//                     points: polylinePoints,
//                   ),
//                 },
//               ),
//             ),
//
//             Positioned(
//               top: driverCompletedRide ? 550 : 450,
//               right: 10,
//               child: Column(
//                 children: [
//                   FloatingActionButton(
//                     mini: true,
//                     backgroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     onPressed: _goToCurrentLocation,
//                     child: const Icon(Icons.my_location, color: Colors.black),
//                   ),
//                 ],
//               ),
//             ),
//
//             Positioned(
//               top: 45,
//               left: 10,
//               right: 10,
//               child: Row(
//                 children: [
//                   Expanded(
//                     flex: 1,
//                     child: Container(
//                       height: 100,
//
//                       color: AppColors.directionColor,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 20,
//                           horizontal: 10,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             Image.asset(
//                               getManeuverIcon(maneuver),
//                               height: 32,
//                               width: 32,
//                             ),
//
//                             SizedBox(height: 5),
//                             CustomTextfield.textWithStyles600(
//                               distance,
//                               color: AppColors.commonWhite,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     flex: 3,
//                     child: Container(
//                       height: 100,
//                       color: AppColors.directionColor1,
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 20,
//                           horizontal: 10,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.center,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               maxLine: 2,
//                               '${parseHtmlString(directionText)}',
//                               fontSize: 13,
//                               color: AppColors.commonWhite,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             DraggableScrollableSheet(
//               initialChildSize: driverCompletedRide ? 0.28 : 0.75,
//               minChildSize: driverCompletedRide ? 0.25 : 0.40,
//               maxChildSize:
//                   driverCompletedRide
//                       ? 0.30
//                       : 0.75, // Can expand up to 95% height
//               // initialChildSize:  0.80, // Start with 80% height
//               // minChildSize: 0.5, // Can collapse to 40%
//               // maxChildSize: 0.80, // Can expand up to 95% height
//               builder: (context, scrollController) {
//                 return Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     // borderRadius: BorderRadius.only(
//                     //   topLeft: Radius.circular(30),
//                     //   topRight: Radius.circular(30),
//                     // ),
//                   ),
//                   child: ListView(
//                     controller: scrollController,
//                     children: [
//                       Center(
//                         child: Container(
//                           width: 60,
//                           height: 5,
//
//                           decoration: BoxDecoration(
//                             color: Colors.grey[400],
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//                       if (!driverCompletedRide) ...[
//                         Container(
//                           decoration: BoxDecoration(
//                             color: AppColors.rideInProgress.withOpacity(0.1),
//                           ),
//                           child: Padding(
//                             padding: const EdgeInsets.all(15),
//                             child: Center(
//                               child: CustomTextfield.textWithStyles600(
//                                 fontSize: 14,
//                                 color: AppColors.rideInProgress,
//                                 'Ride in Progress',
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         /* Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Obx(
//                               () => CustomTextfield.textWithStyles600(
//                                 formatDuration(
//                                   driverStatusController.dropDurationInMin.value
//                                       .toInt(), // ✅ FIXED
//                                 ),
//                                 fontSize: 20,
//                               ),
//                             ),
//                             const SizedBox(width: 10),
//                             Icon(
//                               Icons.circle,
//                               color: AppColors.drkGreen,
//                               size: 10,
//                             ),
//                             const SizedBox(width: 10),
//                             Obx(
//                               () => CustomTextfield.textWithStyles600(
//                                 formatDistance(
//                                   driverStatusController
//                                       .dropDistanceInMeters
//                                       .value,
//                                 ),
//                                 fontSize: 20,
//                               ),
//                             ),
//                           ],
//                         ),*/
//
//                         /*               Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             CustomTextfield.textWithStyles600(
//                               '16 min',
//                               fontSize: 20,
//                             ),
//                             SizedBox(width: 10),
//                             Icon(
//                               Icons.circle,
//                               color: AppColors.drkGreen,
//                               size: 10,
//                             ),
//                             SizedBox(width: 10),
//                             CustomTextfield.textWithStyles600(
//                               '2.3 Km',
//                               fontSize: 20,
//                             ),
//                           ],
//                         ),*/
//                         Center(
//                           child: CustomTextfield.textWithStylesSmall(
//                             'Dropping off $custName',
//                           ),
//                         ),
//
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 20),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 15,
//                                 ),
//                                 child: CustomTextfield.textWithStyles600(
//                                   'Ride Details',
//                                   fontSize: 16,
//                                 ),
//                               ),
//                               const SizedBox(height: 20),
//                               Row(
//                                 children: [
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(40),
//                                       color: AppColors.commonBlack.withOpacity(
//                                         0.1,
//                                       ),
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(4),
//                                       child: Icon(
//                                         Icons.circle,
//                                         color: AppColors.grey,
//                                         size: 10,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         CustomTextfield.textWithStyles600(
//                                           color: AppColors.commonBlack
//                                               .withOpacity(0.5),
//                                           fontSize: 16,
//                                           'Pickup',
//                                         ),
//                                         CustomTextfield.textWithStylesSmall(
//                                           colors: AppColors.textColorGrey,
//                                           customerFrom,
//                                           maxLine: 2,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 20),
//                               Row(
//                                 children: [
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(40),
//                                       color: AppColors.commonBlack.withOpacity(
//                                         0.1,
//                                       ),
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(4),
//                                       child: Icon(
//                                         Icons.circle,
//                                         color: AppColors.commonBlack,
//                                         size: 10,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(width: 20),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         CustomTextfield.textWithStyles600(
//                                           fontSize: 16,
//                                           'Drop off - Constitution Ave',
//                                         ),
//                                         CustomTextfield.textWithStylesSmall(
//                                           colors: AppColors.textColorGrey,
//                                           customerTo,
//                                           maxLine: 2,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               SizedBox(height: 20),
//                               GestureDetector(
//                                 onTap: () {
//                                   setState(() {
//                                     driverCompletedRide = !driverCompletedRide;
//                                   });
//                                 },
//                                 child: Row(
//                                   children: [
//                                     Image.asset(
//                                       AppImages.dummyImg,
//                                       height: 45,
//                                       width: 45,
//                                     ),
//                                     SizedBox(width: 15),
//                                     CustomTextfield.textWithStyles600(
//                                       custName,
//                                       fontSize: 20,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               const SizedBox(height: 15),
//                               Container(
//                                 decoration: BoxDecoration(
//                                   color: AppColors.containerColor1,
//                                 ),
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 30,
//                                     vertical: 10,
//                                   ),
//                                   child: Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       CustomTextfield.textWithImage(
//                                         colors: AppColors.commonBlack,
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 12,
//                                         text: 'Get Help',
//                                         imagePath: AppImages.getHelp,
//                                       ),
//                                       SizedBox(
//                                         height: 20,
//                                         child: VerticalDivider(),
//                                       ),
//                                       CustomTextfield.textWithImage(
//                                         colors: AppColors.commonBlack,
//                                         fontWeight: FontWeight.w500,
//                                         fontSize: 12,
//                                         text: 'Share Trip Status',
//                                         imagePath: AppImages.share,
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(height: 20),
//                               Buttons.button(
//                                 borderColor: AppColors.buttonBorder,
//                                 buttonColor: AppColors.commonWhite,
//                                 borderRadius: 8,
//
//                                 textColor: AppColors.commonBlack,
//
//                                 onTap: () {
//                                   Buttons.showDialogBox(context: context);
//                                 },
//                                 text: Text('Stop New Ride Request'),
//                               ),
//                               SizedBox(height: 10),
//                               Buttons.button(
//                                 borderRadius: 8,
//
//                                 buttonColor: AppColors.red,
//
//                                 onTap: () {
//                                   Buttons.showCancelRideBottomSheet(
//                                     context,
//                                     onConfirmCancel: (reason) {},
//                                   );
//                                 },
//                                 text: Text('Cancel this Ride'),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ] else ...[
//                         Column(
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.circle,
//                                   color: AppColors.drkGreen,
//                                   size: 13,
//                                 ),
//                                 SizedBox(width: 10),
//                                 CustomTextfield.textWithStyles600(
//                                   '1 min away',
//                                   fontSize: 20,
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 10),
//                             CustomTextfield.textWithStylesSmall(
//                               fontWeight: FontWeight.w500,
//                               'Dropping off Rebecca',
//                             ),
//                             const SizedBox(height: 5),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 20,
//                                 vertical: 10,
//                               ),
//                               child: ActionSlider.standard(
//                                 action: (controller) async {
//                                   controller.loading();
//
//                                   await Future.delayed(
//                                     const Duration(seconds: 1),
//                                   );
//                                   final message = await driverStatusController
//                                       .completeRideRequest(
//                                         context,
//                                         Amount: '',
//                                         bookingId: widget.bookingId,
//                                       );
//
//                                   if (message != null) {
//                                     controller.success();
//
//                                     // ScaffoldMessenger.of(context).showSnackBar(
//                                     //   SnackBar(content: Text(message)),
//                                     // );
//                                   } else {
//                                     controller.failure();
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text('Failed to start ride'),
//                                       ),
//                                     );
//                                   }
//
//                                   await Future.delayed(
//                                     const Duration(milliseconds: 300),
//                                   );
//
//                                   // Navigate to the next screen
//                                   // Navigator.push(
//                                   //   context,
//                                   //   MaterialPageRoute(
//                                   //     builder:
//                                   //         (context) => CashCollectedScreen(),
//                                   //   ), // replace with your widget
//                                   // );
//                                 },
//
//                                 height: 50,
//                                 backgroundColor: AppColors.drkGreen,
//                                 toggleColor: Colors.white,
//                                 icon: Icon(
//                                   Icons.double_arrow,
//                                   color: AppColors.drkGreen,
//                                   size: 28,
//                                 ),
//                                 child: const Text(
//                                   'Complete Ride',
//                                   style: TextStyle(
//                                     color: AppColors.commonWhite,
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 // action: (controller) async {
//                                 //   controller.loading();
//                                 //   await Future.delayed(
//                                 //     const Duration(seconds: 3),
//                                 //   );
//                                 //   controller.success();
//                                 // },
//                               ),
//                             ),
//                             const SizedBox(height: 10),
//                           ],
//                         ),
//                       ],
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

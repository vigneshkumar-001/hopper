import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopper/utils/map/shared_map.dart';

import 'map_ui_config.dart';
import 'ride_map_controller.dart';

class RideMapView extends StatefulWidget {
  const RideMapView({
    super.key,
    required this.controller,
    required this.initialPosition,
    this.mapStyle,
    this.myLocationEnabled = false,
    this.fitToBounds = false,
    this.trafficEnabled = false,
    this.compassEnabled = false,
    this.extraMarkers = const <Marker>{},
    this.extraPolylines = const <Polyline>{},
    this.extraCircles = const <Circle>{},
    this.onMapCreated,
    this.onUserCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  final RideMapController controller;
  final LatLng initialPosition;
  final String? mapStyle;

  final bool myLocationEnabled;
  final bool fitToBounds;
  final bool trafficEnabled;
  final bool compassEnabled;

  final Set<Marker> extraMarkers;
  final Set<Polyline> extraPolylines;
  final Set<Circle> extraCircles;

  final ValueChanged<GoogleMapController>? onMapCreated;
  final VoidCallback? onUserCameraMoveStarted;
  final ValueChanged<CameraPosition>? onCameraMove;
  final VoidCallback? onCameraIdle;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<RideMapView> createState() => _RideMapViewState();
}

class _RideMapViewState extends State<RideMapView> {
  static const LatLng _kDefaultCityFallback = LatLng(9.914, 78.097);

  static bool _isProbablyInvalidLatLng(LatLng p) {
    // Many flows previously passed (0,0) or stale placeholders; that shows a
    // "blank blue/ocean" map. Treat it as invalid and fall back.
    return p.latitude.abs() < 0.0001 && p.longitude.abs() < 0.0001;
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    // For pickup screen, keep Google attribution closer to the bottom edge
    // (still visible above the bottom sheet) to match user expectation and
    // remain branding-compliant.
    // Keep Google attribution as low as possible while ensuring it stays above
    // the bottom sheet (branding-compliant: visible, not obscured).
    final bottomExtra =
        widget.controller.mode == RideMapMode.pickupNavigation ? 8.0 : MapUiConfig.mapBottomExtraPadding;
    final padding = EdgeInsets.fromLTRB(
      MapUiConfig.mapSidePadding,
      mediaPadding.top + MapUiConfig.mapTopPadding,
      MapUiConfig.mapSidePadding,
      mediaPadding.bottom +
          widget.controller.bottomSheetHeight +
          bottomExtra,
    );

    return ValueListenableBuilder<Set<Marker>>(
      valueListenable: widget.controller.markers,
      builder: (context, baseMarkers, _) {
        return ValueListenableBuilder<Set<Polyline>>(
          valueListenable: widget.controller.polylines,
          builder: (context, basePolys, __) {
            return ValueListenableBuilder<Set<Marker>>(
              valueListenable: widget.controller.overlayMarkers,
              builder: (context, overlayMarkers, ___) {
                return ValueListenableBuilder<Set<Polyline>>(
                  valueListenable: widget.controller.overlayPolylines,
                  builder: (context, overlayPolys, ____) {
                    return ValueListenableBuilder<Set<Circle>>(
                      valueListenable: widget.controller.overlayCircles,
                      builder: (context, overlayCircles, _____) {
                        final markers = <Marker>{
                          ...baseMarkers,
                          ...overlayMarkers,
                          ...widget.extraMarkers,
                        };
                        final polylines = <Polyline>{
                          ...basePolys,
                          ...overlayPolys,
                          ...widget.extraPolylines,
                        };

                        // In navigation modes we use pickup indicator to highlight current target.
                        final pickupPulseTarget =
                            widget.controller.dropPosition ??
                            widget.controller.pickupPosition;

                        final initial = widget.controller.lastVehiclePosition ??
                            widget.controller.navigationDestination ??
                            widget.controller.pickupPosition ??
                            widget.controller.dropPosition ??
                            widget.initialPosition;
                        final initialPos =
                            _isProbablyInvalidLatLng(initial) ? _kDefaultCityFallback : initial;

                        final styleForMap =
                            widget.controller.mode == RideMapMode.home
                                ? widget.mapStyle
                                : null;

                        return SharedMap(
                          initialPosition: initialPos,
                          initialZoom:
                              widget.controller.mode == RideMapMode.home
                                  ? MapUiConfig.defaultZoom
                                  : MapUiConfig.navigationZoom,
                          // Prefer RideMapController-applied style for all ride flows.
                          // Passing a style string here can override controller.setMapStyle
                          // in some plugin versions.
                          mapStyle: styleForMap,
                          autoLoadMapStyle:
                              widget.controller.mode == RideMapMode.home,
                          padding: padding,
                          pickupPosition: pickupPulseTarget,
                          pickupIndicatorStyle:
                              pickupPulseTarget == null
                                  ? PickupIndicatorStyle.none
                                  : PickupIndicatorStyle.pulse,
                          pickupIndicatorColor: const Color(0xFF00A85E),
                          pickupTargetColor: Colors.black,
                           myLocationEnabled: widget.myLocationEnabled,
                           fitToBounds: widget.fitToBounds,
                           trafficEnabled: widget.trafficEnabled,
                           compassEnabled:
                               widget.compassEnabled ||
                               widget.controller.cameraBearingEnabledNow,
                           markers: markers,
                           polylines: polylines,
                            circles: <Circle>{...overlayCircles, ...widget.extraCircles},
                            followDriver: widget.controller.autoFollowEnabled,
                            followBearingEnabled: widget.controller.cameraBearingEnabledNow,
                           followZoom:
                               widget.controller.mode == RideMapMode.home
                                   ? MapUiConfig.defaultZoom
                                   : widget.controller.navigationFollowZoom
                                      .clamp(16.5, 18.0),
                          followTilt:
                              widget.controller.mode == RideMapMode.home
                                  ? 0.0
                                  : MapUiConfig.cameraTilt,
                          onCameraMoveStarted: widget.onUserCameraMoveStarted,
                          onCameraMove: widget.onCameraMove,
                          onCameraIdle: widget.onCameraIdle,
                          onMapCreated: (gm) {
                            widget.controller.attachMapController(gm);
                            widget.onMapCreated?.call(gm);
                          },
                          gestureRecognizers: widget.gestureRecognizers,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/models.dart';
import 'package:vasttrafik_nara/stop_page.dart';

class MapPage extends StatefulWidget {
  final Line line;
  final JourneyDetail detail;
  final String lineDirection;

  const MapPage(
      {super.key,
      required this.line,
      required this.lineDirection,
      required this.detail});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  DateTime? lastUpdated;
  LivePosition? vehiclePosition;
  var mapController = MapController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      this.setState(() {
        // To change bus indicator even if no new data is available
        this.lastUpdated = DateTime.now();
      });
      fetchData();
    });
    trackEvent('Page Shown', {
      'Page Name': 'Map',
    });
  }

  @override
  dispose() {
    super.dispose();
    timer?.cancel();
  }

  fetchData() async {
    // final lowerLeft = Coordinate(
    //   widget.stops.map((e) => e.stop.lat).reduce((a, b) => a < b ? a : b),
    //   widget.stops.map((e) => e.stop.lon).reduce((a, b) => a < b ? a : b),
    // );
    // final upperRight = Coordinate(
    //   widget.stops.map((e) => e.stop.lat).reduce((a, b) => a > b ? a : b),
    //   widget.stops.map((e) => e.stop.lon).reduce((a, b) => a > b ? a : b),
    // );
    if (Env.useAltCredentials) {
      final pos = await vasttrafikApi
          .getRealtimeVehiclePosition(widget.detail.journeyGid);
      if (this.mounted) {
        this.setState(() {
          this.vehiclePosition = pos;
        });
      }
    } else {
      final res =
          await vasttrafikApi.getVehiclePosition(widget.detail.journeyRef);
      if (this.mounted) {
        this.setState(() {
          this.vehiclePosition = res;
        });
      }
    }
  }

  Widget buildOpenStreetMap() {
    final stopCoords = widget.detail.stops
        .map((e) => LatLng(e.stopArea.lat, e.stopArea.lon))
        .toList();
    final journeyCoords = widget.detail.coordinates
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();
    final isRecent = this.vehiclePosition != null &&
        this
            .vehiclePosition!
            .updatedAt
            .isAfter(DateTime.now().subtract(Duration(minutes: 2)));
    var initial = CameraFit.coordinates(
        coordinates: stopCoords,
        padding: EdgeInsets.only(top: 20, bottom: 50, left: 20, right: 20));
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCameraFit: initial),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'vasttrafik_nara.flown.io',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              strokeWidth: 7,
              points: journeyCoords,
              color: convertHexToColor(widget.line.bgColor),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            ...stopCoords.asMap().entries.map((it) {
              final stop = widget.detail.stops[it.key];
              return Marker(
                point: it.value,
                height: 12,
                width: 12,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StopPage(stop: stop.stopArea),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: convertHexToColor(widget.line.bgColor),
                        width: 2,
                      ),
                      color: convertHexToColor(widget.line.fgColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        CurrentLocationLayer(),
        if (this.vehiclePosition != null)
          AnimatedLocationMarkerLayer(
              style: LocationMarkerStyle(
                markerSize: Size(30, 30),
                marker: Container(
                  decoration: BoxDecoration(
                    color: convertHexToColor(widget.line.bgColor),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: isRecent
                      ? Icon(
                          Icons.train,
                          color: convertHexToColor(widget.line.fgColor),
                        )
                      : CupertinoActivityIndicator(
                          color: convertHexToColor(widget.line.fgColor),
                        ),
                ),
              ),
              position: LocationMarkerPosition(
                latitude: vehiclePosition!.lat,
                longitude: vehiclePosition!.lon,
                accuracy: 0,
              )),
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 20,
                bottom: 20,
                child: Wrap(
                  spacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final position = await getCurrentLocation(context)
                              .timeout(Duration(seconds: 5));
                          mapController.move(
                              LatLng(position.latitude, position.longitude),
                              16);
                        } catch (err) {
                          print('Location error');
                        }
                      },
                      child: const Icon(
                        Icons.my_location,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        mapController.fitCamera(initial);
                      },
                      child: const Icon(
                        Icons.polyline,
                      ),
                    ),
                    if (vehiclePosition != null)
                      ElevatedButton(
                        onPressed: () async {
                          mapController.move(
                              LatLng(
                                  vehiclePosition!.lat, vehiclePosition!.lon),
                              16);
                        },
                        child: const Icon(
                          Icons.train,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.line.name + ' ' + widget.lineDirection,
        ),
      ),
      body: buildOpenStreetMap(),
    );
  }
}

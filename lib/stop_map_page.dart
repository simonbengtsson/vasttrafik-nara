import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/home_page.dart';
import 'package:vasttrafik_nara/journey_page.dart';
import 'package:vasttrafik_nara/models.dart';

class StopMapPage extends StatefulWidget {
  final StopArea stop;

  const StopMapPage({super.key, required this.stop});

  @override
  State<StopMapPage> createState() => _MapPageState();
}

class _MapPageState extends State<StopMapPage> {
  StopAreaDetail? stopDetail;
  List<LivePosition> vehiclePositions = [];
  var mapController = MapController();
  Timer? timer;

  var mostRecentTimer = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetch();
    timer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      fetchData();
    });
    trackEvent('Page Shown', {
      'Page Name': 'Stop Map',
    });
  }

  @override
  dispose() {
    super.dispose();
    timer?.cancel();
  }

  fetch() async {
    var res = await vasttrafikApi.stopAreaDetail(widget.stop.id);
    if (mounted) {
      setState(() {
        stopDetail = res;
      });
      mapController.move(LatLng(res.lat, res.lon), 17);
    }
  }

  fetchData() async {
    var before = DateTime.now();
    final lowerLeft = Coordinate(
      mapController.camera.visibleBounds.southWest.latitude,
      mapController.camera.visibleBounds.southWest.longitude,
    );
    final upperRight = Coordinate(
      mapController.camera.visibleBounds.northWest.latitude,
      mapController.camera.visibleBounds.northEast.longitude,
    );
    final pos = await vasttrafikApi.getAllVehicles(lowerLeft, upperRight);
    if (this.mounted && before.isAfter(mostRecentTimer)) {
      mostRecentTimer = before;
      this.setState(() {
        this.vehiclePositions = pos;
      });
    }
  }

  Widget buildOpenStreetMap() {
    final stopPoints = stopDetail?.stopPoints ?? [];
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
          initialCenter:
              LatLng(defaultLocation.latitude, defaultLocation.longitude),
          initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'vasttrafik_nara.flown.io',
        ),
        MarkerLayer(
          markers: [
            ...stopPoints.asMap().entries.map((point) {
              return Marker(
                rotate: true,
                point: LatLng(point.value.lat, point.value.lon),
                child: Container(
                  child: Center(
                      child: Text(
                    point.value.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }),
          ],
        ),
        CurrentLocationLayer(),
        for (var vehiclePosition in vehiclePositions)
          AnimatedLocationMarkerLayer(
            key: ValueKey(vehiclePosition.journeyRef),
            style: LocationMarkerStyle(
              markerSize: Size(30, 30),
              marker: InkWell(
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => JourneyPage(
                            vehiclePosition.line,
                            vehiclePosition.lineDirection,
                            vehiclePosition.journeyRef)),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: convertHexToColor(vehiclePosition.bgColor),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                      child: Text(vehiclePosition.lineName,
                          style: TextStyle(
                              color:
                                  convertHexToColor(vehiclePosition.fbColor)))),
                ),
              ),
            ),
            position: LocationMarkerPosition(
              latitude: vehiclePosition.lat,
              longitude: vehiclePosition.lon,
              accuracy: 0,
            ),
          ),
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
                        if (stopPoints.isNotEmpty) {
                          final coords = stopPoints
                              .map((e) => LatLng(e.lat, e.lon))
                              .toList();
                          mapController.fitCamera(
                            CameraFit.coordinates(
                                padding: EdgeInsets.all(40),
                                coordinates: coords,
                                minZoom: 16),
                          );
                        } else {
                          mapController.move(
                              LatLng(widget.stop.lat, widget.stop.lon), 16);
                        }
                      },
                      child: const Icon(
                        Icons.location_on,
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
          this.widget.stop.name,
        ),
      ),
      body: buildOpenStreetMap(),
    );
  }
}

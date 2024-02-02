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
  final Stop stop;

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
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
          initialCenter:
              LatLng(gothenburgLocation.latitude, gothenburgLocation.longitude),
          initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'vasttrafik_nara.flown.io',
        ),
        MarkerLayer(
          markers: [
            ...(stopDetail?.stopPoints ?? []).asMap().entries.map((point) {
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
            key: ValueKey(vehiclePosition.detailsReference),
            style: LocationMarkerStyle(
              markerSize: Size(30, 30),
              marker: InkWell(
                onTap: () async {
                  var journey = await vasttrafikApi.getJourneyDetails(
                      '', vehiclePosition.detailsReference);
                  var stops = journey.stops
                      .where((it) =>
                          it.departureTime != null &&
                          it.departureTime!.isAfter(DateTime.now()))
                      .toList();
                  stops.sort(
                      (a, b) => a.departureTime!.compareTo(b.departureTime!));
                  var nextStopId = stops.first.stop.id;
                  var departures =
                      await vasttrafikApi.getDepartures(nextStopId);
                  var depart = departures
                      .where((it) =>
                          it.journeyRefId == vehiclePosition.detailsReference)
                      .toList()
                      .firstOrNull;
                  if (depart == null) {
                    print('Why sometimes null here? Last stop?');
                    return;
                  }
                  // Find next stop point and its area
                  // Fetch departures and find for this line
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => JourneyPage(depart)),
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
                        if (stopDetail != null) {
                          mapController.move(
                              LatLng(stopDetail!.lat, stopDetail!.lon), 17);
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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class MapPage extends StatefulWidget {
  final Journey journey;
  final List<JourneyStop> stops;

  const MapPage({super.key, required this.journey, required this.stops});

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
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      this.setState(() {
        // To change bus indicator even if no new data is available
        this.lastUpdated = DateTime.now();
      });
      fetchData();
    });
    mixpanelInstance.track('Page Shown', properties: {
      'Page Name': 'Map',
    });
  }

  @override
  dispose() {
    super.dispose();
    timer?.cancel();
  }

  fetchData() async {
    final pos = await vasttrafikApi.vehiclePosition(widget.journey.journeyGid);
    if (this.mounted) {
      this.setState(() {
        this.vehiclePosition = pos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coords =
        widget.stops.map((e) => LatLng(e.stop.lat, e.stop.lon)).toList();
    final vehiclePosition = LatLng(
        this.vehiclePosition?.lat ?? coords.first.latitude,
        this.vehiclePosition?.lon ?? coords.first.longitude);
    final isRecent = this.vehiclePosition != null &&
        this
            .vehiclePosition!
            .updatedAt
            .isAfter(DateTime.now().subtract(Duration(minutes: 2)));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.journey.shortName + ' ' + widget.journey.direction,
        ),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
                coordinates: coords, padding: EdgeInsets.all(20))),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'vasttrafik_nara.flown.io',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                strokeWidth: 7,
                points: coords,
                color: widget.journey.bgColor,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              ...coords.asMap().entries.map((it) {
                final isLastOrFirst =
                    it.key == coords.length - 1 || it.key == 0;
                return Marker(
                  point: it.value,
                  height: isLastOrFirst ? 12 : 7,
                  width: isLastOrFirst ? 12 : 7,
                  child: Tooltip(
                    message: widget.stops[it.key].stop.name,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.journey.fgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }),
              Marker(
                rotate: true,
                point: vehiclePosition,
                child: Container(
                  decoration: BoxDecoration(
                    color: isRecent
                        ? widget.journey.bgColor
                        : widget.journey.fgColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: isRecent
                      ? Icon(
                          Icons.train,
                          color: widget.journey.fgColor,
                        )
                      : CupertinoActivityIndicator(
                          color: widget.journey.bgColor,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

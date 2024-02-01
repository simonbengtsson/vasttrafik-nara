import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/map_page.dart';
import 'package:vasttrafik_nara/stop_page.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyPage extends StatefulWidget {
  final Journey journey;

  JourneyPage(this.journey);

  @override
  createState() => _JourneyPageState(this.journey);
}

class _JourneyPageState extends State<JourneyPage> {
  Journey journey;
  List<JourneyStop> stops = [];
  ScrollController? _scrollController;

  bool loading = true;

  _JourneyPageState(this.journey);

  @override
  initState() {
    super.initState();
    fetchData().then((item) {
      mixpanelInstance.track('Page Shown', properties: {
        'Page Name': 'Journey',
        'Journey Name': journey.name,
        'Journey Direction': journey.direction,
        'Journey Id': journey.journeyRefId,
        'Shown Stop Count': item.length
      });
    });
  }

  Future<List<JourneyStop>> fetchData() async {
    var ref = this.journey.journeyRefId;
    var stops = await vasttrafikApi.getJourneyStops(ref);

    if (this.mounted) {
      this.setState(() {
        this.stops = stops;
        this.loading = false;
      });
    }

    return stops;
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = this.journey.bgColor;
    var lum = bgColor.computeLuminance();

    var stopIndex = this
        .stops
        .indexWhere((stop) => stop.stopPointId == this.journey.stopId);
    this._scrollController =
        ScrollController(initialScrollOffset: stopIndex * 56.0);

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var listView = loading
        ? loader
        : ListView.builder(
            itemCount: this.stops.length,
            controller: this._scrollController,
            itemBuilder: (context, index) {
              final stop = this.stops[index];
              var isActive = stop.stopPointId == this.journey.stopId;
              var time = '';
              var depTime = stop.departureTime;
              if (depTime != null) {
                time = formatDepartureTime(depTime, false);
              }
              var style = TextStyle(
                fontSize: 18.0,
                color: isActive
                    ? Colors.black
                    : Colors.black.withOpacity(index < stopIndex ? 0.3 : 0.8),
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              );

              return Container(
                  child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StopPage(stop: stop.stop),
                    ),
                  );
                },
                selected: isActive,
                title: Text(stop.stop.name, style: style),
                trailing: Text(time, style: style),
              ));
            });

    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgColor,
          systemOverlayStyle: lum < 0.7
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          iconTheme: IconThemeData(color: this.journey.fgColor),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'Map',
              onPressed: stops.isEmpty
                  ? null
                  : () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MapPage(journey: widget.journey, stops: stops),
                        ),
                      );
                    },
            ),
          ],
          title: Text(this.journey.shortName + ' ' + this.journey.direction,
              style: TextStyle(color: this.journey.fgColor)),
        ),
        body: listView);
  }
}

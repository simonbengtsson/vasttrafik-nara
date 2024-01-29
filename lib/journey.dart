import 'package:vasttrafik_nara/stop.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyScreen extends StatefulWidget {
  final Departure departure;

  JourneyScreen(this.departure);

  @override
  createState() => _JourneyScreenState(this.departure);
}

class _JourneyScreenState extends State<JourneyScreen> {
  Departure departure;
  List<Stop> stops = [];
  ScrollController? _scrollController;

  bool loading = true;

  _JourneyScreenState(this.departure);

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var ref = this.departure.journeyId;
    var journey = await api.getJourney(ref);

    if (this.mounted) {
      this.setState(() {
        this.stops = journey.stops;
        this.loading = false;
      });
    }
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    Color fgColor = this.departure.fgColor;
    var lum = fgColor.computeLuminance();

    var stopIndex =
        this.stops.indexWhere((stop) => stop.id == this.departure.stopId);
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
              var style = TextStyle(
                fontSize: 18.0,
                color: stop.id == this.departure.stopId
                    ? Colors.black
                    : Colors.black.withOpacity(index < stopIndex ? 0.3 : 0.8),
                fontWeight: stop.id == this.departure.stopId
                    ? FontWeight.w900
                    : FontWeight.w500,
              );

              return Container(
                  child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => StopPage(stop: stop)),
                  );
                },
                selected: stop.id == this.departure.stopId,
                title: Text(stop.name, style: style),
                trailing: Text(stop.name, style: style),
              ));
            });

    var name = this.departure.shortName + ' ' + this.departure.direction;
    return Scaffold(
        appBar: AppBar(
          backgroundColor: fgColor,
          systemOverlayStyle: lum < 0.7
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: this.departure.bgColor),
          title: Text(name, style: TextStyle(color: this.departure.bgColor)),
        ),
        body: listView);
  }
}

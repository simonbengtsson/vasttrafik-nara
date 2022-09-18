import 'package:vasttrafik_nara/stop.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyScreen extends StatefulWidget {
  final Map<String, dynamic> departure;

  JourneyScreen(this.departure);

  @override
  createState() => _JourneyScreenState(this.departure);
}

class _JourneyScreenState extends State<JourneyScreen> {
  Map<String, dynamic> departure;
  List<Stop> stops = [];
  ScrollController? _scrollController;

  _JourneyScreenState(this.departure);

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var ref = this.departure['JourneyDetailRef']['ref'];
    var journey = await api.getJourney(ref);

    if (this.mounted) {
      this.setState(() {
        List raw = journey['Stop'];
        var stops = List<Stop>.from(raw.map((it) => Stop(it)));
        this.stops = stops;
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
    Color fgColor = hexColor(this.departure['fgColor']);
    var lum = fgColor.computeLuminance();

    var stopIndex =
        this.stops.indexWhere((stop) => stop.id == this.departure['stopid']);
    this._scrollController =
        ScrollController(initialScrollOffset: stopIndex * 56.0);

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var listView = stopIndex < 0
        ? loader
        : ListView.builder(
            itemCount: this.stops.length,
            controller: this._scrollController,
            itemBuilder: (context, index) {
              final stop = this.stops[index];
              var style = TextStyle(
                fontSize: 18.0,
                color: stop.id == this.departure['stopid']
                    ? Colors.black
                    : Colors.black.withOpacity(index < stopIndex ? 0.3 : 0.8),
                fontWeight: stop.id == this.departure['stopid']
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
                selected: stop.id == this.departure['stopid'],
                title: Text(stop.name, style: style),
                trailing: Text(stop.departureTime, style: style),
              ));
            });

    var name = this.departure['sname'] + ' ' + this.departure['direction'];
    return Scaffold(
        appBar: AppBar(
          backgroundColor: fgColor,
          systemOverlayStyle: lum < 0.7
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: hexColor(this.departure['bgColor'])),
          title: Text(name,
              style: TextStyle(color: hexColor(this.departure['bgColor']))),
        ),
        body: listView);
  }
}

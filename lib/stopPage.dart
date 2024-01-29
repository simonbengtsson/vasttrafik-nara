import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/journeyPage.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class StopPage extends StatefulWidget {
  StopPage({Key? key, required this.stop}) : super(key: key);

  final Stop stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {
  List<Journey> departures = [];
  List<Stop> nextStops = [];

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);

    var stopId = this.widget.stop.id;
    var departs = await api.getDepartures(stopId);
    departs.sort((a, b) {
      return a.date.compareTo(b.date);
    });

    if (mounted) {
      this.setState(() {
        this.departures = departs;
      });
    }
  }

  Widget buildItem(Journey departure) {
    var subtitle = departure.track == null ? '' : 'Läge ${departure.track}';
    var direction = departure.direction;
    final viaIndex = direction.indexOf(' via ');
    if (viaIndex > 0) {
      var via = direction.substring(viaIndex, direction.length).trim();
      subtitle = [subtitle, via].join(' • ');
      direction = direction.substring(0, viaIndex).trim();
    }

    var textStyle = TextStyle(
        color: departure.bgColor, fontSize: 18.0, fontWeight: FontWeight.bold);
    return Container(
        decoration: BoxDecoration(
          color: departure.fgColor,
        ),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JourneyPage(departure)),
            );
          },
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(departure.shortName, style: textStyle)],
          ),
          minLeadingWidth: 60,
          title: Text(direction, style: textStyle),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, style: TextStyle(color: departure.bgColor)),
          trailing: Text(departure.time, style: textStyle),
        ));
  }

  @override
  Widget build(BuildContext context) {
    this.nextStops.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    return Scaffold(
      appBar: AppBar(
        title: Text(this.widget.stop.name),
        actions: [],
      ),
      body: this.departures.length == 0
          ? loader
          : ListView.builder(
              itemCount: departures.length,
              itemBuilder: (context, index) {
                final item = departures[index];
                return buildItem(item);
              }),
    );
  }
}

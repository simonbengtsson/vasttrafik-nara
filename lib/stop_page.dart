import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/journey_page.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class StopPage extends StatefulWidget {
  StopPage({Key? key, required this.stop}) : super(key: key);

  final Stop stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {
  List<Journey> journeys = [];

  @override
  initState() {
    super.initState();
    fetchData().then((list) {
      mixpanelInstance.track('Page Shown', properties: {
        'Page Name': 'Stop',
        'Stop Name': widget.stop.name,
        'Stop Id': widget.stop.id,
        'Shown Journey Count': list.length,
      });
    });
  }

  Future<List<Journey>> fetchData() async {
    var stopId = this.widget.stop.id;
    var journeys = await vasttrafikApi.getDepartures(stopId);
    journeys.sort((a, b) {
      return a.date.compareTo(b.date);
    });

    if (mounted) {
      this.setState(() {
        this.journeys = journeys;
      });
    }
    return journeys;
  }

  Widget buildItem(Journey departure) {
    var subtitle = departure.track == null ? '' : departure.track!;
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
          trailing:
              Text(formatDepartureTime(departure.date, true), style: textStyle),
        ));
  }

  @override
  Widget build(BuildContext context) {
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
      body: this.journeys.length == 0
          ? loader
          : ListView.builder(
              itemCount: journeys.length,
              itemBuilder: (context, index) {
                final item = journeys[index];
                return buildItem(item);
              }),
    );
  }
}

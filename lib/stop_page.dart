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

  Widget buildItem(Journey journey) {
    List<String> subtitleComponents = [];
    var directionName = journey.direction;
    final viaIndex = directionName.indexOf(' via ');
    if (journey.track != null) {
      subtitleComponents.add(journey.track!);
    }
    subtitleComponents.add(formatDepartureTime(journey.date, false));
    if (viaIndex > 0) {
      final via =
          directionName.substring(viaIndex, directionName.length).trim();
      subtitleComponents.add(via);
      directionName = directionName.substring(0, viaIndex).trim();
    }

    var textStyle = TextStyle(
        color: journey.fgColor, fontSize: 18.0, fontWeight: FontWeight.bold);
    return Container(
        decoration: BoxDecoration(
          color: journey.bgColor,
        ),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JourneyPage(journey)),
            );
          },
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(journey.shortName, style: textStyle)],
          ),
          minLeadingWidth: 60,
          title: Text(directionName, style: textStyle),
          subtitle: Text(subtitleComponents.join(' · '),
              style: TextStyle(color: textStyle.color)),
          trailing:
              Text(formatDepartureTime(journey.date, true), style: textStyle),
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

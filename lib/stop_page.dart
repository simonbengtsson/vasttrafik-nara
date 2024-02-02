import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/information_page.dart';
import 'package:vasttrafik_nara/journey_page.dart';
import 'package:vasttrafik_nara/models.dart';
import 'package:vasttrafik_nara/stop_map_page.dart';

class StopPage extends StatefulWidget {
  StopPage({Key? key, required this.stop}) : super(key: key);

  final Stop stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {
  Information? information;
  List<Deparature> journeys = [];

  @override
  initState() {
    super.initState();
    fetchInformation();
    fetchData().then((list) {
      trackEvent('Page Shown', {
        'Page Name': 'Stop',
        'Stop Name': widget.stop.name,
        'Stop Id': widget.stop.id,
        'Shown Journey Count': list.length,
      });
    });
  }

  Future<void> fetchInformation() async {
    var stopId = this.widget.stop.id;
    var info = await vasttrafikApi.getStopInformation(stopId);
    if (mounted) {
      this.setState(() {
        this.information = info;
      });
    }
  }

  Future<List<Deparature>> fetchData() async {
    var stopId = this.widget.stop.id;
    var journeys = await vasttrafikApi.getDepartures(stopId);
    journeys.sort((a, b) {
      return a.estimatedTime.compareTo(b.estimatedTime);
    });

    if (mounted) {
      this.setState(() {
        this.journeys = journeys;
      });
    }
    return journeys;
  }

  Widget buildItem(Deparature journey) {
    List<Widget> subtitleComponents = [];
    var directionName = journey.direction;
    final viaIndex = directionName.indexOf(' via ');
    var textStyle = TextStyle(
        color: convertHexToColor(journey.fgColor),
        fontSize: 18.0,
        fontWeight: FontWeight.bold);
    final subTextStyle = TextStyle(color: textStyle.color);
    if (journey.track != null) {
      subtitleComponents.add(Text(journey.track!, style: subTextStyle));
    }
    final isDelayed =
        !journey.estimatedTime.isAtSameMomentAs(journey.plannedTime);
    if (isDelayed) {
      subtitleComponents.add(Text(
          formatDepartureTime(journey.plannedTime, false),
          style: subTextStyle.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: subTextStyle.color!.withOpacity(0.8),
              decorationThickness: 3)));
    }
    subtitleComponents.add(Text(
        formatDepartureTime(journey.estimatedTime, false),
        style: subTextStyle));

    if (journey.isCancelled) {
      subtitleComponents.add(Text('Cancelled',
          style: subTextStyle.copyWith(
              color: Colors.red, backgroundColor: Colors.white)));
    }
    if (viaIndex > 0) {
      final via =
          directionName.substring(viaIndex, directionName.length).trim();
      subtitleComponents.add(Text(via, style: subTextStyle));
      directionName = directionName.substring(0, viaIndex).trim();
    }

    return Container(
        decoration: BoxDecoration(
          color: convertHexToColor(journey.bgColor),
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
          subtitle: Wrap(spacing: 5, children: [
            for (var it in subtitleComponents) it,
          ]),
          trailing: Text(formatDepartureTime(journey.estimatedTime, true),
              style: textStyle),
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
        actions: [
          if (information != null)
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'Info',
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InformationPage(
                      information: information!,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Map',
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StopMapPage(
                    stop: widget.stop,
                  ),
                ),
              );
            },
          ),
        ],
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

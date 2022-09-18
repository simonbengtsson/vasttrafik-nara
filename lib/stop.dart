import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/journey.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class StopPage extends StatefulWidget {
  StopPage({Key? key, required this.stop}) : super(key: key);

  final Stop stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {
  List<Departure> departures = [];
  List<Stop> nextStops = [];
  var activeNextStopTags = {};

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);

    var stopId = this.widget.stop.id;
    var departs = await api.getDepartures(stopId, DateTime.now()) ?? [];
    departs.sort((a, b) {
      String aTime = a['rtTime'] ?? a['time'];
      String bTime = b['rtTime'] ?? b['time'];
      String aDate = a['rtDate'] ?? a['date'];
      String bDate = b['rtDate'] ?? b['date'];
      var ad = DateTime.parse(aDate + 'T' + aTime);
      var bd = DateTime.parse(bDate + 'T' + bTime);
      return ad.compareTo(bd);
    });

    var departs2 =
        departs.map((it) => Departure(it)).toList().cast<Departure>();

    this.setState(() {
      this.departures = departs2;
    });

    var nextStops = await initNextStops(api, departs);

    this.setState(() {
      this.nextStops = nextStops;
    });
  }

  Future<List<Stop>> initNextStops(api, departs) async {
    List<Future> futures = [];
    var nexts = {};
    departs.forEach((dep) {
      var ref = dep['JourneyDetailRef']['ref'];
      futures.add(api.getJourney(ref).then((journey) {
        var nextStop = getNextStop(journey, dep);
        if (nextStop != null) {
          dep['nextStop'] = nextStop;
          var saved = nextStop.data['departures'] ?? [];
          saved.add(dep);
          nextStop.data['departures'] = saved;
          nexts[convertToStopId(nextStop.id)] = nextStop;
        }
      }));
    });
    await Future.wait(futures);

    return List<Stop>.from(nexts.values.toList());
  }

  Stop? getNextStop(journey, dep) {
    var stops = journey["Stop"];
    var stopIndex = stops.indexWhere((stop) => stop['id'] == dep['stopid']);
    if (stopIndex >= 0 && stops.length > stopIndex + 1) {
      var data = stops[stopIndex + 1];
      return Stop(data);
    }
    return null;
  }

  convertToStopId(String id) {
    var intId = int.parse(id);
    return '${(intId / 1000).round()}';
  }

  @override
  Widget build(BuildContext context) {
    //return buildSectionList(context);
    return buildList(context);
  }

  Widget buildChip(Departure dep) {
    return Padding(
      padding: EdgeInsets.only(right: 10),
      child: TextButton(
          child: Wrap(children: [
            Container(
                padding: EdgeInsets.all(7),
                constraints: BoxConstraints(minWidth: 40),
                decoration: BoxDecoration(
                    color: dep.fgColor,
                    borderRadius: BorderRadius.all(Radius.circular(5))),
                child: Text(dep.shortName,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            Padding(
                padding: EdgeInsets.all(7),
                child: Text(dep.time,
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.6), fontSize: 20)))
          ]),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JourneyScreen(dep),
                ));
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.all(5),
            backgroundColor: Color.fromRGBO(200, 200, 200, 0.3),
          )),
    );
  }

  Widget buildSection(Stop nextStop) {
    List deps =
        this.departures.where((it) => it.nextStop.id == nextStop.id).toList();
    var depw = deps.map((it) => buildChip(it));
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(nextStop.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        Wrap(children: depw.toList(), runSpacing: 7, spacing: -3),
      ]),
    );
  }

  Widget buildSectionList(BuildContext context) {
    var items = <DepartureItem>[];
    departures.forEach((dep) {
      if (this.activeNextStopTags.length == 0 ||
          this.activeNextStopTags.containsKey(dep.nextStop.id)) {
        items.add(DepartureItem(dep, context));
      }
    });

    this.nextStops.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var main = this.nextStops.length == 0
        ? loader
        : ListView(
            children: this.nextStops.map((it) => buildSection(it)).toList());
    return Scaffold(
        appBar: AppBar(
          title: Text(this.widget.stop.name),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              color: Colors.black,
              tooltip: 'Refresh',
              onPressed: () {
                _onRefresh();
              },
            ),
          ],
        ),
        body: main);
  }

  Widget buildList(BuildContext context) {
    var items = <DepartureItem>[];
    departures.forEach((dep) {
      if (this.activeNextStopTags.length == 0 ||
          this.activeNextStopTags.containsKey(dep.nextStop.id)) {
        items.add(DepartureItem(dep, context));
      }
    });

    this.nextStops.sort((a, b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    List<TextButton> buttons = this.nextStops.map((stop) {
      String id = stop.id;
      return TextButton(
          onPressed: () => {
                this.setState(() {
                  if (this.activeNextStopTags[id] == null) {
                    this.activeNextStopTags[id] = stop;
                  } else {
                    this.activeNextStopTags.remove(id);
                  }
                })
              },
          child: Text(stop.name,
              style: TextStyle(
                  color: this.activeNextStopTags[id] == null
                      ? Colors.grey
                      : Colors.black,
                  fontSize: 16,
                  fontWeight: this.activeNextStopTags[id] == null
                      ? FontWeight.bold
                      : FontWeight.bold)));
    }).toList();
    var tagsView = SizedBox(
      height: 70.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 0,
              blurRadius: 5,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: ListView(scrollDirection: Axis.horizontal, children: buttons),
      ),
    );

    Widget listView = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return item.build();
        });

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var cmp = this.departures.length == 0
        ? loader
        : Expanded(
            child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return item.build();
                }));
    listView = Column(children: <Widget>[tagsView, cmp]);

    return Scaffold(
        appBar: AppBar(
          title: Text(this.widget.stop.name),
          actions: [],
        ),
        body: listView);
  }

  _onRefresh() async {
    this.setState(() {
      this.departures = [];
      this.nextStops = [];
    });
    await fetchData();
  }
}

class Stop {
  final Map<String, dynamic> data;

  Stop(this.data);

  String get name {
    String name = data['name'];
    if (name.contains(', Göteborg')) {
      name = name.replaceAll(', Göteborg', '');
    }
    return name;
  }

  String get id => data['id'];
  double get lat => double.parse(data['lat']);
  double get lon => double.parse(data['lon']);
  String get departureTime => data['depTime'] ?? '-';
}

class Departure {
  final Map<String, dynamic> data;

  Departure(this.data);

  Stop get nextStop {
    return data['nextStop'];
  }

  String get name {
    var name = data['name'];
    if (name.contains(', Påstigning fram')) {
      print('REMOVED $name');
      name = name.replaceAll(', Påstigning fram', '');
    } else {
      print('KEPT $name');
    }
    return name;
  }

  String get shortName {
    return data['sname'];
  }

  String get direction {
    var name = data['direction'];
    if (name.contains(', Påstigning fram')) {
      print('REMOVED $name');
      name = name.replaceAll(', Påstigning fram', '');
    }
    return name;
  }

  String? get track {
    return data['track'];
  }

  Color get bgColor {
    return _hexColor(data['bgColor']);
  }

  Color get fgColor {
    return _hexColor(data['fgColor']);
  }

  String get time {
    var timeStr = data['rtTime'] ?? data['time'];
    var dateStr = data['date'] + ' ' + timeStr;
    DateFormat format = new DateFormat("yyyy-MM-dd HH:mm");
    var date = format.parse(dateStr);
    var now = DateTime.now();
    //var now = DateTime.parse("2021-03-12 05:00:00");

    var minDiff =
        (date.millisecondsSinceEpoch - now.millisecondsSinceEpoch) / 1000 / 60;

    var minStr = timeStr;
    if (minDiff <= 0) {
      minStr = "Now";
    } else if (minDiff < 60) {
      minStr = "${minDiff.ceil()}";
    }

    return minStr;
  }

  String get stopId => data['stopid'];

  _hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }
}

class DepartureItem {
  final Departure departure;
  final BuildContext context;

  DepartureItem(this.departure, this.context);

  Widget build() {
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
              MaterialPageRoute(builder: (context) => JourneyScreen(departure)),
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
}

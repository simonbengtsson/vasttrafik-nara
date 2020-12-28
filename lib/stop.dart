import 'dart:async';

import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/journey.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
/*import 'package:vasttrafik_nara/selectable_tags.dart';*/
import 'package:shared_preferences/shared_preferences.dart';

class StopPage extends StatefulWidget {
  StopPage({Key key, this.stop}) : super(key: key);

  var stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {

  var departures = [];
  var nextStops = [];
  var activeNextStopTags = {};

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);

    var stopId = this.widget.stop['id'];
    var departs = await api.getDepartures(stopId, DateTime.now()) ?? [];
    departs.sort((a, b) {
      var aTime = a['rtTime'] ?? a['time'];
      var bTime = b['rtTime'] ?? b['time'];
      return aTime.compareTo(bTime) as int;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var isEnabled = prefs.getBool('isNextStopsEnabled') ?? false;
    if (!isEnabled) {
      initNextStops(api, departs);
    }

    if (this.mounted) {
      this.setState(() {
        this.departures = departs;
      });
    }
  }

  initNextStops(api, departs) async {
    List<Future> futures = [];
    var nexts = {};
    departs.forEach((dep) {
      var ref = dep['JourneyDetailRef']['ref'];
      futures.add(api.getJourney(ref).then((journey) {
        var nextStop = getNextStop(journey, dep);
        dep['nextStop'] = nextStop;
        nexts[convertToStopId(nextStop['id'])] = nextStop;
      }));
    });
    await Future.wait(futures);
    
    if (this.mounted) {
      this.setState(() {
        this.nextStops = nexts.values.toList();
      });
    }
  }
  
  getNextStop(journey, dep) {
    var stops = journey["Stop"];
    var stopIndex = stops.indexWhere((stop) => stop['id'] == dep['stopid']);
    if (stopIndex >= 0 && stops.length > stopIndex + 1) {
      var stop = stops[stopIndex + 1];
      stop['name'] = removeGothenburg(stop['name']);
      return stop;
    }
    return null;
  }

  convertToStopId(String id) {
    var intId = int.parse(id);
    return '${(intId / 1000).round()}';
  }

  @override
  Widget build(BuildContext context) {
    var items = <DepartureItem>[];
    departures.forEach((dep) {
      if (this.activeNextStopTags.length == 0 || this.activeNextStopTags.containsKey(dep['nextStop']['id'])) {
        items.add(DepartureItem(dep, context));
      }
    });

    this.nextStops.sort((a, b) {
      return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
    });
    /*
    var _tags = this.nextStops.map((nextStop) {
      var id = int.parse(nextStop['id']);
      return Tag(title: nextStop['name'], id: id, active: false);
    }).toList();

    var tagsView = SelectableTags(
      tags: _tags,
      onPressed: (tag) {
        this.setState(() {
          if (tag.active) {
            this.activeNextStopTags['${tag.id}'] = tag;
          } else {
            this.activeNextStopTags.remove('${tag.id}');
          }
        });
      },
    );
     */

    Widget listView = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return item.build();
        }
    );

    /*if (_tags.length > 0) {
      listView = Column(children: <Widget>[
        tagsView,
        Expanded(child:  ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return item.build();
            }
        ))
      ]);
    }*/

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Column(
              children: <Widget>[CupertinoActivityIndicator(
                  animating: true,
                  radius: 15.0
              )]
          )
        )
    );

    return Scaffold(
        appBar: AppBar(
            title: Text(removeGothenburg(this.widget.stop['name'])),
            actions: [],
        ),
        body: SafeArea(child: this.departures.length == 0 ? loader : listView)
    );
  }

  removeGothenburg(name) {
    if (name.endsWith(', Göteborg')) {
      name = name.substring(0, name.length - ', Göteborg'.length);
    }
    return name;
  }

  _onRefresh() async {
    this.setState(() {
      this.departures = [];
    });
    await fetchData();
  }
}

class DepartureItem {
  final Map departure;
  final BuildContext context;

  DepartureItem(this.departure, this.context);

  String getRelativeTime(Map<String, dynamic> departure) {
    var timeStr = departure['rtTime'] ?? departure['time'];
    var dateStr = departure['date'] + ' ' + timeStr;
    DateFormat format = new DateFormat("yyyy-MM-dd HH:mm");
    var date = format.parse(dateStr);
    var now = DateTime.now();

    var minDiff = (date.millisecondsSinceEpoch - now.millisecondsSinceEpoch) / 1000 / 60;

    var minStr = timeStr;
    if (minDiff <= 0) {
      minStr = "Now";
    } else if (minDiff < 60) {
      minStr = "${minDiff.ceil()}";
    }

    return minStr;
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build() {
    String direction = departure['direction'];
    var subtitle = 'Läge ${departure['track']}';
    final viaIndex = direction.indexOf(' via ');
    if (viaIndex > 0) {
      subtitle = subtitle + ' • ' + direction.substring(viaIndex, direction.length).trim();
      direction = direction.substring(0, viaIndex).trim();
    }

    var minStr = getRelativeTime(departure);
    var textStyle = TextStyle(color: hexColor(departure['bgColor']), fontSize: 18.0, fontWeight: FontWeight.bold);
    return Container(
        decoration: BoxDecoration (
            color: hexColor(departure['fgColor']),
        ),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JourneyScreen(departure)),
            );
          },
          leading: Text(departure['sname'], style: textStyle),
          title: Text(direction, style: textStyle),
          subtitle: Text(subtitle, style: TextStyle(color: hexColor(departure['bgColor']))),
          trailing: Text(minStr, style: textStyle),
        )
    );
  }
}
import 'dart:io';
import 'package:arctic_tern/journey.dart';
import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:latlong/latlong.dart';
import "package:pull_to_refresh/pull_to_refresh.dart";
import 'package:device_info/device_info.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var nearbyStops = [];
  LatLng currentLocation;
  RefreshController refreshController;

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    var deviceInfo = DeviceInfoPlugin();
    var isPhysical = Platform.isIOS ? (await deviceInfo.iosInfo).isPhysicalDevice : (await deviceInfo.androidInfo).isPhysicalDevice;
    if (isPhysical) {
      var location = Location();
      var loc = await location.getLocation();
      this.currentLocation = LatLng(loc['latitude'], loc['longitude']);
    } else {
      this.currentLocation = LatLng(57.6897091, 11.9719767); // Chalmers
      //this.currentLocation = LatLng(57.7067818, 11.9668661); // Brunnsparken
    }

    VasttrafikApi api = VasttrafikApi();
    var stops = (await api.getNearby(this.currentLocation, limit: 50)).toList();
    //stops = stops.where((stop) => stop['track'] == null);

    var futures = stops.map<Future>((stop) async {
      var departs = await api.getDepartures(stop['id'], DateTime.now());
      departs.sort((a, b) {
        return (a['rtTime'] ?? a['time']).compareTo(b['rtTime'] ?? b['time']) as int;
      });
      stop['departures'] = departs;
    });
    await Future.wait(futures);

    this.setState(() {
      this.nearbyStops = stops;
    });
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  buildStopHeader(stop) {
    var name = stop['name'];
    if (name.endsWith(', Göteborg')) {
      name = name.substring(0, name.length - ', Göteborg'.length);
    }

    final Distance distance = new Distance();
    var offset = distance.as(
        LengthUnit.Meter,
        new LatLng(double.parse(stop['lat']), double.parse(stop['lon'])),
        this.currentLocation
    );
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 0.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: AutoSizeText(name, overflow: TextOverflow.ellipsis, maxLines: 1, minFontSize: 16.0, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0))),
              Text("${offset.round()} m", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0))
            ]
        )
    );
  }

  String getRelativeTime(Map<String, dynamic> departure) {
    var timeStr = departure['rtTime'] ?? departure['time'];
    var dateStr = departure['date'] + ' ' + timeStr;
    DateFormat format = new DateFormat("yyyy-MM-dd hh:mm");
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

  @override
  Widget build(BuildContext context) {
    var items = <ListItem>[];
    nearbyStops.forEach((stop) {
      items.add(HeadingItem(stop));
      stop['departures'].take(5).forEach((dep) {
        items.add(MessageItem(dep));
      });
    });

    var listView = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is HeadingItem) {
            return ListTile(
              title: buildStopHeader(item.stop),
            );
          } else if (item is MessageItem) {
            var departure = item.departure;

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
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 2.0))
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
    );

    this.refreshController = RefreshController();

    var refresher = SmartRefresher(
      enablePullDown: true,
      onRefresh: _onRefresh,
      headerConfig: RefreshConfig(visibleRange: 50.0),
      headerBuilder: (ctx, mode) {
        return CupertinoActivityIndicator(
          animating: mode == RefreshStatus.canRefresh || mode == RefreshStatus.refreshing || mode == RefreshStatus.completed,
          radius: 15.0,
        );
      },
      child: listView,
      controller: this.refreshController,
    );

    return Scaffold(
        appBar: AppBar(title: Text('Arctic Tern'), backgroundColor: Colors.black,),
        body: SafeArea(child: refresher)
    );
  }

  _onRefresh(isUp) async {
    await fetchData();
    refreshController.sendBack(true, RefreshStatus.completed);
  }
}

abstract class ListItem {}

// A ListItem that contains data to display a heading
class HeadingItem implements ListItem {
  final Map stop;

  HeadingItem(this.stop);
}

// A ListItem that contains data to display a message
class MessageItem implements ListItem {
  final Map<String, dynamic> departure;

  MessageItem(this.departure);
}
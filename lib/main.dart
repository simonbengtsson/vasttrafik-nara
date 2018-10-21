import 'package:arctic_turn/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:latlong/latlong.dart';
import "package:pull_to_refresh/pull_to_refresh.dart";

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.lightBlue[800],
        accentColor: Colors.cyan[600],
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

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
    var location = Location();
    //var loc = await location.getLocation();
    //this.currentLocation = LatLng(loc['latitude'], loc['longitude'])
    //this.currentLocation = LatLng(57.6897091, 11.9719767); // Chalmers
    this.currentLocation = LatLng(57.7067818, 11.9668661); // Brunnsparken

    VasttrafikApi api = VasttrafikApi();
    var stops = await api.getNearby(this.currentLocation, limit: 50);
    stops = stops.where((stop) => stop['track'] == null).toList();

    var futures = stops.map<Future>((stop) async {
      var departs = await api.getDepartures(stop['id'], DateTime.now());
      print(departs);
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
            Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0)),
            Text("${offset.round()} m", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0))
          ]
        )
    );
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
            var textStyle = TextStyle(color: hexColor(departure['bgColor']), fontSize: 18.0, fontWeight: FontWeight.bold);
            return Container(
                decoration: BoxDecoration (
                    color: hexColor(departure['fgColor']),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 2.0))
                ),
                child: ListTile(
                  leading: Text(departure['sname'], style: textStyle),
                  title: Text(departure['direction'], style: textStyle),
                  trailing: Text(departure['rtTime'] ?? departure['time'], style: textStyle),
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
          animating: mode == RefreshStatus.canRefresh || mode == RefreshStatus.refreshing,
          radius: 15.0,
        );
      },
      child: listView,
      controller: this.refreshController,
    );

    return Scaffold(
      backgroundColor: Colors.black,
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
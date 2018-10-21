import 'package:arctic_turn/vasttrafik.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'dart:async';

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

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    var location = Location();
    //var loc = await location.getLocation();
    //var loc = {'latitude': 57.6897091, 'longitude': 11.9719767}; // Chalmers
    var loc = {'latitude': 57.7067818, 'longitude': 11.9668661}; // Brunnsparken

    VasttrafikApi api = VasttrafikApi();
    var stops = await api.getNearby(loc['latitude'], loc['longitude'], limit: 20);
    stops = stops.where((stop) => stop['track'] == null).toList();

    var futures = stops.map<Future>((stop) async {
      return api
          .getDepartures(stop['id'], DateTime.now())
          .then((departs) {
            print(departs);
            departs.sort((a, b) {
              return a['rtTime' ?? a['time']].compareTo(b['rtTime'] ?? b['time']) as int;
            });
            stop['departures'] = departs;
          });
    });
    await Future.wait(futures);

    this.setState(() {
      this.nearbyStops = stops;
    });
  }

  buildDepartureList(departures) {
    var children = departures.take(5).map<Widget>((departure) {
      var textStyle = TextStyle(color: hexColor(departure['bgColor']), fontSize: 18.0, fontWeight: FontWeight.bold);
      return new Container(
          decoration: new BoxDecoration (
            color: hexColor(departure['fgColor']),
          ),
          child: ListTile(
            leading: Text(departure['sname'], style: textStyle),
            title: Text(departure['direction'], style: textStyle),
            trailing: Text(departure['rtTime'] ?? departure['time'], style: textStyle),
          )
      );
    }).toList();
    return ListView(
      children: children
    );
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
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
        child: Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0))
    );
  }

  List<Widget> buildStopSections(stops) {
    var list = <Widget>[];
    print("Stops");
    print(stops);
    stops.forEach((stop) {
      list.add(buildStopHeader(stop));
      list.add(Expanded(child: buildDepartureList(stop['departures'] ?? [])));
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: buildStopSections(this.nearbyStops),
        ),
      )
    );
  }
}

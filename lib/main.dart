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
  var departures = [];

  @override
  initState() {
    super.initState();
    fetchData();
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (this.nearbyStops.length == 0) {
        return;
      }
      VasttrafikApi api = VasttrafikApi();
      var departs = await api.getDepartures(this.nearbyStops[0]['id'], DateTime.now());
      this.setState(() {
        this.departures = departs;
      });
    });
  }

  fetchData() async {
    var location = Location();
    //var loc = await location.getLocation();
    //var loc = {'latitude': 57.6897091, 'longitude': 11.9719767}; // Chalmers
    var loc = {'latitude': 57.7067818, 'longitude': 11.9668661}; // Brunnsparken

    VasttrafikApi api = VasttrafikApi();
    var stops = await api.getNearby(loc['latitude'], loc['longitude']);
    var departs = await api.getDepartures(stops[0]['id'], DateTime.now());

    this.setState(() {
      this.departures = departs;
      this.nearbyStops = stops.where((stop) => stop['track'] == null).toList();
    });
  }

  buildDepartureList() {
    this.departures.sort((a, b) => a['rtTime'].compareTo(b['rtTime']));
    return ListView(
      children: this.departures.map((departure) {
        var textStyle = TextStyle(color: hexColor(departure['bgColor']), fontSize: 18.0, fontWeight: FontWeight.bold);
        return new Container (
            decoration: new BoxDecoration (
                color: hexColor(departure['fgColor']),
            ),
            child: ListTile(
              leading: Text(departure['sname'], style: textStyle),
              title: Text(departure['direction'], style: textStyle),
              trailing: Text(departure['rtTime'], style: textStyle),
            )
        );
      }).toList()
    );
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    var stop = '...';
    if (this.nearbyStops.length > 0) {
      stop = this.nearbyStops[0]['name'];
      if (stop.endsWith(', Göteborg')) {
        stop = stop.substring(0, stop.length - ', Göteborg'.length);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
              child: Text(stop, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0),
            )),
            Expanded(child: buildDepartureList())
          ],
        ),
      )
    );
  }
}

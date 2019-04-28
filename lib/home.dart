import 'dart:io';
import 'package:arctic_tern/env.dart';
import 'package:arctic_tern/journey.dart';
import 'package:arctic_tern/stop.dart';
import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:latlong/latlong.dart';
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

    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var stops = (await api.getNearby(this.currentLocation, limit: 50)).toList();
    stops = stops.where((stop) => stop['track'] == null).toList();

    this.setState(() {
      this.nearbyStops = stops;
    });
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    var items = <ListItem>[];
    nearbyStops.forEach((stop) {
      items.add(StopHeadingItem(stop, currentLocation, context));
    });

    var listView = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return item.build();
        }
    );

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
            title: Text('Arctic Tern', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'Open shopping cart',
                onPressed: _onRefresh,
              ),
            ],
            backgroundColor: Colors.black
        ),
        body: SafeArea(child: this.nearbyStops.length == 0 ? loader : listView)
    );
  }

  _onRefresh() async {
    this.setState(() {
      this.nearbyStops = [];
    });
    await fetchData();
  }
}

abstract class ListItem {
  Widget build();
}

class StopHeadingItem implements ListItem {
  final Map stop;
  final BuildContext context;
  final LatLng currentLocation;

  StopHeadingItem(this.stop, this.currentLocation, this.context);

  @override
  Widget build() {
    var name = stop['name'];
    if (name.endsWith(', Göteborg')) {
      name = name.substring(0, name.length - ', Göteborg'.length);
    }

    final Distance distance = new Distance();
    var offset = distance.as(
        LengthUnit.Meter,
        LatLng(double.parse(stop['lat']), double.parse(stop['lon'])),
        this.currentLocation
    );

    var style = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w700, fontSize: 28.0);
    //var style = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30.0);
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StopPage(stop: this.stop)),
        );
      },
      title: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 0.0),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(child: AutoSizeText(name, overflow: TextOverflow.ellipsis, maxLines: 1, minFontSize: 16.0, style: style)),
              Text("${offset.round()} m", style: style)
            ]
        )
      )
    );
  }
}

class DepartureItem implements ListItem {
  final Map departure;
  final BuildContext context;

  DepartureItem(this.departure, this.context);

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
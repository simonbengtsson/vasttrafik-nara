import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/stop.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var fetchComplete = false;
  var nearbyStops = [];
  var isSearching = false;
  LatLng? currentLocation;

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    var deviceInfo = DeviceInfoPlugin();
    var isPhysical = Platform.isIOS
        ? (await deviceInfo.iosInfo).isPhysicalDevice
        : (await deviceInfo.androidInfo).isPhysicalDevice;
    if (isPhysical) {
      var location = Location();
      var loc = await location.getLocation();
      this.currentLocation = LatLng(loc.latitude!, loc.longitude!);
    } else {
      this.currentLocation = LatLng(57.6897091, 11.9719767); // Chalmers
      //this.currentLocation = LatLng(57.7067818, 11.9668661); // Brunnsparken
    }

    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var stops = await api.getNearby(this.currentLocation!) ?? [];
    stops = stops.where((stop) => stop['track'] == null).toList();

    this.setState(() {
      this.nearbyStops = stops;
      this.fetchComplete = true;
    });
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    var items = <StopHeadingItem>[];
    nearbyStops.forEach((stop) {
      items.add(StopHeadingItem(stop, currentLocation, context));
    });

    var listView = ListView.builder(
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

    var mainCmp;
    if (!this.fetchComplete) {
      mainCmp = loader;
    } else if (this.nearbyStops.length == 0) {
      mainCmp = Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
              child: Column(children: <Widget>[
            Text(
              "No stops nearby",
              style: TextStyle(fontSize: 16),
            )
          ])));
    } else {
      mainCmp = listView;
    }

    final _controller = TextEditingController();
    var typeAhead = TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _controller,
          style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 17,
                color: Colors.black,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
          decoration: InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            hintText: 'Search for stops...',
          )),
      suggestionsCallback: (pattern) async {
        VasttrafikApi api =
            VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
        var stops = await api.search(pattern) ?? [];
        stops = stops.where((stop) => stop['track'] == null).toList();
        return stops;
      },
      itemBuilder: (context, inputStop) {
        var stop = inputStop as Map<String, dynamic>;
        var name = stop['name'];
        if (name.endsWith(', Göteborg')) {
          name = name.substring(0, name.length - ', Göteborg'.length);
        }
        return ListTile(
          title: Text(name),
        );
      },
      onSuggestionSelected: (stop) {
        _controller.text = "";
        print("Selected ${stop.toString()}");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StopPage(stop: stop)),
        );
      },
    );

    return Scaffold(
        appBar: AppBar(
            //leading: Icon(Icons.search),
            title: SizedBox(height: 50, child: typeAhead),
            brightness: Brightness.light,
            actions: <Widget>[
              /*IconButton(
                      icon: Icon(Icons.search),
                      color: Colors.black,
                      tooltip: 'Search',
                      onPressed: () {
                        setState(() {
                          this.isSearching = true;
                        });
                        print("Search...");
                      },
                    ),*/
              IconButton(
                icon: Icon(Icons.refresh),
                color: Colors.black,
                tooltip: 'Refresh',
                onPressed: () {
                  _onRefresh();
                },
              ),
              /*PopupMenuButton<String>(
                onSelected: (choice) async {
                  if (choice == 'Refresh') {
                    _onRefresh();
                  } else {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    var isEnabled = prefs.getBool('nextStopsFlag') ?? false;
                    prefs.setBool('nextStopsFlag', !isEnabled);
                  }
                },
                itemBuilder: (BuildContext context) {
                  //var choices = ["Refresh", "Toggle next stops"];
                  var choices = ["Refresh"];
                  return choices.map((String choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Text(choice),
                    );
                  }).toList();
                },
              ),*/
            ],
            backgroundColor: Colors.white),
        body: SafeArea(child: mainCmp));
  }

  _onRefresh() async {
    this.setState(() {
      this.nearbyStops = [];
      this.fetchComplete = false;
    });
    await fetchData();
  }
}

class Choice {
  const Choice({this.title, this.icon});

  final String? title;
  final IconData? icon;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: 'Car', icon: Icons.directions_car),
  const Choice(title: 'Bicycle', icon: Icons.directions_bike),
  const Choice(title: 'Boat', icon: Icons.directions_boat),
  const Choice(title: 'Bus', icon: Icons.directions_bus),
  const Choice(title: 'Train', icon: Icons.directions_railway),
  const Choice(title: 'Walk', icon: Icons.directions_walk),
];

class StopHeadingItem {
  final Map stop;
  final BuildContext context;
  final LatLng? currentLocation;

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
        this.currentLocation!);

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
                  Flexible(
                      child: AutoSizeText(name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          minFontSize: 16.0,
                          style: Theme.of(context).textTheme.headline)),
                  Text("${offset.round()} m",
                      style: Theme.of(context)
                          .textTheme
                          .headline!
                          .copyWith(color: Colors.grey))
                ])));
  }
}

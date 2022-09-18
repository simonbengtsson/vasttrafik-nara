import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/stop.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

var gothenburgLocation = Position(
    latitude: 57.7068421,
    longitude: 11.9704796,
    timestamp: DateTime.now(),
    accuracy: -1,
    altitude: -1,
    heading: -1,
    speed: -1,
    speedAccuracy: -1);

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var fetchComplete = false;
  List<Stop> nearbyStops = [];
  var isSearching = false;
  Position? currentLocation;

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    try {
      var position =
          await getCurrentLocation(context).timeout(Duration(seconds: 5));
      var distanceAway = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          gothenburgLocation.latitude,
          gothenburgLocation.longitude);
      if (distanceAway < 200 * 1000) {
        this.currentLocation = position;
      } else {
        print(
            "Far from Gothenburg (${distanceAway.round()}, not using current location");
      }
    } catch (error, stack) {
      var details = FlutterErrorDetails(exception: error, stack: stack);
      FlutterError.presentError(details);
      print('Error getting location. Details above');
    }

    var currentLocation = this.currentLocation ?? gothenburgLocation;
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var rawStops = await api.getNearby(currentLocation) ?? [];
    var stops = List<Stop>.from(rawStops
        .where((stop) => stop['track'] == null && stop['id'].startsWith('9'))
        .map((it) => Stop(it)));

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
            hintText: 'Search for stops',
          )),
      suggestionsCallback: (pattern) async {
        VasttrafikApi api =
            VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
        var rawStops = await api.search(pattern) ?? [];
        var stops = rawStops
            .where((stop) => stop['track'] == null)
            .map((it) => Stop(it))
            .toList();
        return stops;
      },
      itemBuilder: (context, inputStop) {
        var stop = inputStop as Stop;
        return ListTile(
          title: Text(stop.name),
        );
      },
      onSuggestionSelected: (stop) {
        _controller.text = "";
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StopPage(stop: stop as Stop)),
        );
      },
    );

    return Scaffold(
        appBar: AppBar(
            title: SizedBox(height: 50, child: typeAhead),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            actions: <Widget>[
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
        body: mainCmp);
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
  final Stop stop;
  final BuildContext context;
  final Position? currentLocation;

  StopHeadingItem(this.stop, this.currentLocation, this.context);

  Widget build() {
    var name = stop.name;
    var offset = this.currentLocation == null
        ? null
        : Geolocator.distanceBetween(stop.lat, stop.lon,
            this.currentLocation!.latitude, this.currentLocation!.longitude);

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
                          style: Theme.of(context).textTheme.headline6!)),
                  Text(offset != null ? "${offset.round()} m" : '',
                      style: Theme.of(context)
                          .textTheme
                          .headline6!
                          .copyWith(color: Colors.grey))
                ])));
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/stop_page.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

var gothenburgLocation = Coordinate(57.7068421, 11.9704796);

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
    fetchData().then((item) {
      trackEvent('Page Shown', {
        'Page Name': 'Home',
        'Shown Stop Count': item.$1?.length ?? 0,
        'Uses Device Location': item.$2 != null ? 'Yes' : 'No',
        'Distance Away': item.$3 ?? null,
      });
    });
  }

  Future<(List<Stop>?, Position?, double?)> fetchData() async {
    Future? authPromise;
    if (vasttrafikApi.authToken == null) {
      authPromise = vasttrafikApi.authorize();
    }
    double? distanceAway;
    try {
      var position =
          await getCurrentLocation(context).timeout(Duration(seconds: 5));
      distanceAway = Geolocator.distanceBetween(
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
      trackEvent('Error Triggered', {
        'Error Message': 'Could not get location',
        'Thrown Error': error.toString(),
        'Thrown Stack': stack.toString(),
      });
    }
    List<Stop>? stops;
    try {
      var currentLocation = this.currentLocation == null
          ? gothenburgLocation
          : Coordinate(
              this.currentLocation!.latitude, this.currentLocation!.longitude);
      if (authPromise != null) {
        await authPromise;
      }
      stops = await vasttrafikApi.getNearby(currentLocation);

      this.setState(() {
        this.nearbyStops = stops!;
        this.fetchComplete = true;
      });
    } catch (error, stack) {
      var details = FlutterErrorDetails(exception: error, stack: stack);
      FlutterError.presentError(details);
      trackEvent('Error Triggered', {
        'Error Message': 'Could not get stops',
        'Thrown Error': error.toString(),
        'Thrown Stack': stack.toString(),
      });
      print('Error getting vasttrafik stops');
    }
    return (stops, this.currentLocation, distanceAway);
  }

  final _controller = TextEditingController();

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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

    var typeAhead = TypeAheadField(
      hideKeyboardOnDrag: true,
      hideOnLoading: true,
      controller: _controller,
      hideOnEmpty: true,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        );
      },
      suggestionsCallback: (pattern) async {
        pattern = pattern.trim();
        var stops =
            pattern.isNotEmpty ? await vasttrafikApi.search(pattern) : null;
        return stops;
      },
      itemBuilder: (context, stop) {
        return ListTile(
          title: Text(stop.name),
        );
      },
      onSelected: (stop) {
        _controller.clear();
        FocusScope.of(context).unfocus();
        trackEvent('Stop Search Result Tapped', {
          'Stop Name': stop.name,
          'Stop Id': stop.id,
          'Search Query': _controller.text
        });
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StopPage(stop: stop)),
        );
      },
    );

    return Scaffold(
        appBar: AppBar(
          title: SizedBox(height: 50, child: typeAhead),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.refresh),
              color: Theme.of(context).colorScheme.onBackground,
              tooltip: 'Refresh',
              onPressed: () {
                _onRefresh();
              },
            ),
          ],
        ),
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
          FocusScope.of(context).unfocus();
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
                          style: Theme.of(context).textTheme.titleLarge!)),
                  Text(offset != null ? "${offset.round()} m" : '',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(color: Colors.grey))
                ])));
  }
}

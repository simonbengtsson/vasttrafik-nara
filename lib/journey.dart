import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyScreen extends StatefulWidget {

  Map<String, dynamic> departure;

  JourneyScreen(this.departure);

  @override
  createState() => _JourneyScreenState(this.departure);
}

class _JourneyScreenState extends State<JourneyScreen> {

  double _ITEM_HEIGHT = 70.0;

  Map<String, dynamic> departure;
  List stops = [];
  Map<String, dynamic> journey = {};
  ScrollController _scrollController;

  _JourneyScreenState(this.departure);

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi();
    var ref = this.departure['JourneyDetailRef']['ref'];
    var journey = await api.getJourney(ref);

    this.setState(() {
      this.stops = journey['Stop'];
      this.journey = journey;
    });

    print(this.departure);
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    Color fgColor = hexColor(this.departure['fgColor']);
    var lum = fgColor.computeLuminance();

    var stopIndex = this.stops.indexWhere((stop) => stop['id'] == this.departure['stopid']);
    this._scrollController = ScrollController(initialScrollOffset: stopIndex * 56.0);

    var listView = stopIndex < 0 ? Text('') : ListView.builder(
        itemCount: this.stops.length,
        controller: this._scrollController,

        itemBuilder: (context, index) {
          final stop = this.stops[index];
          final weight = stop['id'] == this.departure['stopid'] ? FontWeight.bold : FontWeight.normal;
          return Container(
              child: ListTile(
                selected: stop['id'] == this.departure['stopid'],
                title: Text(
                    stop['name'],
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.white.withOpacity(index < stopIndex ? 0.5 : 1.0),
                      fontWeight: weight,
                    )
                ),
              )
          );
        }
    );

    var name = this.departure['sname'] + ' ' + this.departure['direction'];
    return Scaffold(
        appBar: AppBar(
          backgroundColor: fgColor,
          brightness: lum < 0.7 ? Brightness.dark : Brightness.light,
          iconTheme: IconThemeData(color: hexColor(this.departure['bgColor'])),
          title: Text(name, style: TextStyle(color: hexColor(this.departure['bgColor']))),
        ),
        body: listView
    );
  }
}
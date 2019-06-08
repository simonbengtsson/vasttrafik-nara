import 'package:arctic_tern/stop.dart';
import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:arctic_tern/env.dart';

class JourneyScreen extends StatefulWidget {

  Map<String, dynamic> departure;

  JourneyScreen(this.departure);

  @override
  createState() => _JourneyScreenState(this.departure);
}

class _JourneyScreenState extends State<JourneyScreen> {

  Map<String, dynamic> departure;
  List stops = [];
  ScrollController _scrollController;

  _JourneyScreenState(this.departure);

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api =  VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);
    var ref = this.departure['JourneyDetailRef']['ref'];
    var journey = await api.getJourney(ref);

    if (this.mounted) {
      this.setState(() {
        this.stops = journey['Stop'];
      });
    }
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

    var listView = stopIndex < 0 ? loader : ListView.builder(
        itemCount: this.stops.length,
        controller: this._scrollController,

        itemBuilder: (context, index) {
          final stop = this.stops[index];
          var style = TextStyle(
            fontSize: 18.0,
            color: stop['id'] == this.departure['stopid'] ? Colors.black : Colors.black.withOpacity(index < stopIndex ? 0.3 : 0.8),
            fontWeight: stop['id'] == this.departure['stopid'] ? FontWeight.w900 : FontWeight.w500,
          );

          var name = stop['name'];
          if (name.endsWith(', Göteborg')) {
            name = name.substring(0, name.length - ', Göteborg'.length);
          }

          return Container(
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => StopPage(stop: stop)),
                  );
                },
                selected: stop['id'] == this.departure['stopid'],
                title: Text(
                    name,
                    style: style
                ),
                trailing: Text(stop['depTime'] ?? stop['arrTime'], style: style),
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
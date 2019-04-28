import 'package:arctic_tern/env.dart';
import 'package:arctic_tern/journey.dart';
import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StopPage extends StatefulWidget {
  StopPage({Key key, this.stop}) : super(key: key);

  var stop;

  @override
  _StopPageState createState() => _StopPageState();
}

class _StopPageState extends State<StopPage> {

  var departures = [];

  @override
  initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    VasttrafikApi api = VasttrafikApi(Env.vasttrafikKey, Env.vasttrafikSecret);

    var departs = await api.getDepartures(this.widget.stop['id'], DateTime.now());
    departs.sort((a, b) {
      return (a['rtTime'] ?? a['time']).compareTo(b['rtTime'] ?? b['time']) as int;
    });

    this.setState(() {
      this.departures = departs;
    });
  }

  @override
  Widget build(BuildContext context) {
    var items = <DepartureItem>[];
    departures.forEach((dep) {
      items.add(DepartureItem(dep, context));
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
            title: Text(this.widget.stop['name'], style: TextStyle(fontWeight: FontWeight.w900)),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'Open shopping cart',
                onPressed: _onRefresh,
              ),
            ],
            backgroundColor: Colors.black
        ),
        body: SafeArea(child: this.departures.length == 0 ? loader : listView)
    );
  }

  _onRefresh() async {
    this.setState(() {
      this.departures = [];
    });
    await fetchData();
  }
}

class DepartureItem {
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
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

  Map<String, dynamic> departure;
  List stops = [];
  Map<String, dynamic> journey = {};

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
    var items = this.stops.map((stop) => stop['name']).toList();

    Color fgColor = hexColor(this.departure['fgColor']);
    var lum = fgColor.computeLuminance();

    var name = this.departure['sname'] + ' ' + this.departure['direction'];
    return Scaffold(
        appBar: AppBar(
          backgroundColor: fgColor,
          brightness: lum < 0.7 ? Brightness.dark : Brightness.light,
          iconTheme: IconThemeData(color: hexColor(this.departure['bgColor'])),
          title: Text(name, style: TextStyle(color: hexColor(this.departure['bgColor']))),
        ),
        body: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                  child: ListTile(
                    title: Text(item, style: TextStyle(color: Colors.white)),
                  )
              );
            }
        )
    );
  }
}
import 'dart:io';
import 'package:arctic_tern/env.dart';
import 'package:arctic_tern/journey.dart';
import 'package:arctic_tern/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:latlong/latlong.dart';
import 'package:device_info/device_info.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';

import 'home.dart';

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
    var items = <ListItem>[];
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
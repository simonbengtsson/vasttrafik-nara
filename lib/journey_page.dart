import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/information_page.dart';
import 'package:vasttrafik_nara/map_page.dart';
import 'package:vasttrafik_nara/models.dart';
import 'package:vasttrafik_nara/stop_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyPage extends StatefulWidget {
  final Line line;
  final String lineDirection;
  final String journeyRef;

  JourneyPage(this.line, this.lineDirection, this.journeyRef);

  @override
  createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  List<Information> informationItems = [];
  JourneyDetail? journeyDetail;
  ScrollController? _scrollController;
  bool loading = true;
  StopArea? nextStop;

  _JourneyPageState();

  @override
  initState() {
    super.initState();
    fetchData().then((item) {
      trackEvent('Page Shown', {
        'Page Name': 'Journey',
        'Journey Name': widget.line.name,
        //'Journey Direction': widget.line.direction,
        'Journey Id': widget.journeyRef,
        'Shown Stop Count': item.length
      });
    }).catchError((error) {
      print('Error fetching data $error');
    });
  }

  fetchInformationItems(JourneyDetail detail) async {
    if (widget.line.id != null) {
      final info = await vasttrafikApi.getJourneyInformation(widget.line.id!);
      if (this.mounted) {
        this.setState(() {
          this.informationItems = info;
        });
      }
    }
  }

  Future<List<JourneyStop>> fetchData() async {
    // Page opened from clicking a vehicle on map etc so we
    // find the next stop instead of using the one
    var detail = await vasttrafikApi.getJourneyDetails(widget.journeyRef);
    fetchInformationItems(detail).catchError((error) {
      print('Error fetching information: $error');
    });
    var stops = detail.stops
        .where((it) => it.departureTime.isAfter(DateTime.now()))
        .toList();
    stops.sort((a, b) => a.departureTime!.compareTo(b.departureTime));
    var nextStop = stops.firstOrNull?.stopArea ?? detail.stops.last.stopArea;

    if (this.mounted) {
      this.setState(() {
        this.journeyDetail = detail;
        this.nextStop = nextStop;
        this.loading = false;
      });
    }

    return detail.stops;
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = convertHexToColor(widget.line.bgColor);
    var lum = bgColor.computeLuminance();

    final stops = this.journeyDetail?.stops ?? [];

    var nextStopIndex = stops.indexWhere((element) =>
        element.departureTime != null &&
        element.departureTime!.isAfter(DateTime.now()));

    if (_scrollController == null) {
      if (nextStopIndex != -1) {
        _scrollController =
            ScrollController(initialScrollOffset: nextStopIndex * 56.0);
      }
    }

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var listView = loading || this.journeyDetail == null
        ? loader
        : ListView.builder(
            itemCount: stops.length,
            controller: this._scrollController,
            itemBuilder: (context, index) {
              final stop = stops[index];
              var isRemainingStop =
                  stop.departureTime?.isAfter(DateTime.now()) ?? false;
              var time = '';
              var depTime = stop.departureTime;
              if (depTime != null) {
                time = formatDepartureTime(depTime, false);
              }
              var style = TextStyle(
                fontSize: 18.0,
                color: isRemainingStop
                    ? Theme.of(context).colorScheme.onBackground
                    : Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.3),
                fontWeight:
                    index == nextStopIndex ? FontWeight.w900 : FontWeight.w500,
              );

              return Container(
                  child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StopPage(stop: stop.stopArea),
                    ),
                  );
                },
                selected: isRemainingStop,
                title: Text(stop.stopArea.name, style: style),
                trailing: Text(time, style: style),
              ));
            });

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.line.name + ' ' + widget.lineDirection,
              style: TextStyle(color: convertHexToColor(widget.line.fgColor))),
          backgroundColor: bgColor,
          systemOverlayStyle: lum < 0.7
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          iconTheme:
              IconThemeData(color: convertHexToColor(widget.line.fgColor)),
          actions: [
            if (informationItems.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_rounded),
                tooltip: 'Info',
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InformationPage(
                        informations: informationItems,
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'Map',
              onPressed: stops.isEmpty
                  ? null
                  : () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPage(
                              line: widget.line,
                              lineDirection: widget.lineDirection,
                              detail: this.journeyDetail!),
                        ),
                      );
                    },
            ),
          ],
        ),
        body: listView);
  }
}

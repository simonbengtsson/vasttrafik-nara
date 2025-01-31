import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

final vasttrafikApi = VasttrafikApi();
late Mixpanel mixpanelInstance;

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

initMixpanel() async {
  if (!isMobile()) {
    return; // Mixpanel on macos was not supported
  }
  mixpanelInstance = await Mixpanel.init(
    "563842b985116f25ac9bfdea7b799cf8",
    trackAutomaticEvents: true,
  );
}

trackEvent(String eventName, [Map<String, dynamic>? props]) {
  if (!isMobile()) {
    return; // Mixpanel on macos was not supported
  }
  if (!kDebugMode) {
    mixpanelInstance.track(eventName, properties: props);
  }
  print('Logged: ${eventName}');
}

Future<void> openMap(
    BuildContext context, double latitude, double longitude) async {
  final googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
  if (await canLaunchUrl(googleUrl)) {
    await launchUrl(googleUrl);
  } else {
    showAlertDialog(context,
        title: 'Oops',
        message: 'Could not open Google Maps. Make sure it is installed.');
  }
}

showAlertDialog(BuildContext context,
    {required String title, required String message, Function? action}) {
  final actionButton = TextButton(
    child: Text('Ok'),
    onPressed: () {
      action?.call();
    },
  );

  final alert = AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      actionButton,
    ],
  );

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

Future<Position> getCurrentLocation(BuildContext context) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    showAlertDialog(
      context,
      title: 'Location Services Disabled',
      message: 'Enable location services to show stops nearby',
      action: () async {
        await Geolocator.openLocationSettings();
      },
    );
    return Future.error('Location services are disabled.');
  }

  var permission = await Geolocator.checkPermission();
  if (LocationPermission.denied == permission) {
    permission = await Geolocator.requestPermission();
  }

  if ([LocationPermission.denied, LocationPermission.deniedForever]
      .contains(permission)) {
    showAlertDialog(
      context,
      title: 'Location Permission Denied',
      message:
          'Go to phone settings and allow location permission to show nearby stops.',
      action: () async {
        await Geolocator.openAppSettings();
      },
    );
    return Future.error('Location permissions are denied');
  }

  return Geolocator.getCurrentPosition(timeLimit: Duration(seconds: 5));
}

distanceBetween(Position a, Position b) {
  return Geolocator.distanceBetween(
      a.latitude, a.longitude, b.latitude, b.longitude);
}

String formatDepartureTime(DateTime date, bool relative) {
  if (relative) {
    var timeDiff = date.difference(DateTime.now());
    if (timeDiff.inMinutes < 1) {
      return 'Now';
    } else if (timeDiff.inMinutes < 60) {
      return '${timeDiff.inMinutes}';
    }
  }
  String formattedDate = DateFormat('HH:mm').format(date);
  return formattedDate;
}

Color convertHexToColor(String hexStr) {
  var hex = 'FF' + hexStr.substring(1);
  var numColor = int.parse(hex, radix: 16);
  return Color(numColor);
}

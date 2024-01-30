import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

late Mixpanel mixpanelInstance;

initMixpanel() async {
  mixpanelInstance = await Mixpanel.init(
    "563842b985116f25ac9bfdea7b799cf8",
    trackAutomaticEvents: true,
  );
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

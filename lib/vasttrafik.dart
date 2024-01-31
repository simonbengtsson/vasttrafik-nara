import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

class Journey {
  late String name;
  late String shortName;
  late String direction;
  String? track;
  late DateTime plannedTime;
  late DateTime date;
  late Color bgColor;
  late Color fgColor;
  late Stop nextStop;
  late String stopId;
  late String journeyId;

  Journey(Map data) {
    var service = data['serviceJourney'];
    var line = data['serviceJourney']['line'];
    var stopPoint = data['stopPoint'];
    name = line['name'];
    shortName = line['shortName'];
    direction = service['direction'];
    if (direction.contains(', Påstigning fram')) {
      direction = direction.replaceAll(', Påstigning fram', '');
    }

    var planned = data['plannedTime'];
    var estimated = data['estimatedTime'] ?? planned;
    plannedTime = parseVasttrafikDate(planned);
    date = parseVasttrafikDate(estimated);
    bgColor = _hexColor(line['backgroundColor']);
    fgColor = _hexColor(line['foregroundColor']);

    journeyId = data['detailsReference'];
    stopId = stopPoint['gid'];
    track = stopPoint['platform'];
  }
}

_hexColor(hexStr) {
  var hex = 'FF' + hexStr.substring(1);
  var numColor = int.parse(hex, radix: 16);
  return Color(numColor);
}

class Stop {
  late String id;
  late double lat;
  late double lon;
  late String name;

  Stop(Map data) {
    name = data['name'];
    if (name.contains(', Göteborg')) {
      name = name.replaceAll(', Göteborg', '');
    }
    id = data['gid'];
    lat = data['latitude'];
    lon = data['longitude'] ?? 0;
  }
}

class JourneyStop {
  late DateTime? departureTime;
  late String platform;
  late String stopPointId;
  late Stop stop;

  JourneyStop(Map data) {
    // Arrival time is used for last stop
    var time = data['plannedDepartureTime'] ?? data['estimatedArrivalTime'];
    departureTime = time != null ? parseVasttrafikDate(time) : null;
    platform = data['plannedPlatform'];
    stopPointId = data['stopPoint']['gid'];
    stop = Stop(data['stopPoint']['stopArea']);
  }
}

parseVasttrafikDate(String dateStr) {
  return DateTime.parse(dateStr).toLocal();
}

class Coordinate {
  double latitude;
  double longitude;

  Coordinate(this.latitude, this.longitude);
}

class VasttrafikApi {
  String clientId;
  String clientSecret;

  String basePath = "https://ext-api.vasttrafik.se/pr/v4";

  VasttrafikApi(this.clientId, this.clientSecret);

  Future<List<Stop>> search(query) async {
    String path = "/locations/by-text";
    String queryString = "?q=$query&types=stoparea";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Stop>.from(map['results'].map((it) => Stop(it)).toList());
  }

  Future<List<Stop>> getNearby(Coordinate latLng) async {
    String path = "/locations/by-coordinates";
    String queryString =
        "?latitude=${latLng.latitude}&longitude=${latLng.longitude}&limit=500&types=stoparea";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Stop>.from(map['results'].map((it) => Stop(it)).toList());
  }

  Future<List<JourneyStop>> getJourneyStops(String ref) async {
    String url = basePath + '/journeys/${ref}/details';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<JourneyStop>.from(
        map['tripLegs'][0]['callsOnTripLeg'].map((it) => JourneyStop(it)));
  }

  Future<List<Journey>> getDepartures(String stopId) async {
    String path = "/stop-areas/${stopId}/departures";
    String queryString = "?maxDeparturesPerLineAndDirection=10&limit=20";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Journey>.from(map['results'].map((it) => Journey(it)));
  }

  _callApi(String url) async {
    Uri uri = Uri.parse(url);
    String token = await _authorize();
    return http.get(uri, headers: {'Authorization': "Bearer $token"});
  }

  _authorize() async {
    Uri uri = Uri.parse('https://ext-api.vasttrafik.se/token');
    var res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=client_credentials&client_id=${clientId}&client_secret=${clientSecret}',
    );

    var json = jsonDecode(res.body);
    return json['access_token'];
  }
}

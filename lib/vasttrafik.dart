import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

class Departure {
  late String name;
  late String shortName;
  late String direction;
  String? track;
  late DateTime plannedTime;
  late DateTime date;
  late String time;
  late Color bgColor;
  late Color fgColor;
  late Stop nextStop;
  late String stopId;
  late String journeyId;

  Departure(Map data) {
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
    plannedTime = DateTime.parse(planned);
    date = DateTime.parse(estimated);
    time = date.hour.toString();
    bgColor = _hexColor(line['backgroundColor']);
    fgColor = _hexColor(line['foregroundColor']);

    stopId = line['gid'];
    journeyId = data['detailsReference'];
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

class Journey {
  late List<Stop> stops;

  Journey(Map data) {
    stops = List<Stop>.from(data['tripLegs'][0]['callsOnTripLeg']
        .map((it) => Stop(it['stopPoint']['stopArea'])));
  }
}

class Coordinate {
  double latitude;
  double longitude;

  Coordinate(this.latitude, this.longitude);
}

class VasttrafikApi {
  String authKey;
  String authSecret;

  String basePath = "https://ext-api.vasttrafik.se/pr/v4";

  VasttrafikApi(this.authKey, this.authSecret);

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

  Future<Journey> getJourney(String ref) async {
    String url = basePath + '/journeys/${ref}/details';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return Journey(map);
  }

  Future<List<Departure>> getDepartures(String stopId) async {
    String path = "/stop-areas/${stopId}/departures";
    String queryString = "?maxDeparturesPerLineAndDirection=10&limit=20";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Departure>.from(map['results'].map((it) => Departure(it)));
  }

  _callApi(String url) async {
    Uri uri = Uri.parse(url);
    String token = await _authorize();
    return http.get(uri, headers: {'Authorization': "Bearer $token"});
  }

  _authorize() async {
    const base64 = Base64Codec();
    const utf8 = Utf8Codec();

    String str = authKey + ':' + authSecret;
    String authHeader = "Basic " + base64.encode(utf8.encode(str));

    String url = 'https://ext-api.vasttrafik.se/token';
    var body = 'grant_type=client_credentials';

    Uri uri = Uri.parse(url);
    print(uri);
    var res = await http.post(uri,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body);

    var json = jsonDecode(res.body);
    return json['access_token'];
  }
}

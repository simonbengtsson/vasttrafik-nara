import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:vasttrafik_nara/env.dart';

class Deparature {
  late Map data;
  late String name;
  late String shortName;
  late String direction;
  String? track;
  late DateTime plannedTime;
  late DateTime estimatedTime;
  late Color bgColor;
  late Color fgColor;
  late Stop nextStop;
  late String stopId;
  late String journeyRefId;

  bool get isCancelled {
    return data['isCancelled'] ?? false;
  }

  String get journeyGid {
    return data['serviceJourney']['gid'];
  }

  Deparature(Map data) {
    var service = data['serviceJourney'];
    direction = service['direction'];
    if (direction.contains(', Påstigning fram')) {
      direction = direction.replaceAll(', Påstigning fram', '');
    }

    var line = service['line'];
    name = line['name'];
    shortName = line['shortName'];
    bgColor = _hexColor(line['backgroundColor']);
    fgColor = _hexColor(line['foregroundColor']);

    var planned = data['plannedTime'];
    var estimated = data['estimatedTime'] ?? planned;
    plannedTime = parseVasttrafikDate(planned);
    estimatedTime = parseVasttrafikDate(estimated);

    journeyRefId = data['detailsReference'];

    var stopPoint = data['stopPoint'];
    stopId = stopPoint['gid'];
    track = stopPoint['platform'];

    this.data = data;
  }
}

_hexColor(hexStr) {
  var hex = 'FF' + hexStr.substring(1);
  var numColor = int.parse(hex, radix: 16);
  return Color(numColor);
}

class Stop {
  late Map data;
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
    this.data = data;
  }
}

class JourneyDetail {
  Map data;
  List<JourneyStop> stops;

  List<Coordinate> get coordinates {
    final coords = data['tripLegs'][0]['serviceJourneys'][0]
            ['serviceJourneyCoordinates'] ??
        [];
    return List<Coordinate>.from(
        coords.map((it) => Coordinate(it['latitude'], it['longitude'])));
  }

  JourneyDetail(this.data, this.stops);
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

class StopPoint {
  late Map data;
  late String id;
  late double lat;
  late double lon;
  late String name;

  StopPoint(Map data) {
    name = data['designation'];
    id = data['gid'];
    lat = data['geometry']['northingCoordinate'];
    lon = data['geometry']['eastingCoordinate'];
    this.data = data;
  }
}

class StopAreaDetail {
  late Map data;
  late String name;
  late String id;
  late double lat;
  late double lon;
  late List<StopPoint> stopPoints;

  StopAreaDetail(Map data) {
    name = data['name'];
    id = data['gid'];
    lat = data['geometry']['northingCoordinate'];
    lon = data['geometry']['eastingCoordinate'];
    stopPoints =
        List<StopPoint>.from(data['stopPoints'].map((it) => StopPoint(it)));
    this.data = data;
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

class Line {
  late Map data;
  late String name;
  late String bgColor;
  late String fgColor;
  late String transportMode;

  Line(Map data) {
    name = data['name'];
    bgColor = data['line']['backgroundColor'];
    fgColor = data['line']['foregroundColor'];
    transportMode = data['transportMode'];
    this.data = data;
  }
}

class LivePosition {
  late Map data;
  late double lat;
  late double lon;
  late DateTime updatedAt;

  String get detailsReference {
    return data['detailsReference'];
  }

  Color get bgColor {
    return _hexColor(data['line']['backgroundColor']);
  }

  Color get fbColor {
    return _hexColor(data['line']['foregroundColor']);
  }

  String get lineName {
    return data['line']?['name'] ?? '-';
  }

  LivePosition(Map data) {
    lat = data['latitude'] ?? data['lat'];
    lon = data['longitude'] ?? data['long'];
    updatedAt = DateTime.now();
    this.data = data;
  }
}

class LivePositionInternal extends LivePosition {
  late bool atStop;
  late double lat;
  late double lon;
  late double speed;
  late DateTime updatedAt;

  LivePositionInternal(Map data) : super(data) {
    atStop = data['atStop'];
    lat = data['lat'];
    lon = data['long'];
    speed = data['speed'];
    updatedAt = parseVasttrafikDate(data['updatedAt']);
  }
}

class VasttrafikApi {
  String? authToken;
  String? authTokenAlt;
  String clientId;
  String clientSecret;

  String basePlaneraResaApi =
      "https://ext-api.vasttrafik.se/pr/v4${Env.useAltCredentials ? '-int' : ''}";
  String baseGeoApi = "https://ext-api.vasttrafik.se/geo/v2";
  String baseFposApi =
      "https://ext-api.vasttrafik.se/fpos/v1"; // Only supported with alt credentials

  VasttrafikApi(this.clientId, this.clientSecret);

  Future<List<Stop>> search(query) async {
    String path = "/locations/by-text";
    String queryString = "?q=$query&types=stoparea";
    String url = basePlaneraResaApi + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Stop>.from(map['results'].map((it) => Stop(it)).toList());
  }

  Future<StopAreaDetail> stopAreaDetail(String stopAreaId) async {
    String path =
        "/StopAreas/$stopAreaId?includeStopPoints=true&includeGeometry=true&srid=4326";
    String url = baseGeoApi + path;
    var res = await _callApi(url, true);
    var json = res.body;
    var map = jsonDecode(json);
    return StopAreaDetail(map['stopArea']);
  }

// Potentially more exact? Need verification but when tried on testflight the bus got ahead of actual position.
// Does not seem to happen with the internal api
  Future<LivePositionInternal?> vehiclePosition(String journeyId) async {
    String path = "/positions/${journeyId}";
    String url = baseFposApi + path;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    if (map['status'] == 404) {
      return null;
    }
    return LivePositionInternal(map);
  }

  Future<List<LivePosition>> getAllVehicles(
      Coordinate lowerLeft, Coordinate upperRight) async {
    String url =
        '$basePlaneraResaApi/positions?lowerLeftLat=${lowerLeft.latitude}&lowerLeftLong=${lowerLeft.longitude}&upperRightLat=${upperRight.latitude}&upperRightLong=${upperRight.longitude}&limit=200';

    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<LivePosition>.from(map.map((it) => LivePosition(it)));
  }

  Future<LivePosition?> getVehicles(String journeyRefId) async {
    if (Env.useAltCredentials) {
      return await vehiclePosition(journeyRefId);
    }
    final highestValidLatitude = 90;
    final lowestValidLatitude = -90;
    final highestValidLongitude = 180;
    final lowestValidLongitude = -180;
    String url =
        '$basePlaneraResaApi/positions?lowerLeftLat=${lowestValidLatitude}&lowerLeftLong=${lowestValidLongitude}&upperRightLat=${highestValidLatitude}&upperRightLong=${highestValidLongitude}&detailsReferences=${journeyRefId}&limit=1';

    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map.isEmpty ? null : LivePosition(map[0]);
  }

  Future<List<Stop>> getNearby(Coordinate latLng) async {
    String path = "/locations/by-coordinates";
    String queryString =
        "?latitude=${latLng.latitude}&longitude=${latLng.longitude}&limit=500&types=stoparea";
    String url = basePlaneraResaApi + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Stop>.from(map['results'].map((it) => Stop(it)).toList());
  }

  Future<JourneyDetail> getJourneyDetails2(
      String stopAreaId, String ref) async {
    String url =
        basePlaneraResaApi + '/stop-areas/$stopAreaId/departures/$ref/details';
    //String url = basePlaneraResaApi + '/journeys/${ref}/details';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    var list = List<JourneyStop>.from(
        map['tripLegs'][0]['callsOnTripLeg'].map((it) => JourneyStop(it)));
    return JourneyDetail(map, list);
  }

  Future<JourneyDetail> getJourneyDetails(String stopAreaId, String ref) async {
    //String url2 = basePlaneraResaApi + '/stop-areas/$stopAreaId/departures/$ref/details';
    String url = basePlaneraResaApi +
        '/journeys/${ref}/details?includes=servicejourneycoordinates';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    var list = List<JourneyStop>.from(
        map['tripLegs'][0]['callsOnTripLeg'].map((it) => JourneyStop(it)));
    return JourneyDetail(map, list);
  }

  Future<List<Deparature>> getDepartures(String stopId) async {
    String path = "/stop-areas/${stopId}/departures";
    String queryString = "?maxDeparturesPerLineAndDirection=10&limit=20";
    String url = basePlaneraResaApi + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<Deparature>.from(map['results'].map((it) => Deparature(it)));
  }

  _callApi(String url, [bool forceNormal = false]) async {
    Uri uri = Uri.parse(url);
    var token = Env.useAltCredentials ? authTokenAlt : authToken;
    if (forceNormal) {
      token = authToken;
    }
    return http.get(uri, headers: {'Authorization': "Bearer ${token!}"});
  }

  Future authorize(bool alt) async {
    var clientId = alt ? Env.vasttrafikClientIdAlt : Env.vasttrafikClientId;
    var clientSecret =
        alt ? Env.vasttrafikClientSecretAlt : Env.vasttrafikClientSecret;
    Uri uri = Uri.parse('https://ext-api.vasttrafik.se/token');
    var res = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=client_credentials&client_id=${clientId}&client_secret=${clientSecret}',
    );

    var json = jsonDecode(res.body);
    if (alt) {
      authTokenAlt = json['access_token'];
    } else {
      authToken = json['access_token'];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vasttrafik_nara/env.dart';
import 'package:vasttrafik_nara/models.dart';

class VasttrafikApi {
  String? authToken;
  String? authTokenAlt;

  String basePlaneraResaApi = "https://ext-api.vasttrafik.se/pr/v4";
  String basePlaneraResaApiInternal =
      "https://ext-api.vasttrafik.se/pr/v4-int'";
  String baseGeoApi = "https://ext-api.vasttrafik.se/geo/v2";
  String baseInformationApi = "https://ext-api.vasttrafik.se/ts/v1";
  String baseFposApi =
      "https://ext-api.vasttrafik.se/fpos/v1"; // Only supported with alt credentials

  Future<List<StopArea>> search(query) async {
    String path = "/locations/by-text";
    String queryString = "?q=$query&types=stoparea";
    String url = basePlaneraResaApi + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<StopArea>.from(
        map['results'].map((it) => StopArea(it)).toList());
  }

  Future<StopAreaDetail> stopAreaDetail(String stopAreaId) async {
    String path =
        "/StopAreas/$stopAreaId?includeStopPoints=true&includeGeometry=true&srid=4326";
    String url = baseGeoApi + path;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return StopAreaDetail(map['stopArea']);
  }

  Future<LivePositionInternal?> getRealtimeVehiclePosition(
      String journeyId) async {
    // Realtime. Not available unless used with internal credentials found in
    // togo app.
    String url = "${baseFposApi}/positions/${journeyId}";
    var res = await _callApi(url, true);
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

  Future<LivePosition?> getVehiclePosition(String journeyRefId) async {
    if (authTokenAlt != null) {
      return await getRealtimeVehiclePosition(journeyRefId);
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

  Future<List<StopArea>> getNearby(Coordinate latLng) async {
    String path = "/locations/by-coordinates";
    String queryString =
        "?latitude=${latLng.latitude}&longitude=${latLng.longitude}&radiusInMeters=50000&limit=20&types=stoparea";
    String url = basePlaneraResaApi + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return List<StopArea>.from(
        map['results'].map((it) => StopArea(it)).toList());
  }

  Future<JourneyDetail> getJourneyDetails2(
      String stopAreaId, String ref) async {
    String url =
        basePlaneraResaApi + '/stop-areas/$stopAreaId/departures/$ref/details';
    //String url = basePlaneraResaApi + '/journeys/${ref}/details';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return JourneyDetail(map);
  }

  Future<JourneyDetail> getJourneyDetails(String ref) async {
    //String url2 = basePlaneraResaApi + '/stop-areas/$stopAreaId/departures/$ref/details';
    String url = basePlaneraResaApi +
        '/journeys/${ref}/details?includes=servicejourneycoordinates';
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return JourneyDetail(map);
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

  _callApi(String url, [bool altInternal = false]) async {
    Uri uri = Uri.parse(url);
    var token = altInternal ? authTokenAlt : authToken;
    var result = http.get(uri, headers: {'Authorization': "Bearer ${token!}"});
    return result;
  }

  Future authorizeAll() async {
    await authorize(false);
    await authorize(true);
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

    if (res.statusCode != 200) {
      print(res);
      throw Exception('Failed to authorize. Internal? ${alt}');
    }

    var json = jsonDecode(res.body);
    if (alt) {
      authTokenAlt = json['access_token'];
    } else {
      authToken = json['access_token'];
    }
  }

  Future<List<Information>> getStopInformation(String stopId) async {
    var path = '/traffic-situations/stoparea/${stopId}';
    var url = baseInformationApi + path;
    var res = await _callApi(url);
    var json = jsonDecode(res.body);
    return List<Information>.from(json.map((it) => Information(it)));
  }

  Future<List<Information>> getJourneyInformation(String lineId) async {
    var path = '/traffic-situations/line/${lineId}';
    //path = '/traffic-situations';
    var url = baseInformationApi + path;
    var res = await _callApi(url);
    var json = jsonDecode(res.body);
    return List<Information>.from(json.map((it) => Information(it)));
  }
}

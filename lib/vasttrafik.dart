import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';

class VasttrafikApi {

  String authKey = '8aOzt2RmMIG0OXSyIgjM2IkHvAoa';
  String authSecret = 'OMxjxjaXblXdpn8E1gYFehHyx3Ea';

  String basePath = "https://api.vasttrafik.se/bin/rest.exe/v2";

  search(query) async {
    String path = "/location.name";
    String queryString = "?input=$query&format=json";
    String url = basePath + path + queryString;
    return _callApi(url);
  }

  getNearby(LatLng latLng, {limit = 10}) async {
    String path = "/location.nearbystops";
    String queryString = "?originCoordLat=${latLng.latitude}&originCoordLong=${latLng.longitude}&format=json&maxNo=$limit";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map['LocationList']['StopLocation'];
  }

  getDepartures(id, date) async {
    var formatter = DateFormat('yyyy-MM-dd');
    String dateStr = formatter.format(date);
    var timeFormatter = DateFormat('HH:mm');
    String timeStr = timeFormatter.format(date);

    String path = "/departureBoard";
    String queryString = "?id=$id&date=$dateStr&time=$timeStr&format=json";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map['DepartureBoard']['Departure'];
  }

  _callApi(url) async {
    String token = await _authorize();
    return http.get(url, headers: {'Authorization': "Bearer $token"});
  }

  _authorize() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    String deviceId = '$now';

    const base64 = Base64Codec();
    const utf8 = Utf8Codec();

    String str = authKey + ':' + authSecret;
    String authHeader = "Basic " + base64.encode(utf8.encode(str));

    String url = 'https://api.vasttrafik.se/token?grant_type=client_credentials&scope=device_' + deviceId;
    var res = await http.post(url, headers: {'Authorization': authHeader});

    var json = jsonDecode(res.body);
    return json['access_token'];
  }
}

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class VasttrafikApi {
  String authKey;
  String authSecret;

  String basePath = "https://api.vasttrafik.se/bin/rest.exe/v2";

  VasttrafikApi(this.authKey, this.authSecret);

  search(query) async {
    String path = "/location.name";
    String queryString = "?input=$query&format=json";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map['LocationList']['StopLocation'];
  }

  getNearby(Position latLng) async {
    String path = "/location.nearbystops";
    String queryString =
        "?originCoordLat=${latLng.latitude}&originCoordLong=${latLng.longitude}&format=json&maxNo=500";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map['LocationList']['StopLocation'];
  }

  getJourney(String ref) async {
    var res = await _callApi(ref);
    var json = res.body;
    var map = jsonDecode(json);
    return map['JourneyDetail'];
  }

  getDepartures(id, date) async {
    var formatter = DateFormat('yyyy-MM-dd');
    String dateStr = formatter.format(date);
    var timeFormatter = DateFormat('HH:mm');
    String timeStr = timeFormatter.format(date);

    String path = "/departureBoard";
    // &timeSpan=100
    String queryString = "?id=$id&date=$dateStr&time=$timeStr&format=json";
    String url = basePath + path + queryString;
    var res = await _callApi(url);
    var json = res.body;
    var map = jsonDecode(json);
    return map['DepartureBoard']['Departure'];
  }

  removeGothenburg(name) {
    if (name.endsWith(', Göteborg')) {
      name = name.substring(0, name.length - ', Göteborg'.length);
    }
    return name;
  }

  _callApi(String url) async {
    Uri uri = Uri.parse(url);
    String token = await _authorize();
    return http.get(uri, headers: {'Authorization': "Bearer $token"});
  }

  _authorize() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    String deviceId = '$now';

    const base64 = Base64Codec();
    const utf8 = Utf8Codec();

    String str = authKey + ':' + authSecret;
    String authHeader = "Basic " + base64.encode(utf8.encode(str));

    String url =
        'https://api.vasttrafik.se/token?grant_type=client_credentials&scope=device_' +
            deviceId;
    Uri uri = Uri.parse(url);
    var res = await http.post(uri, headers: {'Authorization': authHeader});

    var json = jsonDecode(res.body);
    return json['access_token'];
  }
}

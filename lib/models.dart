class Information {
  late Map data;

  String get situationNumber {
    return data['situationNumber'];
  }

  DateTime get startTime {
    return parseVasttrafikDate(data['startTime']);
  }

  DateTime get endTime {
    return parseVasttrafikDate(data['endTime']);
  }

  String get title {
    return data['title'];
  }

  String get description {
    String message = data['description'];
    if (message
        .startsWith('Sök din resa i appen To Go eller Reseplaneraren. ')) {
      message = message.replaceAll(
          'Sök din resa i appen To Go eller Reseplaneraren. ', '');
    }
    return message;
  }

  String get severity {
    return data['severity'];
  }

  Information(Map data) {
    this.data = data;
  }
}

class Deparature {
  late Map data;
  late String name;
  late String shortName;
  late String direction;
  String? track;
  late DateTime plannedTime;
  late DateTime estimatedTime;
  late String bgColor;
  late String fgColor;
  late StopArea nextStop;
  late String stopId;
  late String journeyRefId;

  Line get line {
    return Line(data['serviceJourney']['line']);
  }

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
    bgColor = line['backgroundColor'];
    fgColor = line['foregroundColor'];

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

class StopArea {
  late Map data;
  late String id;
  late double lat;
  late double lon;
  late String name;

  StopArea(Map data) {
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

  List<JourneyStop> get stops {
    final calls = data['tripLegs'][0]['callsOnTripLeg'].where((it) {
      // There was some duplicate stops without time and platform etc
      var time = it['plannedDepartureTime'] ??
          it['estimatedArrivalTime'] ??
          it['plannedArrivalTime'] ??
          it['estimatedArrivalTime'];
      if (time == null) {
        print('No time ${it['stopPoint']['name']}');
      }
      return time != null;
    });
    return List<JourneyStop>.from(calls.map((it) => JourneyStop(it)));
  }

  String get journeyRef {
    return data['tripLegs'][0]['serviceJourneys'][0]['ref'];
  }

  String get journeyGid {
    return data['tripLegs'][0]['serviceJourneys'][0]['gid'];
  }

  List<Coordinate> get coordinates {
    final coords = data['tripLegs'][0]['serviceJourneys'][0]
            ['serviceJourneyCoordinates'] ??
        [];
    return List<Coordinate>.from(
        coords.map((it) => Coordinate(it['latitude'], it['longitude'])));
  }

  JourneyDetail(this.data);
}

class JourneyStop {
  late DateTime departureTime;
  late String platform;
  late String stopPointId;
  late StopArea stopArea;

  JourneyStop(Map data) {
    // Arrival time useful if last stop on journey since there is no departure times for those
    var time = data['estimatedDepartureTime'] ??
        data['plannedDepartureTime'] ??
        data['estimatedArrivalTime'] ??
        data['plannedArrivalTime'];
    departureTime = time != null ? parseVasttrafikDate(time) : null;
    platform = data['plannedPlatform'] ?? null;
    stopPointId = data['stopPoint']['gid'];
    stopArea = StopArea(data['stopPoint']['stopArea']);
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
  late String shortName;
  late String bgColor;
  late String fgColor;
  late String transportMode;

  Line(Map data) {
    name = data['shortName'] ?? data['name'];
    bgColor = data['backgroundColor'];
    fgColor = data['foregroundColor'];
    transportMode = data['transportMode'];
    this.data = data;
  }

  String? get id {
    // Gid not returned when line obtained from geo api
    return data['gid'];
  }
}

class LivePosition {
  late Map data;
  late double lat;
  late double lon;
  late DateTime updatedAt;

  Line get line {
    return Line(data['line']);
  }

  String get journeyRef {
    return data['detailsReference'];
  }

  String get bgColor {
    return data['line']['backgroundColor'];
  }

  String get fbColor {
    return data['line']['foregroundColor'];
  }

  String get lineName {
    return data['line']['name'] ?? '-';
  }

  LivePosition(Map data) {
    lat = data['latitude'] ?? data['lat'];
    lon = data['longitude'] ?? data['long'];
    updatedAt = DateTime.now();
    this.data = data;
  }

  String get lineDirection {
    return data['direction'];
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

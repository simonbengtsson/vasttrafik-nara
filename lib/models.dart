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
  late Stop nextStop;
  late String stopId;
  late String journeyRefId;

  String get lineId {
    return data['serviceJourney']['line']['gid'];
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

  String get bgColor {
    return data['line']['backgroundColor'];
  }

  String get fbColor {
    return data['line']['foregroundColor'];
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

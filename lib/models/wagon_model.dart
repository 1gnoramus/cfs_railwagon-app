class Wagon {
  final String number;
  final String from;
  final String to;
  final String lastStation;
  final String lastUpdate;
  final String departureTime;
  final String cargo;
  final String operation;
  final String leftDistance;
  final String group;

  Wagon({
    required this.number,
    required this.from,
    required this.to,
    required this.lastStation,
    required this.lastUpdate,
    required this.departureTime,
    required this.cargo,
    required this.operation,
    required this.leftDistance,
    this.group = "Нет группы",
  });

  factory Wagon.fromJson(Map<String, dynamic> json) {
    return Wagon(
        number: json['number'],
        from: json['from'],
        to: json['to'],
        lastStation: json['lastStation'],
        lastUpdate: json['lastUpdate'],
        departureTime: json['departureTime'],
        cargo: json['cargo'],
        operation: json['operation'],
        group: json['group'],
        leftDistance: json['leftDistance']);
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'from': from,
      'to': to,
      'lastStation': lastStation,
      'lastUpdate': lastUpdate,
      'departureTime': departureTime,
      'cargo': cargo,
      'operation': operation,
      'group': group,
      'leftDistance': leftDistance,
    };
  }
}

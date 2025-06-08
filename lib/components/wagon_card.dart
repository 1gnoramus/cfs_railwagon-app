import 'package:flutter/material.dart';

class WagonCard extends StatefulWidget {
  final String number;
  final String from;
  final String to;
  final String lastStation;
  final String lastUpdate;
  final String departureTime;
  final String cargo;
  final String operation;
  final String leftDistance;

  const WagonCard({
    super.key,
    required this.number,
    required this.from,
    required this.to,
    required this.lastStation,
    required this.lastUpdate,
    required this.departureTime,
    required this.cargo,
    required this.operation,
    required this.leftDistance,
  });

  @override
  State<WagonCard> createState() => _WagonCardState();
}

class _WagonCardState extends State<WagonCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('№ ${widget.number}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF002E5D),
                      )),
              const SizedBox(height: 8),
              Text('Маршрут: ${widget.from} → ${widget.to}'),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Последняя станция: ${widget.lastStation}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Обновлено: ${widget.lastUpdate}'),
              if (_expanded) ...[
                const Divider(),
                Text('Операция: ${widget.operation}'),
                Text('Дата выхода вагона: ${widget.departureTime}'),
                Text('Груз: ${widget.cargo}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cfs_railwagon/models/wagon_model.dart';
import 'package:cfs_railwagon/services/providers/wagon_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final String group;

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
    required this.group,
  });

  @override
  State<WagonCard> createState() => _WagonCardState();
}

class _WagonCardState extends State<WagonCard> {
  bool _expanded = false;
  late TextEditingController groupController;

  late String group;

  @override
  void initState() {
    super.initState();
    group = widget.group;
    groupController = TextEditingController(text: widget.group);
  }

  @override
  void dispose() {
    groupController.dispose();
    super.dispose();
  }

  Future<void> editWagon() async {
    groupController.text = group;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Редактировать вагон"),
          content: TextField(
            controller: groupController,
            decoration: const InputDecoration(labelText: 'Группа'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, groupController.text),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final updatedWagon = Wagon(
        number: widget.number,
        from: widget.from,
        to: widget.to,
        lastStation: widget.lastStation,
        lastUpdate: widget.lastUpdate,
        departureTime: widget.departureTime,
        cargo: widget.cargo,
        operation: widget.operation,
        leftDistance: widget.leftDistance,
        group: result,
      );

      final wagonProvider = context.read<WagonProvider>();
      await wagonProvider.editWagon(updatedWagon);

      setState(() {
        group = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группа обновлена')),
      );
    }
  }

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
              Text('Группа: ${group}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => editWagon(),
                    child: Icon(Icons.edit, size: 20),
                  )
                ],
              ),
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

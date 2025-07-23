import 'package:cfs_railwagon/models/wagon_model.dart';
import 'package:cfs_railwagon/services/providers/wagon_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String note;
  final String group;
  final bool isTracked;
  final ValueChanged<bool>? onTrackChanged;

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
    required this.isTracked,
    this.onTrackChanged,
    this.note = "Нет примечаний",
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

  String _truncateText(String text, {int maxLength = 12}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
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
          note: widget.note);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (widget.note != "Нет примечаний")
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child:
                              Icon(Icons.warning, color: Colors.red, size: 18),
                        ),
                      Text(
                        '№ ${widget.number}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF002E5D),
                                ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => editWagon(),
                    child: const Icon(Icons.edit, size: 20),
                  ),
                ],
              ),
              Text('Группа: ${group}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),

              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth * 0.3,
                            child: Column(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.blue, size: 20),
                                const SizedBox(height: 4),
                                Tooltip(
                                  message: widget.from,
                                  child: Text(
                                    _truncateText(widget.from),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _truncateText(widget.departureTime),
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Текущее местоположение
                          SizedBox(
                            width: constraints.maxWidth * 0.3,
                            child: Column(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.red, size: 20),
                                const SizedBox(height: 4),
                                Tooltip(
                                  message: widget.lastStation,
                                  child: Text(
                                    _truncateText(widget.lastStation),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _truncateText(widget.lastUpdate),
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Станция назначения
                          SizedBox(
                            width: constraints.maxWidth * 0.3,
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Tooltip(
                                  message: widget.to,
                                  child: Text(
                                    _truncateText(widget.to),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Расстояние до конечной точки
                      Positioned(
                        right: constraints.maxWidth * 0.25,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Осталось: ${_truncateText(widget.leftDistance, maxLength: 15)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: widget.isTracked,
                    onChanged: (value) =>
                        widget.onTrackChanged?.call(value ?? false),
                  ),
                  const Text("Уведомление о прибытии"),
                ],
              ),
              const SizedBox(height: 8),
              // Дополнительная информация
              if (_expanded) ...[
                const Divider(),
                Table(
                  border: TableBorder.all(color: Colors.grey),
                  columnWidths: const {
                    0: FlexColumnWidth(5),
                    1: FlexColumnWidth(5),
                  },
                  children: [
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Станция отправления:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.from),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Станция назначения:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.to),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Примечание:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              widget.note,
                              style: TextStyle(
                                color: widget.note == 'Нет примечаний'
                                    ? Colors.black
                                    : Colors.red,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Текущая станция:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.lastStation),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Осталось, км:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('${widget.leftDistance} км'),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Дата выхода:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.departureTime),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Дата последней операции:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.lastUpdate),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Операция:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.operation),
                          ),
                        )
                      ],
                    ),
                    TableRow(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Груз:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(widget.cargo),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

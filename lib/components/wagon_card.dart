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
  final String note;
  final String group;
  final bool isTracked;
  final ValueChanged<bool>? onTrackChanged;
  final void Function(String wagonNumber)? onViewHistory;

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
    this.onViewHistory,
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя строка: номер и иконки
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (widget.note != "Нет примечаний")
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent, size: 18),
                        ),
                      Text(
                        '№ ${widget.number}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF002E5D),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // История перемещений
                      IconButton(
                        icon: const Icon(Icons.info_outlined,
                            size: 20, color: Color(0xFF2B67C3)),
                        tooltip: 'История перемещений',
                        onPressed: () {
                          if (widget.onViewHistory != null) {
                            widget.onViewHistory!(widget.number);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Группа + карандаш
              Row(
                children: [
                  const Icon(Icons.group_outlined,
                      size: 16, color: Color(0xFF005BBB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Группа: $group',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: editWagon,
                    child: const Icon(Icons.edit_outlined,
                        size: 18, color: Color(0xFF555555)),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Линия маршрута
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Линия маршрута
                      Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Станции
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStationBlock(
                            color: Colors.blue,
                            title: widget.from,
                            subtitle: widget.departureTime,
                            constraints: constraints,
                          ),
                          _buildStationBlock(
                            color: Colors.red,
                            title: widget.lastStation,
                            subtitle: widget.lastUpdate,
                            constraints: constraints,
                          ),
                          _buildStationBlock(
                            color: Colors.green,
                            title: widget.to,
                            subtitle: '',
                            constraints: constraints,
                          ),
                        ],
                      ),

                      // Осталось км
                      Positioned(
                        right: constraints.maxWidth * 0.25,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Осталось: ${_truncateText(widget.leftDistance, maxLength: 15)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 6),
                _buildDetailsTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationBlock({
    required Color color,
    required String title,
    required String subtitle,
    required BoxConstraints constraints,
  }) {
    return SizedBox(
      width: constraints.maxWidth * 0.3,
      child: Column(
        children: [
          Icon(Icons.location_on, color: color, size: 18),
          const SizedBox(height: 3),
          Tooltip(
            message: title,
            child: Text(
              _truncateText(title),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              _truncateText(subtitle),
              style: TextStyle(fontSize: 9.5, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(5),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildRow('Станция отправления:', widget.from),
        _buildRow('Станция назначения:', widget.to),
        _buildRow('Примечание:', widget.note,
            valueColor: widget.note == 'Нет примечаний'
                ? Colors.black
                : Colors.redAccent),
        _buildRow('Текущая станция:', widget.lastStation),
        _buildRow('Осталось, км:', '${widget.leftDistance}'),
        _buildRow('Дата выхода:', widget.departureTime),
        _buildRow('Дата последней операции:', widget.lastUpdate),
        _buildRow('Операция:', widget.operation),
        _buildRow('Груз:', widget.cargo),
      ],
    );
  }

  TableRow _buildRow(String label, String value, {Color? valueColor}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: valueColor ?? Colors.black87),
          ),
        ),
      ],
    );
  }
}

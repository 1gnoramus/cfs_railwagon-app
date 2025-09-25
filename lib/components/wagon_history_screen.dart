import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart';

class WagonHistoryScreen extends StatefulWidget {
  final String wagonId;

  const WagonHistoryScreen({required this.wagonId, Key? key}) : super(key: key);

  @override
  _WagonHistoryScreenState createState() => _WagonHistoryScreenState();
}

class _WagonHistoryScreenState extends State<WagonHistoryScreen> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> journeyCards = []; // Изменили тип данных

  @override
  void initState() {
    super.initState();
    fetchWagonHistory();
  }

  Future<void> fetchWagonHistory() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
        journeyCards = []; // Очищаем предыдущие данные
      });

      final url =
          'https://railwagon-server.vercel.app/download?vagon_id=${widget.wagonId}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.tables.values.first;

      // Ищем настоящую строку с заголовками таблицы
      int headerRowIndex = -1;

      for (int i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        // Проверяем, есть ли в строке ключевые заголовки столбцов
        final rowText = row
            .map((c) => c?.value?.toString().toLowerCase() ?? '')
            .join(' | ');

        // Ищем строку, которая содержит все основные заголовки
        if (rowText.contains('номер вагона') &&
            rowText.contains('дата') &&
            rowText.contains('станция') &&
            rowText.contains('операция')) {
          headerRowIndex = i;
          break;
        }
      }

      // Если не нашли по полному набору, ищем по частичным совпадениям
      if (headerRowIndex == -1) {
        for (int i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final rowText = row
              .map((c) => c?.value?.toString().toLowerCase() ?? '')
              .join(' | ');

          // Считаем количество совпадений с ожидаемыми заголовками
          int matchCount = 0;
          if (rowText.contains('номер вагона')) matchCount++;
          if (rowText.contains('дата')) matchCount++;
          if (rowText.contains('станция')) matchCount++;
          if (rowText.contains('расстояние')) matchCount++;
          if (rowText.contains('операция')) matchCount++;

          if (matchCount >= 3) {
            headerRowIndex = i;
            break;
          }
        }
      }

      // Последняя попытка: ищем строку с максимальным количеством непустых ячеек
      if (headerRowIndex == -1) {
        int maxCells = 0;
        for (int i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final nonEmptyCount = row
              .where((c) =>
                  c != null &&
                  c.value != null &&
                  c.value.toString().trim().isNotEmpty)
              .length;

          if (nonEmptyCount > maxCells) {
            maxCells = nonEmptyCount;
            headerRowIndex = i;
          }
        }
      }

      if (headerRowIndex == -1) {
        throw Exception('Не удалось найти строку заголовков в файле Excel');
      }

      // Получаем заголовки
      final headerRow = sheet.rows[headerRowIndex];
      final headers =
          headerRow.map((cell) => cell?.value?.toString() ?? '').toList();

      print('Найдена строка заголовков: $headerRowIndex');

      // Находим индексы нужных колонок по точным совпадениям
      int findColumnIndex(String pattern) {
        final lowerPattern = pattern.toLowerCase();
        for (int i = 0; i < headers.length; i++) {
          final header = headers[i].toLowerCase();
          if (header.contains(lowerPattern)) {
            return i;
          }
        }
        return -1;
      }

      // Ищем конкретные заголовки
      final stationFromIndex = findColumnIndex('Станция отправления');
      final stationToIndex = findColumnIndex('Станция назначения');
      final dateIndex = findColumnIndex('Дата и время последней операции');
      final distanceIndex = findColumnIndex('Расстояние до станции назначения');

      // Если не нашли, пробуем альтернативные варианты
      if (stationFromIndex == -1) findColumnIndex('Станция отправления');
      if (stationToIndex == -1) findColumnIndex('Станция назначения');
      if (dateIndex == -1) findColumnIndex('Дата и время');
      if (distanceIndex == -1) findColumnIndex('Расстояние');

      print(
          'Индексы колонок: from=$stationFromIndex, to=$stationToIndex, date=$dateIndex, dist=$distanceIndex');

      if (stationFromIndex == -1 || stationToIndex == -1 || dateIndex == -1) {
        throw Exception('Не найдены обязательные колонки');
      }

      final List<Map<String, String>> allRows = [];
      final List<Map<String, dynamic>> newJourneyCards = [];

      // Собираем все строки с данными
      for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];

        String getCell(int idx) {
          if (idx < 0 || idx >= row.length) return '';
          final c = row[idx];
          if (c == null) return '';
          final v = c.value;
          return v == null ? '' : v.toString().trim();
        }

        final stationFrom = getCell(stationFromIndex);
        final stationTo = getCell(stationToIndex);
        final date = getCell(dateIndex);
        final distance = getCell(distanceIndex);

        // Пропускаем полностью пустые строки
        if (stationFrom.isEmpty && stationTo.isEmpty && date.isEmpty) {
          continue;
        }

        if (stationFrom.isNotEmpty && stationTo.isNotEmpty) {
          allRows.add({
            'from': stationFrom,
            'to': stationTo,
            'date': date,
            'distance': distance.isNotEmpty ? distance : '0',
          });
        }
      }

      // Группируем данные по маршрутам и находим первую и последнюю даты
      if (allRows.isNotEmpty) {
        String currentFrom = allRows.first['from']!;
        String currentTo = allRows.first['to']!;
        String firstDate = allRows.first['date']!;
        String lastDate = allRows.first['date']!;
        String distance = allRows.first['distance']!;

        for (int i = 1; i < allRows.length; i++) {
          final row = allRows[i];

          if (row['from'] == currentFrom && row['to'] == currentTo) {
            // Тот же маршрут - обновляем последнюю дату
            lastDate = row['date']!;
          } else {
            // Новый маршрут - сохраняем предыдущий и начинаем новый
            newJourneyCards.add({
              'from': currentFrom,
              'to': currentTo,
              'firstDate': firstDate,
              'lastDate': lastDate,
              'distance': distance,
            });

            currentFrom = row['from']!;
            currentTo = row['to']!;
            firstDate = row['date']!;
            lastDate = row['date']!;
            distance = row['distance']!;
          }
        }

        // Добавляем последний маршрут
        newJourneyCards.add({
          'from': currentFrom,
          'to': currentTo,
          'firstDate': firstDate,
          'lastDate': lastDate,
          'distance': distance,
        });
      }

      // Сохраняем данные в состоянии
      setState(() {
        journeyCards = newJourneyCards;
      });

      print('Найдено записей: ${allRows.length}');
      print('Создано карточек: ${newJourneyCards.length}');
    } catch (e) {
      setState(() {
        error = e.toString();
      });
      print('Ошибка: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildJourneyCard(Map<String, dynamic> journey) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Верхняя часть - станции и расстояние
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Станция отправления с красным маркером
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              journey['from'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Отправлен: ${_formatDate(journey['firstDate'])}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Расстояние по центру
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${journey['distance']} км',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),

                // Станция назначения с зеленым маркером
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              journey['to'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Прибыл: ${_formatDate(journey['lastDate'])}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Разделительная линия
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey[300]),
            SizedBox(height: 8),

            // Информация о времени в пути
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Время в пути',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  _calculateDuration(journey['firstDate'], journey['lastDate']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      // Пытаемся разобрать дату в формате "dd.mm.yyyy, hh:mm"
      final parts = dateString.split(', ');
      if (parts.length == 2) {
        return parts[0]; // Возвращаем только дату без времени
      }
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _calculateDuration(String startDate, String endDate) {
    try {
      final start = _parseDate(startDate);
      final end = _parseDate(endDate);

      if (start != null && end != null) {
        final difference = end.difference(start);
        final days = difference.inDays;
        final hours = difference.inHours % 24;

        if (days > 0) {
          return '$days дн. $hours ч.';
        } else {
          return '$hours ч.';
        }
      }
      return 'Неизвестно';
    } catch (e) {
      return 'Неизвестно';
    }
  }

  DateTime? _parseDate(String dateString) {
    try {
      // Простая обработка для формата "dd.mm.yyyy, hh:mm"
      final parts = dateString.split(', ')[0].split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget buildContent() {
    if (journeyCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'Нет данных о перемещениях',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: journeyCards.length,
      itemBuilder: (context, index) {
        return buildJourneyCard(journeyCards[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История перемещений вагона ${widget.wagonId}'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загрузка данных...'),
                ],
              ),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Ошибка загрузки',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: fetchWagonHistory,
                        icon: Icon(Icons.refresh),
                        label: Text('Попробовать снова'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : buildContent(), // Теперь используем journeyCards из состояния
    );
  }
}

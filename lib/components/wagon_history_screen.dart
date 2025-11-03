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
  List<Map<String, dynamic>> journeyCards = [];
  Map<String, String> wagonInfo = {};

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
        journeyCards = [];
      });

      final url =
          'https://railwagon-server.vercel.app/download?vagon_id=${widget.wagonId}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.tables.values.first;
// ---- Читаем общую информацию из первых строк ----
      Map<String, String> info = {};

      for (var row in sheet.rows.take(20)) {
        // читаем первые 20 строк
        if (row.length >= 2) {
          final key = row[0]?.value?.toString().trim() ?? '';
          final value = row[1]?.value?.toString().trim() ?? '';

          if (key.isNotEmpty && value.isNotEmpty) {
            info[key] = value;
          }
        }
      }

// Сохраняем данные в состояние
      setState(() {
        wagonInfo = info;
      });
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
              'firstDate': lastDate,
              'lastDate': firstDate,
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
    final from = journey['from'] ?? '';
    final to = journey['to'] ?? '';
    final firstDateStr = journey['firstDate'] ?? '';
    final lastDateStr = journey['lastDate'] ?? '';

    final inTransit =
        lastDateStr.trim().isEmpty || lastDateStr.trim() == firstDateStr.trim();

    final departureText = _formatDate(lastDateStr);
    final arrivalText = inTransit ? '—' : _formatDate(firstDateStr);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Верхняя строка: станции
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.blue[800]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    from,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    to,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.circle, size: 10, color: Colors.green[700]),
              ],
            ),

            const SizedBox(height: 6),
            const Divider(height: 1.5, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 6),

            // Нижняя строка: даты и статус
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Отпр: $departureText',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  inTransit ? 'В пути' : 'Прибыл: $arrivalText',
                  style: TextStyle(
                    fontSize: 12,
                    color: inTransit
                        ? Colors.green[700]
                        : Colors.orangeAccent[700],
                    fontWeight: inTransit ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                inTransit
                    ? 'Вагон в пути'
                    : _calculateDurationDays(firstDateStr, lastDateStr),
                style: TextStyle(
                  fontSize: 12.5,
                  color: inTransit ? Colors.green[800] : Colors.blueGrey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Вычисляет разницу в днях и возвращает строку вида "N дн." или "Менее 1 дня"
  String _calculateDurationDays(String startDate, String endDate) {
    final start = _parseDate(startDate);
    final end = _parseDate(endDate);

    if (start == null || end == null) return 'Неизвестно';

    final diff = end.difference(start);
    final days = diff.inDays;

    if (days <= 0) return 'Менее 1 дня';
    if (days == 1) return '1 дн.';
    return '$days дн.';
  }

  /// Разбор даты: поддерживает "dd.mm.yyyy, hh:mm" и "dd.mm.yyyy"
  DateTime? _parseDate(String dateString) {
    try {
      final s = dateString.trim();
      if (s.isEmpty) return null;

      // Ищем форму "dd.mm.yyyy, hh:mm" или "dd.mm.yyyy, hh:mm:ss"
      final regexp = RegExp(
          r'(\d{1,2})\.(\d{1,2})\.(\d{4})(?:,\s*(\d{1,2}):(\d{2})(?::(\d{2}))?)?');
      final m = regexp.firstMatch(s);
      if (m != null) {
        final day = int.parse(m.group(1)!);
        final month = int.parse(m.group(2)!);
        final year = int.parse(m.group(3)!);
        final hour = m.group(4) != null ? int.parse(m.group(4)!) : 0;
        final minute = m.group(5) != null ? int.parse(m.group(5)!) : 0;
        final second = m.group(6) != null ? int.parse(m.group(6)!) : 0;
        return DateTime(year, month, day, hour, minute, second);
      }

      // Попытка распарсить через DateTime.parse (на случай ISO)
      return DateTime.tryParse(s);
    } catch (e) {
      return null;
    }
  }

  /// Немного упрощённый форматтер даты для UI — возвращает "dd.mm.yyyy"
  String _formatDate(String dateString) {
    final dt = _parseDate(dateString);
    if (dt == null) return dateString;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd.$mm.$yyyy';
  }

  Widget buildWagonInfo() {
    if (wagonInfo.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.train, color: Colors.blue[700], size: 28),
              const SizedBox(width: 8),
              Text(
                'Информация о вагоне',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.confirmation_number_outlined,
                  'Номер вагона',
                  wagonInfo['Номер вагона / контейнера:'],
                ),
                const Divider(height: 12),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  'Станция отправления',
                  wagonInfo['Станция отправления:'],
                ),
                _buildInfoRow(
                  Icons.flag_outlined,
                  'Станция назначения',
                  wagonInfo['Станция назначения:'],
                ),
                _buildInfoRow(
                  Icons.location_history_outlined,
                  'Последняя операция',
                  wagonInfo['Станция последней операции:'],
                ),
                _buildInfoRow(
                  Icons.route_outlined,
                  'Расстояние до назначения',
                  '${wagonInfo['Примерное расстояние до станции назначения:'] ?? '—'} км',
                ),
                _buildInfoRow(
                  Icons.groups_2_outlined,
                  'Группа',
                  wagonInfo['Группа:'],
                ),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  'Дата добавления',
                  wagonInfo['Дата добавления на сервер:'],
                ),
                _buildInfoRow(
                  Icons.check_circle_outline,
                  'Состояние',
                  wagonInfo['Состояние:'],
                  valueColor:
                      wagonInfo['Состояние:']?.contains('слежении') == true
                          ? Colors.green[700]
                          : Colors.red[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value,
      {Color? valueColor}) {
    if (value == null || value.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[700], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54, height: 1.2)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget buildContent() {
    if (journeyCards.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            buildWagonInfo(),
            SizedBox(height: 40),
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
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: journeyCards.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return buildWagonInfo();
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[700], size: 26),
                const SizedBox(width: 8),
                Text(
                  'История перемещений',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          );
        }
        return buildJourneyCard(journeyCards[index - 2]);
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

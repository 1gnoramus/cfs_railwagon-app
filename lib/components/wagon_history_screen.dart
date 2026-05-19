import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' as ex;
import 'package:flutter/services.dart' show rootBundle;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class WagonHistoryScreen extends StatefulWidget {
  final String wagonId;

  const WagonHistoryScreen({required this.wagonId, super.key});

  @override
  _WagonHistoryScreenState createState() => _WagonHistoryScreenState();
}

class _WagonHistoryScreenState extends State<WagonHistoryScreen> {
  int _selectedTabIndex = 0;

// Список наших категорий
  final List<Map<String, dynamic>> _tabs = [
    {
      'title': 'Деповской ремонт',
      'icon': Icons.build_circle_outlined,
      'color': Colors.blue[800]
    },
    {
      'title': 'Пробег',
      'icon': Icons.speed_outlined,
      'color': Colors.green[700]
    },
    {
      'title': 'Колесные пары',
      'icon': Icons.album_outlined,
      'color': Colors.orange[800]
    },
    {
      'title': 'Трафареты',
      'icon': Icons.branding_watermark_outlined,
      'color': Colors.purple[700]
    },
  ];
  bool isLoading = true;
  bool showRepairInfo = false;
  String? error;
  List<Map<String, dynamic>> journeyCards = [];
  Map<String, String> wagonInfo = {};
  List<Map<String, String>> repairInfo = [];

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
        wagonInfo = {};
        repairInfo = [];
      });

      final url =
          'https://railwagon-server.vercel.app/download?vagon_id=${widget.wagonId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      final excel = ex.Excel.decodeBytes(response.bodyBytes);
      if (excel.tables.isEmpty) {
        throw Exception('Файл Excel пуст или не содержит таблиц');
      }

      final sheet = excel.tables.values.first;

      // ---- Читаем общую информацию из первых строк ----
      Map<String, String> localInfo = {};
      for (var row in sheet.rows.take(20)) {
        if (row.length >= 2) {
          final key = row[0]?.value?.toString().trim() ?? '';
          final value = row[1]?.value?.toString().trim() ?? '';
          if (key.isNotEmpty && value.isNotEmpty) {
            localInfo[key] = value;
          }
        }
      }

      // Ищем строку с заголовками таблицы
      int headerRowIndex = -1;
      for (int i = 0; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowText = row
            .map((c) => c?.value?.toString().toLowerCase() ?? '')
            .join(' | ');

        if (rowText.contains('номер вагона') &&
            rowText.contains('дата') &&
            rowText.contains('станция') &&
            rowText.contains('операция')) {
          headerRowIndex = i;
          break;
        }
      }

      if (headerRowIndex == -1) {
        for (int i = 0; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final rowText = row
              .map((c) => c?.value?.toString().toLowerCase() ?? '')
              .join(' | ');

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

      final headerRow = sheet.rows[headerRowIndex];
      final headers =
          headerRow.map((cell) => cell?.value?.toString() ?? '').toList();

      int findColumnIndex(String pattern) {
        final lowerPattern = pattern.toLowerCase();
        for (int i = 0; i < headers.length; i++) {
          final header = headers[i].toLowerCase();
          if (header.contains(lowerPattern)) return i;
        }
        return -1;
      }

      int stationFromIndex = findColumnIndex('Станция отправления');
      int stationToIndex = findColumnIndex('Станция назначения');
      int dateIndex = findColumnIndex('Дата и время последней операции');
      int distanceIndex = findColumnIndex('Расстояние до станции назначения');

      if (stationFromIndex == -1)
        stationFromIndex = findColumnIndex('отправления');
      if (stationToIndex == -1) stationToIndex = findColumnIndex('назначения');
      if (dateIndex == -1) dateIndex = findColumnIndex('Дата и время');
      if (distanceIndex == -1) distanceIndex = findColumnIndex('Расстояние');

      if (stationFromIndex == -1 || stationToIndex == -1 || dateIndex == -1) {
        throw Exception('Не найдены обязательные колонки (Станции или Дата)');
      }

      final List<Map<String, String>> allRows = [];
      final List<Map<String, dynamic>> newJourneyCards = [];

      for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];

        String getCell(int idx) {
          if (idx < 0 || idx >= row.length) return '';
          final c = row[idx];
          return c?.value?.toString().trim() ?? '';
        }

        final stationFrom = getCell(stationFromIndex);
        final stationTo = getCell(stationToIndex);
        final date = getCell(dateIndex);
        final distance = getCell(distanceIndex);

        if (stationFrom.isEmpty && stationTo.isEmpty && date.isEmpty) continue;

        if (stationFrom.isNotEmpty && stationTo.isNotEmpty) {
          allRows.add({
            'from': stationFrom,
            'to': stationTo,
            'date': date,
            'distance': distance.isNotEmpty ? distance : '0',
          });
        }
      }

      if (allRows.isNotEmpty) {
        String currentFrom = allRows.first['from']!;
        String currentTo = allRows.first['to']!;
        String firstDate = allRows.first['date']!;
        String lastDate = allRows.first['date']!;
        String distance = allRows.first['distance']!;

        for (int i = 1; i < allRows.length; i++) {
          final row = allRows[i];

          if (row['from'] == currentFrom && row['to'] == currentTo) {
            lastDate = row['date']!;
          } else {
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

        newJourneyCards.add({
          'from': currentFrom,
          'to': currentTo,
          'firstDate': firstDate,
          'lastDate': lastDate,
          'distance': distance,
        });
      }

      final wagonNumber = localInfo['Номер вагона / контейнера:']?.trim();
      List<Map<String, String>> localRepairInfo = [];

      if (wagonNumber != null && wagonNumber.isNotEmpty) {
        localRepairInfo = await _processRepairExcel(wagonNumber);
      }

      setState(() {
        wagonInfo = localInfo;
        journeyCards = newJourneyCards;
        repairInfo = localRepairInfo;
        isLoading = false;
      });
    } catch (e) {
      print('Ошибка парсинга: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Color _getKpColor(String value) {
    if (value.isEmpty) return Colors.transparent;

    // Убираем лишние пробелы, берем первую часть, если там написано что-то через пробел
    final cleanValue = value.trim().split(' ').first;
    final numValue = double.tryParse(cleanValue);

    if (numValue == null)
      return Colors.transparent; // Если в ячейке текст, а не число

    if (numValue < 35) {
      return Colors.red.shade100; // Меньше 35 — критично (Красный)
    } else if (numValue >= 35 && numValue < 45) {
      return Colors.orange.shade100; // 35-45 — предупреждение (Оранжевый)
    } else {
      return Colors.green.shade100; // 45 и выше — всё ок (Зеленый)
    }
  }

// Хелпер для цвета текста (чтобы на светлом фоне текст читался хорошо)
  Color _getKpTextColor(String value) {
    final cleanValue = value.trim().split(' ').first;
    final numValue = double.tryParse(cleanValue);
    if (numValue == null) return Colors.black87;

    if (numValue < 35) return Colors.red.shade900;
    if (numValue >= 35 && numValue < 45) return Colors.orange.shade900;
    return Colors.green.shade900;
  }

  Future<List<Map<String, String>>> _processRepairExcel(
      String wagonNumber) async {
    List<Map<String, String>> results = [];
    try {
      final bytes = await rootBundle.load('lib/assets/excel/remonty.xlsx');
      final decoder =
          SpreadsheetDecoder.decodeBytes(bytes.buffer.asUint8List());

      if (!decoder.tables.containsKey('Ремонты и КП')) {
        print('Лист "Ремонты и КП" не найден');
        return [];
      }

      final table = decoder.tables['Ремонты и КП']!;
      final rows = table.rows;
      if (rows.isEmpty) return [];

      // 1. Автоматически ищем строку заголовков по ключевым словам
      int headerRowIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        final rowText =
            rows[i].map((c) => c?.toString().toLowerCase() ?? '').join(' | ');
        if (rowText.contains('депо ремонта') ||
            rowText.contains('ремонтное депо')) {
          headerRowIndex = i;
          break;
        }
      }

      // Если автоматический поиск не сработал, берём самый первый ряд (индекс 0)
      if (headerRowIndex == -1) headerRowIndex = 0;
      final headerRow = rows[headerRowIndex];

      // 2. Ищем колонку с номером вагона внутри найденной строки заголовков
      int wagonColIndex = -1;
      for (int i = 0; i < headerRow.length; i++) {
        final headerText = headerRow[i]?.toString().toLowerCase().trim() ?? '';

        // Ищем слово "номер"/"вагон" или проверяем пустую ячейку над номерами
        if (headerText.contains('номер') ||
            headerText.contains('вагон') ||
            headerText.isEmpty) {
          if (rows.length > headerRowIndex + 1) {
            final nextRowValue = rows[headerRowIndex + 1][i]?.toString() ?? '';
            // Проверяем, что в следующей строке реально лежит номер вагона (начинается на 9)
            if (nextRowValue.trim().startsWith('9')) {
              wagonColIndex = i;
              break;
            }
          }
        }
      }

      if (wagonColIndex == -1) wagonColIndex = 0;
      final targetWagon = wagonNumber.trim().split('.').first;

      // 3. Бежим по строкам данных строго ПОСЛЕ строки заголовков
      for (int r = headerRowIndex + 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.length <= wagonColIndex) continue;

        String currentWagonCell = row[wagonColIndex]?.toString().trim() ?? '';
        currentWagonCell = currentWagonCell.split('.').first;

        if (currentWagonCell.isNotEmpty && currentWagonCell == targetWagon) {
          Map<String, String> data = {};

          for (int c = 0; c < headerRow.length; c++) {
            // .toLowerCase() спасет от багов, если в Excel написано капсом "ЦЕЛЕВАЯ ДАТА"
            final key = headerRow[c]?.toString().trim().toLowerCase() ?? '';
            dynamic rawValue = row.length > c ? row[c] : '';
            String value = rawValue?.toString().trim() ?? '';
            // Проверяем: если это дата в формате с буквой T, форматируем её
            if (value.contains('00:00')) {
              value = convertExcelDate(value); // Применяем функцию конвертации
            }

            if (key.isNotEmpty) {
              data[key] = value;
            }
          }

          print('PRINT $data ');
          results.add(data);
        }
      }
    } catch (e) {
      print('Ошибка парсинга ремонтов: $e');
      results = [
        {'статус': 'Ошибка парсинга файла: $e'}
      ];
    }
    return results;
  }

  String convertExcelDate(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      // Берём только часть до буквы 'T' (получим "2024-10-15")
      final datePart = rawDate.split('T').first;
      // Разделяем на [2024, 10, 15]
      final parts = datePart.split('-');

      if (parts.length == 3) {
        // Собираем в "15.10.2024"
        return '${parts[2]}.${parts[1]}.${parts[0]}';
      }
      return rawDate; // Если формат оказался странным, возвращаем как было
    } catch (e) {
      return rawDate;
    }
  }

  Widget _buildKpCircle(String title, String value, String date) {
    // Получаем базовый цвет (для фона плашки из прошлого шага)
    Color bgLight = _getKpColor(value);
    Color textColor = _getKpTextColor(value);

    // Создаем более насыщенный цвет для рамки круга
    Color borderColor = Colors.grey.shade400;
    if (bgLight == Colors.red.shade100) borderColor = Colors.red.shade400;
    if (bgLight == Colors.orange.shade100) borderColor = Colors.orange.shade400;
    if (bgLight == Colors.green.shade100) borderColor = Colors.green.shade400;

    // Если данных вообще нет
    final bool hasNoData = value.isEmpty || value == '—';

    return Column(
      children: [
        // Название над кругом (КП 1, КП 2...)
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),

        // Сам кружочек
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: hasNoData ? Colors.grey.shade100 : bgLight,
            shape: BoxShape.circle,
            border: Border.all(
                color: hasNoData ? Colors.grey.shade300 : borderColor,
                width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Text(
              hasNoData ? '—' : value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: hasNoData ? Colors.grey : textColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Дата под кружочком серым цветом
        Text(
          date.isEmpty || date == '—' ? 'нет даты' : date,
          style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget buildContent() {
    // Если истории нет И мы на вкладке истории — выводим заглушку
    if (journeyCards.isEmpty && !showRepairInfo) {
      return SingleChildScrollView(
        child: Column(
          children: [
            buildWagonInfo(),
            const SizedBox(height: 40),
            Icon(Icons.train, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Нет данных о перемещениях',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Вычисляем количество элементов динамических данных в списке
    // Для ремонтов теперь ВСЕГДА возвращаем 1 элемент, так как внутри него будут переключаемые табы
    final int dynamicItemsCount = showRepairInfo
        ? (repairInfo.isEmpty ? 1 : repairInfo.length)
        : journeyCards.length;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: 2 + dynamicItemsCount, // 2 статичные шапки + данные
      itemBuilder: (context, index) {
        if (index == 0) return buildWagonInfo();
        if (index == 1) return buildTabsSelection();

        // Рассчитываем корректный индекс для массивов данных
        final dataIndex = index - 2;

        // ==== СЕКЦИЯ РЕМОНТОВ ====
        if (showRepairInfo) {
          if (repairInfo.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32.0),
              key: ValueKey('empty_repairs'),
              child: Center(
                child: Text('Данные о ремонтах данного вагона не найдены',
                    textAlign: TextAlign.center),
              ),
            );
          }

          // Извлекаем конкретную запись ремонта для этой строки списка
          final item = repairInfo[dataIndex];

          String getValue(String targetKey) {
            if (item.containsKey(targetKey)) {
              final value = item[targetKey];
              return (value == null || value.trim().isEmpty)
                  ? '—'
                  : value.trim();
            }
            return '—';
          }

          return Padding(
            key: ValueKey('repair_$dataIndex'),
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Если записей ремонта несколько (например, старая и новая история)
                if (dataIndex > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(thickness: 2, color: Colors.blueGrey),
                  ),
                  Center(
                      child: Text('Запись ремонта №${dataIndex + 1}',
                          style: const TextStyle(color: Colors.grey))),
                  const SizedBox(height: 8),
                ],

                // 1. ГОРИЗОНТАЛЬНЫЙ СПИСОК ВНУТРЕННИХ ТАБОВ РЕМОНТА
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tabs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, tabIdx) {
                      final tab = _tabs[tabIdx];
                      final isSelected = _selectedTabIndex == tabIdx;
                      final Color activeColor = tab['color'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          avatar: Icon(tab['icon'],
                              size: 16,
                              color: isSelected ? Colors.white : activeColor),
                          label: Text(tab['title']),
                          selected: isSelected,
                          selectedColor: activeColor,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark:
                              false, // Отключаем стандартную галочку, иконки достаточно
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedTabIndex = tabIdx;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // 2. ЕДИНАЯ КАРТОЧКА, ВНУТРИ КОТОРОЙ ОБНОВЛЯЕТСЯ КОНТЕНТ
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        // ТАБ 0: ДЕПОВСКОЙ РЕМОНТ
                        Column(
                          children: [
                            _buildRepairRow('Дата посл. депо ремонта',
                                getValue('дата посл депо ремонта')),
                            _buildRepairRow('Дата след. депо ремонта',
                                getValue('дата след депо ремонта')),
                            _buildRepairRow('Целевая дата ДР (3-4 года)',
                                getValue('целевая дата др')),
                            _buildRepairRow(
                                'Ремонтное депо', getValue('ремонтное депо')),
                          ],
                        ),

                        // ТАБ 1: ПРОБЕГ ВАГОНОВ
                        Column(
                          children: [
                            _buildRepairRow(
                                'На пробеге', getValue('на пробеге')),
                            _buildRepairRow(
                                'Пробег (км)', getValue('пробег (км)')),
                            _buildRepairRow('Дата замера пробега',
                                getValue('дата замера пробега')),
                          ],
                        ),

                        // ТАБ 2: КОЛЕСНЫЕ ПАРЫ (с подсвечиванием чисел)
                        // ТАБ 2: КОЛЕСНЫЕ ПАРЫ (Визуальная схема + таблица)
                        Column(
                          children: [
                            const SizedBox(height: 12),

                            // Группируем 4 круга в один горизонтальный ряд
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildKpCircle('КП 1', getValue('кп 1'),
                                    getValue('датакп 1')),
                                _buildKpCircle('КП 2', getValue('кп 2'),
                                    getValue('датакп 2')),
                                _buildKpCircle('КП 3', getValue('кп 3'),
                                    getValue('датакп 3')),
                                _buildKpCircle('КП 4', getValue('кп 4'),
                                    getValue('датакп 4')),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // Нижняя таблица для депо и комментариев
                            _buildRepairRow('Депо', getValue('депо замены кп')),
                            _buildRepairRow('Комментарий по КП',
                                getValue('комментарий  по кп')),
                          ],
                        ),

                        // ТАБ 3: ТРАФАРЕТЫ
                        Column(
                          children: [
                            _buildRepairRow('Трафарет', getValue('трафарет')),
                            _buildRepairRow('Комментарий по трафаретам',
                                getValue('комментарий по трафаретам')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ==== СЕКЦИЯ ИСТОРИИ ПЕРЕМЕЩЕНИЙ ====
        return buildJourneyCard(journeyCards[dataIndex]);
      },
    );
  }

  // Вынесли блок выбора вкладок в отдельный красивый виджет
  Widget buildTabsSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => showRepairInfo = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: !showRepairInfo
                                ? Colors.blue[700]!
                                : Colors.transparent,
                            width: 2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline,
                        color: !showRepairInfo ? Colors.blue[700] : Colors.grey,
                        size: 24),
                    const SizedBox(width: 8),
                    Text('История',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: !showRepairInfo
                                ? Colors.blue[700]
                                : Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => showRepairInfo = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: showRepairInfo
                                ? Colors.orange
                                : Colors.transparent,
                            width: 2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Состояние',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                showRepairInfo ? Colors.orange : Colors.grey)),
                    const SizedBox(width: 8),
                    Icon(Icons.build,
                        color: showRepairInfo ? Colors.orange : Colors.grey,
                        size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.blue[800]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    from,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
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
                        fontWeight: FontWeight.w600, fontSize: 14),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Отпр: $departureText',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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

  String _calculateDurationDays(String startDate, String endDate) {
    final end = _parseDate(startDate);
    final start = _parseDate(endDate);
    if (start == null || end == null) return 'Неизвестно';

    final diff = end.difference(start);
    final days = diff.inDays;

    if (days <= 0) return 'Менее 1 дня';
    if (days == 1) return '1 дн.';
    return '$days дн.';
  }

  DateTime? _parseDate(String dateString) {
    try {
      final s = dateString.trim();
      if (s.isEmpty) return null;

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
      return DateTime.tryParse(s);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(String dateString) {
    final dt = _parseDate(dateString);
    if (dt == null) return dateString;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$dd.$mm.$yyyy';
  }

  Widget buildWagonInfo() {
    if (wagonInfo.isEmpty) return const SizedBox.shrink();

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
                    color: Colors.blue[900]),
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
                _buildInfoRow(Icons.confirmation_number_outlined,
                    'Номер вагона', wagonInfo['Номер вагона / контейнера:']),
                const Divider(height: 12),
                _buildInfoRow(Icons.location_on_outlined, 'Станция отправления',
                    wagonInfo['Станция отправления:']),
                _buildInfoRow(Icons.flag_outlined, 'Станция назначения',
                    wagonInfo['Станция назначения:']),
                _buildInfoRow(
                    Icons.location_history_outlined,
                    'Последняя операция',
                    wagonInfo['Станция последней операции:']),
                _buildInfoRow(
                  Icons.route_outlined,
                  'Расстояние до назначения',
                  wagonInfo['Примерное расстояние до станции назначения:'] !=
                          null
                      ? '${wagonInfo['Примерное расстояние до станции назначения:']} км'
                      : '—',
                ),
                _buildInfoRow(
                    Icons.groups_2_outlined, 'Группа', wagonInfo['Группа:']),
                _buildInfoRow(Icons.calendar_today_outlined, 'Дата добавления',
                    wagonInfo['Дата добавления на server:']),
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
    if (value == null || value.isEmpty) return const SizedBox.shrink();

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
                      color: valueColor ?? Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepairGroup({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: color, size: 26),
          title: Text(
            title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900]),
          ),
          iconColor: color,
          collapsedIconColor: Colors.grey[600],
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 4),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildRepairRow(String label, String value, {bool isKpValue = false}) {
    Widget valueWidget = Text(
      value.isEmpty ? '—' : value,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      textAlign: TextAlign.end, // Выравниваем текст по правому краю
    );

    // Если это значение колесной пары и оно не пустое, красим его
    if (isKpValue && value.isNotEmpty && value != '—') {
      valueWidget = Container(
        // ИСПРАВЛЕНО: возвращаем нормальный вертикальный отступ (vertical: 4 вместо 34)
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _getKpColor(value),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _getKpTextColor(value),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Левая часть (Подпись) — даем ей фиксированно 65% ширины строки
          Expanded(
            flex: 65,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines:
                  2, // Разрешаем перенос на 2 строки, если текст очень длинный
              overflow: TextOverflow
                  .ellipsis, // Если совсем не влезает — поставит три точки
            ),
          ),

          const SizedBox(
              width: 12), // Комфортный отступ между подписью и значением

          // Правая часть (Значение) — даем ей оставшиеся 35% ширины
          Expanded(
            flex: 35,
            child: Align(
              alignment:
                  Alignment.centerRight, // Прижимаем значение к правому краю
              child: valueWidget,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleWagon =
        wagonInfo['Номер вагона / контейнера:'] ?? widget.wagonId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Вагон $titleWagon'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
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
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Ошибка загрузки',
                          style: TextStyle(fontSize: 18, color: Colors.red)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: fetchWagonHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Попробовать снова'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : buildContent(),
    );
  }
}

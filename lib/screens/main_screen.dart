import 'package:cfs_railwagon/components/wagon_card.dart';
import 'package:cfs_railwagon/models/wagon_model.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Wagon> wagons = [];
  List<Wagon> filteredWagons = [];
  bool isLoading = false;
  String? errorMessage;

  // Контроллеры для поиска и фильтров
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFromStation;
  String? _selectedToStation;
  String? _selectedCurrentStation;
  String? _selectedGroup;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    downloadAndParseExcel();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedCurrentStation = null;
      _selectedFromStation = null;
      _selectedToStation = null;
      _selectedGroup = null;
      _searchController.clear();
      _isSearchFocused = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      filteredWagons = wagons.where((wagon) {
        final matchesSearch = _searchController.text.isEmpty ||
            wagon.number
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        final matchesFrom =
            _selectedFromStation == null || wagon.from == _selectedFromStation;

        final matchesTo =
            _selectedToStation == null || wagon.to == _selectedToStation;

        final matchesCurrent = _selectedCurrentStation == null ||
            wagon.lastStation == _selectedCurrentStation;
        final matchesGroup =
            _selectedGroup == null || wagon.group == _selectedGroup;

        return matchesSearch &&
            matchesFrom &&
            matchesTo &&
            matchesCurrent &&
            matchesGroup;
      }).toList();
    });
  }

  Future<void> downloadAndParseExcel() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.get(
        Uri.parse('https://railwagon-server.vercel.app/download-excel'),
      );

      if (response.statusCode == 200) {
        final excel = Excel.decodeBytes(response.bodyBytes);
        final sheet = excel.tables.values.first;
        final rows = sheet.rows;

        final newWagons = <Wagon>[];
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row[12]?.value.toString() == '57 platforms (CF&S Kazakhstan)') {
            newWagons.add(Wagon(
              number: row[0]?.value.toString() ?? 'Н/Д',
              from: row[2]?.value.toString() ?? 'Н/Д',
              to: row[3]?.value.toString() ?? 'Н/Д',
              lastStation: row[5]?.value.toString() ?? 'Н/Д',
              lastUpdate: row[6]?.value.toString() ?? 'Н/Д',
              departureTime:
                  row[4]?.value.toString() ?? 'Нет дополнительной информации',
              cargo:
                  row[9]?.value.toString() ?? 'Нет дополнительной информации',
              operation:
                  row[7]?.value.toString() ?? 'Нет дополнительной информации',
              leftDistance:
                  row[8]?.value.toString() ?? 'Нет дополнительной информации',
            ));
          }
        }

        setState(() {
          wagons = newWagons;
          filteredWagons = newWagons;
          _resetFilters();
        });
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка при загрузке данных: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildExpandingFilterDropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool isExpanded = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? 220 : 150,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        onTap: () => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
        value: value,
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'Все',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...options.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ],
        onChanged: (value) {
          onChanged(value);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFiltersSection() {
    final fromStations = wagons.map((w) => w.from).toSet().toList();
    final toStations = wagons.map((w) => w.to).toSet().toList();
    final currentStations = wagons.map((w) => w.lastStation).toSet().toList();
    final groups =
        wagons.map((w) => w.group).where((g) => g != null).toSet().toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          // Первая строка - поиск и 2 фильтра
          Row(
            children: [
              _buildSearchField(),
              _buildCompactFilterDropdown(
                label: 'Отправление',
                options: fromStations,
                value: _selectedFromStation,
                onChanged: (value) {
                  setState(() => _selectedFromStation = value);
                  _applyFilters();
                },
              ),
              _buildCompactFilterDropdown(
                label: 'Назначение',
                options: toStations,
                value: _selectedToStation,
                onChanged: (value) {
                  setState(() => _selectedToStation = value);
                  _applyFilters();
                },
              ),
            ],
          ),

          // Вторая строка - оставшиеся фильтры
          Row(
            children: [
              _buildCompactFilterDropdown(
                label: 'Текущая станция',
                options: currentStations,
                value: _selectedCurrentStation,
                onChanged: (value) {
                  setState(() => _selectedCurrentStation = value);
                  _applyFilters();
                },
              ),
              _buildCompactFilterDropdown(
                label: 'Группа',
                options: groups.cast<String>(),
                value: _selectedGroup,
                onChanged: (value) {
                  setState(() => _selectedGroup = value);
                  _applyFilters();
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.filter_alt_off, size: 20),
                tooltip: 'Сбросить фильтры',
                onPressed: _resetFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterDropdown({
    required String label,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
    double width = 100,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant,
        ),
        value: value,
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(
              'Все',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...options.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSearchFocused ? 150 : 50,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Focus(
        onFocusChange: (hasFocus) {
          setState(() {
            _isSearchFocused = hasFocus;
          });
        },
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Поиск вагона',
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Список вагонов"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: downloadAndParseExcel,
            tooltip: 'Обновить данные',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersSection(),
          if (isLoading)
            const LinearProgressIndicator()
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: filteredWagons.isEmpty && !isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.train, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          wagons.isEmpty
                              ? 'Данные не загружены'
                              : 'Ничего не найдено',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (wagons.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: downloadAndParseExcel,
                            child: const Text('Загрузить данные'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredWagons.length,
                    itemBuilder: (context, index) {
                      final wagon = filteredWagons[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: WagonCard(
                          key: ValueKey(wagon.number),
                          number: wagon.number,
                          from: wagon.from,
                          to: wagon.to,
                          lastStation: wagon.lastStation,
                          lastUpdate: wagon.lastUpdate,
                          departureTime: wagon.departureTime,
                          cargo: wagon.cargo,
                          operation: wagon.operation,
                          leftDistance: wagon.leftDistance,
                          group: wagon.group,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

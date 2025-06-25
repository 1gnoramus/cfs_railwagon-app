import 'dart:convert';

import 'package:cfs_railwagon/models/wagon_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesRepo {
  final String _key = 'saved_wagons_info';

  Future<List<Wagon>> loadWagons() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWagonsInfo = prefs.getString('${_key}');

    if (savedWagonsInfo != null) {
      List decodedData = json.decode(savedWagonsInfo);
      return decodedData.map((item) => Wagon.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> saveWagons(List<Wagon> wagonsInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = wagonsInfo.map((item) => item.toJson()).toList();
    await prefs.setString('${_key}', json.encode(jsonList));
  }

  Future<void> editWagon(Wagon updatedWagon) async {
    final prefs = await SharedPreferences.getInstance();
    final savedWagonsInfo = prefs.getString('${_key}');
    print('savedWagonsInfo');

    if (savedWagonsInfo != null) {
      List decoded = json.decode(savedWagonsInfo);
      List<Wagon> list = decoded.map((item) => Wagon.fromJson(item)).toList();

      int index = list.indexWhere(
        (wagon) => wagon.number == updatedWagon.number,
      );

      if (index != -1) {
        list[index] = updatedWagon;
        await prefs.setString(
            '${_key}', json.encode(list.map((item) => item.toJson()).toList()));
      }
    }
  }
}

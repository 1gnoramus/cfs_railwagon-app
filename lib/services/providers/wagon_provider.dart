import 'dart:convert';

import 'package:cfs_railwagon/models/wagon_model.dart';
import 'package:cfs_railwagon/services/repositories/shared_prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WagonProvider with ChangeNotifier {
  final SharedPreferencesRepo _prefsRepo = SharedPreferencesRepo();
  List<Wagon> _wagons = [];

  List<Wagon> get wagons => _wagons;
  Future<void> loadWagons() async {
    _wagons = await _prefsRepo.loadWagons();
    notifyListeners();
  }

  Future<void> saveWagons(List<Wagon> wagons) async {
    _wagons = wagons;
    await _prefsRepo.saveWagons(_wagons);

    notifyListeners();
  }

  Future<void> editWagon(Wagon updatedWagon) async {
    final index =
        _wagons.indexWhere((item) => item.number == updatedWagon.number);
    if (index != -1) {
      _wagons[index] = updatedWagon;
      await _prefsRepo.editWagon(updatedWagon);
      notifyListeners();
    }
  }

  Future<void> saveTrackedWagons(List<String> trackedNumbers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackedWagons', jsonEncode(trackedNumbers));
  }

  Future<List<String>> loadTrackedWagons() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('trackedWagons');
    if (jsonString == null) return [];
    return List<String>.from(jsonDecode(jsonString));
  }
}

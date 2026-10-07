import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/food_item.dart';

class DatabaseService {
  static const String _fileName = 'foodexp_data.json';
  late String _filePath;
  List<FoodItem> _cache = [];

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/$_fileName';
    await _load();
  }

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) {
      _cache = [];
      await _saveToDisk();
      return;
    }
    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      _cache = jsonList
          .map((j) => FoodItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      _cache = [];
    }
  }

  Future<void> _saveToDisk() async {
    final jsonList = _cache.map((item) => item.toJson()).toList();
    final file = File(_filePath);
    await file.writeAsString(json.encode(jsonList));
  }

  List<FoodItem> getAll() {
    final sorted = List<FoodItem>.from(_cache);
    sorted.sort((a, b) {
      final aExp = a.daysUntilExpiry ?? 99999;
      final bExp = b.daysUntilExpiry ?? 99999;
      return aExp.compareTo(bExp);
    });
    return sorted;
  }

  FoodItem? getById(String id) {
    try {
      return _cache.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(FoodItem item) async {
    _cache.add(item);
    await _saveToDisk();
  }

  Future<void> delete(String id) async {
    _cache.removeWhere((item) => item.id == id);
    await _saveToDisk();
  }

  Future<void> update(FoodItem item) async {
    final index = _cache.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _cache[index] = item;
    } else {
      _cache.add(item);
    }
    await _saveToDisk();
  }

  List<FoodItem> search(String query) {
    final lower = query.toLowerCase();
    return _cache
        .where((item) =>
            item.name.toLowerCase().contains(lower) ||
            (item.barcode?.contains(query) ?? false))
        .toList();
  }
}
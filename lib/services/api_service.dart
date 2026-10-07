import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class ApiService {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v2';
  static const String _userAgent = 'FoodExp/1.0 (Android)';

  /// Cerca un prodotto tramite barcode su Open Food Facts
  /// Restituisce un FoodItem pre-compilato o null se non trovato
  static Future<FoodItem?> lookupBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/product/$barcode.json'),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      // Nome prodotto
      String name = _extractName(product);

      // Data di scadenza: proviamo TUTTI i campi data possibili
      DateTime? expirationDate = _extractDate(product, [
        'expiration_date',
        'best_before_date',
        'use_by_date',
        'end_date',
        'sell_by_date',
        'display_by_date',
      ]);

      // Data di confezionamento
      DateTime? packagingDate = _extractDate(product, [
        'manufacturing_date',
        'production_date',
        'packaging_date',
        'created_datetime',
      ]);

      // Giorni dopo apertura
      int? daysAfterOpening;
      final openAfterText = _findStringInKeys(product, [
        'conservation_conditions',
        'customer_service_fr',
        'packaging_text_fr',
        'packaging_text_en',
        'packaging_text_it',
        'warning',
      ]);
      if (openAfterText != null) {
        daysAfterOpening = _extractDaysAfterOpening(openAfterText);
      }

      // Se ancora nessuna scadenza, stima in base alla categoria
      bool expiryEstimated = false;
      if (expirationDate == null) {
        expirationDate = _estimateExpiryFromCategory(product);
        expiryEstimated = expirationDate != null;
      }

      // Conservazione
      final storage = _findStringInKeys(product, [
        'conservation_conditions',
        'storage_instructions',
        'customer_service_fr',
      ]);

      return FoodItem(
        barcode: barcode,
        name: name.isEmpty ? 'Scansionato: $barcode' : name,
        packagingDate: packagingDate,
        expirationDate: expirationDate,
        daysAfterOpening: daysAfterOpening,
        storageCondition: storage,
        isExpiryEstimated: expiryEstimated,
      );
    } catch (e) {
      return null;
    }
  }

  static String _extractName(Map<String, dynamic> p) {
    String? name = p['product_name']?.toString();
    if (name != null && name.isNotEmpty) return name;

    name = p['product_name_it']?.toString();
    if (name != null && name.isNotEmpty) return name;

    name = p['generic_name']?.toString();
    if (name != null && name.isNotEmpty) return name;

    name = p['generic_name_it']?.toString();
    if (name != null && name.isNotEmpty) return name;

    final brand = p['brands']?.toString() ?? '';
    final quantity = p['product_quantity']?.toString() ?? '';
    if (brand.isNotEmpty) return '$brand ${quantity}g'.trim();

    return '';
  }

  static DateTime? _extractDate(Map<String, dynamic> p, List<String> keys) {
    for (final key in keys) {
      final val = p[key];
      if (val == null) continue;

      if (val is String && val.isNotEmpty) {
        final parsed = _tryParseDate(val);
        if (parsed != null) return parsed;
      }

      if (val is List) {
        for (final item in val) {
          final parsed = _tryParseDate(item.toString());
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  static String? _findStringInKeys(Map<String, dynamic> p, List<String> keys) {
    for (final key in keys) {
      final val = p[key];
      if (val is String && val.isNotEmpty) return val;
      if (val is List && val.isNotEmpty) return val.first.toString();
    }
    return null;
  }

  static DateTime? _tryParseDate(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) return null;

    // ISO 8601
    try {
      return DateTime.parse(raw);
    } catch (_) {}

    // DD/MM/YYYY
    try {
      final parts = raw.split('/');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}

    // YYYY-MM-DD
    try {
      final parts = raw.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return DateTime(y, m, d);
      }
    } catch (_) {}

    // MM-YYYY (ultimo giorno del mese)
    try {
      final parts = raw.split('-');
      if (parts.length == 2 && parts[0].length <= 2) {
        final m = int.parse(parts[0]);
        final y = int.parse(parts[1]);
        if (m >= 1 && m <= 12) {
          return DateTime(y, m + 1, 0);
        }
      }
    } catch (_) {}

    return null;
  }

  static int? _extractDaysAfterOpening(String text) {
    final lower = text.toLowerCase();

    final patterns = [
      RegExp(r'entro\s+(\d+)\s+giorn'),
      RegExp(r'(\d+)\s+giorn'),
      RegExp(r'within\s+(\d+)\s+day'),
      RegExp(r'(\d+)\s+day'),
      RegExp(r'dans\s+les\s+(\d+)\s+jour'),
      RegExp(r'(\d+)\s+jour'),
      RegExp(r'(\d+)\s+ore'),
      RegExp(r'(\d+)\s+hour'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final n = int.tryParse(match.group(1)!);
        if (n != null && n > 0 && n <= 90) return n;
      }
    }
    return null;
  }

  static DateTime? _estimateExpiryFromCategory(Map<String, dynamic> p) {
    final categories = <String>[];

    final tags = p['categories_tags'];
    if (tags is List) {
      categories.addAll(tags.map((t) => t.toString().toLowerCase()));
    }
    final catText = (p['categories']?.toString() ?? '').toLowerCase();
    categories.add(catText);

    final now = DateTime.now();
    final allCats = categories.join(' ');

    // Categoria -> giorni di scadenza stimati
    const categoryMap = {
      'latte': 7, 'yogurt': 14, 'formaggi': 21, 'formaggio': 21,
      'mozzarella': 10, 'ricotta': 7, 'burro': 30, 'panna': 14,
      'milk': 7, 'cheese': 21, 'yoghurt': 14, 'butter': 30, 'cream': 14,
      'pane': 3, 'bread': 3, 'fette biscottate': 180, 'cracker': 180,
      'carne': 5, 'meat': 5, 'pollo': 5, 'chicken': 5,
      'pesce': 3, 'fish': 3, 'salumi': 14, 'prosciutto': 14,
      'frutta': 7, 'fruit': 7, 'verdura': 5, 'vegetable': 7,
      'insalata': 5, 'salad': 5,
      'surgelati': 365, 'frozen': 365, 'gelato': 365, 'ice cream': 365,
      'pasta': 730, 'riso': 730, 'rice': 730,
      'cereali': 365, 'cereal': 365, 'farina': 365, 'flour': 365,
      'conserv': 730, 'canned': 730, 'scatola': 730,
      'pelati': 730, 'tonno': 730, 'legumi': 730,
      'acqua': 730, 'water': 730, 'bibita': 365, 'soda': 365,
      'succo': 180, 'juice': 180,
      'vino': 1825, 'wine': 1825, 'birra': 365, 'beer': 365,
      'biscotti': 365, 'cookie': 365,
      'cioccolato': 365, 'chocolate': 365,
      'snack': 180, 'merend': 90, 'patatine': 180, 'chips': 180,
      'uova': 28, 'egg': 28,
      'olio': 730, 'oil': 730, 'aceto': 1095, 'vinegar': 1095,
      'sale': 1825, 'salt': 1825, 'zucchero': 1095, 'sugar': 1095,
    };

    for (final entry in categoryMap.entries) {
      if (allCats.contains(entry.key)) {
        return now.add(Duration(days: entry.value));
      }
    }

    if (allCats.contains('fresh') || allCats.contains('fresco')) {
      return now.add(const Duration(days: 7));
    }

    return null;
  }
}
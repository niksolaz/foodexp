import 'package:uuid/uuid.dart';

class FoodItem {
  final String id;
  String? barcode;
  String name;
  DateTime? packagingDate;
  DateTime? expirationDate;
  DateTime? openedDate;
  int? daysAfterOpening; // giorni di durata dopo apertura
  String? storageCondition; // es. "in frigo", "in dispensa"
  String? notes;
  final DateTime createdAt;
  bool isOpened;
  bool isExpiryEstimated; // true se la scadenza proviene da stima, non da dato esatto

  FoodItem({
    String? id,
    this.barcode,
    required this.name,
    this.packagingDate,
    this.expirationDate,
    this.openedDate,
    this.daysAfterOpening,
    this.storageCondition,
    this.notes,
    DateTime? createdAt,
    this.isOpened = false,
    this.isExpiryEstimated = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  // Calcola la data di scadenza post-apertura
  DateTime? get postOpeningExpiry {
    if (openedDate == null || daysAfterOpening == null) return null;
    return openedDate!.add(Duration(days: daysAfterOpening!));
  }

  // Giorni rimanenti alla scadenza (normale o post-apertura)
  int? get daysUntilExpiry {
    final target = isOpened ? postOpeningExpiry : expirationDate;
    if (target == null) return null;
    return target.difference(DateTime.now()).inDays;
  }

  // Stato dell'alimento
  String get statusText {
    final days = daysUntilExpiry;
    if (days == null) return 'Nessuna scadenza';
    if (days < 0) return 'SCADUTO!';
    if (days == 0) return 'Scade oggi';
    if (days <= 3) return 'Scade tra $days giorni';
    return 'Ancora $days giorni';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'packagingDate': packagingDate?.toIso8601String(),
        'expirationDate': expirationDate?.toIso8601String(),
        'openedDate': openedDate?.toIso8601String(),
        'daysAfterOpening': daysAfterOpening,
        'storageCondition': storageCondition,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'isOpened': isOpened,
        'isExpiryEstimated': isExpiryEstimated,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        packagingDate: json['packagingDate'] != null
            ? DateTime.parse(json['packagingDate'] as String)
            : null,
        expirationDate: json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'] as String)
            : null,
        openedDate: json['openedDate'] != null
            ? DateTime.parse(json['openedDate'] as String)
            : null,
        daysAfterOpening: json['daysAfterOpening'] as int?,
        storageCondition: json['storageCondition'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isOpened: json['isOpened'] as bool? ?? false,
        isExpiryEstimated: json['isExpiryEstimated'] as bool? ?? false,
      );

  FoodItem copyWith({
    String? barcode,
    String? name,
    DateTime? packagingDate,
    DateTime? expirationDate,
    DateTime? openedDate,
    int? daysAfterOpening,
    String? storageCondition,
    String? notes,
    bool? isOpened,
    bool? isExpiryEstimated,
    bool clearOpenedDate = false,
    bool clearDaysAfterOpening = false,
    bool clearExpirationDate = false,
    bool clearPackagingDate = false,
    bool clearStorageCondition = false,
    bool clearNotes = false,
    bool clearBarcode = false,
  }) =>
      FoodItem(
        id: id,
        barcode: clearBarcode ? null : (barcode ?? this.barcode),
        name: name ?? this.name,
        packagingDate: clearPackagingDate
            ? null
            : (packagingDate ?? this.packagingDate),
        expirationDate: clearExpirationDate
            ? null
            : (expirationDate ?? this.expirationDate),
        openedDate:
            clearOpenedDate ? null : (openedDate ?? this.openedDate),
        daysAfterOpening: clearDaysAfterOpening
            ? null
            : (daysAfterOpening ?? this.daysAfterOpening),
        storageCondition: clearStorageCondition
            ? null
            : (storageCondition ?? this.storageCondition),
        notes: clearNotes ? null : (notes ?? this.notes),
        createdAt: createdAt,
        isOpened: isOpened ?? this.isOpened,
        isExpiryEstimated: isExpiryEstimated ?? this.isExpiryEstimated,
      );

  @override
  String toString() =>
      'FoodItem(id: $id, name: $name, barcode: $barcode, expiry: $expirationDate, opened: $isOpened)';
}
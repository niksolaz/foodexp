import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddFoodScreen extends StatefulWidget {
  final DatabaseService db;
  final String? barcode;
  final FoodItem? prefillItem;
  final bool isExpiryEstimated; // true se la scadenza è stimata, non esatta

  const AddFoodScreen({
    super.key,
    required this.db,
    this.barcode,
    this.prefillItem,
    this.isExpiryEstimated = false,
  });

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _daysAfterOpeningController;
  late TextEditingController _storageController;
  late TextEditingController _notesController;

  DateTime? _expirationDate;
  DateTime? _packagingDate;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefillItem;
    _isEditing = prefill != null;

    _nameController = TextEditingController(text: prefill?.name ?? '');
    _barcodeController =
        TextEditingController(text: widget.barcode ?? prefill?.barcode ?? '');
    _daysAfterOpeningController = TextEditingController(
        text: prefill?.daysAfterOpening?.toString() ?? '');
    _storageController =
        TextEditingController(text: prefill?.storageCondition ?? '');
    _notesController = TextEditingController(text: prefill?.notes ?? '');
    _expirationDate = prefill?.expirationDate;
    _packagingDate = prefill?.packagingDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _daysAfterOpeningController.dispose();
    _storageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry
          ? (_expirationDate ?? now)
          : (_packagingDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isExpiry ? 'Data di scadenza' : 'Data di confezionamento',
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expirationDate = picked;
        } else {
          _packagingDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final item = FoodItem(
      id: widget.prefillItem?.id,
      barcode: _barcodeController.text.isEmpty
          ? null
          : _barcodeController.text,
      name: _nameController.text.trim(),
      packagingDate: _packagingDate,
      expirationDate: _expirationDate,
      daysAfterOpening: int.tryParse(_daysAfterOpeningController.text),
      storageCondition: _storageController.text.isEmpty
          ? null
          : _storageController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isOpened: widget.prefillItem?.isOpened ?? false,
    );

    await widget.db.save(item);

    // Pianifica notifica di scadenza
    if (item.expirationDate != null) {
      await NotificationService.scheduleExpiryNotification(item);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Prodotto' : 'Nuovo Prodotto'),
        backgroundColor: const Color(0xFF1a56db),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salva',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome prodotto *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fastfood),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci il nome' : null,
            ),
            const SizedBox(height: 16),

            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'Codice a barre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Date row
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Confezionamento',
                    date: _packagingDate,
                    onTap: () => _pickDate(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: widget.isExpiryEstimated
                        ? 'Scadenza (stimata)'
                        : 'Scadenza',
                    date: _expirationDate,
                    onTap: () => _pickDate(true),
                    isExpiry: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Giorni dopo apertura
            TextFormField(
              controller: _daysAfterOpeningController,
              decoration: const InputDecoration(
                labelText: 'Giorni di durata dopo apertura',
                hintText: 'es. 3 (si conserva 3 giorni in frigo)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Condizioni conservazione
            TextFormField(
              controller: _storageController,
              decoration: const InputDecoration(
                labelText: 'Conservazione',
                hintText: 'es. In frigo dopo apertura',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.ac_unit),
              ),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Pulsante Salva
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salva Prodotto'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool isExpiry;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
    this.isExpiry = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: date != null
                ? (isExpiry ? Colors.orange : Colors.blue)
                : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isExpiry ? Icons.event_busy : Icons.event,
                  size: 18,
                  color: date != null
                      ? (isExpiry ? Colors.orange : Colors.blue)
                      : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date!.day}/${date!.month}/${date!.year}'
                        : 'Imposta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w600 : null,
                      color: date != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
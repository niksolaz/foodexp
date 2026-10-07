import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/food_item.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'add_food_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  final DatabaseService db;
  final FoodItem item;

  const FoodDetailScreen({
    super.key,
    required this.db,
    required this.item,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late FoodItem _item;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _voiceStatus = '';

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    final available = await _speech.initialize(
      onStatus: (status) {
        if (mounted) {
          setState(() => _voiceStatus = status);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _voiceStatus = 'Errore: $error');
        }
      },
    );
    if (mounted) {
      setState(() => _speechAvailable = available);
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;

    setState(() {
      _isListening = true;
      _voiceStatus = 'In ascolto...';
    });

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _processVoiceCommand(result.recognizedWords.toLowerCase());
          _speech.stop();
          setState(() {
            _isListening = false;
            _voiceStatus = '';
          });
        }
      },
      // ignore: deprecated_member_use
      localeId: 'it_IT',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _voiceStatus = '';
    });
  }

  void _processVoiceCommand(String words) {
    // Comandi vocali riconosciuti:
    // "apri" / "aperto" → imposta come aperto
    // "apri [nome]" → cerca e apri (gestito dalla home, qui assumiamo "apri")
    if (words.contains('apri') || words.contains('aperto')) {
      _markAsOpened();
    } else if (words.contains('chiudi') || words.contains('chiuso')) {
      _markAsClosed();
    } else if (words.contains('elimina') || words.contains('cancella')) {
      _confirmDelete();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comando non riconosciuto: "$words". '
              'Prova: "apri", "chiudi", "elimina"'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _markAsOpened() async {
    if (_item.isOpened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Già aperto!')),
      );
      return;
    }

    final updated = _item.copyWith(
      isOpened: true,
      openedDate: DateTime.now(),
    );

    await widget.db.update(updated);
    await NotificationService.showOpenedNotification(updated);
    await NotificationService.scheduleExpiryNotification(updated);

    setState(() => _item = updated);

    if (mounted) {
      final postExpiry = _item.postOpeningExpiry;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(postExpiry != null
              ? 'Aperto! Da consumare entro il '
                  '${postExpiry.day}/${postExpiry.month}/${postExpiry.year}'
              : 'Aperto!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _markAsClosed() async {
    if (!_item.isOpened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non ancora aperto!')),
      );
      return;
    }

    final updated = _item.copyWith(isOpened: false, clearOpenedDate: true);
    await widget.db.update(updated);
    await NotificationService.cancelItemNotifications(updated);
    await NotificationService.scheduleExpiryNotification(updated);

    setState(() => _item = updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impostato come chiuso.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina'),
        content: Text('Eliminare "${_item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await NotificationService.cancelItemNotifications(_item);
      await widget.db.delete(_item.id);
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.pop(context, true);
      }
    }
  }

  Color _expiryColor() {
    final days = _item.daysUntilExpiry;
    if (days == null) return Colors.grey;
    if (days < 0) return Colors.red;
    if (days == 0) return Colors.orange;
    if (days <= 3) return Colors.amber;
    return Colors.green;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final postExpiry = _item.postOpeningExpiry;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        backgroundColor: const Color(0xFF1a56db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddFoodScreen(
                    db: widget.db,
                    prefillItem: _item,
                  ),
                ),
              );
              if (result == true) {
                // Ricarica dal DB
                final updated = widget.db.getById(_item.id);
                if (updated != null && mounted) {
                  setState(() => _item = updated);
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color:
                _item.isOpened ? Colors.deepOrange.withAlpha(20) : null,
            child: Row(
              children: [
                Icon(
                  _item.isOpened
                      ? Icons.open_in_full
                      : Icons.inventory_2_outlined,
                  color: _item.isOpened ? Colors.deepOrange : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _item.isOpened ? 'APERTO' : 'CHIUSO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _item.isOpened
                              ? Colors.deepOrange
                              : Colors.grey,
                        ),
                      ),
                      Text(
                        _item.statusText,
                        style: TextStyle(
                          color: _expiryColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge giorni rimanenti
                if (_item.daysUntilExpiry != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _expiryColor().withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _expiryColor()),
                    ),
                    child: Text(
                      '${_item.daysUntilExpiry}d',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _expiryColor(),
                        fontSize: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Dettagli
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _detailRow(Icons.qr_code, 'Codice a barre',
                    _item.barcode ?? 'Nessuno'),
                _detailRow(Icons.calendar_today, 'Confezionamento',
                    _formatDate(_item.packagingDate)),
                _detailRow(Icons.event_busy, 'Scadenza',
                    _formatDate(_item.expirationDate)),
                if (_item.isOpened)
                  _detailRow(Icons.open_in_new, 'Data apertura',
                      _formatDate(_item.openedDate)),
                if (_item.isOpened && _item.daysAfterOpening != null)
                  _detailRow(
                      Icons.timer, 'Scadenza post-apertura',
                      _formatDate(postExpiry)),
                if (_item.daysAfterOpening != null)
                  _detailRow(Icons.schedule, 'Durata dopo apertura',
                      '${_item.daysAfterOpening} giorni'),
                if (_item.storageCondition != null &&
                    _item.storageCondition!.isNotEmpty)
                  _detailRow(Icons.ac_unit, 'Conservazione',
                      _item.storageCondition!),
                if (_item.notes != null && _item.notes!.isNotEmpty)
                  _detailRow(Icons.notes, 'Note', _item.notes!),
              ],
            ),
          ),
        ],
      ),
      // Pulsante apri/chiudi con voce
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Pulsante apri/chiudi principale
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _item.isOpened ? _markAsClosed : _markAsOpened,
                  icon: Icon(_item.isOpened
                      ? Icons.inventory_2
                      : Icons.open_in_full),
                  label: Text(_item.isOpened ? 'Chiudi' : 'Apri'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _item.isOpened
                        ? Colors.grey[700]
                        : Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Pulsante vocale
              FloatingActionButton(
                onPressed: _isListening ? _stopListening : _startListening,
                backgroundColor: _isListening ? Colors.red : const Color(0xFF1a56db),
                tooltip: _voiceStatus.isNotEmpty ? _voiceStatus : (_isListening ? 'Ascoltando...' : 'Comandi vocali'),
                child: Icon(
                  _isListening ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
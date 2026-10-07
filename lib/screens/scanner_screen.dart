import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import 'add_food_screen.dart';

class ScannerScreen extends StatefulWidget {
  final DatabaseService db;

  const ScannerScreen({super.key, required this.db});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.pdf417,
        BarcodeFormat.qrCode,
        BarcodeFormat.itf,
        BarcodeFormat.aztec,
      ],
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _isProcessing = true;
    final raw = barcode.rawValue!;

    // Feedback aptico
    // (opzionale: HapticFeedback.lightImpact())

    try {
      // Cerca su Open Food Facts
      final foodItem = await ApiService.lookupBarcode(raw);

      if (!mounted) return;

      // Vai alla schermata di aggiunta (pre-compilata o vuota)
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddFoodScreen(
            db: widget.db,
            barcode: raw,
            prefillItem: foodItem,
            isExpiryEstimated: foodItem?.isExpiryEstimated ?? false,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true); // Torna alla home con refresh
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore durante la ricerca';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _manualEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodScreen(db: widget.db),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona'),
        backgroundColor: const Color(0xFF1a56db),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Errore fotocamera: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _manualEntry,
                      child: const Text('Inserisci manualmente'),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay mirino
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing
                      ? Colors.deepOrange
                      : const Color(0xFF1a56db),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Ricerca prodotto...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Error message
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Pulsante inserimento manuale
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _manualEntry,
              icon: const Icon(Icons.edit_note),
              label: const Text('Inserisci manualmente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1a56db),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Toggle flash
          Positioned(
            top: 16,
            right: 16,
            child: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) {
                final hasFlash = switch (state.torchState) {
                  TorchState.auto => null, // unknown
                  TorchState.off => false,
                  TorchState.on => true,
                  TorchState.unavailable => null,
                };
                // Mostra il pulsante flash sempre; se unavailable, sarà disabilitato
                return IconButton(
                  onPressed: () {
                    if (hasFlash != null) {
                      _controller.toggleTorch();
                    }
                  },
                  icon: Icon(
                    hasFlash == true ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black38,
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
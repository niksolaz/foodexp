import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import 'scanner_screen.dart';
import 'food_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final DatabaseService db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FoodItem> _items = [];
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _items = widget.db.getAll();
      } else {
        _items = widget.db.search(_searchQuery);
      }
    });
  }

  Color _expiryColor(FoodItem item) {
    final days = item.daysUntilExpiry;
    if (days == null) return Colors.grey;
    if (days < 0) return Colors.red;
    if (days == 0) return Colors.orange;
    if (days <= 3) return Colors.amber;
    return Colors.green;
  }

  IconData _expiryIcon(FoodItem item) {
    final days = item.daysUntilExpiry;
    if (days == null) return Icons.help_outline;
    if (days < 0) return Icons.dangerous;
    if (days <= 3) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cerca alimento...',
                  border: InputBorder.none,
                ),
                onChanged: (q) {
                  _searchQuery = q;
                  _loadItems();
                },
              )
            : const Text('FoodExp'),
        backgroundColor: const Color(0xFF1a56db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                  _loadItems();
                }
              });
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.kitchen, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun alimento',
                    style: TextStyle(
                        fontSize: 20, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scansiona un codice a barre o aggiungi\nmanualmente un prodotto',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _loadItems(),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildItemCard(item);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToScanner(),
        backgroundColor: const Color(0xFF1a56db),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scansiona'),
      ),
    );
  }

  Widget _buildItemCard(FoodItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _expiryColor(item).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _expiryIcon(item),
                  color: _expiryColor(item),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.isOpened) ...[
                          const Icon(Icons.open_in_full,
                              size: 14, color: Colors.deepOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Aperto',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepOrange[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _expiryColor(item),
                          ),
                        ),
                      ],
                    ),
                    if (item.storageCondition != null &&
                        item.storageCondition!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.storageCondition!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Days badge
              if (item.daysUntilExpiry != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _expiryColor(item).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.daysUntilExpiry}d',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _expiryColor(item),
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScannerScreen(db: widget.db)),
    );
    if (result == true) _loadItems();
  }

  Future<void> _openDetail(FoodItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => FoodDetailScreen(db: widget.db, item: item)),
    );
    if (result == true) _loadItems();
  }
}
import 'package:flutter/material.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';

import '../widgets/item_extension_dialog.dart';
import 'extensions_logs_view.dart';

class ExtensionsView extends StatefulWidget {
  const ExtensionsView({super.key});

  @override
  State<ExtensionsView> createState() => _ExtensionsViewState();
}

class _ExtensionsViewState extends State<ExtensionsView> {
  final FirebaseServiceForItems _service = FirebaseServiceForItems();
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => isLoading = true);
    final categories = await _service.getCategories();

    // Fetch items in parallel
    final futures = categories.map((category) async {
      final items = await _service.searchItems(category.name, '');
      return items.map((item) => {
        ...item,
        'categoryName': category.name,
        'categoryId': category.name,
      });
    });

    final results = await Future.wait(futures);
    final tempList = results.expand((list) => list).toList();

    setState(() {
      allItems = tempList;
      filteredItems = tempList;
      isLoading = false;
    });
  }

  void _filterItems(String query) {
    setState(() {
      searchQuery = query;
      filteredItems = allItems.where((item) {
        final name = item['name'].toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showExtensionDialog(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ItemExtensionDialog(item: item),
    );

    if (result == true) {
      _loadItems(); // Refresh after extension
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Extensions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExtensionLogsView()),
              );
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search items...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterItems,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                final quantity = item['quantity'] ?? 0;
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor:
                        quantity > 0 ? Colors.green : Colors.red,
                        child: Text('$quantity'),
                      ),
                      title: Text(
                        item['name'] ?? 'No Name',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Category: ${item['categoryName']}'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _showExtensionDialog(item),
                    ),
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

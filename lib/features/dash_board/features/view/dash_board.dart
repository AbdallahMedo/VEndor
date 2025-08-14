import 'package:flutter/material.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import '../../../vendor_items/presentation/views/category_item_view.dart';

class DashboardPage extends StatefulWidget {
  final bool isAdmin;
  const DashboardPage({super.key, this.isAdmin = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseServiceForItems _firebaseService = FirebaseServiceForItems();

  Map<String, dynamic>? _itemResult;
  bool _isLoading = false;

  Future<void> _searchItem() async {
    final itemId = _searchController.text.trim();
    if (itemId.isEmpty) return;

    setState(() => _isLoading = true);

    final item = await _firebaseService.getItemById(itemId);

    setState(() {
      _itemResult = item;
      _isLoading = false;
    });
  }

  Widget _buildResultCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_itemResult == null) {
      return const Center(
        child: Text("No item found", style: TextStyle(fontSize: 16)),
      );
    }

    return GestureDetector(
      onTap: () {
        final categoryId = _itemResult!['categoryId'];
        final categoryName = _itemResult!['categoryName'];

        if (categoryId != null && categoryName != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryItemsView(
                categoryId: categoryId,
                categoryName: categoryName,
                isAdmin: widget.isAdmin,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Missing category info for this item."),
            ),
          );
        }
      },
      child: Card(
        elevation: 5,
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.qr_code, "Item ID", _itemResult!['itemId']),
              const SizedBox(height: 8),
              _infoRow(Icons.label, "Name", _itemResult!['name']),
              const SizedBox(height: 8),
              _infoRow(Icons.storage, "Quantity", _itemResult!['quantity'].toString()),
              const SizedBox(height: 8),
              _infoRow(Icons.category, "Category", _itemResult!['categoryName']),
              const SizedBox(height: 8),
              _infoRow(Icons.person, "Added By", _itemResult!['addedBy']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Text(
          "$label: ",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value.toString(),
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Enter Item ID',
                  hintText: 'e.g., abc123',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _itemResult = null);
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => _searchItem(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildResultCard()),
          ],
        ),
      ),
    );
  }
}

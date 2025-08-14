import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../vendor_items/presentation/views/category_item_view.dart';

class SearchPage extends StatefulWidget {
  final bool isAdmin;

  const SearchPage({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Items",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration:  InputDecoration(
                hintText: "Search by item name...",
                border: OutlineInputBorder(
                  borderRadius:BorderRadius.circular(15)
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No items found."));
                }

                final results = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_query);
                }).toList();

                if (results.isEmpty) {
                  return const Center(child: Text("No matching items."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final itemDoc = results[index];
                    final item = itemDoc.data() as Map<String, dynamic>;

                    final itemName = item['name'] ?? 'Unnamed';
                    final quantity = item['quantity'] ?? 0;
                    final categoryId = item['categoryId'];
                    final categoryName = item['categoryName'];

                    // Get the first letter and uppercase it
                    final firstLetter = itemName.isNotEmpty ? itemName[0].toUpperCase() : '?';

                    // Generate a color from the first letter for avatar background
                    final avatarColor = Colors.primaries[firstLetter.codeUnitAt(0) % Colors.primaries.length];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      elevation: 3,

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        leading: CircleAvatar(
                          backgroundColor: avatarColor,
                          child: Text(
                            firstLetter,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          itemName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "Qty: $quantity",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                        onTap: () {
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

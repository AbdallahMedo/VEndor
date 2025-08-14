import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';


class ItemExtensionDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemExtensionDialog({super.key, required this.item});

  @override
  State<ItemExtensionDialog> createState() => _ItemExtensionDialogState();
}

class _ItemExtensionDialogState extends State<ItemExtensionDialog> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final FirebaseServiceForItems _service = FirebaseServiceForItems();

  bool isLoading = false;
  bool isCheckingQuantity = false;
  String? errorMessage;

  Future<void> _showInsufficientQuantityDialog(int availableQty ,int qty) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Quantity'),
        content: Text(
            'Available quantity is $availableQty  which is less than the requested amount $qty .'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<int> _getAvailableQuantity() async {
    try {
      final item = widget.item;
      final doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(item['categoryId'])
          .collection('items')
          .doc(item['id'])
          .get();

      return doc.data()?['quantity'] ?? 0;
    } catch (e) {
      print('Error getting available quantity: $e');
      return 0;
    }
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_quantityController.text.trim());
    final reason = _reasonController.text.trim();

    if (qty == null || qty <= 0) {
      setState(() => errorMessage = 'Please enter a valid quantity.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => errorMessage = 'Reason is required.');
      return;
    }

    setState(() {
      errorMessage = null;
      isCheckingQuantity = true;
    });

    try {
      final availableQty = await _getAvailableQuantity();

      if (availableQty < qty) {
        setState(() => isCheckingQuantity = false);
        await _showInsufficientQuantityDialog(availableQty,qty);
        return;
      }

      setState(() {
        isCheckingQuantity = false;
        isLoading = true;
      });

      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';
      final item = widget.item;

      await _service.decreaseItemQuantity(
        categoryName: item['categoryName'],
        itemId: item['id'],
        itemName: item['name'],
        deleteQuantity: qty,
        deletedBy: userEmail,
      );

      await FirebaseFirestore.instance.collection('vendor_extensions').add({
        'itemId': item['id'],
        'itemName': item['name'],
        'categoryId': item['categoryId'],
        'categoryName': item['categoryName'],
        'quantity': qty,
        'reason': reason,
        'deliveredBy': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        errorMessage = 'Something went wrong. Please try again.';
        isLoading = false;
        isCheckingQuantity = false;
      });
      print('Error extending item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Extend Item',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  item['name'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.note_alt),
                    border: OutlineInputBorder(),
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: (isLoading || isCheckingQuantity) ? null : () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton.icon(
                      onPressed: (isLoading || isCheckingQuantity) ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: const Text("Confirm"),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isLoading || isCheckingQuantity)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (isCheckingQuantity)
                        const SizedBox(height: 8),
                      if (isCheckingQuantity)
                        const Text(
                          'Checking available quantity...',
                          style: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
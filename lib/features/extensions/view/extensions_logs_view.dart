import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExtensionLogsView extends StatelessWidget {
  const ExtensionLogsView({super.key});

  Future<void> _deleteLog(String docId) async {
    await FirebaseFirestore.instance
        .collection('vendor_extensions')
        .doc(docId)
        .delete();
  }

  Future<void> _clearAllLogs(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('Are you sure you want to delete all logs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (shouldClear == true) {
      final batch = FirebaseFirestore.instance.batch();
      final logs = await FirebaseFirestore.instance.collection('vendor_extensions').get();
      for (var doc in logs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final logStream = FirebaseFirestore.instance
        .collection('vendor_extensions')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Extension Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear All Logs',
            onPressed: () => _clearAllLogs(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: logStream,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No logs found."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final item = data['itemName'] ?? 'Unnamed';
              final qty = data['quantity'] ?? 0;
              final user = data['deliveredBy'] ?? 'Unknown';
              final reason = data['reason'] ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('$item × $qty'),
                    subtitle: Text(
                      'By: $user\nReason: $reason\nTime: ${timestamp ?? 'N/A'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Log',
                      onPressed: () => _deleteLog(doc.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

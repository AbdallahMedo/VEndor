import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String name;
  final int quantity;
  final VoidCallback? onDelete;
  final VoidCallback? onAdd;
  final bool isAdmin;
  final bool readOnly; // New flag

  const ItemCard({
    super.key,
    required this.name,
    required this.quantity,
    this.onDelete,
    this.onAdd,
    this.isAdmin = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.indigoAccent.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // CircleAvatar with first letter
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigoAccent,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name and quantity info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[900],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quantity: $quantity',
                    style: theme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // Only show buttons if not readOnly
            if (!readOnly) ...[
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Colors.blueAccent,
                iconSize: 28,
                onPressed: onAdd,
                tooltip: 'Add Quantity',
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  iconSize: 28,
                  onPressed: onDelete,
                  tooltip: 'Delete Quantity',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

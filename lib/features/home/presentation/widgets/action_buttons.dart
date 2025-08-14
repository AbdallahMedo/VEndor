import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onAddCategory;
  final VoidCallback onAddItem;
  final VoidCallback onDeleteCategory;
  final VoidCallback onCompletedBoards;
  final VoidCallback onEditCategory;
  final VoidCallback onEditItemName; // ✅ NEW


  /// ✅ NEW
  final VoidCallback onSearchItems;

  const ActionButtons({
    Key? key,
    required this.isAdmin,
    required this.onAddCategory,
    required this.onAddItem,
    required this.onDeleteCategory,
    required this.onCompletedBoards,
    required this.onEditCategory,
    required this.onSearchItems,
    required this.onEditItemName,

  }) : super(key: key);

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 60,
          width: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: [Colors.indigoAccent, Colors.deepPurpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.add_box,
            label: "Add Category",
            onTap: onAddCategory,
          ),
          _buildActionButton(
            icon: Icons.playlist_add,
            label: "Add Item",
            onTap: onAddItem,
          ),
          _buildActionButton(
            icon: Icons.delete_forever,
            label: "Delete Category",
            onTap: onDeleteCategory,
          ),
          _buildActionButton(
            icon: Icons.done_all,
            label: "Completed Boards",
            onTap: onCompletedBoards,
          ),
          _buildActionButton(
            icon: Icons.edit,
            label: "Edit Category",
            onTap: onEditCategory,
          ),
          /// ✅ NEW BUTTON
          _buildActionButton(
            icon: Icons.search,
            label: "Search Items",
            onTap: onSearchItems,
          ),
          _buildActionButton(
            icon: Icons.edit_note,
            label: "Edit Item Name",
            onTap: onEditItemName,
          ),

        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class RoleCard extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onTap;

  const RoleCard({super.key, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 4,
        color: isAdmin ? Colors.green.shade100 : Colors.blue.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
            color: isAdmin ? Colors.green : Colors.blue,
          ),
          title: Text(
            isAdmin ? "You are an Admin" : "You are a User",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

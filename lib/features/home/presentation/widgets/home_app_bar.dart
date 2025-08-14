import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isSearchActive;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchToggle;
  // final VoidCallback onLogout;
  final VoidCallback refresh;
  final String firstName;
  final String lastName;

  const HomeAppBar({
    Key? key,
    required this.isSearchActive,
    required this.onSearchChanged,
    required this.onSearchToggle,
    // required this.onLogout,
    required this.refresh,
    required this.firstName,
    required this.lastName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (context) {
          return IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          );
        },
      ),
      title: isSearchActive
          ? TextField(
        onChanged: onSearchChanged,
        autofocus: true,
        style: const TextStyle(color: Colors.black),
        decoration: const InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: Colors.black),
          border: InputBorder.none,
        ),
      )
          : Text(
        "Hi, $firstName $lastName",
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          onPressed: onSearchToggle,
          icon: Icon(isSearchActive ? Icons.close : Icons.search),
        ),
        // IconButton(
        //   onPressed: onLogout,
        //   icon: const Icon(Icons.logout,color: Colors.red,),
        // ),

        IconButton(onPressed: refresh, icon: Icon(Icons.refresh),),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../services/firebase_services.dart';
import '../../../Manufacturing order/manufacturing_order.dart';
import '../../../add_user/add_new_user.dart';
import '../../../completed_boards/boards_view.dart';
import '../../../completed_boards/delivered_view.dart';
import '../../../dash_board/features/view/dash_board.dart';
import '../../../deletion_requests/deletion_requests.dart';
import '../../../extensions//view/extensions_logs_view.dart';
import '../../../extensions//view/extensions_view.dart';
import '../../../login/presentation/views/login_view.dart';
import '../../../shortage_view/shortage_view.dart';
import '../../../synthesize_view/synthesize_view.dart';
import 'change_password.dart';
import 'role_card.dart';

class AppDrawer extends StatefulWidget {
  AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String currentDate = '';
  String currentTime = '';
  bool isAdmin = false;
  bool isLoading = true;
  String firstName = '';
  String lastName = '';
  int _shortageItemCount = 0;
  int _deletionRequestCount = 0;
  int _manufacturingRequestCount = 0;
  StreamSubscription? _manufacturingSubscription;
  StreamSubscription? _shortageSubscription;
  StreamSubscription? _deletionSubscription;

  final FirebaseService _fire = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DocumentReference _limitsDocRef =
      FirebaseFirestore.instance.collection('shortageLimits').doc('itemLimits');

  final List<String> _emojis = ['😊', '👋', '🎉', '🚀', '🧪', '💡'];
  int _emojiIndex = 0;
  Timer? _emojiTimer;

  void _setCurrentDateTime() {
    final now = DateTime.now();
    currentDate = DateFormat('yMMMMd').format(now);
    currentTime = DateFormat('jm').format(now);
  }

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _startEmojiTimer();
    _setCurrentDateTime();
    _setupShortageListener();
    _setupDeletionListener();
    _setupManufacturingListener();
    _startNotificationListener();
  }
  void _startNotificationListener() {
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    if (currentEmail == null) return;

    FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: currentEmail)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final data = doc.doc.data();
          if (data != null) {
            _showInAppNotification(data['title'], data['message']);
            doc.doc.reference.update({'read': true});
          }
        }
      }
    });
  }

  void _showInAppNotification(String? title, String? message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListTile(
          leading: const Icon(Icons.notifications, color: Colors.white),
          title: Text(title ?? 'Notification', style: const TextStyle(color: Colors.white)),
          subtitle: Text(message ?? '', style: const TextStyle(color: Colors.white70)),
        ),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  void _startEmojiTimer() {
    _emojiTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() => _emojiIndex = (_emojiIndex + 1) % _emojis.length);
    });
  }

  void _setupShortageListener() {
    _shortageSubscription = _firestore
        .collectionGroup('items')
        .snapshots()
        .listen((itemsSnapshot) async {
      final limitsSnapshot = await _limitsDocRef.get();
      final Map<String, int> customLimits = {};

      if (limitsSnapshot.exists) {
        final data = limitsSnapshot.data() as Map<String, dynamic>;
        data.forEach((key, value) {
          customLimits[key] =
              value is int ? value : int.tryParse(value.toString()) ?? 1;
        });
      }

      int count = 0;
      for (var doc in itemsSnapshot.docs) {
        final itemData = doc.data();
        final itemName = itemData['name']?.toString() ?? 'Unnamed';
        final quantity = (itemData['quantity'] is int)
            ? itemData['quantity'] as int
            : (itemData['quantity'] as double?)?.toInt() ?? 0;
        final limit = customLimits[itemName] ?? 1;

        if (quantity < limit) {
          count++;
        }
      }

      if (mounted) {
        setState(() => _shortageItemCount = count);
      }
    });
  }

  void _setupDeletionListener() {
    _deletionSubscription = _firestore
        .collection('deletion_requests')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _deletionRequestCount = snapshot.docs.length);
      }
    });
  }

  void _setupManufacturingListener() {
    _manufacturingSubscription = FirebaseFirestore.instance
        .collection('manufacturing_requests')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _manufacturingRequestCount = snapshot.docs.length);
      }
    });
  }

  @override
  void dispose() {
    _emojiTimer?.cancel();
    _shortageSubscription?.cancel();
    _deletionSubscription?.cancel();
    _manufacturingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.email).get();
        final data = doc.data();

        if (data != null && mounted) {
          setState(() {
            isAdmin = data['isAdmin'] == true;
            firstName = data['firstName'] ?? '';
            lastName = data['lastName'] ?? '';
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      width: 350,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo, Colors.deepPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${_emojis[_emojiIndex]} Hi, $firstName $lastName',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📅 $currentDate',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              '⏰ $currentTime',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      RoleCard(
                        isAdmin: isAdmin,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isAdmin
                                ? 'You have administrator access.'
                                : 'You are logged in as a regular user.'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDrawerTile(
                        icon: Icons.memory,
                        title: 'Boards',
                        onTap: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BoardsView(
                                  deletedBy: user.displayName ??
                                      user.phoneNumber ??
                                      user.uid,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _buildDrawerTile(
                        icon: Icons.mark_email_read_outlined,
                        title: 'Deliver',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DeliveredViews()),
                        ),
                      ),
                      _buildDrawerTile(
                        icon: Icons.extension,
                        title: 'Extensions',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ExtensionsView()),
                        ),
                      ),
                      _buildDrawerTile(
                        icon: Icons.send_time_extension,
                        title: 'Extensions Logs',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ExtensionLogsView()),
                        ),
                      ),

                      if (!isAdmin)
                        _buildDrawerTile(
                          icon: Icons.dangerous_outlined,
                          title: 'Defected',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SynthesizeView()),
                          ),
                        ),
                      if (isAdmin)
                        _buildDrawerTile(
                          icon: Icons.dangerous_outlined,
                          title: 'Defected Requests',
                          trailing: _deletionRequestCount > 0
                              ? CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    '$_deletionRequestCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => DeletionRequestsView()),
                          ),
                        ),
                      if (isAdmin)
                        _buildDrawerTile(
                          icon: Icons.warning_amber_rounded,
                          title: 'Shortage Items',
                          trailing: _shortageItemCount > 0
                              ? CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    '$_shortageItemCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShortageItemsPage(),
                            ),
                          ),
                        ),
                      _buildDrawerTile(
                        icon: Icons.factory_outlined,
                        title: 'Manufacturing Order',
                        trailing: _manufacturingRequestCount > 0
                            ? CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '$_manufacturingRequestCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ManufacturingOrderView()),
                        ),
                      ),
                      _buildDrawerTile(
                        icon: Icons.password,
                        title: 'Change Password',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChangePasswordPage()),
                        ),
                      ),
                      if (isAdmin)
                        _buildDrawerTile(
                          icon: Icons.person_add_alt_1,
                          title: "Add user",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AddNewUser()),
                          ),
                        ),
                      if (isAdmin)
                        _buildDrawerTile(
                          icon: Icons.dashboard_outlined,
                          title: "Dash Board",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const DashboardPage()),
                          ),
                        ),
                      _buildDrawerTile(
                        icon: Icons.logout,
                        title: 'Log out',
                        onTap: () async {
                          await _fire.signOut();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginView()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Powered By © 2025 ChemTech',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool enabled = true,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: enabled ? Colors.white : Colors.grey.shade200,
        elevation: 3,
        child: ListTile(
          leading: Icon(icon, color: enabled ? Colors.deepPurple : Colors.grey),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.black87 : Colors.grey,
            ),
          ),
          trailing: trailing,
          enabled: enabled,
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}

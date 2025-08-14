import 'package:flutter/material.dart';
import 'package:vendor_chem_tech/features/add_user/widgets/add_user_fields.dart';
import '../../services/firebase_services.dart';

class AddNewUser extends StatefulWidget {
  const AddNewUser({super.key});

  @override
  State<AddNewUser> createState() => _AddNewUserState();
}

class _AddNewUserState extends State<AddNewUser> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAdmin = false;
  bool _isLoading = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await _firebaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _isAdmin,
      );

      setState(() => _isLoading = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User added successfully")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New User",style: TextStyle(color: Colors.white),),
        backgroundColor: theme.primaryColor,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              CustomTextField(
                controller: _firstNameController,
                label: "First Name",
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _lastNameController,
                label: "Last Name",
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailController,
                label: "Email",
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                label: "Password",
                isPassword: true,
                prefixIcon: Icons.lock,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text("Is Admin",style: TextStyle(fontWeight: FontWeight.bold),),
                value: _isAdmin,
                contentPadding: EdgeInsets.zero,
                activeColor: theme.primaryColor,
                onChanged: (value) {
                  setState(() => _isAdmin = value ?? false);
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: theme.primaryColor,
                  elevation: 5,
                ),
                onPressed: _submit,
                child: Text(
                  "Add User",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/////new changes/////
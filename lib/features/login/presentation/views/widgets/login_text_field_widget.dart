import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_chem_tech/features/home/presentation/views/home_view.dart';
import '../../../../../services/firebase_services.dart';
import '../../../bloc/login_bloc.dart';
import '../../../bloc/login_event.dart';
import '../../../bloc/login_state.dart';

class LoginTextFieldWidget extends StatefulWidget {
  final bool obscureTextToggle;

  const LoginTextFieldWidget({super.key, this.obscureTextToggle = true});

  @override
  State<LoginTextFieldWidget> createState() => _LoginTextFieldWidgetState();
}

class _LoginTextFieldWidgetState extends State<LoginTextFieldWidget> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('rememberMe') ?? false;
    if (remembered) {
      setState(() {
        _rememberMe = true;
        _userController.text = prefs.getString('savedEmail') ?? '';
        _passController.text = prefs.getString('savedPassword') ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(FirebaseService()),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginFailure) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.error)));
          } else if (state is LoginSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeView(
                  firstName: state.firstName,
                  lastName: state.lastName,
                  isAdmin: state.isAdmin,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Please enter your email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  obscureText: widget.obscureTextToggle ? _obscurePassword : false,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    suffixIcon: widget.obscureTextToggle
                        ? IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) => setState(() => _rememberMe = value ?? false),
                    ),
                    const Text("Remember Me"),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: state is LoginLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      context.read<LoginBloc>().add(
                        LoginButtonPressed(
                          _userController.text.trim(),
                          _passController.text.trim(),
                          _rememberMe,
                        ),
                      );
                    }
                  },
                  child: state is LoginLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text('Login'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

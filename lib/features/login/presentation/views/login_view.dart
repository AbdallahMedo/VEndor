import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vendor_chem_tech/core/utils/constants.dart';
import 'package:vendor_chem_tech/features/login/presentation/views/widgets/login_text_field_widget.dart';
import 'package:vendor_chem_tech/services/firebase_services.dart';

import '../../bloc/login_bloc.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(FirebaseService()),
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: SizedBox(
        height: 380,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Card(
            color: kSecondaryColor,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(15.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoginTextFieldWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

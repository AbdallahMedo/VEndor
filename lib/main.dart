import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:vendor_chem_tech/features/splash/presentation/bloc/splash_bloc.dart';
import 'package:vendor_chem_tech/features/splash/presentation/bloc/splash_event.dart';
import 'package:vendor_chem_tech/features/splash/presentation/views/splash_view.dart';
import 'package:vendor_chem_tech/services/firebase_services.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final boardService = FirebaseServiceForItems();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SplashBloc>(
          create: (_) =>
          SplashBloc(FirebaseService())..add(CheckAuthentication()),
        ),
        BlocProvider<HomeBloc>(
          create: (_) => HomeBloc(FirebaseServiceForItems()),
        ),
      ],
      child: const GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vendor Chem Tech',
        home: SplashView(),
      ),
    );
  }
}


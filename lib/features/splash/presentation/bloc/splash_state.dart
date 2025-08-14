import 'package:equatable/equatable.dart';

abstract class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {}

class SplashAuthenticated extends SplashState {
  final String firstName;
  final String lastName;
  final bool isAdmin;

  const SplashAuthenticated({
    required this.firstName,
    required this.lastName,
    required this.isAdmin,
  });

  @override
  List<Object?> get props => [firstName, lastName, isAdmin];
}

class SplashUnauthenticated extends SplashState {}

class SplashError extends SplashState {
  final String message;

  const SplashError(this.message);

  @override
  List<Object?> get props => [message];
}

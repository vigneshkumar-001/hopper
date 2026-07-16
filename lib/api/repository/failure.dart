import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class AuthenticationFailure extends Failure {
  final String code;

  const AuthenticationFailure(super.message, {required this.code});

  @override
  List<Object> get props => [message, code];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

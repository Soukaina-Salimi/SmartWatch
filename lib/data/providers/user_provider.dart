// FILE: lib/data/providers/user_provider.dart
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel _user = UserModel(
    id: 'u1',
    name: 'Safa',
    email: 'safa@example.com',
  );

  UserModel get user => _user;

  void updateProfile({String? name, String? email}) {
    _user = _user.copyWith(
      name: name ?? _user.name,
      email: email ?? _user.email,
    );
    notifyListeners();
  }
}

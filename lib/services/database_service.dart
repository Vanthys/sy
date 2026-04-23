import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/isar_database.dart';

part 'database_service.g.dart';

class DatabaseService {
  Future<Isar> open() {
    return openIsarDatabase();
  }
}

@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  return DatabaseService();
}

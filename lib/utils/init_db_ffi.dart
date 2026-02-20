import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inicializa SQLite para Windows/Linux/macOS (desktop)
void initDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

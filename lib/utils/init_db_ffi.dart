import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inicializa SQLite FFI solo en Windows/Linux/macOS.
/// En Android/iOS se usa la implementación nativa (no FFI).
void initDatabase() {
  if (Platform.isAndroid || Platform.isIOS) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'minuto_a_minuto.db';
  static const int _dbVersion = 2;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vendedores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        codigo TEXT NOT NULL,
        zona TEXT NOT NULL,
        coachId TEXT NOT NULL,
        geolocalizacionActiva INTEGER DEFAULT 0,
        horaInicioJornada TEXT,
        presupuestoMensual REAL DEFAULT 0,
        presupuestoDiario REAL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE supervisores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        codigo TEXT NOT NULL,
        zona TEXT NOT NULL,
        cargo TEXT NOT NULL,
        superiorId TEXT,
        subordinadosIds TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE registro_llamadas (
        id TEXT PRIMARY KEY,
        fecha TEXT NOT NULL,
        horaInicio TEXT NOT NULL,
        horaFin TEXT NOT NULL,
        duracionMinutos INTEGER NOT NULL,
        tipoLlamada TEXT NOT NULL,
        cargoLider TEXT NOT NULL,
        zona TEXT NOT NULL,
        nombreLider TEXT NOT NULL,
        nombreContactado TEXT NOT NULL,
        clientesProgramados INTEGER DEFAULT 0,
        clientesVisitados INTEGER DEFAULT 0,
        ventaDia REAL DEFAULT 0,
        recaudoDia REAL DEFAULT 0,
        cumplioMeta INTEGER DEFAULT 0,
        coincidenciaPpvcRvc INTEGER DEFAULT 0,
        conversion60 INTEGER DEFAULT 0,
        recuperacionPerdidos INTEGER DEFAULT 0,
        observaciones TEXT,
        confirmacionVeracidad INTEGER NOT NULL,
        rutaGrabacion TEXT,
        transcripcionTexto TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ppvc (
        id TEXT PRIMARY KEY,
        vendedorId TEXT NOT NULL,
        fecha TEXT NOT NULL,
        zona TEXT NOT NULL,
        clientesProgramados INTEGER DEFAULT 0,
        clientes60Ids TEXT,
        clientesPerdidosIds TEXT,
        metaVenta REAL DEFAULT 0,
        metaRecaudo REAL DEFAULT 0,
        programado2DiasAntes INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE rvc (
        id TEXT PRIMARY KEY,
        vendedorId TEXT NOT NULL,
        fecha TEXT NOT NULL,
        zona TEXT NOT NULL,
        clientesVisitados INTEGER DEFAULT 0,
        clientes60Visitados INTEGER DEFAULT 0,
        clientesPerdidosVisitados INTEGER DEFAULT 0,
        ventaTotal REAL DEFAULT 0,
        recaudoTotal REAL DEFAULT 0,
        clientesNoVisitados TEXT,
        descuentosAplicados INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE alertas (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        fecha TEXT NOT NULL,
        mensaje TEXT NOT NULL,
        vendedorId TEXT,
        supervisorId TEXT,
        zona TEXT,
        resuelta INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE ubicaciones (
        id TEXT PRIMARY KEY,
        vendedorId TEXT NOT NULL,
        fecha TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    // Sin datos precargados: el usuario registra su propia estructura
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE registro_llamadas ADD COLUMN rutaGrabacion TEXT',
        );
        await db.execute(
          'ALTER TABLE registro_llamadas ADD COLUMN transcripcionTexto TEXT',
        );
      } catch (_) {}
    }
  }

  // Vendedores
  static Future<void> insertVendedor(Vendedor v) async {
    final db = await database;
    await db.insert('vendedores', v.toMap());
  }

  static Future<List<Vendedor>> getVendedores() async {
    final db = await database;
    final maps = await db.query('vendedores');
    return maps.map((m) => Vendedor.fromMap(m)).toList();
  }

  static Future<Vendedor?> getVendedor(String id) async {
    final db = await database;
    final maps = await db.query('vendedores', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Vendedor.fromMap(maps.first);
  }

  static Future<void> updateVendedor(Vendedor v) async {
    final db = await database;
    await db.update('vendedores', v.toMap(), where: 'id = ?', whereArgs: [v.id]);
  }

  // Supervisores
  static Future<void> insertSupervisor(Supervisor s) async {
    final db = await database;
    await db.insert('supervisores', s.toMap());
  }

  static Future<List<Supervisor>> getSupervisores() async {
    final db = await database;
    final maps = await db.query('supervisores');
    return maps.map((m) => Supervisor.fromMap(m)).toList();
  }

  static Future<Supervisor?> getSupervisor(String id) async {
    final db = await database;
    final maps =
        await db.query('supervisores', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Supervisor.fromMap(maps.first);
  }

  static Future<void> deleteSupervisor(String id) async {
    final db = await database;
    await db.delete('supervisores', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteVendedor(String id) async {
    final db = await database;
    await db.delete('vendedores', where: 'id = ?', whereArgs: [id]);
  }

  // Registro Llamadas
  static Future<void> insertRegistroLlamada(RegistroLlamada r) async {
    final db = await database;
    await db.insert('registro_llamadas', r.toMap());
  }

  static Future<List<RegistroLlamada>> getRegistroLlamadas({
    DateTime? desde,
    DateTime? hasta,
    String? zona,
    String? nombreContactado,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? args;
    if (desde != null || hasta != null || zona != null || nombreContactado != null) {
      final conditions = <String>[];
      args = <dynamic>[];
      if (desde != null) {
        conditions.add('fecha >= ?');
        args.add(desde.toIso8601String().split('T')[0]);
      }
      if (hasta != null) {
        conditions.add('fecha <= ?');
        args.add(hasta.toIso8601String().split('T')[0]);
      }
      if (zona != null && zona.isNotEmpty) {
        conditions.add('zona = ?');
        args.add(zona);
      }
      if (nombreContactado != null && nombreContactado.isNotEmpty) {
        conditions.add('nombreContactado = ?');
        args.add(nombreContactado);
      }
      where = conditions.join(' AND ');
    }
    final maps = await db.query('registro_llamadas',
        where: where, whereArgs: args, orderBy: 'horaInicio DESC');
    return maps.map((m) => RegistroLlamada.fromMap(m)).toList();
  }

  static Future<List<RegistroLlamada>> getLlamadasHoy(String? contactadoId) async {
    final hoy = DateTime.now();
    final list = await getRegistroLlamadas(desde: hoy, hasta: hoy);
    if (contactadoId != null) {
      return list.where((l) => l.nombreContactado == contactadoId).toList();
    }
    return list;
  }

  // PPVC
  static Future<void> insertPpvc(Ppvc p) async {
    final db = await database;
    await db.insert('ppvc', p.toMap());
  }

  static Future<Ppvc?> getPpvcHoy(String vendedorId) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final maps = await db.query('ppvc',
        where: 'vendedorId = ? AND fecha = ?',
        whereArgs: [vendedorId, hoy]);
    return maps.isEmpty ? null : Ppvc.fromMap(maps.first);
  }

  static Future<List<Ppvc>> getPpvcByFecha(DateTime fecha) async {
    final db = await database;
    final f = fecha.toIso8601String().split('T')[0];
    final maps = await db.query('ppvc', where: 'fecha = ?', whereArgs: [f]);
    return maps.map((m) => Ppvc.fromMap(m)).toList();
  }

  // RVC
  static Future<void> insertRvc(Rvc r) async {
    final db = await database;
    await db.insert('rvc', r.toMap());
  }

  static Future<Rvc?> getRvcHoy(String vendedorId) async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T')[0];
    final maps = await db.query('rvc',
        where: 'vendedorId = ? AND fecha = ?',
        whereArgs: [vendedorId, hoy]);
    return maps.isEmpty ? null : Rvc.fromMap(maps.first);
  }

  static Future<List<Rvc>> getRvcByFecha(DateTime fecha) async {
    final db = await database;
    final f = fecha.toIso8601String().split('T')[0];
    final maps = await db.query('rvc', where: 'fecha = ?', whereArgs: [f]);
    return maps.map((m) => Rvc.fromMap(m)).toList();
  }

  // Alertas
  static Future<void> insertAlerta(Alerta a) async {
    final db = await database;
    await db.insert('alertas', {
      'id': a.id,
      'tipo': a.tipo.name,
      'fecha': a.fecha.toIso8601String(),
      'mensaje': a.mensaje,
      'vendedorId': a.vendedorId,
      'supervisorId': a.supervisorId,
      'zona': a.zona,
      'resuelta': a.resuelta ? 1 : 0,
    });
  }

  static Future<List<Alerta>> getAlertasPendientes() async {
    final db = await database;
    final maps = await db.query('alertas',
        where: 'resuelta = 0', orderBy: 'fecha DESC');
    return maps.map((m) => Alerta(
          id: m['id'] as String,
          tipo: TipoAlerta.values.firstWhere(
            (e) => e.name == m['tipo'],
            orElse: () => TipoAlerta.sinLlamada12m,
          ),
          fecha: DateTime.parse(m['fecha'] as String),
          mensaje: m['mensaje'] as String,
          vendedorId: m['vendedorId'] as String?,
          supervisorId: m['supervisorId'] as String?,
          zona: m['zona'] as String? ?? '',
          resuelta: (m['resuelta'] ?? 0) == 1,
        )).toList();
  }

  // Ubicaciones
  static Future<void> guardarUbicacion({
    required String vendedorId,
    required double lat,
    required double lng,
  }) async {
    final db = await database;
    final id = '${vendedorId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('ubicaciones', {
      'id': id,
      'vendedorId': vendedorId,
      'fecha': DateTime.now().toIso8601String().split('T')[0],
      'latitud': lat,
      'longitud': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

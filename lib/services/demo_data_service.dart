import 'package:uuid/uuid.dart';
import '../models/vendedor.dart';
import '../models/supervisor.dart';
import '../models/registro_llamada.dart';
import '../models/ppvc.dart';
import '../models/rvc.dart';
import '../models/alerta.dart';
import '../models/tipo_llamada.dart';
import '../models/nivel_cargo.dart';

/// Datos de demostración para presentaciones.
/// Activar con DataService.useDemoData = true
class DemoDataService {
  static const _uuid = Uuid();

  static List<Supervisor> getSupervisores() {
    return [
      Supervisor(
        id: 'sup-demo-1',
        nombre: 'Carlos Mendoza',
        codigo: 'COACH001',
        zona: 'Norte',
        cargo: NivelCargo.coach,
        telefono: '3001112233',
        subordinadosIds: ['ven-demo-1', 'ven-demo-2', 'ven-demo-3'],
      ),
      Supervisor(
        id: 'sup-demo-2',
        nombre: 'Ana García',
        codigo: 'KAM001',
        zona: 'Centro',
        cargo: NivelCargo.kam,
        telefono: '3002223344',
        superiorId: 'sup-demo-3',
        subordinadosIds: ['sup-demo-1'],
      ),
      Supervisor(
        id: 'sup-demo-3',
        nombre: 'Roberto Pérez',
        codigo: 'JEFE001',
        zona: 'Nacional',
        cargo: NivelCargo.jefe,
        telefono: '3003334455',
        subordinadosIds: ['sup-demo-2'],
      ),
    ];
  }

  static List<Vendedor> getVendedores() {
    final hoy = DateTime.now();
    // presupuestoDiario = presupuestoMensual / 30
    return [
      Vendedor(
        id: 'ven-demo-1',
        nombre: 'Miguel Torres',
        codigo: 'V001',
        zona: 'Norte',
        coachId: 'sup-demo-1',
        telefono: '3014445566',
        geolocalizacionActiva: true,
        horaInicioJornada: DateTime(hoy.year, hoy.month, hoy.day, 7, 45),
        presupuestoMensual: 45000000,
        presupuestoDiario: 1500000,
      ),
      Vendedor(
        id: 'ven-demo-2',
        nombre: 'Sandra López',
        codigo: 'V002',
        zona: 'Norte',
        coachId: 'sup-demo-1',
        telefono: '3015556677',
        geolocalizacionActiva: true,
        horaInicioJornada: DateTime(hoy.year, hoy.month, hoy.day, 8, 15),
        presupuestoMensual: 38000000,
        presupuestoDiario: 1266667,
      ),
      Vendedor(
        id: 'ven-demo-3',
        nombre: 'Andrés Martínez',
        codigo: 'V003',
        zona: 'Norte',
        coachId: 'sup-demo-1',
        telefono: '3016667788',
        geolocalizacionActiva: false,
        horaInicioJornada: DateTime(hoy.year, hoy.month, hoy.day, 8, 45),
        presupuestoMensual: 32000000,
        presupuestoDiario: 1066667,
      ),
      Vendedor(
        id: 'ven-demo-4',
        nombre: 'Laura Rodríguez',
        codigo: 'V004',
        zona: 'Centro',
        coachId: 'sup-demo-1',
        telefono: '3017778899',
        geolocalizacionActiva: true,
        horaInicioJornada: DateTime(hoy.year, hoy.month, hoy.day, 7, 30),
        presupuestoMensual: 52000000,
        presupuestoDiario: 1733333,
      ),
      Vendedor(
        id: 'ven-demo-5',
        nombre: 'Jorge Sánchez',
        codigo: 'V005',
        zona: 'Centro',
        coachId: 'sup-demo-1',
        telefono: '3018889900',
        geolocalizacionActiva: true,
        horaInicioJornada: DateTime(hoy.year, hoy.month, hoy.day, 8, 0),
        presupuestoMensual: 41000000,
        presupuestoDiario: 1366667,
      ),
    ];
  }

  static List<RegistroLlamada> getRegistroLlamadas({
    DateTime? desde,
    DateTime? hasta,
  }) {
    final hoy = DateTime.now();
    final d = desde ?? DateTime(hoy.year, hoy.month, hoy.day);
    final h = hasta ?? hoy;

    return [
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 8, 30),
        horaFin: DateTime(d.year, d.month, d.day, 8, 35),
        duracionMinutos: 5,
        tipoLlamada: TipoLlamada.manana,
        cargoLider: NivelCargo.coach,
        zona: 'Norte',
        nombreLider: 'Carlos Mendoza',
        nombreContactado: 'Miguel Torres',
        clientesProgramados: 12,
        clientesVisitados: 10,
        ventaDia: 1850000,
        recaudoDia: 920000,
        cumplioMeta: true,
        coincidenciaPpvcRvc: true,
        observaciones: 'Llamada de mañana. Planeación ejecutada. Zona Norte.',
        confirmacionVeracidad: true,
      ),
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 9, 0),
        horaFin: DateTime(d.year, d.month, d.day, 9, 8),
        duracionMinutos: 8,
        tipoLlamada: TipoLlamada.manana,
        cargoLider: NivelCargo.coach,
        zona: 'Norte',
        nombreLider: 'Carlos Mendoza',
        nombreContactado: 'Sandra López',
        clientesProgramados: 10,
        clientesVisitados: 9,
        ventaDia: 1420000,
        recaudoDia: 680000,
        cumplioMeta: true,
        coincidenciaPpvcRvc: true,
        observaciones: 'Buen avance. Objetivos claros.',
        confirmacionVeracidad: true,
      ),
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 10, 15),
        horaFin: DateTime(d.year, d.month, d.day, 10, 22),
        duracionMinutos: 7,
        tipoLlamada: TipoLlamada.manana,
        cargoLider: NivelCargo.coach,
        zona: 'Norte',
        nombreLider: 'Carlos Mendoza',
        nombreContactado: 'Andrés Martínez',
        clientesProgramados: 8,
        clientesVisitados: 5,
        ventaDia: 680000,
        recaudoDia: 320000,
        cumplioMeta: false,
        coincidenciaPpvcRvc: false,
        observaciones: 'Necesita refuerzo en visitas.',
        confirmacionVeracidad: true,
      ),
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 14, 0),
        horaFin: DateTime(d.year, d.month, d.day, 14, 12),
        duracionMinutos: 12,
        tipoLlamada: TipoLlamada.tarde,
        cargoLider: NivelCargo.coach,
        zona: 'Norte',
        nombreLider: 'Carlos Mendoza',
        nombreContactado: 'Miguel Torres',
        clientesProgramados: 12,
        clientesVisitados: 11,
        ventaDia: 2100000,
        recaudoDia: 1150000,
        cumplioMeta: true,
        coincidenciaPpvcRvc: true,
        observaciones: 'Cierre de tarde. Meta superada.',
        confirmacionVeracidad: true,
      ),
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 16, 30),
        horaFin: DateTime(d.year, d.month, d.day, 16, 38),
        duracionMinutos: 8,
        tipoLlamada: TipoLlamada.tarde,
        cargoLider: NivelCargo.coach,
        zona: 'Centro',
        nombreLider: 'Carlos Mendoza',
        nombreContactado: 'Laura Rodríguez',
        clientesProgramados: 15,
        clientesVisitados: 14,
        ventaDia: 2450000,
        recaudoDia: 1320000,
        cumplioMeta: true,
        coincidenciaPpvcRvc: true,
        observaciones: 'Excelente ejecución. Top del equipo.',
        confirmacionVeracidad: true,
      ),
      RegistroLlamada(
        id: _uuid.v4(),
        fecha: d,
        horaInicio: DateTime(d.year, d.month, d.day, 11, 0),
        horaFin: DateTime(d.year, d.month, d.day, 11, 6),
        duracionMinutos: 6,
        tipoLlamada: TipoLlamada.kam,
        cargoLider: NivelCargo.kam,
        zona: 'Nacional',
        nombreLider: 'Ana García',
        nombreContactado: 'Carlos Mendoza',
        clientesProgramados: 30,
        clientesVisitados: 28,
        ventaDia: 0,
        recaudoDia: 0,
        cumplioMeta: true,
        coincidenciaPpvcRvc: true,
        observaciones: 'Revisión KAM. Disciplina operativa en orden.',
        confirmacionVeracidad: true,
      ),
    ];
  }

  static List<Alerta> getAlertasPendientes() {
    final hoy = DateTime.now();
    return [
      Alerta(
        id: _uuid.v4(),
        tipo: TipoAlerta.vendedorSinLlamada8am,
        fecha: hoy,
        mensaje: 'Andrés Martínez no ha hecho ninguna llamada antes de las 8:20',
        vendedorId: 'ven-demo-3',
        supervisorId: 'sup-demo-1',
        zona: 'Norte',
        resuelta: false,
      ),
      Alerta(
        id: _uuid.v4(),
        tipo: TipoAlerta.sinCierre5pm,
        fecha: hoy,
        mensaje: 'Falta cierre de día para 2 vendedores en zona Norte',
        supervisorId: 'sup-demo-1',
        zona: 'Norte',
        resuelta: false,
      ),
      Alerta(
        id: _uuid.v4(),
        tipo: TipoAlerta.cliente60NoProgramado,
        fecha: hoy,
        mensaje: 'Cliente clave 60 no programado en PPVC - Sandra López',
        vendedorId: 'ven-demo-2',
        zona: 'Norte',
        resuelta: false,
      ),
      Alerta(
        id: _uuid.v4(),
        tipo: TipoAlerta.sinVisitasAntes10am,
        fecha: hoy,
        mensaje: 'Jorge Sánchez sin visitas registradas antes de las 10 AM',
        vendedorId: 'ven-demo-5',
        zona: 'Centro',
        resuelta: false,
      ),
    ];
  }

  static List<Ppvc> getPpvcByFecha(DateTime fecha) {
    return [
      Ppvc(
        id: 'ppvc-1',
        vendedorId: 'ven-demo-1',
        fecha: fecha,
        zona: 'Norte',
        clientesProgramados: 12,
        metaVenta: 1500000,
        metaRecaudo: 800000,
        programado2DiasAntes: true,
      ),
      Ppvc(
        id: 'ppvc-2',
        vendedorId: 'ven-demo-2',
        fecha: fecha,
        zona: 'Norte',
        clientesProgramados: 10,
        metaVenta: 1200000,
        metaRecaudo: 600000,
        programado2DiasAntes: true,
      ),
      Ppvc(
        id: 'ppvc-3',
        vendedorId: 'ven-demo-3',
        fecha: fecha,
        zona: 'Norte',
        clientesProgramados: 8,
        metaVenta: 1000000,
        metaRecaudo: 500000,
        programado2DiasAntes: false,
      ),
      Ppvc(
        id: 'ppvc-4',
        vendedorId: 'ven-demo-4',
        fecha: fecha,
        zona: 'Centro',
        clientesProgramados: 15,
        metaVenta: 1800000,
        metaRecaudo: 1200000,
        programado2DiasAntes: true,
      ),
      Ppvc(
        id: 'ppvc-5',
        vendedorId: 'ven-demo-5',
        fecha: fecha,
        zona: 'Centro',
        clientesProgramados: 11,
        metaVenta: 1400000,
        metaRecaudo: 750000,
        programado2DiasAntes: true,
      ),
    ];
  }

  static List<Rvc> getRvcByFecha(DateTime fecha) {
    return [
      Rvc(
        id: 'rvc-1',
        vendedorId: 'ven-demo-1',
        fecha: fecha,
        zona: 'Norte',
        clientesVisitados: 10,
        clientes60Visitados: 2,
        clientesPerdidosVisitados: 1,
        ventaTotal: 1850000,
        recaudoTotal: 920000,
      ),
      Rvc(
        id: 'rvc-2',
        vendedorId: 'ven-demo-2',
        fecha: fecha,
        zona: 'Norte',
        clientesVisitados: 9,
        clientes60Visitados: 1,
        clientesPerdidosVisitados: 0,
        ventaTotal: 1420000,
        recaudoTotal: 680000,
      ),
      Rvc(
        id: 'rvc-3',
        vendedorId: 'ven-demo-3',
        fecha: fecha,
        zona: 'Norte',
        clientesVisitados: 5,
        clientes60Visitados: 0,
        clientesPerdidosVisitados: 0,
        ventaTotal: 680000,
        recaudoTotal: 320000,
      ),
      Rvc(
        id: 'rvc-4',
        vendedorId: 'ven-demo-4',
        fecha: fecha,
        zona: 'Centro',
        clientesVisitados: 14,
        clientes60Visitados: 3,
        clientesPerdidosVisitados: 2,
        ventaTotal: 2450000,
        recaudoTotal: 1320000,
      ),
      Rvc(
        id: 'rvc-5',
        vendedorId: 'ven-demo-5',
        fecha: fecha,
        zona: 'Centro',
        clientesVisitados: 8,
        clientes60Visitados: 1,
        clientesPerdidosVisitados: 0,
        ventaTotal: 980000,
        recaudoTotal: 520000,
      ),
    ];
  }
}

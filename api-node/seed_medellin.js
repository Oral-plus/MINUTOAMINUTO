const BASE = "http://localhost:3005";

const medellin_calls = [
  {
    id: "med-vend-001_" + Date.now(),
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: new Date(Date.now() - 3600000).toISOString(),
    horaFin: new Date(Date.now() - 3300000).toISOString(),
    duracionMinutos: 5,
    tipoLlamada: "manana",
    cargoLider: "vendedor",
    zona: "Medellín Centro",
    nombreLider: "Vendedor Test",
    nombreContactado: "Cliente Medellín",
    numeroContacto: "3001234567",
    numeroPropietario: "3100000000",
    clientesProgramados: 15,
    clientesVisitados: 12,
    ventaDia: 950000,
    recaudoDia: 400000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 3,
    recuperacionPerdidos: 1,
    observaciones: "Llamada desde Medellín - Vendedor activo.",
    confirmacionVeracidad: 1,
    latitud: "6.2442",
    longitud: "-75.5812"
  },
  {
    id: "med-kam-001_" + Date.now(),
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: new Date(Date.now() - 1800000).toISOString(),
    horaFin: new Date(Date.now() - 1500000).toISOString(),
    duracionMinutos: 10,
    tipoLlamada: "kam",
    cargoLider: "kam",
    zona: "Medellín Antioquia",
    nombreLider: "KAM Medellín",
    nombreContactado: "Equipo Ventas Antioquia",
    numeroContacto: "3109876543",
    numeroPropietario: "3200000000",
    clientesProgramados: 40,
    clientesVisitados: 35,
    ventaDia: 5400000,
    recaudoDia: 2800000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 0,
    recuperacionPerdidos: 0,
    observaciones: "Seguimiento KAM - Región Antioquia.",
    confirmacionVeracidad: 1,
    latitud: "6.2518",
    longitud: "-75.5636"
  },
  {
    id: "med-vend-002_" + Date.now(),
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: new Date(Date.now() - 7200000).toISOString(),
    horaFin: new Date(Date.now() - 6900000).toISOString(),
    duracionMinutos: 4,
    tipoLlamada: "manana",
    cargoLider: "vendedor",
    zona: "Medellín Belén",
    nombreLider: "Carlos Vendedor",
    nombreContactado: "Supermercado El Vecino",
    numeroContacto: "3051112233",
    numeroPropietario: "3110000000",
    clientesProgramados: 10,
    clientesVisitados: 5,
    ventaDia: 450000,
    recaudoDia: 200000,
    cumplioMeta: 0,
    coincidenciaPpvcRvc: 0,
    conversion60: 1,
    recuperacionPerdidos: 0,
    observaciones: "Vendedor en Belén, reporte parcial.",
    confirmacionVeracidad: 1,
    latitud: "6.2318",
    longitud: "-75.5900"
  },
  {
    id: "med-kam-002_" + Date.now(),
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: new Date(Date.now() - 3600000).toISOString(),
    horaFin: new Date(Date.now() - 3000000).toISOString(),
    duracionMinutos: 15,
    tipoLlamada: "kam",
    cargoLider: "kam",
    zona: "Antioquia Sur",
    nombreLider: "Martha KAM",
    nombreContactado: "Equipo Itagüí",
    numeroContacto: "3154445566",
    numeroPropietario: "3201112233",
    clientesProgramados: 50,
    clientesVisitados: 48,
    ventaDia: 8900000,
    recaudoDia: 4500000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 0,
    recuperacionPerdidos: 0,
    observaciones: "Excelente desempeño en Itagüí y Sabaneta.",
    confirmacionVeracidad: 1,
    latitud: "6.1728",
    longitud: "-75.6091"
  }
];

async function main() {
  console.log("Enviando registros de Medellín a:", BASE);
  for (const r of medellin_calls) {
    try {
      console.log(`  Enviando JSON para ${r.id}:`, JSON.stringify(r));
      const res = await fetch(`${BASE}/llamadas`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
        body: JSON.stringify(r),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        console.log(`  OK ${r.id}: ${r.nombreLider} (${r.cargoLider}) - Mode: ${data.mode}${data.columnsStripped?.length ? ' (Stripped: ' + data.columnsStripped.join(',') + ')' : ''}`);
      }
    } catch (err) {
      console.log(`  ERROR ${r.id}: ${err.message}`);
    }
  }

  console.log("\nVerificando inserción...");
  try {
    const res = await fetch(`${BASE}/llamadas`);
    const list = await res.json();
    if (Array.isArray(list)) {
      const hoy = new Date().toISOString().slice(0, 10);
      const filtered = list.filter(l => l.id.startsWith("med-"));
      console.log(`Encontrados ${filtered.length} registros de Medellín:`);
      filtered.forEach(l => {
        console.log(`  - ID: ${l.id}, Lat: ${l.latitud}, Lng: ${l.longitud}`);
      });
    }
  } catch (err) {
    console.log("Error verificando:", err.message);
  }
}

main();

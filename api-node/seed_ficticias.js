/**
 * Inserta registros ficticios de llamadas vía API POST /llamadas
 * y sube un audio de prueba a cada uno (POST /llamadas/:id/audio).
 * Verifica que la API guarde registros y audios correctamente.
 *
 * Uso:
 *   node seed_ficticias.js
 *   API_BASE=http://localhost:3005 node seed_ficticias.js
 */

const BASE = process.env.API_BASE || process.env.API_BASE_URL || "https://minutoamimuto.oral-plus.com";

// Audio WAV minimal válido (~1s silencio 8kHz mono 16-bit) en base64
function getMinimalWavBase64() {
  const sampleRate = 8000;
  const durationSec = 1;
  const numSamples = sampleRate * durationSec;
  const dataSize = numSamples * 2; // 16-bit
  const headerSize = 44;
  const buf = Buffer.alloc(headerSize + dataSize);
  let off = 0;
  buf.write("RIFF", off); off += 4;
  buf.writeUInt32LE(36 + dataSize, off); off += 4;
  buf.write("WAVE", off); off += 4;
  buf.write("fmt ", off); off += 4;
  buf.writeUInt32LE(16, off); off += 4; // chunk size
  buf.writeUInt16LE(1, off); off += 2;  // PCM
  buf.writeUInt16LE(1, off); off += 2;  // mono
  buf.writeUInt32LE(sampleRate, off); off += 4;
  buf.writeUInt32LE(sampleRate * 2, off); off += 4; // byte rate
  buf.writeUInt16LE(2, off); off += 2;  // block align
  buf.writeUInt16LE(16, off); off += 2; // bits per sample
  buf.write("data", off); off += 4;
  buf.writeUInt32LE(dataSize, off);
  return buf.toString("base64");
}

const MINIMAL_WAV_B64 = getMinimalWavBase64();

const ficticias = [
  {
    id: "fict-001",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 5,
    tipoLlamada: "manana",
    cargoLider: "coach",
    zona: "Zona Norte",
    nombreLider: "Juan Perez",
    nombreContactado: "Maria Lopez",
    numeroContacto: "3015551234",
    numeroPropietario: "3001112233",
    clientesProgramados: 12,
    clientesVisitados: 10,
    ventaDia: 1850000,
    recaudoDia: 920000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 2,
    recuperacionPerdidos: 1,
    observaciones: "Llamada mañana. Planeación zona Norte.",
    confirmacionVeracidad: 1,
  },
  {
    id: "fict-002",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 8,
    tipoLlamada: "manana",
    cargoLider: "coach",
    zona: "Zona Norte",
    nombreLider: "Juan Perez",
    nombreContactado: "Carlos Mendoza",
    numeroContacto: "3015552234",
    numeroPropietario: "3001112233",
    clientesProgramados: 10,
    clientesVisitados: 9,
    ventaDia: 1420000,
    recaudoDia: 680000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 1,
    recuperacionPerdidos: 0,
    observaciones: "Buen avance. Objetivos claros.",
    confirmacionVeracidad: 1,
  },
  {
    id: "fict-003",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 7,
    tipoLlamada: "manana",
    cargoLider: "coach",
    zona: "Zona Norte",
    nombreLider: "Juan Perez",
    nombreContactado: "Andres Martinez",
    numeroContacto: "3015553234",
    numeroPropietario: "3001112233",
    clientesProgramados: 8,
    clientesVisitados: 5,
    ventaDia: 680000,
    recaudoDia: 320000,
    cumplioMeta: 0,
    coincidenciaPpvcRvc: 0,
    conversion60: 0,
    recuperacionPerdidos: 0,
    observaciones: "Necesita refuerzo en visitas.",
    confirmacionVeracidad: 1,
  },
  {
    id: "fict-004",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 12,
    tipoLlamada: "tarde",
    cargoLider: "coach",
    zona: "Zona Norte",
    nombreLider: "Juan Perez",
    nombreContactado: "Maria Lopez",
    numeroContacto: "3015551234",
    numeroPropietario: "3001112233",
    clientesProgramados: 12,
    clientesVisitados: 11,
    ventaDia: 2100000,
    recaudoDia: 1150000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 2,
    recuperacionPerdidos: 1,
    observaciones: "Cierre de tarde. Meta superada.",
    confirmacionVeracidad: 1,
  },
  {
    id: "fict-005",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 8,
    tipoLlamada: "tarde",
    cargoLider: "coach",
    zona: "Zona Centro",
    nombreLider: "Ana Garcia",
    nombreContactado: "Laura Rodriguez",
    numeroContacto: "3015554234",
    numeroPropietario: "3002223344",
    clientesProgramados: 15,
    clientesVisitados: 14,
    ventaDia: 2450000,
    recaudoDia: 1320000,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 3,
    recuperacionPerdidos: 2,
    observaciones: "Excelente ejecución. Top del equipo.",
    confirmacionVeracidad: 1,
  },
  {
    id: "fict-006",
    fecha: new Date().toISOString().slice(0, 10),
    horaInicio: null,
    horaFin: null,
    duracionMinutos: 6,
    tipoLlamada: "kam",
    cargoLider: "kam",
    zona: "Nacional",
    nombreLider: "Roberto Perez",
    nombreContactado: "Ana Garcia",
    numeroContacto: "3002223344",
    numeroPropietario: "3003334455",
    clientesProgramados: 30,
    clientesVisitados: 28,
    ventaDia: 0,
    recaudoDia: 0,
    cumplioMeta: 1,
    coincidenciaPpvcRvc: 1,
    conversion60: 0,
    recuperacionPerdidos: 0,
    observaciones: "Revisión KAM. Disciplina operativa en orden.",
    confirmacionVeracidad: 1,
  },
];

function setHora(obj, h, m) {
  const d = new Date();
  d.setHours(h, m, 0, 0);
  const iso = d.toISOString();
  obj.horaInicio = iso;
  obj.horaFin = new Date(d.getTime() + obj.duracionMinutos * 60000).toISOString();
  return obj;
}

async function main() {
  console.log("API base:", BASE);
  console.log("Insertando 6 registros ficticios...\n");

  const horarios = [[8, 30], [9, 0], [10, 15], [14, 0], [16, 30], [11, 0]];
  let ok = 0;
  let fail = 0;

  for (let i = 0; i < ficticias.length; i++) {
    const r = ficticias[i];
    const [h, m] = horarios[i] || [8, 0];
    setHora(r, h, m);

    const body = { ...r };

    try {
      const res = await fetch(`${BASE}/llamadas`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();

      if (res.ok && data.success) {
        let audioOk = false;
        try {
          const audioRes = await fetch(`${BASE}/llamadas/${r.id}/audio`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ audioBase64: MINIMAL_WAV_B64, mimeType: "audio/wav" }),
          });
          const audioData = await audioRes.json();
          audioOk = audioRes.ok && audioData.success;
        } catch (_) {}
        console.log(`  OK ${r.id}: ${r.nombreLider} -> ${r.nombreContactado} (${data.mode || "inserted"})${audioOk ? " + audio" : " (audio skip)"}`);
        ok++;
      } else {
        console.log(`  FAIL ${r.id}: ${data.error || res.status} - ${JSON.stringify(data)}`);
        fail++;
      }
    } catch (err) {
      console.log(`  FAIL ${r.id}: ${err.message}`);
      fail++;
    }
  }

  console.log("\n--- Resumen ---");
  console.log(`Insertados: ${ok}, Fallidos: ${fail}`);

  if (ok > 0) {
    console.log("\nVerificando GET /llamadas...");
    try {
      const res = await fetch(`${BASE}/llamadas`);
      const list = await res.json();
      if (Array.isArray(list)) {
        const hoy = new Date().toISOString().slice(0, 10);
        const filtrados = list.filter((x) => x.fecha === hoy || (x.fecha && x.fecha.startsWith && x.fecha.startsWith(hoy)));
        console.log(`Total hoy (${hoy}): ${filtrados.length} registros`);
      } else {
        console.log("Respuesta GET:", typeof list, list);
      }
    } catch (e) {
      console.log("Error GET /llamadas:", e.message);
    }
  }

  process.exit(fail > 0 ? 1 : 0);
}

main();

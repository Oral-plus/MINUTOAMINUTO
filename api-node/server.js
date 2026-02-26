"use strict";

const express = require("express");
const cors = require("cors");
const os = require("os");
const sql = require("mssql");

const app = express();
const port = Number(process.env.PORT || 3005);

app.use(cors());
app.use(express.json({ limit: "30mb" }));

function parseBool(value, fallback) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "y", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "n", "off"].includes(normalized)) return false;
  return fallback;
}

function parseIntSafe(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

const dbConfig = {
  user: process.env.DB_USER || "sa",
  password: process.env.DB_PASS || "Sky2022*!",
  server: process.env.DB_HOST || "192.168.2.244",
  database: process.env.DB_NAME || "minuto_a_minuto",
  port: parseIntSafe(process.env.DB_PORT, 1433),
  connectionTimeout: parseIntSafe(process.env.DB_CONNECT_TIMEOUT, 30000),
  requestTimeout: parseIntSafe(process.env.DB_REQUEST_TIMEOUT, 30000),
  options: {
    encrypt: parseBool(process.env.DB_ENCRYPT, false),
    trustServerCertificate: parseBool(process.env.DB_TRUST_SERVER_CERT, true),
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

const geminiConfig = {
  modelPrimary: process.env.GEMINI_MODEL || "gemini-2.5-flash",
  modelFallback: process.env.GEMINI_FALLBACK_MODEL || "gemini-2.5-flash-lite",
};

let poolPromise = null;

const TABLES = Object.freeze({
  cartera: "[CONSULTA_CARTERA]",
  vendedores: "[vendedores]",
  supervisores: "[supervisores]",
  llamadas: "[registro_llamadas]",
  ppvc: "[ppvc]",
  rvc: "[rvc]",
  alertas: "[alertas]",
  ubicaciones: "[ubicaciones]",
});

const SAFE_COLUMN_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

function makeId(prefix) {
  return `${prefix}_${Date.now()}`;
}

function asString(value, fallback = "") {
  if (value === undefined || value === null) return fallback;
  return String(value).trim();
}

function asNullableString(value) {
  const normalized = asString(value, "");
  return normalized === "" ? null : normalized;
}

function asInt(value, fallback = 0) {
  const num = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(num) ? num : fallback;
}

function asDouble(value, fallback = 0) {
  const num = Number(value ?? fallback);
  return Number.isFinite(num) ? num : fallback;
}

function asCsv(value) {
  if (Array.isArray(value)) {
    return value.map((v) => String(v).trim()).filter((v) => v.length > 0).join(",");
  }
  return asString(value, "");
}

function requireStringField(body, field) {
  const value = asString(body[field], "");
  if (!value) {
    throw new Error(`Campo requerido: ${field}`);
  }
  return value;
}

function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function normalizeRowForJson(row) {
  const out = {};
  for (const [key, value] of Object.entries(row)) {
    if (value instanceof Date) {
      out[key] = key === "fecha" ? value.toISOString().slice(0, 10) : value.toISOString();
      continue;
    }
    out[key] = value;
  }
  return out;
}

function normalizeRowsForJson(rows) {
  return rows.map(normalizeRowForJson);
}

function rowsAffectedCount(result) {
  if (!result || !Array.isArray(result.rowsAffected)) return 0;
  return result.rowsAffected.reduce((acc, n) => acc + Number(n || 0), 0);
}

async function runQuery(sqlText, bindInputs) {
  const pool = await getPool();
  const request = pool.request();
  if (typeof bindInputs === "function") {
    bindInputs(request);
  }
  return request.query(sqlText);
}

async function runQueryOne(sqlText, bindInputs) {
  const result = await runQuery(sqlText, bindInputs);
  return result.recordset[0] || null;
}

async function runExecute(sqlText, bindInputs) {
  const result = await runQuery(sqlText, bindInputs);
  return rowsAffectedCount(result);
}

async function upsertById(tableRef, id, payload) {
  const columns = Object.keys(payload);
  if (columns.length === 0) {
    throw new Error("No hay campos para guardar.");
  }

  for (const col of columns) {
    if (!SAFE_COLUMN_NAME.test(col)) {
      throw new Error(`Nombre de columna no permitido: ${col}`);
    }
  }

  const exists = await runQueryOne(
    `SELECT COUNT(1) AS total FROM ${tableRef} WHERE id = @id`,
    (request) => {
      request.input("id", asString(id));
    },
  );
  const alreadyExists = Number(exists?.total || 0) > 0;

  if (alreadyExists) {
    const setClause = columns.map((col) => `[${col}] = @${col}`).join(", ");
    await runExecute(
      `UPDATE ${tableRef} SET ${setClause} WHERE id = @id`,
      (request) => {
        request.input("id", asString(id));
        for (const col of columns) {
          request.input(col, payload[col] ?? null);
        }
      },
    );
    return "updated";
  }

  const insertColumns = ["id", ...columns];
  const insertColumnSql = insertColumns.map((col) => `[${col}]`).join(", ");
  const insertValueSql = insertColumns.map((col) => `@${col}`).join(", ");

  await runExecute(
    `INSERT INTO ${tableRef} (${insertColumnSql}) VALUES (${insertValueSql})`,
    (request) => {
      request.input("id", asString(id));
      for (const col of columns) {
        request.input(col, payload[col] ?? null);
      }
    },
  );
  return "inserted";
}

function getGeminiModels() {
  const models = [geminiConfig.modelPrimary, geminiConfig.modelFallback]
    .map((m) => asString(m, ""))
    .where((m) => m.length > 0);
  return [...new Set(models)];
}

function resolveGeminiApiKey(req) {
  const headerKey = asString(req?.headers?.["x-gemini-api-key"], "");
  const envKey = asString(process.env.GEMINI_API_KEY, "");
  return headerKey || envKey;
}

function extractTranscriptionText(payload) {
  const candidates = Array.isArray(payload?.candidates) ? payload.candidates : [];
  for (const candidate of candidates) {
    const parts = Array.isArray(candidate?.content?.parts)
      ? candidate.content.parts
      : [];
    const joined = parts
      .map((part) => (typeof part?.text === "string" ? part.text : ""))
      .join("\n")
      .trim();
    if (joined) return joined;
  }
  return "";
}

async function callGeminiModel({ apiKey, model, audioBase64, mimeType }) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}` +
    `:generateContent?key=${encodeURIComponent(apiKey)}`;

  const body = {
    contents: [
      {
        role: "user",
        parts: [
          {
            inline_data: {
              mime_type: mimeType,
              data: audioBase64,
            },
          },
          {
            text:
              "Transcribe este audio exactamente en el mismo idioma. " +
              "Devuelve solo el texto transcrito, sin explicaciones.",
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 2048,
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const rawBody = await response.text();
  let parsed = null;
  try {
    parsed = JSON.parse(rawBody);
  } catch (_) {
    parsed = null;
  }

  if (!response.ok) {
    const detail =
      parsed?.error?.message ||
      parsed?.message ||
      rawBody ||
      `HTTP ${response.status}`;
    throw new Error(`${model}: ${detail}`);
  }

  const text = extractTranscriptionText(parsed);
  if (!text) {
    throw new Error(`${model}: respuesta sin texto de transcripción`);
  }
  return text;
}

async function transcribeWithGemini({ apiKey, audioBase64, mimeType }) {
  const models = getGeminiModels();
  if (models.length === 0) {
    throw new Error("No hay modelo Gemini configurado.");
  }

  let lastError = "Error desconocido de transcripción.";
  for (const model of models) {
    try {
      const text = await callGeminiModel({
        apiKey,
        model,
        audioBase64,
        mimeType,
      });
      return { text, model };
    } catch (e) {
      lastError = e instanceof Error ? e.message : String(e);
    }
  }
  throw new Error(lastError);
}

function missingDbConfig() {
  // Permitimos fallback local por defecto para evitar bloqueo en entornos sin variables.
  return [];
}

async function getPool() {
  const missing = missingDbConfig();
  if (missing.length > 0) {
    throw new Error(`Faltan variables de entorno: ${missing.join(", ")}`);
  }

  if (!poolPromise) {
    const pool = new sql.ConnectionPool(dbConfig);
    pool.on("error", (err) => {
      console.error("Pool SQL error:", err.message);
      poolPromise = null;
    });
    poolPromise = pool.connect().catch((err) => {
      poolPromise = null;
      throw err;
    });
  }

  return poolPromise;
}

function formatDate(date) {
  if (!date) return "";
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleDateString("es-CO");
}

function formatCurrency(amount) {
  const value = Number(amount || 0);
  return new Intl.NumberFormat("es-CO", {
    style: "currency",
    currency: "COP",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(value);
}

function calculateDaysUntilDue(dueDate) {
  if (!dueDate) return 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const due = new Date(dueDate);
  if (Number.isNaN(due.getTime())) return 0;
  due.setHours(0, 0, 0, 0);

  const diffMs = due.getTime() - today.getTime();
  return Math.ceil(diffMs / (1000 * 60 * 60 * 24));
}

function getInvoiceStatus(daysUntilDue) {
  if (daysUntilDue < 0) return "Vencida";
  if (daysUntilDue <= 3) return "Urgente";
  if (daysUntilDue <= 7) return "Proxima";
  return "Vigente";
}

function getPriority(status) {
  switch (status) {
    case "Vencida":
      return 1;
    case "Urgente":
      return 2;
    case "Proxima":
      return 3;
    default:
      return 4;
  }
}

function mapInvoice(row) {
  const amount = Number(row.valor_formateado || 0);
  const daysUntilDue = calculateDaysUntilDue(row.DocDueDate);
  const status = getInvoiceStatus(daysUntilDue);
  const reference = `ORAL-${row.DocNum}-${Date.now()}`;

  return {
    cardCode: row.CardCode,
    cardName: row.CardName,
    cardFName: row.CardFName,
    docNum: row.DocNum,
    docDueDate: row.DocDueDate,
    formattedDueDate: formatDate(row.DocDueDate),
    amount,
    formattedAmount: formatCurrency(amount),
    daysUntilDue,
    status,
    priority: getPriority(status),
    pdfUrl: row.U_HBT_VisorPublico || null,
    isOverdue: daysUntilDue < 0,
    isUrgent: daysUntilDue >= 0 && daysUntilDue <= 3,
    isUpcoming: daysUntilDue > 3 && daysUntilDue <= 7,
    dueInfo:
      daysUntilDue < 0
        ? `Vencida hace ${Math.abs(daysUntilDue)} dias`
        : daysUntilDue === 0
          ? "Vence hoy"
          : `Vence en ${daysUntilDue} dias`,
    description: `Pago factura ${row.DocNum} - ${row.CardName}`,
    wompiData: {
      reference,
      amountInCents: Math.round(amount * 100),
      currency: "COP",
      customerName: row.CardFName || row.CardName,
    },
  };
}

async function runDbHealth() {
  const pool = await getPool();

  const ping = await pool.request().query("SELECT 1 AS ok, DB_NAME() AS db_name, GETDATE() AS server_time");
  const tableCheck = await pool
    .request()
    .query("SELECT COUNT(*) AS total FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CONSULTA_CARTERA'");

  let tableRows = null;
  if (Number(tableCheck.recordset[0]?.total || 0) > 0) {
    const countResult = await pool.request().query("SELECT COUNT(*) AS total FROM CONSULTA_CARTERA");
    tableRows = Number(countResult.recordset[0]?.total || 0);
  }

  return {
    ping: ping.recordset[0],
    tableExists: Number(tableCheck.recordset[0]?.total || 0) > 0,
    tableRows,
  };
}

app.get("/", (_req, res) => {
  res.json({
    success: true,
    api: "api-node",
    message: "API Node.js activa",
    timestamp: new Date().toISOString(),
  });
});

app.get("/health", (_req, res) => {
  res.json({
    success: true,
    status: "ok",
    uptimeSeconds: Math.round(process.uptime()),
    host: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get("/health/db", async (_req, res) => {
  const startedAt = Date.now();
  try {
    const health = await runDbHealth();
    res.json({
      success: true,
      database: {
        server: dbConfig.server,
        database: dbConfig.database,
        port: dbConfig.port,
        connected: true,
      },
      checks: health,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Error de conexion SQL Server",
      message: error.message,
      database: {
        server: dbConfig.server,
        database: dbConfig.database,
        port: dbConfig.port,
      },
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/api/test", async (_req, res) => {
  const startedAt = Date.now();
  try {
    const health = await runDbHealth();
    res.json({
      success: true,
      status: "API funcionando correctamente",
      database: "Conectado a SQL Server",
      checks: health,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      status: "Error en la API",
      message: error.message,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  }
});

// Compatibilidad con la app Flutter existente
app.get("/test", async (_req, res) => {
  const startedAt = Date.now();
  try {
    const health = await runDbHealth();
    res.json({
      success: true,
      message: "Conexion exitosa",
      checks: health,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  }
});

app.post("/transcribe", async (req, res) => {
  const startedAt = Date.now();
  try {
    const body = req.body || {};
    const audioBase64 = asString(body.audioBase64, "");
    const mimeType = asString(body.mimeType, "audio/mp4");
    if (!audioBase64) {
      return res.status(400).json({
        success: false,
        error: "audioBase64 es requerido",
      });
    }

    const apiKey = resolveGeminiApiKey(req);
    if (!apiKey) {
      return res.status(400).json({
        success: false,
        error:
          "No se encontró llave de Gemini. Configure GEMINI_API_KEY o envíe x-gemini-api-key.",
      });
    }

    const { text, model } = await transcribeWithGemini({
      apiKey,
      audioBase64,
      mimeType,
    });

    return res.json({
      success: true,
      text,
      model,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : String(error),
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  }
});

app.get("/vendedores", async (req, res) => {
  try {
    const id = asString(req.query.id, "");
    if (id) {
      const row = await runQueryOne(
        `SELECT * FROM ${TABLES.vendedores} WHERE id = @id`,
        (request) => request.input("id", id),
      );
      return res.json(row ? normalizeRowForJson(row) : null);
    }
    const result = await runQuery(`SELECT * FROM ${TABLES.vendedores} ORDER BY nombre`);
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.get("/vendedores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    const row = await runQueryOne(
      `SELECT * FROM ${TABLES.vendedores} WHERE id = @id`,
      (request) => request.input("id", id),
    );
    return res.json(row ? normalizeRowForJson(row) : null);
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/vendedores", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("v");
    const payload = {
      nombre: requireStringField(body, "nombre"),
      codigo: requireStringField(body, "codigo"),
      zona: requireStringField(body, "zona"),
      coachId: requireStringField(body, "coachId"),
      geolocalizacionActiva: asInt(body.geolocalizacionActiva, 0),
      horaInicioJornada: asNullableString(body.horaInicioJornada),
      presupuestoMensual: asDouble(body.presupuestoMensual, 0),
      presupuestoDiario: asDouble(body.presupuestoDiario, 0),
    };
    const mode = await upsertById(TABLES.vendedores, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.delete("/vendedores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id) {
      return res.status(400).json({ success: false, error: "id requerido" });
    }
    const rows = await runExecute(
      `DELETE FROM ${TABLES.vendedores} WHERE id = @id`,
      (request) => request.input("id", id),
    );
    return res.json({ success: true, id, rows });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.get("/supervisores", async (_req, res) => {
  try {
    const result = await runQuery(`SELECT * FROM ${TABLES.supervisores} ORDER BY nombre`);
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.get("/supervisores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    const row = await runQueryOne(
      `SELECT * FROM ${TABLES.supervisores} WHERE id = @id`,
      (request) => request.input("id", id),
    );
    return res.json(row ? normalizeRowForJson(row) : null);
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/supervisores", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("s");
    const payload = {
      nombre: requireStringField(body, "nombre"),
      codigo: requireStringField(body, "codigo"),
      zona: requireStringField(body, "zona"),
      cargo: asString(body.cargo, "coach"),
      superiorId: asNullableString(body.superiorId),
      subordinadosIds: asCsv(body.subordinadosIds),
    };
    const mode = await upsertById(TABLES.supervisores, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.delete("/supervisores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id) {
      return res.status(400).json({ success: false, error: "id requerido" });
    }
    const rows = await runExecute(
      `DELETE FROM ${TABLES.supervisores} WHERE id = @id`,
      (request) => request.input("id", id),
    );
    return res.json({ success: true, id, rows });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.get("/llamadas", async (req, res) => {
  try {
    const desde = asString(req.query.desde, todayIsoDate());
    const hasta = asString(req.query.hasta, todayIsoDate());
    const zona = asString(req.query.zona, "");
    const nombreContactado = asString(req.query.nombreContactado, "");

    const whereParts = ["fecha >= @desde", "fecha <= @hasta"];
    if (zona) whereParts.push("zona = @zona");
    if (nombreContactado) whereParts.push("nombreContactado = @nombreContactado");

    const sqlText = `
      SELECT *
      FROM ${TABLES.llamadas}
      WHERE ${whereParts.join(" AND ")}
      ORDER BY horaInicio DESC
    `;

    const result = await runQuery(sqlText, (request) => {
      request.input("desde", desde);
      request.input("hasta", hasta);
      if (zona) request.input("zona", zona);
      if (nombreContactado) request.input("nombreContactado", nombreContactado);
    });

    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/llamadas", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("llamada");
    const payload = {
      fecha: requireStringField(body, "fecha"),
      horaInicio: requireStringField(body, "horaInicio"),
      horaFin: requireStringField(body, "horaFin"),
      duracionMinutos: asInt(body.duracionMinutos, 0),
      tipoLlamada: requireStringField(body, "tipoLlamada"),
      cargoLider: requireStringField(body, "cargoLider"),
      zona: requireStringField(body, "zona"),
      nombreLider: requireStringField(body, "nombreLider"),
      nombreContactado: requireStringField(body, "nombreContactado"),
      clientesProgramados: asInt(body.clientesProgramados, 0),
      clientesVisitados: asInt(body.clientesVisitados, 0),
      ventaDia: asDouble(body.ventaDia, 0),
      recaudoDia: asDouble(body.recaudoDia, 0),
      cumplioMeta: asInt(body.cumplioMeta, 0),
      coincidenciaPpvcRvc: asInt(body.coincidenciaPpvcRvc, 0),
      conversion60: asInt(body.conversion60, 0),
      recuperacionPerdidos: asInt(body.recuperacionPerdidos, 0),
      observaciones: asString(body.observaciones, ""),
      confirmacionVeracidad: asInt(body.confirmacionVeracidad, 0),
      rutaGrabacion: asNullableString(body.rutaGrabacion),
      transcripcionTexto: asNullableString(body.transcripcionTexto),
    };
    const mode = await upsertById(TABLES.llamadas, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.patch("/llamadas/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id) {
      return res.status(400).json({ success: false, error: "id requerido" });
    }

    const body = req.body || {};
    const updates = {};
    if (Object.prototype.hasOwnProperty.call(body, "observaciones")) {
      updates.observaciones = asString(body.observaciones, "");
    }
    if (Object.prototype.hasOwnProperty.call(body, "rutaGrabacion")) {
      updates.rutaGrabacion = asNullableString(body.rutaGrabacion);
    }
    if (Object.prototype.hasOwnProperty.call(body, "transcripcionTexto")) {
      updates.transcripcionTexto = asNullableString(body.transcripcionTexto);
    }

    const columns = Object.keys(updates);
    if (columns.length === 0) {
      return res.status(400).json({ success: false, message: "Sin campos para actualizar" });
    }

    const setClause = columns.map((c) => `[${c}] = @${c}`).join(", ");
    const rows = await runExecute(
      `UPDATE ${TABLES.llamadas} SET ${setClause} WHERE id = @id`,
      (request) => {
        request.input("id", id);
        for (const col of columns) {
          request.input(col, updates[col] ?? null);
        }
      },
    );

    return res.json({ success: true, id, rows });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.get("/ppvc", async (req, res) => {
  try {
    const fecha = asString(req.query.fecha, todayIsoDate());
    const vendedorId = asString(req.query.vendedorId, "");
    if (vendedorId) {
      const row = await runQueryOne(
        `SELECT * FROM ${TABLES.ppvc} WHERE vendedorId = @vendedorId AND fecha = @fecha`,
        (request) => {
          request.input("vendedorId", vendedorId);
          request.input("fecha", fecha);
        },
      );
      return res.json(row ? normalizeRowForJson(row) : null);
    }

    const result = await runQuery(
      `SELECT * FROM ${TABLES.ppvc} WHERE fecha = @fecha`,
      (request) => request.input("fecha", fecha),
    );
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/ppvc", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("ppvc");
    const payload = {
      vendedorId: requireStringField(body, "vendedorId"),
      fecha: requireStringField(body, "fecha"),
      zona: asString(body.zona, ""),
      clientesProgramados: asInt(body.clientesProgramados, 0),
      clientes60Ids: asCsv(body.clientes60Ids),
      clientesPerdidosIds: asCsv(body.clientesPerdidosIds),
      metaVenta: asDouble(body.metaVenta, 0),
      metaRecaudo: asDouble(body.metaRecaudo, 0),
      programado2DiasAntes: asInt(body.programado2DiasAntes, 0),
    };
    const mode = await upsertById(TABLES.ppvc, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.get("/rvc", async (req, res) => {
  try {
    const fecha = asString(req.query.fecha, todayIsoDate());
    const vendedorId = asString(req.query.vendedorId, "");
    if (vendedorId) {
      const row = await runQueryOne(
        `SELECT * FROM ${TABLES.rvc} WHERE vendedorId = @vendedorId AND fecha = @fecha`,
        (request) => {
          request.input("vendedorId", vendedorId);
          request.input("fecha", fecha);
        },
      );
      return res.json(row ? normalizeRowForJson(row) : null);
    }

    const result = await runQuery(
      `SELECT * FROM ${TABLES.rvc} WHERE fecha = @fecha`,
      (request) => request.input("fecha", fecha),
    );
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/rvc", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("rvc");
    const payload = {
      vendedorId: requireStringField(body, "vendedorId"),
      fecha: requireStringField(body, "fecha"),
      zona: asString(body.zona, ""),
      clientesVisitados: asInt(body.clientesVisitados, 0),
      clientes60Visitados: asInt(body.clientes60Visitados, 0),
      clientesPerdidosVisitados: asInt(body.clientesPerdidosVisitados, 0),
      ventaTotal: asDouble(body.ventaTotal, 0),
      recaudoTotal: asDouble(body.recaudoTotal, 0),
      clientesNoVisitados: asCsv(body.clientesNoVisitados),
      descuentosAplicados: asInt(body.descuentosAplicados, 0),
    };
    const mode = await upsertById(TABLES.rvc, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.get("/alertas", async (req, res) => {
  try {
    const resuelta = asInt(req.query.resuelta, 0);
    const result = await runQuery(
      `SELECT * FROM ${TABLES.alertas} WHERE resuelta = @resuelta ORDER BY fecha DESC`,
      (request) => request.input("resuelta", resuelta),
    );
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/alertas", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("alerta");
    const payload = {
      tipo: requireStringField(body, "tipo"),
      fecha: requireStringField(body, "fecha"),
      mensaje: requireStringField(body, "mensaje"),
      vendedorId: asNullableString(body.vendedorId),
      supervisorId: asNullableString(body.supervisorId),
      zona: asString(body.zona, ""),
      resuelta: asInt(body.resuelta, 0),
    };
    const mode = await upsertById(TABLES.alertas, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.post("/ubicaciones", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("ub");
    const payload = {
      vendedorId: requireStringField(body, "vendedorId"),
      fecha: asString(body.fecha, todayIsoDate()),
      latitud: asDouble(body.latitud, 0),
      longitud: asDouble(body.longitud, 0),
      timestamp: asString(body.timestamp, new Date().toISOString()),
    };
    const mode = await upsertById(TABLES.ubicaciones, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: "Ruta no encontrada",
    availableEndpoints: [
      "GET /health",
      "GET /health/db",
      "GET /test",
      "POST /transcribe",
      "GET /vendedores",
      "GET /supervisores",
      "GET /llamadas",
      "GET /ppvc",
      "GET /rvc",
      "GET /alertas",
    ],
    timestamp: new Date().toISOString(),
  });
});

let httpServer = null;

async function startServer() {
  console.log("Iniciando API Node.js...");
  console.log("=".repeat(50));
  console.log(`Puerto: ${port}`);
  console.log(`Host SQL: ${dbConfig.server}:${dbConfig.port}`);
  console.log(`DB SQL: ${dbConfig.database}`);

  httpServer = app.listen(port, "0.0.0.0", () => {
    console.log("API iniciada correctamente");
    console.log(`URL local: http://localhost:${port}`);
  });

  httpServer.on("error", (err) => {
    console.error("Error al iniciar servidor:", err.message);
    process.exit(1);
  });
}

async function shutdown() {
  try {
    if (httpServer) {
      await new Promise((resolve) => httpServer.close(resolve));
    }
    if (poolPromise) {
      const pool = await poolPromise;
      await pool.close();
    }
  } catch (err) {
    console.error("Error cerrando recursos:", err.message);
  } finally {
    process.exit(0);
  }
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
process.on("unhandledRejection", (reason) => {
  console.error("Unhandled Rejection:", reason);
});
process.on("uncaughtException", (err) => {
  console.error("Uncaught Exception:", err.message);
  process.exit(1);
});

if (require.main === module) {
  startServer().catch((err) => {
    console.error("Error fatal iniciando API:", err.message);
    process.exit(1);
  });
}

module.exports = { app, startServer, getPool };

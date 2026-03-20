"use strict";

const path = require("path");
require("dotenv").config({ path: path.join(__dirname, ".env") });

const express = require("express");
const cors = require("cors");
const fs = require("fs");
const os = require("os");
const sql = require("mssql");
const ExcelJS = require("exceljs");
const cron = require("node-cron");
const crypto = require("crypto");

const UPLOADS_DIR = path.join(process.cwd(), "uploads", "audio");
if (!fs.existsSync(path.dirname(UPLOADS_DIR))) {
  fs.mkdirSync(path.dirname(UPLOADS_DIR), { recursive: true });
}
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

const app = express();
const port = Number(process.env.PORT || 3005);

app.use(cors());
app.use(express.json({ limit: "30mb" }));
app.use("/audio", express.static(UPLOADS_DIR));
app.use(express.static(path.join(__dirname, "public")));

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

// Modelos Gemini: gemini-2.5-flash (principal), gemini-2.5-flash-lite (fallback), gemini-2.0-flash (compatibilidad)
const geminiConfig = {
  modelPrimary: process.env.GEMINI_MODEL || "gemini-1.5-flash",
  modelFallback: process.env.GEMINI_FALLBACK_MODEL || "gemini-1.5-flash-8b",
  modelLegacy: "gemini-1.5-flash-lite", // Fallback adicional
};

let poolPromise = null;
let sapPoolPromise = null;

// Pool secundario para la DB de SAP (mismo host, diferente base de datos)
async function getSapPool() {
  if (!sapPoolPromise) {
    const sapDb = process.env.SAP_DB_NAME || "RBOSKY3";
    const sapConfig = {
      ...dbConfig,
      database: sapDb,
    };
    const pool = new sql.ConnectionPool(sapConfig);
    pool.on("error", (err) => {
      console.error("Pool SAP error:", err.message);
      sapPoolPromise = null;
    });
    sapPoolPromise = pool.connect().catch((err) => {
      sapPoolPromise = null;
      throw err;
    });
  }
  return sapPoolPromise;
}

async function runSapQuery(sqlText, bindInputs) {
  const pool = await getSapPool();
  const request = pool.request();
  if (typeof bindInputs === "function") bindInputs(request);
  return request.query(sqlText);
}

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
const SAFE_ID = /^[a-zA-Z0-9_.-]{1,80}$/; // Evita path traversal en endpoints de audio

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
  const models = [
    geminiConfig.modelPrimary,
    geminiConfig.modelFallback,
    geminiConfig.modelLegacy,
  ]
    .map((m) => (typeof m === "string" ? m : ""))
    .filter((m) => m && m.length > 0);
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
            inlineData: {
              mimeType: mimeType,
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

  let tableCarteraExists = false;
  let tableCarteraRows = null;
  let registroLlamadasExists = false;
  let registroLlamadasRows = null;

  try {
    const tables = await pool.request().query(
      "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('CONSULTA_CARTERA','registro_llamadas')"
    );
    const names = (tables.recordset || []).map((r) => r.TABLE_NAME);
    tableCarteraExists = names.includes("CONSULTA_CARTERA");
    registroLlamadasExists = names.includes("registro_llamadas");

    if (tableCarteraExists) {
      const r = await pool.request().query("SELECT COUNT(*) AS total FROM CONSULTA_CARTERA");
      tableCarteraRows = Number(r.recordset[0]?.total || 0);
    }
    if (registroLlamadasExists) {
      const r = await pool.request().query("SELECT COUNT(*) AS total FROM registro_llamadas");
      registroLlamadasRows = Number(r.recordset[0]?.total || 0);
    }
  } catch (_) {
    // Tablas opcionales, no fallar el health
  }

  return {
    ping: ping.recordset[0],
    tables: {
      CONSULTA_CARTERA: tableCarteraExists ? { exists: true, rows: tableCarteraRows } : { exists: false },
      registro_llamadas: registroLlamadasExists ? { exists: true, rows: registroLlamadasRows } : { exists: false },
    },
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
    // Validar tamaño mínimo (~1KB) para evitar envíos vacíos a Gemini
    const buf = Buffer.from(audioBase64, "base64");
    if (buf.length < 512) {
      return res.status(400).json({
        success: false,
        error: "El audio es demasiado corto o está vacío",
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

/**
 * GET /cartera/contactos?cargo=COACH&nombre=Steven
 * Retorna clientes de SAP filtrados por cargo del usuario logueado.
 * Cargos: COACH, KAM, JEFE DE VENTAS (sin filtro)
 */
app.get("/cartera/contactos", async (req, res) => {
  try {
    const cargo   = asString(req.query.cargo, "").toUpperCase().trim();
    const nombre  = asString(req.query.nombre, "").trim();
    const page    = Math.max(1, asInt(req.query.page, 1));
    const perPage = Math.min(500, Math.max(10, asInt(req.query.perPage, 200)));
    const offset  = (page - 1) * perPage;

    // Construir WHERE dinámico según cargo
    let whereExtra = "";
    const bindFn = (request) => {
      if (nombre && (cargo === "COACH" || cargo === "KAM")) {
        request.input("nombre", nombre);
      }
    };

    if (cargo === "COACH" && nombre) {
      whereExtra = "AND T2.[Name] = @nombre";
    } else if (cargo === "KAM" && nombre) {
      whereExtra = "AND T3.[Name] = @nombre";
    }
    // JEFE DE VENTAS → sin filtro adicional

    const sqlText = `
      SELECT
        T0.[CardCode]   AS cardCode,
        T0.[CardName]   AS cardName,
        T0.[CardFName]  AS cardFName,
        T1.[SlpName]    AS slpName,
        T2.[Name]       AS coach,
        T3.[Name]       AS kam
      FROM OCRD T0
      INNER JOIN OSLP T1
        ON T0.[SlpCode] = T1.[SlpCode]
      INNER JOIN [dbo].[@COACH] T2
        ON T0.[U_COACH] = T2.[Code]
      INNER JOIN [dbo].[@SKY_NEGOCIADOR] T3
        ON T0.[U_NEGOCIADOR] = T3.[Code]
      WHERE T0.[validFor] = 'Y'
        ${whereExtra}
      ORDER BY T0.[CardName]
      OFFSET ${offset} ROWS FETCH NEXT ${perPage} ROWS ONLY
    `;

    const result = await runSapQuery(sqlText, bindFn);
    const rows   = result.recordset || [];

    return res.json({
      success: true,
      total: rows.length,
      page,
      perPage,
      cargo: cargo || "TODOS",
      nombre: nombre || null,
      data: rows,
    });
  } catch (error) {
    console.error("[/cartera/contactos] ERROR:", error.message);
    return res.status(500).json({
      success: false,
      error: error.message,
      hint: !process.env.SAP_DB_NAME
        ? "Configura SAP_DB_NAME=<nombre_db_sap> en el entorno del servidor"
        : undefined,
    });
  }
});

// Diagnóstico SAP — verifica si las tablas existen en la DB de SAP
app.get("/cartera/contactos/test", async (_req, res) => {
  try {
    const result = await runSapQuery(`
      SELECT TABLE_NAME
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_NAME IN ('OCRD','OSLP')
    `);
    const tables = (result.recordset || []).map((r) => r.TABLE_NAME);
    return res.json({
      success: true,
      sapDb: process.env.SAP_DB_NAME || "RBOSKY3",
      tablasSap: tables,
      ocrdOk: tables.includes("OCRD"),
      oslpOk: tables.includes("OSLP"),
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /cartera/supervisores?cargo=COACH  → lista de nombres únicos de COACHes
 * GET /cartera/supervisores?cargo=KAM    → lista de nombres únicos de KAMs
 * Usado en la pantalla de login para mostrar el dropdown de quien está iniciando sesión.
 */
app.get("/cartera/supervisores", async (req, res) => {
  try {
    const cargo = asString(req.query.cargo, "").toUpperCase().trim();
    if (!["COACH", "KAM"].includes(cargo)) {
      return res.status(400).json({
        success: false,
        error: 'cargo debe ser COACH o KAM',
      });
    }

    // COACH → tabla @COACH, KAM → tabla @SKY_NEGOCIADOR
    const tableAlias = cargo === "COACH" ? "@COACH" : "@SKY_NEGOCIADOR";

    const result = await runSapQuery(`
      SELECT DISTINCT T.[Name] AS nombre
      FROM [dbo].[${tableAlias}] T
      INNER JOIN OCRD C ON ${cargo === "COACH" ? "C.[U_COACH] = T.[Code]" : "C.[U_NEGOCIADOR] = T.[Code]"}
      WHERE C.[validFor] = 'Y'
        AND T.[Name] IS NOT NULL
        AND T.[Name] <> ''
      ORDER BY T.[Name]
    `);

    const nombres = (result.recordset || []).map((r) => asString(r.nombre));
    return res.json({ success: true, cargo, data: nombres });
  } catch (err) {
    console.error("[/cartera/supervisores] ERROR:", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /cartera/vendedores?cargo=COACH&nombre=MARIO
 * Retorna los nombres de los vendedores (Salespersons) asignados a ese supervisor en SAP.
 */
app.get("/cartera/vendedores", async (req, res) => {
  try {
    const cargo = asString(req.query.cargo, "").toUpperCase().trim();
    const nombre = asString(req.query.nombre, "").trim();

    if (!["COACH", "KAM"].includes(cargo)) {
      return res.status(400).json({
        success: false,
        error: 'cargo debe ser COACH o KAM',
      });
    }

    if (!nombre) {
      return res.status(400).json({
        success: false,
        error: 'nombre es requerido',
      });
    }

    // Filtramos vendedores (SlpName) basados en el Coach o KAM asignado en OCRD
    const whereClause = cargo === "COACH" ? "T2.[Name] = @nombre" : "T3.[Name] = @nombre";

    const result = await runSapQuery(`
      SELECT DISTINCT T1.[SlpName] AS nombre
      FROM OCRD T0
      INNER JOIN OSLP T1 ON T0.[SlpCode] = T1.[SlpCode]
      INNER JOIN [dbo].[@COACH] T2 ON T0.[U_COACH] = T2.[Code]
      INNER JOIN [dbo].[@SKY_NEGOCIADOR] T3 ON T0.[U_NEGOCIADOR] = T3.[Code]
      WHERE T0.[validFor] = 'Y'
        AND ${whereClause}
      ORDER BY T1.[SlpName]
    `, (request) => request.input("nombre", nombre));

    const vendedores = (result.recordset || []).map((r) => asString(r.nombre));
    return res.json({ success: true, data: vendedores });
  } catch (err) {
    console.error("[/cartera/vendedores] ERROR:", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ═══════════════════════════════════════════════════════════════════
// ADMIN — Gestión de usuarios (protegido con clave admin)
// ═══════════════════════════════════════════════════════════════════
const ADMIN_PASSWORD = "OralPlus2026!";

function requireAdmin(req, res, next) {
  const pw = req.headers["x-admin-key"] || req.query.adminKey || "";
  if (pw !== ADMIN_PASSWORD) {
    return res.status(401).json({ success: false, error: "Clave admin incorrecta" });
  }
  next();
}

// POST /admin/login — valida clave admin
app.post("/admin/login", (req, res) => {
  const pw = asString(req.body.password, "");
  if (pw === ADMIN_PASSWORD) {
    return res.json({ success: true, message: "Admin autenticado" });
  }
  return res.status(401).json({ success: false, error: "Clave incorrecta" });
});

// PATCH /admin/supervisores/:id — editar supervisor (cargo, alias, codigo, zona, nombre, telefono)
app.patch("/admin/supervisores/:id", requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const fields = [];
    const binds = (r) => { r.input("id", id); };
    const b = req.body;
    const sets = [];
    if (b.nombre !== undefined)   sets.push({ col: "nombre",   val: b.nombre });
    if (b.cargo !== undefined)    sets.push({ col: "cargo",    val: b.cargo });
    if (b.alias !== undefined)    sets.push({ col: "alias",    val: b.alias });
    if (b.codigo !== undefined)   sets.push({ col: "codigo",   val: b.codigo });
    if (b.zona !== undefined)     sets.push({ col: "zona",     val: b.zona });
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos para actualizar" });

    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    const request = localPool.request().input("id", id);
    sets.forEach((s, i) => request.input(`v${i}`, s.val));
    await request.query(`UPDATE supervisores SET ${setParts.join(",")} WHERE id=@id`);
    return res.json({ success: true, message: "Supervisor actualizado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /admin/supervisores/:id — eliminar supervisor
app.delete("/admin/supervisores/:id", requireAdmin, async (req, res) => {
  try {
    await localPool.request().input("id", req.params.id).query("DELETE FROM supervisores WHERE id=@id");
    return res.json({ success: true, message: "Supervisor eliminado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /admin/vendedores/:id — editar vendedor (alias, codigo, zona, nombre, telefono, coachId)
app.patch("/admin/vendedores/:id", requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const b = req.body;
    const sets = [];
    if (b.nombre !== undefined)   sets.push({ col: "nombre",   val: b.nombre });
    if (b.alias !== undefined)    sets.push({ col: "alias",    val: b.alias });
    if (b.codigo !== undefined)   sets.push({ col: "codigo",   val: b.codigo });
    if (b.zona !== undefined)     sets.push({ col: "zona",     val: b.zona });
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (b.coachId !== undefined)  sets.push({ col: "coachId",  val: b.coachId });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos para actualizar" });

    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    const request = localPool.request().input("id", id);
    sets.forEach((s, i) => request.input(`v${i}`, s.val));
    await request.query(`UPDATE vendedores SET ${setParts.join(",")} WHERE id=@id`);
    return res.json({ success: true, message: "Vendedor actualizado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /admin/vendedores/:id — eliminar vendedor
app.delete("/admin/vendedores/:id", requireAdmin, async (req, res) => {
  try {
    await localPool.request().input("id", req.params.id).query("DELETE FROM vendedores WHERE id=@id");
    return res.json({ success: true, message: "Vendedor eliminado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /supervisores/:id — actualizar telefono/alias (sin admin, para la app)
app.patch("/supervisores/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const b = req.body;
    const sets = [];
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (b.alias !== undefined)    sets.push({ col: "alias",    val: b.alias });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos" });
    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    const request = localPool.request().input("id", id);
    sets.forEach((s, i) => request.input(`v${i}`, s.val));
    await request.query(`UPDATE supervisores SET ${setParts.join(",")} WHERE id=@id`);
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /vendedores/:id — actualizar telefono/alias (sin admin, para la app)
app.patch("/vendedores/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const b = req.body;
    const sets = [];
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (b.alias !== undefined)    sets.push({ col: "alias",    val: b.alias });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos" });
    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    const request = localPool.request().input("id", id);
    sets.forEach((s, i) => request.input(`v${i}`, s.val));
    await request.query(`UPDATE vendedores SET ${setParts.join(",")} WHERE id=@id`);
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /sap/sync-users
 * Sincroniza todos los vendedores, coaches y KAMs de SAP a la DB local.
 * Asigna contraseñas secuenciales (001, 002...) a los nuevos.
 */


/**
 * GET /sap/export-excel
 * Genera un Excel con todos los usuarios y sus códigos de acceso.
 */
app.get("/sap/export-excel", async (req, res) => {
  try {
    const pool = await getPool();
    const sups = await pool.request().query("SELECT id, nombre, alias, codigo, cargo, sapCode FROM supervisores");
    const vends = await pool.request().query("SELECT id, nombre, alias, codigo, zona, sapCode FROM vendedores");

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet("Usuarios Minuto a Minuto");

    worksheet.columns = [
      { header: 'ID Local', key: 'id', width: 35 },
      { header: 'Tipo', key: 'tipo', width: 15 },
      { header: 'Nombre SAP', key: 'nombre', width: 30 },
      { header: 'Alias (Login)', key: 'alias', width: 15 },
      { header: 'Contraseña', key: 'codigo', width: 15 },
      { header: 'Cargo/Zona', key: 'cargo', width: 20 },
      { header: 'SAP Code', key: 'sapCode', width: 15 }
    ];

    sups.recordset.forEach(s => {
      worksheet.addRow({
        id: s.id,
        tipo: 'SUPERVISOR',
        nombre: s.nombre,
        alias: s.alias,
        codigo: s.codigo,
        cargo: s.cargo,
        sapCode: s.sapCode
      });
    });

    vends.recordset.forEach(v => {
      worksheet.addRow({
        id: v.id,
        tipo: 'VENDEDOR',
        nombre: v.nombre,
        alias: v.alias,
        codigo: v.codigo,
        cargo: v.zona,
        sapCode: v.sapCode
      });
    });

    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    res.setHeader("Content-Disposition", "attachment; filename=Usuarios_Minuto_A_Minuto.xlsx");

    await workbook.xlsx.write(res);
    res.end();
  } catch (err) {
    console.error("[/sap/export-excel] ERROR:", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /cartera/equipo-jerarquico
 * Retorna la jerarquía completa para el Jefe de Ventas.
 */
app.get("/cartera/equipo-jerarquico", async (req, res) => {
  try {
    const sapPool = await getSapPool();
    const localPool = await getPool();

    // Traer todos los KAMs
    const kams = await sapPool.request().query(`
      SELECT DISTINCT T.[Name] AS nombre, T.[Code] AS codigo
      FROM [dbo].[@SKY_NEGOCIADOR] T
      INNER JOIN OCRD C ON C.[U_NEGOCIADOR] = T.[Code]
      WHERE C.[validFor] = 'Y'
    `);

    const jerarquia = [];

    for (const kam of kams.recordset) {
      // Para cada KAM, sus Coaches
      const coaches = await sapPool.request()
        .input("kamCode", kam.codigo)
        .query(`
          SELECT DISTINCT T2.[Name] AS nombre, T2.[Code] AS codigo
          FROM OCRD T0
          INNER JOIN [dbo].[@COACH] T2 ON T0.[U_COACH] = T2.[Code]
          WHERE T0.[validFor] = 'Y' AND T0.[U_NEGOCIADOR] = @kamCode
        `);

      const kamData = {
        nombre: kam.nombre,
        coaches: []
      };

      const hoy = new Date().toISOString().split('T')[0];
      const llamadasHoy = await localPool.request()
        .input("hoy", hoy)
        .query(`SELECT nombreLider, COUNT(*) as total FROM registro_llamadas WHERE fecha = @hoy GROUP BY nombreLider`);
      
      const countsMap = {};
      llamadasHoy.recordset.forEach(r => {
        countsMap[r.nombreLider] = r.total;
      });

      for (const coach of coaches.recordset) {
        // Para cada Coach, sus Vendedores
        const vendedores = await sapPool.request()
          .input("coachCode", coach.codigo)
          .input("kamCode", kam.codigo)
          .query(`
            SELECT DISTINCT T1.[SlpName] AS nombre
            FROM OCRD T0
            INNER JOIN OSLP T1 ON T0.[SlpCode] = T1.[SlpCode]
            WHERE T0.[validFor] = 'Y' AND T0.[U_COACH] = @coachCode AND T0.[U_NEGOCIADOR] = @kamCode
          `);

        kamData.coaches.push({
          nombre: coach.nombre,
          vendedores: vendedores.recordset.map(v => ({
            nombre: v.nombre,
            llamadas: countsMap[v.nombre] || 0
          }))
        });
      }
      jerarquia.push(kamData);
    }

    return res.json({ success: true, data: jerarquia });
  } catch (err) {
    console.error("[/cartera/equipo-jerarquico] ERROR:", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * Núcleo de sincronización de usuarios SAP -> DB Local.
 * @param {object} options.send - Función para enviar mensajes de progreso (opcional).
 */
async function fullUserSyncCore({ send = () => {} } = {}) {
  const sapPool = await getSapPool();
  const localPool = await getPool();

  send("🚀 Iniciando conexión con SAP y DB Local...", "start");

  // 1. Traer Coaches de SAP
  send("🔍 Consultando Coaches en SAP...");
  const coachesSap = await sapPool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre, T.[Code] AS codigo,
           (SELECT TOP 1 C2.[City] FROM OCRD C2 WHERE C2.[U_COACH] = T.[Code] AND C2.[validFor]='Y' AND C2.[City] IS NOT NULL AND C2.[City] <> '') AS zona
    FROM [dbo].[@COACH] T
    INNER JOIN OCRD C ON C.[U_COACH] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
  `);

  // 2. Traer KAMs de SAP
  send("🔍 Consultando KAMs en SAP...");
  const kamsSap = await sapPool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre, T.[Code] AS codigo,
           (SELECT TOP 1 C2.[City] FROM OCRD C2 WHERE C2.[U_NEGOCIADOR] = T.[Code] AND C2.[validFor]='Y' AND C2.[City] IS NOT NULL AND C2.[City] <> '') AS zona
    FROM [dbo].[@SKY_NEGOCIADOR] T
    INNER JOIN OCRD C ON C.[U_NEGOCIADOR] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
  `);

  // 3. Traer Vendedores de SAP con su ciudad predominante
  send("🔍 Consultando Vendedores en SAP...");
  const vendorsSap = await sapPool.request().query(`
    SELECT DISTINCT T1.[SlpName] AS nombre, T1.[SlpCode] AS codigo,
           (SELECT TOP 1 [City] FROM OCRD WHERE [SlpCode] = T1.[SlpCode] AND [validFor]='Y') AS zona
    FROM OSLP T1
    INNER JOIN OCRD T0 ON T0.[SlpCode] = T1.[SlpCode]
    WHERE T0.[validFor] = 'Y' AND T1.[SlpName] IS NOT NULL AND T1.[SlpName] <> ''
  `);

  send(`📦 Encontrados: ${coachesSap.recordset.length} Coaches, ${kamsSap.recordset.length} KAMs, ${vendorsSap.recordset.length} Vendedores.`);

  let creados = 0;
  let actualizados = 0;

  async function getNextPass() {
    const r = await localPool.request().query("SELECT COUNT(*) as total FROM (SELECT codigo FROM supervisores UNION SELECT codigo FROM vendedores) as t");
    return ((r.recordset[0].total || 0) + 1).toString().padStart(3, '0');
  }

  async function getNextAlias(prefix) {
    prefix = prefix.toUpperCase();
    const table = prefix === 'VEND' ? 'vendedores' : 'supervisores';
    const r = await localPool.request()
      .query(`SELECT COUNT(*) as total FROM ${table} WHERE alias LIKE '${prefix}%'`);
    return `${prefix}${(r.recordset[0].total + 1).toString().padStart(2, '0')}`;
  }

  const sapCodeToId = {};

  // Combinar Supervisores (Coaches y KAMs)
  const allSups = [
    ...coachesSap.recordset.map(s => ({ ...s, cargo: 'COACH' })),
    ...kamsSap.recordset.map(s => ({ ...s, cargo: 'KAM' }))
  ];

  for (const s of allSups) {
    const zona = s.zona || 'COLOMBIA';
    const existing = await localPool.request()
      .input("sap", s.codigo.toString())
      .input("nom", s.nombre)
      .query("SELECT id, alias FROM supervisores WHERE sapCode = @sap OR nombre = @nom");

    let lid;
    if (existing.recordset.length > 0) {
      lid = existing.recordset[0].id;
      const alias = existing.recordset[0].alias || await getNextAlias(s.cargo);
      await localPool.request()
        .input("id", lid).input("nom", s.nombre).input("sap", s.codigo.toString()).input("car", s.cargo).input("ali", alias).input("zon", zona)
        .query("UPDATE supervisores SET nombre=@nom, sapCode=@sap, cargo=@car, alias=@ali, zona=@zon WHERE id=@id");
      actualizados++;
      send(`🔸 Actualizado: [${s.cargo}] ${s.nombre} (${zona}, Alias: ${alias})`, "update");
    } else {
      lid = crypto.randomUUID();
      const p = await getNextPass();
      const a = await getNextAlias(s.cargo);
      await localPool.request()
        .input("id", lid).input("nom", s.nombre).input("cod", p).input("sap", s.codigo.toString()).input("car", s.cargo).input("ali", a).input("zon", zona)
        .query("INSERT INTO supervisores (id, nombre, codigo, cargo, sapCode, alias, zona) VALUES (@id, @nom, @cod, @car, @sap, @ali, @zon)");
      creados++;
      send(`✨ Creado: [${s.cargo}] ${s.nombre} (${zona}, Alias: ${a}, Pass: ${p})`, "create");
    }
    sapCodeToId[s.codigo.toString()] = lid;
  }

  // Sync Vendedores
  for (const v of vendorsSap.recordset) {
    if (!v.nombre) continue;
    const zona = v.zona || "COLOMBIA";
    const existing = await localPool.request()
      .input("sap", (v.codigo || "").toString())
      .input("nom", v.nombre)
      .query("SELECT id, alias FROM vendedores WHERE sapCode = @sap OR (sapCode IS NULL AND nombre = @nom)");

    if (existing.recordset.length > 0) {
      const vid = existing.recordset[0].id;
      const ali = existing.recordset[0].alias || await getNextAlias('VEND');
      await localPool.request()
        .input("id", vid).input("nom", v.nombre).input("sap", (v.codigo || "").toString()).input("ali", ali).input("zon", zona)
        .query("UPDATE vendedores SET nombre=@nom, sapCode=@sap, alias=@ali, zona=@zon WHERE id=@id");
      actualizados++;
      send(`🔸 Actualizado: [VENDEDOR] ${v.nombre} (${zona}, Alias: ${ali})`, "update");
    } else {
      const p = await getNextPass();
      const a = await getNextAlias('VEND');
      await localPool.request()
        .input("id", crypto.randomUUID()).input("nom", v.nombre).input("cod", p).input("sap", (v.codigo || "").toString()).input("ali", a).input("zon", zona)
        .query("INSERT INTO vendedores (id, nombre, codigo, zona, sapCode, alias) VALUES (@id, @nom, @cod, @zon, @sap, @ali)");
      creados++;
      send(`✨ Creado: [VENDEDOR] ${v.nombre} (Alias: ${a}, Pass: ${p})`, "create");
    }
  }

  send("🔗 Vinculando jerarquías Coach -> KAM...");
  const relCK = await sapPool.request().query("SELECT DISTINCT U_COACH, U_NEGOCIADOR FROM OCRD WHERE ([validFor]='Y' AND U_COACH IS NOT NULL AND U_NEGOCIADOR IS NOT NULL)");
  for (const r of relCK.recordset) {
    const cid = sapCodeToId[r.U_COACH.toString()];
    const kid = sapCodeToId[r.U_NEGOCIADOR.toString()];
    if (cid && kid) await localPool.request().input("c",cid).input("k",kid).query("UPDATE supervisores SET superiorId=@k WHERE id=@c");
  }

  send("🔗 Vinculando Vendedores -> Coach...");
  const relVC = await sapPool.request().query("SELECT DISTINCT SlpCode, U_COACH FROM OCRD WHERE ([validFor]='Y' AND SlpCode IS NOT NULL AND U_COACH IS NOT NULL)");
  for (const r of relVC.recordset) {
    const cid = sapCodeToId[r.U_COACH.toString()];
    if (cid) await localPool.request().input("sc",r.SlpCode.toString()).input("ci",cid).query("UPDATE vendedores SET coachId=@ci WHERE sapCode=@sc");
  }

  return { creados, actualizados };
}

/**
 * GET /sap/sync-users
 */
app.get("/sap/sync-users", async (req, res) => {
  try {
    const result = await fullUserSyncCore();
    return res.json({ success: true, ...result });
  } catch (err) {
    console.error("[/sap/sync-users] ERROR:", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /sap/sync-users-stream (SSE)
 */
app.get("/sap/sync-users-stream", async (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();

  const send = (msg, type = "info") => {
    res.write(`data: ${JSON.stringify({ msg, type })}\n\n`);
  };

  try {
    const result = await fullUserSyncCore({ send });
    send(`✅ Sincronización finalizada. Creados: ${result.creados}, Actualizados: ${result.actualizados}`, "done");
    res.write("event: end\ndata: finish\n\n");
    res.end();
  } catch (err) {
    console.error("[SSE] ERROR:", err.message);
    send(`❌ ERROR FATAL: ${err.message}`, "error");
    res.end();
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
      coachId: asNullableString(body.coachId),
      telefono: asNullableString(body.telefono),
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
      telefono: asNullableString(body.telefono),
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

// Actualizar campos de un supervisor (p.ej. telefono para correlacion dual)
app.patch("/supervisores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id) return res.status(400).json({ success: false, error: "id requerido" });
    const body = req.body || {};
    const ALLOWED = new Set(["telefono", "nombre", "zona", "cargo"]);
    const updates = {};
    for (const [k, v] of Object.entries(body)) {
      if (ALLOWED.has(k) && SAFE_COLUMN_NAME.test(k)) updates[k] = asString(v, "");
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, error: "No hay campos validos para actualizar" });
    }
    const setClause = Object.keys(updates).map((col) => `[${col}] = @${col}`).join(", ");
    await runExecute(
      `UPDATE ${TABLES.supervisores} SET ${setClause} WHERE id = @id`,
      (request) => {
        request.input("id", id);
        for (const [k, v] of Object.entries(updates)) request.input(k, v);
      }
    );
    return res.json({ success: true, id, updated: Object.keys(updates) });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

// Actualizar campos de un vendedor (p.ej. telefono para correlacion dual)
app.patch("/vendedores/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id) return res.status(400).json({ success: false, error: "id requerido" });
    const body = req.body || {};
    const ALLOWED = new Set(["telefono", "nombre", "zona"]);
    const updates = {};
    for (const [k, v] of Object.entries(body)) {
      if (ALLOWED.has(k) && SAFE_COLUMN_NAME.test(k)) updates[k] = asString(v, "");
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, error: "No hay campos validos para actualizar" });
    }
    const setClause = Object.keys(updates).map((col) => `[${col}] = @${col}`).join(", ");
    await runExecute(
      `UPDATE ${TABLES.vendedores} SET ${setClause} WHERE id = @id`,
      (request) => {
        request.input("id", id);
        for (const [k, v] of Object.entries(updates)) request.input(k, v);
      }
    );
    return res.json({ success: true, id, updated: Object.keys(updates) });
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

function normalizePhone(n) {
  if (!n || typeof n !== "string") return "";
  return n.replace(/[\s\-\(\)\+]/g, "").replace(/\D/g, "");
}

function phonesMatch(a, b) {
  const na = normalizePhone(a);
  const nb = normalizePhone(b);
  if (!na || !nb) return false;
  return na === nb || na.endsWith(nb) || nb.endsWith(na);
}

// Columnas permitidas para registro_llamadas (evita errores por columnas inexistentes)
const LLAMADAS_COLUMNS = new Set([
  "fecha", "horaInicio", "horaFin", "duracionMinutos", "tipoLlamada", "cargoLider",
  "zona", "nombreLider", "nombreContactado", "numeroContacto", "numeroPropietario",
  "clientesProgramados", "clientesVisitados", "ventaDia", "recaudoDia", "cumplioMeta",
  "coincidenciaPpvcRvc", "conversion60", "recuperacionPerdidos", "observaciones",
  "confirmacionVeracidad", "rutaGrabacion", "rutaGrabacionPuntoB", "transcripcionTexto",
  "latitud", "longitud", "fechaCreacion",
]);

app.post("/llamadas", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "") || makeId("llamada");
    const numeroPropietario = asNullableString(body.numeroPropietario);
    const numeroContacto = asNullableString(body.numeroContacto);
    const horaInicio = asString(body.horaInicio, "");
    const fechaStr = asString(body.fecha, "").split("T")[0];

    // Validación mínima
    if (!fechaStr || !asString(body.horaInicio, "") || !asString(body.horaFin, "")) {
      return res.status(400).json({
        success: false,
        error: "fecha, horaInicio y horaFin son requeridos",
      });
    }

    // Buscar correlación dual (punto A + punto B)
    if (numeroPropietario && numeroContacto && horaInicio) {
      const nP = normalizePhone(numeroPropietario);
      const nC = normalizePhone(numeroContacto);
      if (nP && nC) {
        try {
          const rows = await runQuery(
            `SELECT id, horaInicio FROM ${TABLES.llamadas}
             WHERE fecha = @fecha
             AND numeroPropietario IS NOT NULL AND numeroContacto IS NOT NULL
             AND numeroPropietario = @nC AND numeroContacto = @nP`,
            (request) => {
              request.input("fecha", fechaStr);
              request.input("nP", nP);
              request.input("nC", nC);
            }
          );
          const list = (rows.recordset || []).filter((row) => {
            const diffMs = Math.abs(new Date(horaInicio) - new Date(row.horaInicio));
            return diffMs <= 600000;
          });
          if (list.length > 0) {
            return res.json({
              success: true,
              mergeTarget: list[0].id,
              id: list[0].id,
            });
          }
        } catch (dbErr) {
          // Si falla la búsqueda (ej. tabla vacía), continuar con insert
        }
      }
    }

    const rawPayload = {
      fecha: fechaStr,
      horaInicio: requireStringField(body, "horaInicio"),
      horaFin: requireStringField(body, "horaFin"),
      duracionMinutos: Math.max(0, asInt(body.duracionMinutos, 1)),
      tipoLlamada: requireStringField(body, "tipoLlamada"),
      cargoLider: requireStringField(body, "cargoLider"),
      zona: requireStringField(body, "zona"),
      nombreLider: requireStringField(body, "nombreLider"),
      nombreContactado: requireStringField(body, "nombreContactado"),
      numeroContacto: body.numeroContacto ? (normalizePhone(body.numeroContacto) || null) : null,
      numeroPropietario: body.numeroPropietario ? (normalizePhone(body.numeroPropietario) || null) : null,
      clientesProgramados: asInt(body.clientesProgramados, 0),
      clientesVisitados: asInt(body.clientesVisitados, 0),
      ventaDia: asDouble(body.ventaDia, 0),
      recaudoDia: asDouble(body.recaudoDia, 0),
      cumplioMeta: asInt(body.cumplioMeta, 0),
      coincidenciaPpvcRvc: asInt(body.coincidenciaPpvcRvc, 0),
      conversion60: asInt(body.conversion60, 0),
      recuperacionPerdidos: asInt(body.recuperacionPerdidos, 0),
      observaciones: asString(body.observaciones, ""),
      confirmacionVeracidad: asInt(body.confirmacionVeracidad, 1),
      rutaGrabacion: asNullableString(body.rutaGrabacion),
      rutaGrabacionPuntoB: asNullableString(body.rutaGrabacionPuntoB),
      transcripcionTexto: asNullableString(body.transcripcionTexto),
      fechaCreacion: new Date().toISOString(), // Timestamp exacto de registro en servidor
    };
    if (body.latitud != null && body.longitud != null) {
      rawPayload.latitud = asDouble(body.latitud, 0);
      rawPayload.longitud = asDouble(body.longitud, 0);
    }

    const payload = {};
    for (const [k, v] of Object.entries(rawPayload)) {
      if (LLAMADAS_COLUMNS.has(k)) payload[k] = v;
    }

    // Intento resiliente: si falla por columna invalida, quitarla y reintentar
    let lastError = null;
    const badColumns = new Set();
    for (let attempt = 0; attempt <= 5; attempt++) {
      const safePayload = {};
      for (const [k, v] of Object.entries(payload)) {
        if (!badColumns.has(k)) safePayload[k] = v;
      }
      try {
        const mode = await upsertById(TABLES.llamadas, id, safePayload);
        return res.json({ success: true, id, mode, columnsStripped: [...badColumns] });
      } catch (err) {
        lastError = err;
        // Detectar error de columna invalida de SQL Server
        const match = err.message?.match(/Invalid column name '([^']+)'/);
        if (match && match[1] && !badColumns.has(match[1])) {
          console.warn(`[llamadas] columna '${match[1]}' no existe en la tabla, reintentando sin ella...`);
          badColumns.add(match[1]);
          continue;
        }
        break; // Error distinto, salir
      }
    }
    throw lastError || new Error('Error desconocido al guardar llamada');
  } catch (error) {
    const status = error.message?.includes("requerido") || error.message?.includes("permitido")
      ? 400
      : 500;
    console.error('[POST /llamadas] ERROR:', error.message);
    return res.status(status).json({
      success: false,
      error: error.message || String(error),
    });
  }
});

// Endpoint de diagnóstico — muestra columnas existentes en registro_llamadas
app.get("/llamadas/diagnostico", async (_req, res) => {
  try {
    const pool = await getPool();
    const cols = await pool.request().query(
      `SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
       FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_NAME = 'registro_llamadas'
       ORDER BY ORDINAL_POSITION`
    );
    const count = await pool.request().query(`SELECT COUNT(*) AS total FROM [registro_llamadas]`);
    const sample = await pool.request().query(`SELECT TOP 3 id, fecha, horaInicio, nombreLider, latitud, longitud FROM [registro_llamadas] ORDER BY id DESC`);
    return res.json({
      success: true,
      totalRegistros: count.recordset[0]?.total,
      columnas: cols.recordset,
      ultimasTres: sample.recordset,
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// Subir audio principal (rutaGrabacion) - como la app envía tras grabar
app.post("/llamadas/:id/audio", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id || !SAFE_ID.test(id)) {
      return res.status(400).json({ success: false, error: "id inválido" });
    }
    const body = req.body || {};
    const audioBase64 = asString(body.audioBase64, "");
    const mimeType = asString(body.mimeType, "audio/mp4");
    if (!audioBase64) {
      return res.status(400).json({ success: false, error: "audioBase64 requerido" });
    }
    const ext = mimeType.includes("wav") ? "wav" : mimeType.includes("amr") ? "amr" : mimeType.includes("mp3") ? "mp3" : "m4a";
    const filename = `${id}.${ext}`;
    const filepath = path.join(UPLOADS_DIR, filename);
    let buf;
    try {
      buf = Buffer.from(audioBase64, "base64");
    } catch (_) {
      return res.status(400).json({ success: false, error: "audioBase64 inválido" });
    }
    if (buf.length > 30 * 1024 * 1024) {
      return res.status(400).json({ success: false, error: "El audio supera el tamaño máximo (30MB)" });
    }
    fs.writeFileSync(filepath, buf);
    const rutaRelativa = `/audio/${filename}`;
    await runExecute(
      `UPDATE ${TABLES.llamadas} SET rutaGrabacion = @path WHERE id = @id`,
      (request) => {
        request.input("path", rutaRelativa);
        request.input("id", id);
      }
    );
    return res.json({ success: true, id, rutaGrabacion: rutaRelativa, audioUrl: rutaRelativa });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

app.post("/llamadas/:id/audio-punto-b", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id || !SAFE_ID.test(id)) {
      return res.status(400).json({ success: false, error: "id inválido" });
    }
    const body = req.body || {};
    const audioBase64 = asString(body.audioBase64, "");
    const mimeType = asString(body.mimeType, "audio/mp4");
    if (!audioBase64) {
      return res.status(400).json({ success: false, error: "audioBase64 requerido" });
    }
    const ext = mimeType.includes("wav") ? "wav" : mimeType.includes("mp3") ? "mp3" : "m4a";
    const filename = `${id}_punto_b.${ext}`;
    const filepath = path.join(UPLOADS_DIR, filename);
    let buf;
    try {
      buf = Buffer.from(audioBase64, "base64");
    } catch (_) {
      return res.status(400).json({ success: false, error: "audioBase64 inválido" });
    }
    if (buf.length > 30 * 1024 * 1024) {
      return res.status(400).json({ success: false, error: "El audio supera el tamaño máximo (30MB)" });
    }
    fs.writeFileSync(filepath, buf);
    const rutaRelativa = `/audio/${filename}`;
    await runExecute(
      `UPDATE ${TABLES.llamadas} SET rutaGrabacionPuntoB = @path WHERE id = @id`,
      (request) => {
        request.input("path", rutaRelativa);
        request.input("id", id);
      }
    );
    return res.json({ success: true, id, rutaGrabacionPuntoB: rutaRelativa, audioUrl: rutaRelativa });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
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
    if (Object.prototype.hasOwnProperty.call(body, "rutaGrabacionPuntoB")) {
      updates.rutaGrabacionPuntoB = asNullableString(body.rutaGrabacionPuntoB);
    }
    if (Object.prototype.hasOwnProperty.call(body, "transcripcionTexto")) {
      updates.transcripcionTexto = asNullableString(body.transcripcionTexto);
    }

    const columns = Object.keys(updates).filter((c) => LLAMADAS_COLUMNS.has(c));
    if (columns.length === 0) {
      return res.status(400).json({ success: false, error: "Sin campos válidos para actualizar" });
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
    return res.status(500).json({
      success: false,
      error: error.message || String(error),
    });
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
      "GET /",
      "GET /health",
      "GET /health/db",
      "GET /test",
      "POST /transcribe",
      "POST /llamadas",
      "GET /llamadas",
      "POST /llamadas/:id/audio",
      "POST /llamadas/:id/audio-punto-b",
      "PATCH /llamadas/:id",
      "GET /vendedores",
      "GET /supervisores",
      "GET /ppvc",
      "GET /rvc",
      "GET /alertas",
    ],
    timestamp: new Date().toISOString(),
  });
});

let httpServer = null;

const sapCodeTables = ['supervisores', 'vendedores'];

/** Crea la tabla registro_llamadas si no existe, y agrega columnas faltantes */
async function ensureColumns() {
  try {
    const pool = await getPool();

    // 1. Crear la tabla completa si no existe
    await pool.request().query(`
      IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'registro_llamadas'
      )
      CREATE TABLE [registro_llamadas] (
        [id]                    NVARCHAR(200) NOT NULL PRIMARY KEY,
        [fecha]                 DATE          NOT NULL,
        [horaInicio]            NVARCHAR(50)  NOT NULL,
        [horaFin]               NVARCHAR(50)  NOT NULL,
        [fechaCreacion]         NVARCHAR(50)  NULL,
        [duracionMinutos]       INT           NOT NULL DEFAULT 0,
        [tipoLlamada]           NVARCHAR(100) NOT NULL,
        [cargoLider]            NVARCHAR(100) NOT NULL,
        [zona]                  NVARCHAR(200) NOT NULL,
        [nombreLider]           NVARCHAR(300) NOT NULL,
        [nombreContactado]      NVARCHAR(300) NOT NULL,
        [numeroContacto]        NVARCHAR(50)  NULL,
        [numeroPropietario]     NVARCHAR(50)  NULL,
        [clientesProgramados]   INT           NOT NULL DEFAULT 0,
        [clientesVisitados]     INT           NOT NULL DEFAULT 0,
        [ventaDia]              FLOAT         NOT NULL DEFAULT 0,
        [recaudoDia]            FLOAT         NOT NULL DEFAULT 0,
        [cumplioMeta]           INT           NOT NULL DEFAULT 0,
        [coincidenciaPpvcRvc]   INT           NOT NULL DEFAULT 0,
        [conversion60]          INT           NOT NULL DEFAULT 0,
        [recuperacionPerdidos]  INT           NOT NULL DEFAULT 0,
        [observaciones]         NVARCHAR(MAX) NULL,
        [confirmacionVeracidad] INT           NOT NULL DEFAULT 1,
        [rutaGrabacion]         NVARCHAR(500) NULL,
        [rutaGrabacionPuntoB]   NVARCHAR(500) NULL,
        [transcripcionTexto]    NVARCHAR(MAX) NULL,
        [latitud]               FLOAT         NULL,
        [longitud]              FLOAT         NULL
      )
    `);
    console.log("[migration] tabla registro_llamadas OK");

    // 2. Agregar columnas nuevas si ya existia la tabla sin ellas
    const newCols = [
      { name: "fechaCreacion",       type: "NVARCHAR(50)  NULL" },
      { name: "latitud",             type: "FLOAT         NULL" },
      { name: "longitud",            type: "FLOAT         NULL" },
      { name: "rutaGrabacionPuntoB", type: "NVARCHAR(500) NULL" },
    ];
    for (const col of newCols) {
      try {
        await pool.request().query(
          `IF NOT EXISTS (
             SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_NAME = 'registro_llamadas' AND COLUMN_NAME = '${col.name}'
           )
           ALTER TABLE [registro_llamadas] ADD [${col.name}] ${col.type}`
        );
        console.log(`[migration] columna '${col.name}' OK`);
      } catch (colErr) {
        console.warn(`[migration] no se pudo agregar '${col.name}': ${colErr.message}`);
      }
    }

    // 3. Asegurar que coachId sea opcional en vendedores (para que el sync no falle)
    try {
      await pool.request().query(`
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'vendedores' AND COLUMN_NAME = 'coachId')
        BEGIN
          ALTER TABLE [vendedores] ALTER COLUMN [coachId] NVARCHAR(200) NULL
        END
      `);
      console.log("[migration] columna 'vendedores.coachId' ahora es opcional (NULL OK)");
    } catch (migErr) {
      console.warn("[migration] error alterando 'vendedores.coachId':", migErr.message);
    }

    // 5. Agregar alias a supervisores y vendedores para login simplificado
    for (const table of sapCodeTables) {
      try {
        await pool.request().query(`
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${table}' AND COLUMN_NAME = 'alias')
          BEGIN
            ALTER TABLE [${table}] ADD [alias] NVARCHAR(100) NULL
          END
        `);
        console.log(`[migration] columna '${table}.alias' OK`);
      } catch (migErr) {
        console.warn(`[migration] error agregando 'alias' a ${table}:`, migErr.message);
      }
    }
  } catch (err) {
    console.warn("[migration] error en migración:", err.message);
  }
}

async function startServer() {
  console.log("Iniciando API Node.js...");
  console.log("=".repeat(50));
  console.log(`Puerto: ${port}`);
  console.log(`Host SQL: ${dbConfig.server}:${dbConfig.port}`);
  console.log(`DB SQL: ${dbConfig.database}`);
  if (process.env.NODE_ENV === "production" && !process.env.DB_PASS) {
    console.warn("ADVERTENCIA: DB_PASS no definido. Usa variables de entorno en producción.");
  }

  // Migración automática de columnas nuevas
  await ensureColumns();

  // Iniciar Cron Jobs
  initCronJobs();

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

function initCronJobs() {
  console.log("[cron] Iniciando planificador de tareas...");

  // Tarea de las 8:20 AM: Alertar sobre vendedores sin llamadas
  cron.schedule("20 8 * * *", async () => {
    console.log("[cron] Ejecutando verificación de llamadas 8:20 AM...");
    try {
      const pool = await getPool();
      const sapPool = await getSapPool();

      // Vendedores activos de SAP
      const vendsSap = await sapPool.request().query(`
        SELECT DISTINCT T1.[SlpName] AS nombre, T2.[Name] AS coach, T3.[Name] AS kam
        FROM OCRD T0
        INNER JOIN OSLP T1 ON T0.[SlpCode] = T1.[SlpCode]
        INNER JOIN [dbo].[@COACH] T2 ON T0.[U_COACH] = T2.[Code]
        INNER JOIN [dbo].[@SKY_NEGOCIADOR] T3 ON T0.[U_NEGOCIADOR] = T3.[Code]
        WHERE T0.[validFor] = 'Y'
      `);

      const hoy = new Date().toISOString().split('T')[0];
      const llamaronHoy = await pool.request()
        .input("hoy", hoy)
        .query(`SELECT DISTINCT nombreLider FROM registro_llamadas WHERE fecha = @hoy`);

      const nombresQueLlamaron = new Set(llamaronHoy.recordset.map(r => r.nombreLider));

      for (const v of vendsSap.recordset) {
        if (!nombresQueLlamaron.has(v.nombre)) {
          const msg = `Vendedor ${v.nombre} no ha realizado llamadas antes de las 8:20 AM`;
          await pool.request()
            .input("id", crypto.randomUUID())
            .input("tipo", "SIN_LLAMADAS_820")
            .input("mensaje", msg)
            .input("vendedor", v.nombre)
            .input("coach", v.coach)
            .input("kam", v.kam)
            .input("fecha", hoy)
            .query(`
              IF NOT EXISTS (SELECT 1 FROM alertas WHERE mensaje = @mensaje AND fecha = @fecha)
              INSERT INTO alertas (id, tipo, mensaje, vendedor, coach, kam, fecha, estado)
              VALUES (@id, @tipo, @mensaje, @vendedor, @coach, @kam, @fecha, 'PENDIENTE')
            `);
        }
      }
    } catch (err) {
      console.error("[cron] Error en tarea 8:20 AM:", err.message);
    }
  });
}

module.exports = { app, startServer, getPool };

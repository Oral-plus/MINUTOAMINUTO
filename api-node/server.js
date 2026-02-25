"use strict";

const express = require("express");
const cors = require("cors");
const os = require("os");
const sql = require("mssql");

const app = express();
const port = Number(process.env.PORT || 3005);

app.use(cors());
app.use(express.json({ limit: "1mb" }));

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
  user: process.env.DB_USER || "",
  password: process.env.DB_PASS || "",
  server: process.env.DB_HOST || "",
  database: process.env.DB_NAME || "",
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

let poolPromise = null;

function missingDbConfig() {
  const required = ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASS"];
  return required.filter((key) => !process.env[key]);
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

app.get("/api/invoices/by-cardcode/:cardcode", async (req, res) => {
  const startedAt = Date.now();
  try {
    const cardCode = String(req.params.cardcode || "").trim();
    if (!cardCode) {
      return res.status(400).json({
        success: false,
        error: "CardCode es requerido",
        timestamp: new Date().toISOString(),
      });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input("cardCode", sql.VarChar(80), cardCode)
      .query("SELECT * FROM CONSULTA_CARTERA WHERE CardCode = @cardCode");

    if (result.recordset.length === 0) {
      return res.json({
        success: true,
        message: "Te encuentras a paz y salvo",
        cardCode,
        count: 0,
        invoices: [],
        queryTimeMs: Date.now() - startedAt,
        timestamp: new Date().toISOString(),
      });
    }

    const invoices = result.recordset.map(mapInvoice).sort((a, b) => a.priority - b.priority);
    const totalAmount = invoices.reduce((sum, item) => sum + item.amount, 0);
    const overdue = invoices.filter((i) => i.isOverdue).length;
    const urgent = invoices.filter((i) => i.isUrgent && !i.isOverdue).length;
    const upcoming = invoices.filter((i) => i.isUpcoming).length;
    const normal = invoices.length - overdue - urgent - upcoming;

    return res.json({
      success: true,
      message: `${invoices.length} facturas encontradas`,
      cardCode,
      count: invoices.length,
      invoices,
      statistics: {
        total: invoices.length,
        overdue,
        urgent,
        upcoming,
        normal,
        totalAmount,
      },
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: "Error interno del servidor",
      message: error.message,
      queryTimeMs: Date.now() - startedAt,
      timestamp: new Date().toISOString(),
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: "Ruta no encontrada",
    availableEndpoints: [
      "GET /health",
      "GET /health/db",
      "GET /api/test",
      "GET /api/invoices/by-cardcode/:cardcode",
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

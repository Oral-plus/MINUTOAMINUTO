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
const nodemailer = require("nodemailer");
const https = require("https");

// docx es opcional — si no está instalado el servidor arranca igual
// y solo falla la generación de Word (no todo el servidor)
let _docxModule = null;
try {
  _docxModule = require("docx");
} catch (_) {
  console.warn("[docx] Módulo 'docx' no instalado. Ejecuta: npm install docx");
}
function getDocx() {
  if (!_docxModule) throw new Error("Módulo 'docx' no instalado en el servidor. Ejecuta: npm install");
  return _docxModule;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMAIL REPORTS — CONFIG, TEMPLATES Y ENVÍO
// ═══════════════════════════════════════════════════════════════════════════════

// ─── CONFIG ──────────────────────────────────────────────────────────────────
const GMAIL_USER = process.env.GMAIL_USER || "skyenviocorreo@gmail.com";
const GMAIL_PASS = process.env.GMAIL_PASS || "caaq lvtq uvyc fmhk";

const RECIPIENTS_FILE = path.join(__dirname, "recipients.json");
const DEFAULT_RECIPIENTS = ["sistemas@oral-plus.com", "skyenviocorreo@gmail.com"];

function loadRecipients() {
  try {
    if (fs.existsSync(RECIPIENTS_FILE)) {
      const data = JSON.parse(fs.readFileSync(RECIPIENTS_FILE, "utf8"));
      if (Array.isArray(data) && data.length > 0) return data;
    }
  } catch (_) {}
  return DEFAULT_RECIPIENTS;
}

function saveRecipients(list) {
  fs.writeFileSync(RECIPIENTS_FILE, JSON.stringify(list, null, 2));
}

function getRecipientsString() {
  return loadRecipients().join(",");
}

const REPORT_TO = process.env.REPORT_TO || getRecipientsString();

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false,
  auth: { user: GMAIL_USER, pass: GMAIL_PASS },
});

// ─── BRAND ───────────────────────────────────────────────────────────────────
const BRAND = {
  primary:  "#6366f1",
  primary2: "#a855f7",
  green:    "#10b981",
  red:      "#f87171",
  amber:    "#f59e0b",
  blue:     "#60a5fa",
  bg:       "#0f0f1a",
  surface:  "#1a1a2e",
  surface2: "#1e1e35",
  text:     "#f1f5f9",
  text2:    "#94a3b8",
  border:   "rgba(255,255,255,0.08)",
};

const LOGO_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" viewBox="0 0 44 44">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#6366f1"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <rect width="44" height="44" rx="12" fill="url(#g)"/>
  <path d="M13.14 20.58c2.66 5.22 6.94 9.48 12.18 12.18l4.06-4.06c.5-.5 1.24-.66 1.88-.44 2.07.68 4.3 1.05 6.58 1.05 1.02 0 1.84.82 1.84 1.84V37c0 1.02-.82 1.84-1.84 1.84C20.34 38.84 7 25.5 7 8.84 7 7.82 7.82 7 8.84 7h5.85c1.02 0 1.84.82 1.84 1.84 0 2.3.37 4.51 1.05 6.58.2.64.06 1.36-.44 1.88l-4.0 4.28z" fill="white" transform="translate(2,2) scale(0.75)"/>
</svg>`;

// ─── HELPERS ─────────────────────────────────────────────────────────────────
function fmtN(n) {
  if (n == null) return "—";
  return Number(n).toLocaleString("es-CO");
}
function fmtMoney(n) {
  if (n == null || n === 0) return "—";
  return "$ " + Number(n).toLocaleString("es-CO", { minimumFractionDigits: 0 });
}
function fmtPct(val, total) {
  if (!total) return "0%";
  return Math.round((val / total) * 100) + "%";
}
function dateLabel(date) {
  return date.toLocaleDateString("es-CO", {
    weekday: "long", year: "numeric", month: "long", day: "numeric",
    timeZone: "America/Bogota",
  });
}
function pill(text, color, bg) {
  return `<span style="display:inline-block;padding:2px 10px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:.04em;color:${color};background:${bg};border:1px solid ${color}33;">${text}</span>`;
}
function metaPill(cumplido) {
  return cumplido
    ? pill("✓ Meta", BRAND.green, "rgba(16,185,129,.15)")
    : pill("✗ Sin meta", BRAND.red,  "rgba(248,113,113,.15)");
}
function trend(val, total) {
  const pct = total ? (val / total) * 100 : 0;
  const color = pct >= 80 ? BRAND.green : pct >= 50 ? BRAND.amber : BRAND.red;
  return `<div style="display:flex;align-items:center;gap:8px;">
    <div style="flex:1;height:6px;border-radius:3px;background:rgba(255,255,255,.08);overflow:hidden;">
      <div style="width:${Math.min(pct,100)}%;height:100%;background:${color};border-radius:3px;"></div>
    </div>
    <span style="font-size:11px;font-weight:700;color:${color};min-width:35px;">${Math.round(pct)}%</span>
  </div>`;
}

// ─── BASE TEMPLATE ────────────────────────────────────────────────────────────
function baseTemplate({ title, subtitle, badge, headerExtra = "", body }) {
  const badgeLabel = typeof badge === "string" ? badge : badge.label;
  const badgeValue = typeof badge === "string" ? badge : badge.value;
  return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head>
<body style="margin:0;padding:0;background:#0a0a14;font-family:'Segoe UI',Arial,sans-serif;-webkit-font-smoothing:antialiased;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#0a0a14;min-height:100vh;">
<tr><td align="center" style="padding:32px 16px;">
<table width="620" cellpadding="0" cellspacing="0" style="max-width:620px;width:100%;border-radius:20px;overflow:hidden;border:1px solid rgba(255,255,255,0.07);box-shadow:0 24px 80px rgba(99,102,241,.18);">
  <tr><td style="background:linear-gradient(135deg,#6366f1 0%,#7c3aed 50%,#a855f7 100%);padding:36px 36px 32px;">
    <table width="100%" cellpadding="0" cellspacing="0"><tr>
      <td style="vertical-align:middle;"><table cellpadding="0" cellspacing="0"><tr>
        <td style="padding-right:14px;vertical-align:middle;">${LOGO_SVG}</td>
        <td style="vertical-align:middle;">
          <div style="font-size:11px;font-weight:700;letter-spacing:.12em;color:rgba(255,255,255,.65);text-transform:uppercase;margin-bottom:4px;">Minuto a Minuto</div>
          <div style="font-size:22px;font-weight:900;color:#ffffff;line-height:1.2;">${title}</div>
          <div style="font-size:13px;color:rgba(255,255,255,.75);margin-top:5px;">${subtitle}</div>
        </td>
      </tr></table></td>
      <td align="right" style="vertical-align:top;">
        <div style="background:rgba(255,255,255,.15);backdrop-filter:blur(10px);border:1px solid rgba(255,255,255,.2);border-radius:10px;padding:8px 16px;display:inline-block;text-align:center;">
          <div style="font-size:10px;font-weight:700;letter-spacing:.08em;color:rgba(255,255,255,.7);text-transform:uppercase;">${badgeLabel}</div>
          <div style="font-size:18px;font-weight:900;color:#fff;">${badgeValue}</div>
        </div>${headerExtra}
      </td>
    </tr></table>
  </td></tr>
  <tr><td style="background:${BRAND.bg};padding:0;">${body}</td></tr>
  <tr><td style="background:${BRAND.surface};padding:24px 36px;border-top:1px solid rgba(255,255,255,.05);">
    <table width="100%" cellpadding="0" cellspacing="0"><tr>
      <td><div style="font-size:11px;color:${BRAND.text2};">📞 <strong style="color:${BRAND.text};">Minuto a Minuto</strong> — Sistema de Seguimiento Comercial ORAL-PLUS<br><span style="color:rgba(148,163,184,.5);">Este correo fue generado automáticamente. Por favor no responder.</span></div></td>
      <td align="right"><div style="font-size:10px;color:rgba(148,163,184,.4);font-weight:600;letter-spacing:.06em;">ORAL-PLUS S.A.S</div></td>
    </tr></table>
  </td></tr>
</table>
</td></tr></table></body></html>`;
}

function statCards(stats) {
  const cells = stats.map(s => `
    <td width="${Math.floor(100 / stats.length)}%" style="padding:0 6px;vertical-align:top;">
      <div style="background:${BRAND.surface2};border:1px solid rgba(255,255,255,.06);border-radius:14px;padding:18px;text-align:center;">
        <div style="font-size:24px;margin-bottom:6px;">${s.icon}</div>
        <div style="font-size:26px;font-weight:900;color:${s.color || BRAND.text};line-height:1;">${s.value}</div>
        <div style="font-size:11px;font-weight:600;color:${BRAND.text2};margin-top:5px;letter-spacing:.03em;">${s.label}</div>
      </div>
    </td>`).join("");
  return `<table width="100%" cellpadding="0" cellspacing="0" style="padding:24px 36px 0;"><tr>${cells}</tr></table>`;
}

function lidersTable(rows, showMeta = false) {
  if (!rows || !rows.length) return `<div style="padding:24px 36px;text-align:center;color:${BRAND.text2};font-size:13px;">Sin registros para este período.</div>`;
  const headers = ["#", "Líder", "Cargo", "Zona", "Llamadas", "Duración prom.", ...(showMeta ? ["Meta"] : [])];
  const hCells = headers.map(h => `<th style="padding:10px 12px;text-align:left;font-size:10px;font-weight:700;letter-spacing:.08em;color:${BRAND.text2};text-transform:uppercase;background:rgba(255,255,255,.03);border-bottom:1px solid rgba(255,255,255,.06);">${h}</th>`).join("");
  const tRows = rows.map((r, i) => {
    const cargoColor = { COACH: BRAND.green, KAM: BRAND.blue, JEFE: BRAND.amber, VENDEDOR: "#a78bfa" }[r.cargo?.toUpperCase()] || BRAND.text2;
    const cargoBg   = { COACH: "rgba(16,185,129,.12)", KAM: "rgba(96,165,250,.12)", JEFE: "rgba(245,158,11,.12)", VENDEDOR: "rgba(167,139,250,.12)" }[r.cargo?.toUpperCase()] || "rgba(255,255,255,.06)";
    const metaCell  = showMeta ? `<td style="padding:12px;">${metaPill(r.cumplioMeta)}</td>` : "";
    const bg        = i % 2 === 0 ? BRAND.bg : BRAND.surface;
    return `<tr style="background:${bg};"><td style="padding:12px;color:${BRAND.text2};font-size:12px;font-weight:700;">${i + 1}</td><td style="padding:12px;font-weight:700;color:${BRAND.text};font-size:13px;">${r.nombre || r.nombreLider || "—"}</td><td style="padding:12px;">${pill(r.cargo || "—", cargoColor, cargoBg)}</td><td style="padding:12px;font-size:12px;color:${BRAND.text2};">${r.zona || "—"}</td><td style="padding:12px;font-weight:900;color:${BRAND.primary};font-size:15px;">${r.llamadas || 0}</td><td style="padding:12px;font-size:12px;color:${BRAND.text2};">${r.durProm != null ? r.durProm + " min" : "—"}</td>${metaCell}</tr>`;
  }).join("");
  return `<div style="padding:24px 36px 0;"><div style="font-size:12px;font-weight:800;letter-spacing:.06em;color:${BRAND.text2};text-transform:uppercase;margin-bottom:12px;">Ranking de líderes</div><div style="border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,.06);"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;"><thead><tr>${hCells}</tr></thead><tbody>${tRows}</tbody></table></div></div>`;
}

function recentCallsTable(llamadas) {
  if (!llamadas || !llamadas.length) return "";
  const rows = llamadas.slice(0, 10).map((c, i) => {
    const bg = i % 2 === 0 ? BRAND.bg : BRAND.surface;
    const hora = c.horaInicio ? new Date(c.horaInicio).toLocaleTimeString("es-CO", { hour: "2-digit", minute: "2-digit", timeZone: "America/Bogota" }) : "—";
    const hasAudio = c.rutaGrabacion || c.rutaGrabacionPuntoB;
    const audioCell = hasAudio ? pill("🎙 Audio", BRAND.blue, "rgba(96,165,250,.12)") : `<span style="color:rgba(255,255,255,.2);font-size:11px;">—</span>`;
    const transcCell = c.transcripcionTexto ? pill("🤖 IA", "#a78bfa", "rgba(167,139,250,.12)") : `<span style="color:rgba(255,255,255,.2);font-size:11px;">—</span>`;
    return `<tr style="background:${bg};"><td style="padding:10px 12px;font-size:11px;color:${BRAND.text2};">${hora}</td><td style="padding:10px 12px;font-weight:700;font-size:12px;color:${BRAND.text};">${c.nombreLider || "—"}</td><td style="padding:10px 12px;font-size:12px;color:${BRAND.text2};">${c.nombreContactado || "Desconocido"}</td><td style="padding:10px 12px;font-weight:700;color:${BRAND.primary};font-size:13px;">${c.duracionMinutos || 0} min</td><td style="padding:10px 12px;">${audioCell}</td><td style="padding:10px 12px;">${transcCell}</td></tr>`;
  }).join("");
  return `<div style="padding:24px 36px 0;"><div style="font-size:12px;font-weight:800;letter-spacing:.06em;color:${BRAND.text2};text-transform:uppercase;margin-bottom:12px;">Últimas llamadas</div><div style="border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,.06);"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;"><thead><tr>${["Hora","Líder","Contactado","Duración","Audio","Transcripción"].map(h => `<th style="padding:10px 12px;text-align:left;font-size:10px;font-weight:700;letter-spacing:.08em;color:${BRAND.text2};text-transform:uppercase;background:rgba(255,255,255,.03);border-bottom:1px solid rgba(255,255,255,.06);">${h}</th>`).join("")}</tr></thead><tbody>${rows}</tbody></table></div>${llamadas.length > 10 ? `<div style="text-align:right;padding-top:8px;font-size:11px;color:${BRAND.text2};">... y ${llamadas.length - 10} llamadas más</div>` : ""}</div>`;
}

function transcripcionesSection(llamadas) {
  const conTransc = llamadas.filter(c => c.transcripcionTexto).slice(0, 5);
  if (!conTransc.length) return "";
  const items = conTransc.map(c => {
    const texto = c.transcripcionTexto.length > 200 ? c.transcripcionTexto.substring(0, 200) + "…" : c.transcripcionTexto;
    return `<div style="background:${BRAND.surface2};border:1px solid rgba(167,139,250,.2);border-left:3px solid #a78bfa;border-radius:10px;padding:16px;margin-bottom:12px;"><div style="display:flex;justify-content:space-between;margin-bottom:8px;"><span style="font-weight:700;font-size:13px;color:${BRAND.text};">${c.nombreLider || "—"}</span><span style="font-size:11px;color:${BRAND.text2};">${c.nombreContactado || "Desconocido"} · ${c.duracionMinutos || 0} min</span></div><div style="font-size:12px;color:${BRAND.text2};line-height:1.6;font-style:italic;">"${texto}"</div></div>`;
  }).join("");
  return `<div style="padding:24px 36px 0;"><div style="font-size:12px;font-weight:800;letter-spacing:.06em;color:${BRAND.text2};text-transform:uppercase;margin-bottom:12px;">🤖 Transcripciones IA destacadas</div>${items}</div>`;
}

function divider(label) {
  return `<div style="padding:20px 36px 0;"><div style="border-top:1px solid rgba(255,255,255,.06);padding-top:20px;">${label ? `<div style="font-size:12px;font-weight:800;letter-spacing:.06em;color:${BRAND.text2};text-transform:uppercase;margin-bottom:4px;">${label}</div>` : ""}</div></div>`;
}
function spacer(h = 24) { return `<div style="height:${h}px;"></div>`; }

// ═══════════════════════════════════════════════════════════════════════════════
// BUILDERS (daily / weekly / monthly HTML reports)
// ═══════════════════════════════════════════════════════════════════════════════
function buildDailyReport({ date, llamadas }) {
  const total = llamadas.length;
  const efectivas = llamadas.filter(c => (c.duracionMinutos || 0) >= 1).length;
  const perdidas = total - efectivas;
  const conAudio = llamadas.filter(c => c.rutaGrabacion || c.rutaGrabacionPuntoB).length;
  const conTransc = llamadas.filter(c => c.transcripcionTexto).length;
  const durTotal = llamadas.reduce((s, c) => s + (c.duracionMinutos || 0), 0);
  const durProm = total ? Math.round(durTotal / total) : 0;
  const cumplieron = llamadas.filter(c => c.cumplioMeta).length;
  const byLider = {};
  llamadas.forEach(c => { const k = c.nombreLider || "Desconocido"; if (!byLider[k]) byLider[k] = { nombre: k, cargo: c.cargoLider, zona: c.zona, llamadas: 0, durTotal: 0, cumplioMeta: false }; byLider[k].llamadas++; byLider[k].durTotal += (c.duracionMinutos || 0); if (c.cumplioMeta) byLider[k].cumplioMeta = true; });
  const ranking = Object.values(byLider).map(r => ({ ...r, durProm: r.llamadas ? Math.round(r.durTotal / r.llamadas) : 0 })).sort((a, b) => b.llamadas - a.llamadas).slice(0, 15);
  const subtitle = dateLabel(date);
  const body = [
    statCards([{ icon: "📞", label: "Total llamadas", value: fmtN(total), color: BRAND.primary },{ icon: "✅", label: "Efectivas", value: fmtN(efectivas), color: BRAND.green },{ icon: "🎙", label: "Con audio", value: fmtN(conAudio), color: BRAND.blue },{ icon: "🤖", label: "Transcripciones", value: fmtN(conTransc), color: "#a78bfa" }]),
    divider(),
    statCards([{ icon: "⏱", label: "Duración promedio", value: durProm + " min", color: BRAND.amber },{ icon: "📉", label: "Perdidas/cortas", value: fmtN(perdidas), color: BRAND.red },{ icon: "🏆", label: "Cumplieron meta", value: fmtN(cumplieron), color: BRAND.green },{ icon: "⏳", label: "Minutos totales", value: fmtN(durTotal), color: BRAND.text2 }]),
    lidersTable(ranking, true), recentCallsTable(llamadas), transcripcionesSection(llamadas), spacer(32),
  ].join("");
  return baseTemplate({ title: "Reporte Diario", subtitle, badge: { label: "Llamadas hoy", value: fmtN(total) }, body });
}

function buildWeeklyReport({ desde, hasta, llamadas }) {
  const total = llamadas.length;
  const efectivas = llamadas.filter(c => (c.duracionMinutos || 0) >= 1).length;
  const conAudio = llamadas.filter(c => c.rutaGrabacion || c.rutaGrabacionPuntoB).length;
  const conTransc = llamadas.filter(c => c.transcripcionTexto).length;
  const durTotal = llamadas.reduce((s, c) => s + (c.duracionMinutos || 0), 0);
  const durProm = total ? Math.round(durTotal / total) : 0;
  const byDay = {};
  llamadas.forEach(c => { const d = (c.fecha || "").split("T")[0]; byDay[d] = (byDay[d] || 0) + 1; });
  const diasLabel = Object.keys(byDay).sort().map(d => { const dt = new Date(d + "T12:00:00"); const dayName = dt.toLocaleDateString("es-CO", { weekday: "short", day: "numeric", timeZone: "America/Bogota" }); const cnt = byDay[d]; return `<tr><td style="padding:8px 12px;font-size:12px;color:${BRAND.text2};">${dayName}</td><td style="padding:8px 12px;font-weight:700;color:${BRAND.text};">${cnt}</td><td style="padding:8px 12px;width:60%;">${trend(cnt, Math.max(...Object.values(byDay)))}</td></tr>`; }).join("");
  const byLider = {};
  llamadas.forEach(c => { const k = c.nombreLider || "Desconocido"; if (!byLider[k]) byLider[k] = { nombre: k, cargo: c.cargoLider, zona: c.zona, llamadas: 0, durTotal: 0 }; byLider[k].llamadas++; byLider[k].durTotal += (c.duracionMinutos || 0); });
  const ranking = Object.values(byLider).map(r => ({ ...r, durProm: r.llamadas ? Math.round(r.durTotal / r.llamadas) : 0 })).sort((a, b) => b.llamadas - a.llamadas).slice(0, 15);
  const fmtDate = d => d.toLocaleDateString("es-CO", { day: "numeric", month: "short", timeZone: "America/Bogota" });
  const subtitle = `Semana del ${fmtDate(desde)} al ${fmtDate(hasta)}`;
  const body = [
    statCards([{ icon: "📞", label: "Total semana", value: fmtN(total), color: BRAND.primary },{ icon: "✅", label: "Efectivas", value: fmtN(efectivas), color: BRAND.green },{ icon: "🎙", label: "Con audio", value: fmtN(conAudio), color: BRAND.blue },{ icon: "🤖", label: "Analizadas con IA", value: fmtN(conTransc), color: "#a78bfa" }]),
    divider("Actividad por día"),
    `<div style="padding:0 36px;"><div style="border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,.06);"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">${diasLabel}</table></div></div>`,
    divider(),
    statCards([{ icon: "⏱", label: "Duración promedio", value: durProm + " min", color: BRAND.amber },{ icon: "⏳", label: "Minutos totales", value: fmtN(durTotal), color: BRAND.text2 },{ icon: "📅", label: "Promedio por día", value: Math.round(total / 7) + "/día", color: BRAND.text2 },{ icon: "📈", label: "Cobertura audio", value: fmtPct(conAudio, total), color: BRAND.blue }]),
    lidersTable(ranking), transcripcionesSection(llamadas), spacer(32),
  ].join("");
  return baseTemplate({ title: "Reporte Semanal", subtitle, badge: { label: "Esta semana", value: fmtN(total) }, body });
}

function buildMonthlyReport({ mes, anio, llamadas }) {
  const total = llamadas.length; const efectivas = llamadas.filter(c => (c.duracionMinutos || 0) >= 1).length; const conAudio = llamadas.filter(c => c.rutaGrabacion || c.rutaGrabacionPuntoB).length; const conTransc = llamadas.filter(c => c.transcripcionTexto).length; const durTotal = llamadas.reduce((s, c) => s + (c.duracionMinutos || 0), 0); const durProm = total ? Math.round(durTotal / total) : 0; const cumplieron = llamadas.filter(c => c.cumplioMeta).length;
  const bySemana = { "Sem 1": 0, "Sem 2": 0, "Sem 3": 0, "Sem 4": 0 };
  llamadas.forEach(c => { const d = new Date((c.fecha || "").split("T")[0] + "T12:00:00"); const dia = d.getDate(); if (dia <= 7) bySemana["Sem 1"]++; else if (dia <= 14) bySemana["Sem 2"]++; else if (dia <= 21) bySemana["Sem 3"]++; else bySemana["Sem 4"]++; });
  const maxSem = Math.max(...Object.values(bySemana));
  const semanaRows = Object.entries(bySemana).map(([sem, cnt]) => `<tr><td style="padding:8px 12px;font-size:12px;color:${BRAND.text2};">${sem}</td><td style="padding:8px 12px;font-weight:700;color:${BRAND.text};">${cnt}</td><td style="padding:8px 12px;width:60%;">${trend(cnt, maxSem)}</td></tr>`).join("");
  const byCargo = {}; llamadas.forEach(c => { const k = (c.cargoLider || "Sin cargo").toUpperCase(); byCargo[k] = (byCargo[k] || 0) + 1; });
  const cargoRows = Object.entries(byCargo).sort((a, b) => b[1] - a[1]).map(([cargo, cnt]) => { const color = { COACH: BRAND.green, KAM: BRAND.blue, JEFE: BRAND.amber, VENDEDOR: "#a78bfa" }[cargo] || BRAND.text2; const bg = { COACH: "rgba(16,185,129,.12)", KAM: "rgba(96,165,250,.12)", JEFE: "rgba(245,158,11,.12)", VENDEDOR: "rgba(167,139,250,.12)" }[cargo] || "rgba(255,255,255,.06)"; return `<tr><td style="padding:8px 12px;">${pill(cargo, color, bg)}</td><td style="padding:8px 12px;font-weight:700;color:${BRAND.text};">${cnt}</td><td style="padding:8px 12px;width:55%;">${trend(cnt, total)}</td></tr>`; }).join("");
  const byLider = {}; llamadas.forEach(c => { const k = c.nombreLider || "Desconocido"; if (!byLider[k]) byLider[k] = { nombre: k, cargo: c.cargoLider, zona: c.zona, llamadas: 0, durTotal: 0 }; byLider[k].llamadas++; byLider[k].durTotal += (c.duracionMinutos || 0); });
  const ranking = Object.values(byLider).map(r => ({ ...r, durProm: r.llamadas ? Math.round(r.durTotal / r.llamadas) : 0 })).sort((a, b) => b.llamadas - a.llamadas).slice(0, 20);
  const mesNombre = new Date(anio, mes - 1, 1).toLocaleDateString("es-CO", { month: "long", year: "numeric", timeZone: "America/Bogota" });
  const subtitle = `Resumen de ${mesNombre.charAt(0).toUpperCase() + mesNombre.slice(1)}`;
  const body = [
    statCards([{ icon: "📞", label: "Total mes", value: fmtN(total), color: BRAND.primary },{ icon: "✅", label: "Efectivas", value: fmtN(efectivas), color: BRAND.green },{ icon: "🏆", label: "Cumplieron meta", value: fmtN(cumplieron), color: BRAND.green },{ icon: "🤖", label: "Analizadas IA", value: fmtN(conTransc), color: "#a78bfa" }]),
    divider(),
    statCards([{ icon: "🎙", label: "Con audio", value: fmtN(conAudio), color: BRAND.blue },{ icon: "⏱", label: "Duración promedio", value: durProm + " min", color: BRAND.amber },{ icon: "⏳", label: "Minutos totales", value: fmtN(durTotal), color: BRAND.text2 },{ icon: "📈", label: "Efectividad", value: fmtPct(efectivas, total), color: BRAND.green }]),
    divider("Actividad por semana"),
    `<div style="padding:0 36px;"><div style="border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,.06);"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">${semanaRows}</table></div></div>`,
    divider("Distribución por cargo"),
    `<div style="padding:0 36px;"><div style="border-radius:12px;overflow:hidden;border:1px solid rgba(255,255,255,.06);"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">${cargoRows}</table></div></div>`,
    lidersTable(ranking), transcripcionesSection(llamadas), spacer(32),
  ].join("");
  return baseTemplate({ title: "Reporte Mensual", subtitle, badge: { label: "Total mes", value: fmtN(total) }, body });
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCIONES DE ENVÍO DE CORREO
// ═══════════════════════════════════════════════════════════════════════════════
async function sendReport({ to, subject, html }) {
  await transporter.sendMail({ from: `"Minuto a Minuto 📞" <${GMAIL_USER}>`, to, subject, html });
  console.log(`[email] Reporte enviado → ${to} | ${subject}`);
}

async function callGeminiServer(prompt) {
  const apiKey = process.env.GEMINI_API_KEY || "";
  if (!apiKey) throw new Error("GEMINI_API_KEY no configurada en el servidor");
  const models = ["gemini-2.0-flash", "gemini-2.5-flash", "gemini-2.5-pro"];
  const bodyStr = JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] });
  for (const model of models) {
    try {
      const text = await new Promise((resolve, reject) => {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const req = https.request(url, { method: "POST", headers: { "Content-Type": "application/json" } }, (res) => {
          let data = ""; res.on("data", (c) => data += c); res.on("end", () => {
            try { const j = JSON.parse(data); if (j.candidates && j.candidates[0]?.content?.parts?.[0]?.text) resolve(j.candidates[0].content.parts[0].text); else reject(new Error(j.error?.message || "Sin respuesta")); } catch (e) { reject(e); }
          });
        }); req.on("error", reject); req.write(bodyStr); req.end();
      });
      return text;
    } catch (_) {}
  }
  throw new Error("Gemini no disponible");
}

async function buildAiDocx(title, reportText) {
  const { Document, Packer, Paragraph, TextRun, AlignmentType, BorderStyle, convertInchesToTwip } = getDocx();
  function parseRuns(text, size, color) {
    const runs = [], boldRe = /\*\*(.+?)\*\*/g; let last = 0, m;
    while ((m = boldRe.exec(text)) !== null) { if (m.index > last) runs.push(new TextRun({ text: text.slice(last, m.index), size, color, font: "Calibri" })); runs.push(new TextRun({ text: m[1], bold: true, size, color, font: "Calibri" })); last = m.index + m[0].length; }
    if (last < text.length) runs.push(new TextRun({ text: text.slice(last), size, color, font: "Calibri" }));
    return runs.length ? runs : [new TextRun({ text, size, color, font: "Calibri" })];
  }
  const paragraphs = [];
  for (const line of reportText.split("\n")) {
    const t = line.trim();
    if (!t) { paragraphs.push(new Paragraph({ spacing: { after: 80 } })); continue; }
    if (t.startsWith("## ")) paragraphs.push(new Paragraph({ children: [new TextRun({ text: t.slice(3), bold: true, size: 28, color: "0d47a1", font: "Calibri" })], spacing: { before: 300, after: 120 }, border: { bottom: { color: "e8eaed", style: BorderStyle.SINGLE, size: 2, space: 4 } } }));
    else if (t.startsWith("# ")) paragraphs.push(new Paragraph({ children: [new TextRun({ text: t.slice(2), bold: true, size: 32, color: "0d47a1", font: "Calibri" })], spacing: { before: 400, after: 160 } }));
    else if (t.startsWith("- ") || t.startsWith("• ")) paragraphs.push(new Paragraph({ children: parseRuns(t.slice(2), 20, "374151"), bullet: { level: 0 }, spacing: { after: 60 } }));
    else paragraphs.push(new Paragraph({ children: parseRuns(t, 20, "374151"), spacing: { after: 80 } }));
  }
  const doc = new Document({ styles: { default: { document: { run: { font: "Calibri", size: 22 } } } }, sections: [{ properties: { page: { margin: { top: convertInchesToTwip(1), bottom: convertInchesToTwip(0.8), left: convertInchesToTwip(1), right: convertInchesToTwip(1) } } }, children: [
    new Paragraph({ children: [new TextRun({ text: title, bold: true, size: 36, color: "0d47a1", font: "Calibri" })], alignment: AlignmentType.CENTER, spacing: { before: 200, after: 100 } }),
    new Paragraph({ children: [new TextRun({ text: `Generado por Minuto a Minuto IA  •  ${new Date().toLocaleDateString("es-CO", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}`, size: 18, color: "9ca3af", italics: true, font: "Calibri" })], alignment: AlignmentType.CENTER, spacing: { after: 300 } }),
    new Paragraph({ border: { bottom: { color: "0d5abd", style: BorderStyle.SINGLE, space: 6, size: 12 } }, spacing: { after: 300 } }),
    ...paragraphs,
    new Paragraph({ border: { top: { color: "e8eaed", style: BorderStyle.SINGLE, space: 6, size: 2 } }, spacing: { before: 500 } }),
    new Paragraph({ children: [new TextRun({ text: "Documento generado automáticamente por inteligencia artificial. Validar con datos originales.", size: 16, color: "9ca3af", italics: true, font: "Calibri" })], alignment: AlignmentType.CENTER }),
  ]}] });
  return Packer.toBuffer(doc);
}

async function sendAiReport({ llamadas, title, filename, to = null, periodDesc }) {
  const recipients = to || getRecipientsString();
  const byCoach = {};
  llamadas.forEach((c) => { const coach = (c.nombreLider || "Desconocido").trim(); if (!byCoach[coach]) byCoach[coach] = { total: 0, conAudio: 0, conTransc: 0, minutos: 0, zona: "", transcripciones: [] }; byCoach[coach].total++; if (c.rutaGrabacion || c.rutaGrabacionPuntoB) byCoach[coach].conAudio++; if (c.transcripcionTexto) { byCoach[coach].conTransc++; byCoach[coach].transcripciones.push(c.transcripcionTexto.substring(0, 300)); } byCoach[coach].minutos += (c.duracionMinutos || 0); if (!byCoach[coach].zona && c.zona) byCoach[coach].zona = c.zona; });
  const coachSummary = Object.keys(byCoach).map((coach) => { const s = byCoach[coach]; return `COACH: ${coach} | Zona: ${s.zona || "?"} | Llamadas: ${s.total} | DurProm: ${s.total > 0 ? (s.minutos / s.total).toFixed(1) : 0}min | Audio: ${s.conAudio} | Transcripciones: ${s.conTransc}\n` + (s.transcripciones.length ? s.transcripciones.slice(0, 2).map(t => "  > " + t).join("\n") : "  [Sin transcripciones]"); }).join("\n\n");
  const total = llamadas.length;
  const prompt = [`Actúa como Consultor Senior de Estrategia Comercial experto en "Minuto a Minuto".`, `Genera el INFORME EJECUTIVO IA – MINUTO A MINUTO (v2.0) en español para el periodo ${periodDesc}.`, `DATOS: Total llamadas: ${total} | Coaches: ${Object.keys(byCoach).length} | Con audio: ${llamadas.filter(c => c.rutaGrabacion || c.rutaGrabacionPuntoB).length} | Con transcripción: ${llamadas.filter(c => c.transcripcionTexto).length}`, `RESUMEN POR COACH:\n${coachSummary}`, `ESTRUCTURA (12 secciones con ## encabezado): ## 1. RESUMEN EJECUTIVO | ## 2. DISCIPLINA OPERATIVA | ## 3. CUMPLIMIENTO DEL SPEECH | ## 4. CALIDAD DE LLAMADAS | ## 5. CALIDAD DE GESTIÓN | ## 6. ANÁLISIS MEDIO DÍA | ## 7. IMPACTO COMERCIAL | ## 8. RANKING DE COACHES | ## 9. ALERTAS Y RIESGOS | ## 10. RECOMENDACIONES | ## 11. PLAN DE ACCIÓN | ## 12. CONCLUSIÓN`, `Usa [VERDE], [AMARILLO] o [ROJO] como semáforos. Sé directo y orientado a resultados.`].join("\n");
  const reportText = await callGeminiServer(prompt);
  const docxBuffer = await buildAiDocx(title, reportText);
  const htmlReport = buildDailyReport({ date: new Date(), llamadas });
  await transporter.sendMail({ from: `"Minuto a Minuto 📞" <${GMAIL_USER}>`, to: recipients, subject: `📄 ${title}`, html: htmlReport, attachments: [{ filename, content: docxBuffer, contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }] });
  console.log(`[email] Informe IA DOCX + HTML enviado → ${recipients} | ${filename}`);
}

function isSunday() { return new Date().getDay() === 0; }

async function sendDailyReport(getPoolFn, TBLS, to = null) {
  if (isSunday()) { console.log("[email] Reporte diario omitido — domingo"); return; }
  try {
    const today = new Date(); const iso = today.toISOString().split("T")[0];
    const pool = await getPoolFn();
    const result = await pool.request().input("desde", iso).input("hasta", iso).query(`SELECT * FROM ${TBLS.llamadas} WHERE fecha >= @desde AND fecha <= @hasta ORDER BY horaInicio DESC`);
    const llamadas = result.recordset || [];
    await sendAiReport({ llamadas, to, title: `INFORME EJECUTIVO IA – MINUTO A MINUTO — ${dateLabel(today)}`, filename: `Informe_Diario_${iso}.docx`, periodDesc: `DIARIO (${iso})` });
  } catch (err) { console.error("[email] Error reporte diario:", err.message); }
}

async function sendWeeklyReport(getPoolFn, TBLS, to = null) {
  if (isSunday()) { console.log("[email] Reporte semanal omitido — domingo"); return; }
  try {
    const now = new Date(); const day = now.getDay(); const mon = new Date(now); mon.setDate(now.getDate() - (day === 0 ? 6 : day - 1)); const sun = new Date(mon); sun.setDate(mon.getDate() + 6);
    const desde = mon.toISOString().split("T")[0]; const hasta = sun.toISOString().split("T")[0];
    const pool = await getPoolFn();
    const result = await pool.request().input("desde", desde).input("hasta", hasta).query(`SELECT * FROM ${TBLS.llamadas} WHERE fecha >= @desde AND fecha <= @hasta ORDER BY horaInicio DESC`);
    const llamadas = result.recordset || [];
    const lD = mon.toLocaleDateString("es-CO", { day: "numeric", month: "short", timeZone: "America/Bogota" });
    const lH = sun.toLocaleDateString("es-CO", { day: "numeric", month: "short", timeZone: "America/Bogota" });
    await sendAiReport({ llamadas, to, title: `INFORME EJECUTIVO IA – MINUTO A MINUTO — SEMANAL ${lD} al ${lH}`, filename: `Informe_Semanal_${desde}_al_${hasta}.docx`, periodDesc: `SEMANAL del ${desde} al ${hasta}` });
  } catch (err) { console.error("[email] Error reporte semanal:", err.message); }
}

async function sendMonthlyReport(getPoolFn, TBLS, to = null) {
  if (isSunday()) { console.log("[email] Reporte mensual omitido — domingo"); return; }
  try {
    const now = new Date(); const mes = now.getMonth() + 1; const anio = now.getFullYear();
    const desde = `${anio}-${String(mes).padStart(2, "0")}-01`;
    const hasta = `${anio}-${String(mes).padStart(2, "0")}-${new Date(anio, mes, 0).getDate()}`;
    const pool = await getPoolFn();
    const result = await pool.request().input("desde", desde).input("hasta", hasta).query(`SELECT * FROM ${TBLS.llamadas} WHERE fecha >= @desde AND fecha <= @hasta ORDER BY horaInicio DESC`);
    const llamadas = result.recordset || [];
    const mesNombre = now.toLocaleDateString("es-CO", { month: "long", year: "numeric", timeZone: "America/Bogota" });
    const mesLabel = mesNombre.charAt(0).toUpperCase() + mesNombre.slice(1);
    await sendAiReport({ llamadas, to, title: `INFORME EJECUTIVO IA – MINUTO A MINUTO — ${mesLabel}`, filename: `Informe_Mensual_${desde}_al_${hasta}.docx`, periodDesc: `MENSUAL (${mesLabel})` });
  } catch (err) { console.error("[email] Error reporte mensual:", err.message); }
}

async function sendTestEmail(to = REPORT_TO) {
  const fakeLlamadas = Array.from({ length: 23 }, (_, i) => ({ nombreLider: ["Carlos Ruiz", "Mónica Pérez", "Jeiser Palomeque", "Camilo Sanchez", "Ana Torres"][i % 5], cargoLider: ["COACH", "KAM", "VENDEDOR", "COACH", "KAM"][i % 5], zona: ["Medellín", "Bogotá", "Chocó", "Barranquilla", "Cali"][i % 5], nombreContactado: "Cliente " + (i + 1), duracionMinutos: i % 4 === 0 ? 0 : Math.floor(Math.random() * 15) + 1, horaInicio: new Date(Date.now() - i * 1800000).toISOString(), fecha: new Date().toISOString().split("T")[0], rutaGrabacion: i % 3 === 0 ? "/audio/test.m4a" : null, transcripcionTexto: i % 5 === 0 ? "El cliente mostró interés en el producto de recaudo, solicitó visita para el próximo lunes y confirmó disponibilidad de pago." : null, cumplioMeta: i % 3 !== 0 }));
  const html = buildDailyReport({ date: new Date(), llamadas: fakeLlamadas });
  await sendReport({ to, subject: `🧪 PRUEBA — Reporte Diario Minuto a Minuto — ${dateLabel(new Date())}`, html });
}

// ═══════════════════════════════════════════════════════════════════════════════

const UPLOADS_DIR = path.join(process.cwd(), "uploads", "audio");
if (!fs.existsSync(path.dirname(UPLOADS_DIR))) {
  fs.mkdirSync(path.dirname(UPLOADS_DIR), { recursive: true });
}
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

const app = express();
const port = Number(process.env.PORT || 3005);

app.use(cors({
  exposedHeaders: ["Content-Range", "Accept-Ranges", "Content-Length"],
  allowedHeaders: ["Range", "Content-Type", "Authorization", "x-admin-key"]
}));
app.use(express.json({ limit: "30mb" }));
app.use("/audio", (req, res, next) => {
  const ext = path.extname(req.path).toLowerCase();
  const mimes = { ".m4a": "audio/mp4", ".mp4": "audio/mp4", ".wav": "audio/wav", ".mp3": "audio/mpeg", ".aac": "audio/aac", ".amr": "audio/amr" };
  if (mimes[ext]) res.setHeader("Content-Type", mimes[ext]);
  res.setHeader("Accept-Ranges", "bytes");
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Expose-Headers", "Content-Range, Accept-Ranges, Content-Length");
  next();
}, express.static(UPLOADS_DIR, { acceptRanges: true }));
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
  database: "minuto_a_minuto",
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

// Modelos Gemini: gemini-2.5-pro (principal), gemini-2.0-pro (fallback), gemini-1.5-pro (compatibilidad)
const geminiConfig = {
  modelPrimary: process.env.GEMINI_MODEL || "gemini-2.5-pro",
  modelFallback: process.env.GEMINI_FALLBACK_MODEL || "gemini-2.0-pro",
  modelLegacy: "gemini-1.5-pro", // Fallback adicional
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
  if (value === null || value === undefined) return fallback;
  const num = Number(value);
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

// app.get("/", (_req, res) => {
//   res.json({
//     success: true,
//     api: "api-node",
//     message: "API Node.js activa",
//     timestamp: new Date().toISOString(),
//   });
// });

app.get("/version", (_req, res) => {
  res.json({
    success: true,
    version: "8.0",
    buildDate: new Date().toISOString()
  });
});

app.get("/health", (_req, res) => {
  res.json({
    success: true,
    status: "ok",
    version: "8.0",
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
    const cargo = asString(req.query.cargo, "").toUpperCase().trim();
    const nombre = asString(req.query.nombre, "").trim();
    const page = Math.max(1, asInt(req.query.page, 1));
    const perPage = Math.min(500, Math.max(10, asInt(req.query.perPage, 200)));
    const offset = (page - 1) * perPage;

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
    const rows = result.recordset || [];

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

// ── SAP SYNC STREAM (SSE) ────────────────────────────────────────────────
// Usado por el panel web admin para sincronizar supervisores y vendedores desde SAP.
app.get("/sap/sync-users-stream", async (req, res) => {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
    "Access-Control-Allow-Origin": "*",
  });

  const send = (msg) => {
    res.write(`data: ${JSON.stringify({ msg })}\n\n`);
  };
  const end = () => {
    res.write(`event: end\ndata: done\n\n`);
    res.end();
  };

  const JEFE_EXCEPTIONS = ["camilo sanchez"];

  try {
    send("Conectando con SAP...");
    const sapPool = await getSapPool();
    const pool = await getPool();

    // 1. Coaches
    send("Leyendo coaches desde SAP...");
    const coachesRes = await sapPool.request().query(`
      SELECT DISTINCT T.[Code] AS code, T.[Name] AS nombre
      FROM [dbo].[@COACH] T
      INNER JOIN OCRD C ON C.[U_COACH] = T.[Code]
      WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
    `);
    const coaches = coachesRes.recordset || [];
    send("  " + coaches.length + " coaches encontrados");

    for (const c of coaches) {
      const id = crypto.randomUUID();
      await pool.request()
        .input("id", id)
        .input("nombre", c.nombre)
        .input("codigo", String(c.code))
        .input("zona", "CENTRO")
        .input("cargo", "COACH")
        .query(`
          IF NOT EXISTS (SELECT 1 FROM supervisores WHERE nombre = @nombre AND cargo = 'COACH')
            INSERT INTO supervisores (id, nombre, codigo, zona, cargo, fechaCreacion)
            VALUES (@id, @nombre, @codigo, @zona, @cargo, GETDATE())
        `);
    }
    send("  Coaches sincronizados OK");

    // 2. KAMs
    send("Leyendo KAMs desde SAP...");
    const kamsRes = await sapPool.request().query(`
      SELECT DISTINCT T.[Code] AS code, T.[Name] AS nombre
      FROM [dbo].[@SKY_NEGOCIADOR] T
      INNER JOIN OCRD C ON C.[U_NEGOCIADOR] = T.[Code]
      WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
    `);
    const kams = kamsRes.recordset || [];
    send("  " + kams.length + " KAMs encontrados");

    for (const k of kams) {
      const id = crypto.randomUUID();
      await pool.request()
        .input("id", id)
        .input("nombre", k.nombre)
        .input("codigo", String(k.code))
        .input("zona", "CENTRO")
        .input("cargo", "KAM")
        .query(`
          IF NOT EXISTS (SELECT 1 FROM supervisores WHERE nombre = @nombre AND cargo = 'KAM')
            INSERT INTO supervisores (id, nombre, codigo, zona, cargo, fechaCreacion)
            VALUES (@id, @nombre, @codigo, @zona, @cargo, GETDATE())
        `);
    }
    send("  KAMs sincronizados OK");

    // 3. Vendedores
    send("Leyendo vendedores desde SAP...");
    const vendsRes = await sapPool.request().query(`
      SELECT DISTINCT
        T1.[SlpCode] AS code,
        T1.[SlpName] AS nombre,
        T2.[Name] AS coach
      FROM OCRD T0
      INNER JOIN OSLP T1 ON T0.[SlpCode] = T1.[SlpCode]
      INNER JOIN [dbo].[@COACH] T2 ON T0.[U_COACH] = T2.[Code]
      WHERE T0.[validFor] = 'Y'
    `);
    const vends = vendsRes.recordset || [];
    send("  " + vends.length + " vendedores encontrados");

    let vendCount = 0;
    let jefeCount = 0;
    for (const v of vends) {
      const nombreLower = (v.nombre || "").toLowerCase();
      const isJefe = JEFE_EXCEPTIONS.some(j => nombreLower.includes(j));

      if (isJefe) {
        const id = crypto.randomUUID();
        await pool.request()
          .input("id", id)
          .input("nombre", v.nombre)
          .input("codigo", String(v.code))
          .input("zona", "CENTRO")
          .input("cargo", "JEFE")
          .query(`
            IF NOT EXISTS (SELECT 1 FROM supervisores WHERE nombre LIKE '%' + @nombre + '%')
              INSERT INTO supervisores (id, nombre, codigo, zona, cargo, fechaCreacion)
              VALUES (@id, @nombre, @codigo, @zona, @cargo, GETDATE())
          `);
        jefeCount++;
        continue;
      }

      let coachId = null;
      if (v.coach) {
        const coachRow = await pool.request()
          .input("coachName", v.coach)
          .query("SELECT TOP 1 id FROM supervisores WHERE nombre = @coachName");
        if (coachRow.recordset.length > 0) coachId = coachRow.recordset[0].id;
      }

      const id = crypto.randomUUID();
      await pool.request()
        .input("id", id)
        .input("nombre", v.nombre)
        .input("codigo", String(v.code))
        .input("zona", "CENTRO")
        .input("coachId", coachId)
        .query(`
          IF NOT EXISTS (SELECT 1 FROM vendedores WHERE nombre = @nombre)
            INSERT INTO vendedores (id, nombre, codigo, zona, coachId, fechaCreacion)
            VALUES (@id, @nombre, @codigo, @zona, @coachId, GETDATE())
        `);
      vendCount++;
    }
    send("  " + vendCount + " vendedores sincronizados, " + jefeCount + " jefes registrados");

    send("Sincronizacion completada exitosamente.");
    end();
  } catch (err) {
    console.error("[/sap/sync-users-stream] ERROR:", err.message);
    send("ERROR: " + err.message);
    end();
  }
});

// GET /sap/sync-users → alias que ejecuta el sync síncrono. Siempre devuelve 200
// para que Nginx no intercepte el error y el cliente pueda leer el mensaje.
app.get(["/sap/sync-users", "/sap-sync"], async (req, res) => {
  try {
    const result = await fullUserSyncCore();
    return res.json({ success: true, ...result });
  } catch (err) {
    console.error("[sap/sync-users] ERROR:", err.message);
    return res.json({ success: false, error: err.message }); // 200 para pasar Nginx
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

/**
 * GET /cartera/equipo-jerarquico
 * Devuelve la jerarquía completa: KAM → COACH → Vendedores
 * con el conteo de llamadas de hoy por vendedor.
 * Usado por BloqueEquipoJerarquico en el Dashboard.
 */
// La implementación de /cartera/equipo-jerarquico se encuentra más abajo (consolidada)

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
    const b = req.body;
    const sets = [];
    if (b.nombre !== undefined) sets.push({ col: "nombre", val: b.nombre });
    if (b.cargo !== undefined) sets.push({ col: "cargo", val: b.cargo });
    if (b.alias !== undefined) sets.push({ col: "alias", val: b.alias });
    if (b.codigo !== undefined) sets.push({ col: "codigo", val: b.codigo });
    if (b.zona !== undefined) sets.push({ col: "zona", val: b.zona });
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos para actualizar" });
    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    await runExecute(`UPDATE ${TABLES.supervisores} SET ${setParts.join(",")} WHERE id=@id`, (r) => {
      r.input("id", id);
      sets.forEach((s, i) => r.input(`v${i}`, s.val));
    });
    return res.json({ success: true, message: "Supervisor actualizado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /admin/supervisores/:id — eliminar supervisor
app.delete("/admin/supervisores/:id", requireAdmin, async (req, res) => {
  try {
    await runExecute(`DELETE FROM ${TABLES.supervisores} WHERE id=@id`, (r) => r.input("id", req.params.id));
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
    if (b.nombre !== undefined) sets.push({ col: "nombre", val: b.nombre });
    if (b.alias !== undefined) sets.push({ col: "alias", val: b.alias });
    if (b.codigo !== undefined) sets.push({ col: "codigo", val: b.codigo });
    if (b.zona !== undefined) sets.push({ col: "zona", val: b.zona });
    if (b.telefono !== undefined) sets.push({ col: "telefono", val: b.telefono });
    if (b.coachId !== undefined) sets.push({ col: "coachId", val: b.coachId });
    if (!sets.length) return res.status(400).json({ success: false, error: "No hay campos para actualizar" });
    const setParts = sets.map((s, i) => `${s.col}=@v${i}`);
    await runExecute(`UPDATE ${TABLES.vendedores} SET ${setParts.join(",")} WHERE id=@id`, (r) => {
      r.input("id", id);
      sets.forEach((s, i) => r.input(`v${i}`, s.val));
    });
    return res.json({ success: true, message: "Vendedor actualizado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /admin/vendedores/:id — eliminar vendedor
app.delete("/admin/vendedores/:id", requireAdmin, async (req, res) => {
  try {
    await runExecute(`DELETE FROM ${TABLES.vendedores} WHERE id=@id`, (r) => r.input("id", req.params.id));
    return res.json({ success: true, message: "Vendedor eliminado" });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /supervisores/:id y /vendedores/:id — implementados más abajo (usan getPool correctamente)

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
async function fullUserSyncCore({ send = () => { } } = {}) {
  const sapPool = await getSapPool();
  const localPool = await getPool();

  send("🚀 Iniciando conexión con SAP y DB Local...", "start");

  // Nombres que SAP trae como vendedor (OSLP) pero son JEFE DE VENTAS
  const JEFE_EXCEPTIONS = [
    'camilo sanchez',
    'camilo sánchez',
    'camilo s nchez',
  ];

  // 1. Traer Coaches de SAP (ciudad más frecuente por GROUP BY)
  send("🔍 Consultando Coaches en SAP...");
  const coachesSap = await sapPool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre, T.[Code] AS codigo,
           (
             SELECT TOP 1 C2.[City]
             FROM OCRD C2
             WHERE C2.[U_COACH] = T.[Code] AND C2.[validFor]='Y'
               AND C2.[City] IS NOT NULL AND C2.[City] <> ''
             GROUP BY C2.[City]
             ORDER BY COUNT(*) DESC
           ) AS zona
    FROM [dbo].[@COACH] T
    INNER JOIN OCRD C ON C.[U_COACH] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
  `);

  // 2. Traer KAMs de SAP (ciudad más frecuente por GROUP BY)
  send("🔍 Consultando KAMs en SAP...");
  const kamsSap = await sapPool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre, T.[Code] AS codigo,
           (
             SELECT TOP 1 C2.[City]
             FROM OCRD C2
             WHERE C2.[U_NEGOCIADOR] = T.[Code] AND C2.[validFor]='Y'
               AND C2.[City] IS NOT NULL AND C2.[City] <> ''
             GROUP BY C2.[City]
             ORDER BY COUNT(*) DESC
           ) AS zona
    FROM [dbo].[@SKY_NEGOCIADOR] T
    INNER JOIN OCRD C ON C.[U_NEGOCIADOR] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
  `);

  // 3. Traer Vendedores de SAP con ciudad más frecuente (GROUP BY)
  send("🔍 Consultando Vendedores en SAP...");
  const vendorsSap = await sapPool.request().query(`
    SELECT DISTINCT
           T1.[SlpName] AS nombre,
           T1.[SlpCode] AS codigo,
           (
             SELECT TOP 1 [City]
             FROM OCRD
             WHERE [SlpCode] = T1.[SlpCode] AND [validFor]='Y'
               AND [City] IS NOT NULL AND [City] <> ''
             GROUP BY [City]
             ORDER BY COUNT(*) DESC
           ) AS zona
    FROM OSLP T1
    INNER JOIN OCRD T0 ON T0.[SlpCode] = T1.[SlpCode]
    WHERE T0.[validFor] = 'Y' AND T1.[SlpName] IS NOT NULL AND T1.[SlpName] <> ''
  `);

  // Separar Jefes de Ventas de vendedores normales
  const jefesSap = vendorsSap.recordset.filter(
    v => JEFE_EXCEPTIONS.includes((v.nombre || '').toLowerCase().trim())
  );
  const vendedoresSap = vendorsSap.recordset.filter(
    v => !JEFE_EXCEPTIONS.includes((v.nombre || '').toLowerCase().trim())
  );

  send(`📦 Encontrados: ${coachesSap.recordset.length} Coaches, ${kamsSap.recordset.length} KAMs, ${jefesSap.length} Jefes, ${vendedoresSap.length} Vendedores.`);

  // Limpiar registros de Jefes mal ubicados en la tabla vendedores
  for (const jefe of jefesSap) {
    try {
      const del = await localPool.request()
        .input("nom", jefe.nombre)
        .query("DELETE FROM vendedores WHERE LOWER(nombre) = LOWER(@nom)");
      if (del.rowsAffected[0] > 0) {
        send(`🔄 Reclasificado: '${jefe.nombre}' eliminado de vendedores → será insertado como JEFE.`, "update");
      }
    } catch (e) {
      send(`⚠️ Error limpiando vendedores para ${jefe.nombre}: ${e.message}`);
    }
  }

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

  // Combinar Supervisores (Coaches, KAMs y Jefes de Ventas)
  const allSups = [
    ...coachesSap.recordset.map(s => ({ ...s, cargo: 'COACH' })),
    ...kamsSap.recordset.map(s => ({ ...s, cargo: 'KAM' })),
    ...jefesSap.map(s => ({ ...s, cargo: 'JEFE' }))
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

  // Sync Vendedores (excluye jefes)
  for (const v of vendedoresSap) {
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
    if (cid && kid) await localPool.request().input("c", cid).input("k", kid).query("UPDATE supervisores SET superiorId=@k WHERE id=@c");
  }

  send("🔗 Vinculando Vendedores -> Coach...");
  const relVC = await sapPool.request().query("SELECT DISTINCT SlpCode, U_COACH FROM OCRD WHERE ([validFor]='Y' AND SlpCode IS NOT NULL AND U_COACH IS NOT NULL)");
  for (const r of relVC.recordset) {
    const cid = sapCodeToId[r.U_COACH.toString()];
    if (cid) await localPool.request().input("sc", r.SlpCode.toString()).input("ci", cid).query("UPDATE vendedores SET coachId=@ci WHERE sapCode=@sc");
  }

  return { creados, actualizados };
}

/**
 * GET /sap/sync-users
 */
// Sincronización finalizada (reemplazada por alias arriba)

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

app.get("/supervisores", async (req, res) => {
  // SAP sync vía query param (evita rutas nuevas que Nginx bloquea)
  if (req.query._sync === "sap") {
    try {
      const result = await fullUserSyncCore();
      return res.json({ success: true, ...result });
    } catch (err) {
      console.error("[supervisores?_sync=sap] ERROR:", err.message);
      return res.json({ success: false, error: err.message });
    }
  }
  // Audio streaming vía query param (evita /audio/:file bloqueado por Nginx)
  if (req.query._audioId) {
    const llamadaId = asString(req.query._audioId, "");
    if (!llamadaId || !SAFE_ID.test(llamadaId)) return res.status(400).end();
    try {
      const row = await runQueryOne(
        `SELECT rutaGrabacion, rutaGrabacionPuntoB FROM ${TABLES.llamadas} WHERE id = @id`,
        (r) => r.input("id", llamadaId)
      );
      const isPuntoB = req.query._b === "1";
      const ruta = isPuntoB ? row?.rutaGrabacionPuntoB : row?.rutaGrabacion;
      if (!ruta) return res.status(404).end();
      const filename = path.basename(ruta);
      const filepath = path.join(UPLOADS_DIR, filename);
      if (!fs.existsSync(filepath)) return res.status(404).end();
      const ext = path.extname(filename).toLowerCase();
      const mimes = { ".m4a": "audio/mp4", ".mp4": "audio/mp4", ".wav": "audio/wav", ".mp3": "audio/mpeg", ".aac": "audio/aac" };
      res.setHeader("Content-Type", mimes[ext] || "audio/mp4");
      res.setHeader("Accept-Ranges", "bytes");
      res.setHeader("Access-Control-Allow-Origin", "*");
      return res.sendFile(filepath);
    } catch (err) {
      return res.status(500).end();
    }
  }
  try {
    const result = await runQuery(`SELECT * FROM ${TABLES.supervisores} ORDER BY nombre`);
    return res.json(normalizeRowsForJson(result.recordset));
  } catch (error) {
    return res.json({ success: false, error: error.message });
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

async function updateUsuarioCampos(tabla, id, body, allowedFields) {
  const ALLOWED = new Set(allowedFields);
  const updates = {};
  for (const [k, v] of Object.entries(body)) {
    if (ALLOWED.has(k) && SAFE_COLUMN_NAME.test(k)) updates[k] = asString(v, "");
  }
  if (Object.keys(updates).length === 0) throw new Error("No hay campos validos para actualizar");
  const setClause = Object.keys(updates).map((col) => `[${col}] = @${col}`).join(", ");
  await runExecute(
    `UPDATE ${tabla} SET ${setClause} WHERE id = @id`,
    (request) => {
      request.input("id", id);
      for (const [k, v] of Object.entries(updates)) request.input(k, v);
    }
  );
  return Object.keys(updates);
}

// Actualizar campos de un supervisor — PATCH y POST alias (Nginx bloquea PATCH)
async function handleUpdateSupervisor(req, res) {
  try {
    const id = asString(req.params.id, "");
    if (!id) return res.status(400).json({ success: false, error: "id requerido" });
    const updated = await updateUsuarioCampos(TABLES.supervisores, id, req.body || {}, ["telefono", "nombre", "zona", "cargo"]);
    return res.json({ success: true, id, updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
}
app.patch("/supervisores/:id", handleUpdateSupervisor);
app.post(["/supervisores/:id/update", "/supervisores-update/:id"], handleUpdateSupervisor);

// Actualizar campos de un vendedor — PATCH y POST alias (Nginx bloquea PATCH)
async function handleUpdateVendedor(req, res) {
  try {
    const id = asString(req.params.id, "");
    if (!id) return res.status(400).json({ success: false, error: "id requerido" });
    const updated = await updateUsuarioCampos(TABLES.vendedores, id, req.body || {}, ["telefono", "nombre", "zona"]);
    return res.json({ success: true, id, updated });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
}
app.patch("/vendedores/:id", handleUpdateVendedor);
app.post(["/vendedores/:id/update", "/vendedores-update/:id"], handleUpdateVendedor);

app.get("/llamadas", async (req, res) => {
  try {
    // Audio streaming vía query param (ruta compatible con Nginx)
    if (req.query._audioId) {
      const llamadaId = asString(req.query._audioId, "");
      if (!llamadaId || !SAFE_ID.test(llamadaId)) return res.status(400).end();
      const mimeMap = { "m4a": "audio/mp4", "mp4": "audio/mp4", "wav": "audio/wav", "amr": "audio/amr", "mp3": "audio/mpeg", "aac": "audio/aac" };
      const exts = ["m4a", "mp4", "wav", "amr", "mp3", "aac"];
      const isPuntoB = req.query._b === "1";
      const suffixes = isPuntoB ? ["_b", "_punto_b", ""] : ["", "_b", "_punto_b"];
      for (const suffix of suffixes) {
        for (const ext of exts) {
          const p = path.join(UPLOADS_DIR, `${llamadaId}${suffix}.${ext}`);
          if (fs.existsSync(p)) return serveAudioStream(req, res, p, mimeMap[ext] || "audio/mp4");
        }
      }
      const row = await runQueryOne(
        `SELECT rutaGrabacion, rutaGrabacionPuntoB FROM ${TABLES.llamadas} WHERE id = @id`,
        (r) => r.input("id", llamadaId)
      );
      if (row) {
        const ruta = isPuntoB ? (row.rutaGrabacionPuntoB || row.rutaGrabacion) : (row.rutaGrabacion || row.rutaGrabacionPuntoB);
        if (ruta && ruta.startsWith("/audio/")) {
          const p = path.join(UPLOADS_DIR, ruta.replace("/audio/", ""));
          if (fs.existsSync(p)) {
            const ext = p.split(".").pop().toLowerCase();
            return serveAudioStream(req, res, p, mimeMap[ext] || "audio/mp4");
          }
        }
      }
      return res.status(404).end();
    }

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

    // Guardar ubicación vía _action (POST /llamadas no está bloqueado por Nginx)
    if (body._action === "ubicacion") {
      return _handleUbicacion(body.vendedorId || body.v, body.latitud || body.lat, body.longitud || body.lng, body.fecha || body.f, body.nombre || body.n, body.cargo || body.c, res);
    }

    // Audio upload vía _action (evita rutas nuevas bloqueadas por Nginx)
    if (body._action === "uploadAudio" || body._action === "uploadAudioB") {
      const regId = asString(body.id, "");
      if (!regId || !SAFE_ID.test(regId)) return res.json({ success: false, error: "id inválido" });
      const audioBase64 = asString(body.audioBase64, "");
      const mimeType = asString(body.mimeType, "audio/mp4");
      if (!audioBase64) return res.json({ success: false, error: "audioBase64 requerido" });
      const ext = mimeType.includes("wav") ? "wav" : mimeType.includes("amr") ? "amr" : mimeType.includes("mp3") ? "mp3" : "m4a";
      const filename = body._action === "uploadAudioB" ? `${regId}_b.${ext}` : `${regId}.${ext}`;
      const filepath = path.join(UPLOADS_DIR, filename);
      let buf;
      try { buf = Buffer.from(audioBase64, "base64"); } catch (_) { return res.json({ success: false, error: "audioBase64 inválido" }); }
      if (buf.length > 30 * 1024 * 1024) return res.json({ success: false, error: "Audio supera 30MB" });
      await fs.promises.writeFile(filepath, buf);
      const rutaRelativa = `/audio/${filename}`;
      const dbCol = body._action === "uploadAudioB" ? "rutaGrabacionPuntoB" : "rutaGrabacion";
      await runExecute(
        `UPDATE ${TABLES.llamadas} SET [${dbCol}] = @path WHERE id = @id`,
        (r) => { r.input("path", rutaRelativa); r.input("id", regId); }
      );
      return res.json({ success: true, id: regId, rutaGrabacion: rutaRelativa, audioUrl: rutaRelativa });
    }

    const id = asString(body.id, "") || makeId("llamada");
    const numeroPropietario = asNullableString(body.numeroPropietario);
    const numeroContacto = asNullableString(body.numeroContacto);
    const horaInicio = asString(body.horaInicio, "");
    const fechaStr = asString(body.fecha, "").split("T")[0];

    // Validación mínima
    if (!fechaStr || !asString(body.horaInicio, "") || !asString(body.horaFin, "")) {
      return res.json({
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
            const mergeId = list[0].id;
            // Patch missing fields onto the merged record from Point B data
            try {
              const patchParts = [];
              const patchInputs = {};
              if (body.latitud != null && body.latitud !== 0) {
                patchParts.push("[latitud] = CASE WHEN [latitud] IS NULL OR [latitud] = 0 THEN @pLat ELSE [latitud] END");
                patchInputs.pLat = asDouble(body.latitud, 0);
              }
              if (body.longitud != null && body.longitud !== 0) {
                patchParts.push("[longitud] = CASE WHEN [longitud] IS NULL OR [longitud] = 0 THEN @pLng ELSE [longitud] END");
                patchInputs.pLng = asDouble(body.longitud, 0);
              }
              if (body.transcripcionTexto) {
                patchParts.push("[transcripcionTexto] = CASE WHEN [transcripcionTexto] IS NULL OR [transcripcionTexto] = '' THEN @pTxt ELSE [transcripcionTexto] END");
                patchInputs.pTxt = body.transcripcionTexto;
              }
              if (patchParts.length > 0) {
                await runExecute(
                  `UPDATE ${TABLES.llamadas} SET ${patchParts.join(", ")} WHERE id = @mid`,
                  (request) => {
                    request.input("mid", mergeId);
                    for (const [k, v] of Object.entries(patchInputs)) request.input(k, v);
                  }
                );
              }
            } catch (patchErr) {
              console.warn('[POST /llamadas] Error patching merge target:', patchErr.message);
            }
            return res.json({
              success: true,
              mergeTarget: mergeId,
              id: mergeId,
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
      tipoLlamada: asString(body.tipoLlamada, "") || (() => { const h = new Date().getHours(); return h >= 6 && h < 12 ? "manana" : h >= 12 && h < 18 ? "tarde" : "noche"; })(),
      cargoLider: asString(body.cargoLider, "coach") || "coach",
      zona: asString(body.zona, "N/A") || "N/A",
      nombreLider: asString(body.nombreLider, "Auto") || "Auto",
      nombreContactado: asString(body.nombreContactado, "Desconocido") || "Desconocido",
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
    // Forzar inclusión de geolocalización si viene en el body
    if (body.latitud !== undefined && body.latitud !== null) {
      rawPayload.latitud = asDouble(body.latitud, null);
    }
    if (body.longitud !== undefined && body.longitud !== null) {
      rawPayload.longitud = asDouble(body.longitud, null);
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
app.post(["/llamadas/:id/audio", "/upload-audio/:id"], async (req, res) => {
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
    await fs.promises.writeFile(filepath, buf);
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
// Helper: streaming con soporte completo de Range Requests (HTTP 206) — necesario para seek en Chrome/Android
function serveAudioStream(req, res, filePath, mimeType) {
  let stat;
  try { stat = fs.statSync(filePath); } catch (_) { return res.status(404).send("Archivo no encontrado"); }
  const fileSize = stat.size;
  const baseHeaders = {
    "Content-Type": mimeType,
    "Accept-Ranges": "bytes",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Expose-Headers": "Content-Range, Accept-Ranges, Content-Length",
    "Cache-Control": "no-cache",
  };
  const range = req.headers.range;
  if (range) {
    const parts = range.replace(/bytes=/, "").split("-");
    const start = parseInt(parts[0], 10);
    const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
    if (isNaN(start) || start >= fileSize) {
      res.writeHead(416, { "Content-Range": `bytes */${fileSize}` });
      return res.end();
    }
    const safeEnd = Math.min(end, fileSize - 1);
    const chunkSize = safeEnd - start + 1;
    res.writeHead(206, { ...baseHeaders, "Content-Length": chunkSize, "Content-Range": `bytes ${start}-${safeEnd}/${fileSize}` });
    fs.createReadStream(filePath, { start, end: safeEnd }).pipe(res);
  } else {
    res.writeHead(200, { ...baseHeaders, "Content-Length": fileSize });
    fs.createReadStream(filePath).pipe(res);
  }
}

// Obtener audio por ID — resuelve extensiones, punto B, y sirve con HTTP 206 para seek correcto
app.get("/audio-play/:id", async (req, res) => {
  try {
    const id = asString(req.params.id, "");
    if (!id || !SAFE_ID.test(id)) return res.status(400).send("ID inválido");

    const mimeMap = { "m4a": "audio/mp4", "mp4": "audio/mp4", "wav": "audio/wav", "amr": "audio/amr", "mp3": "audio/mpeg", "aac": "audio/aac" };
    const exts = ["m4a", "mp4", "wav", "amr", "mp3", "aac"];

    // Buscar archivo por variantes de nombre (principal, punto B, punto_b)
    for (const suffix of ["", "_b", "_punto_b"]) {
      for (const ext of exts) {
        const p = path.join(UPLOADS_DIR, `${id}${suffix}.${ext}`);
        if (fs.existsSync(p)) return serveAudioStream(req, res, p, mimeMap[ext] || "audio/mpeg");
      }
    }

    // Fallback: buscar ruta guardada en DB
    const row = await runQueryOne(
      `SELECT rutaGrabacion, rutaGrabacionPuntoB FROM ${TABLES.llamadas} WHERE id = @id`,
      (request) => { request.input("id", id); }
    );
    if (row) {
      for (const ruta of [row.rutaGrabacion, row.rutaGrabacionPuntoB]) {
        if (ruta && ruta.startsWith("/audio/")) {
          const p = path.join(UPLOADS_DIR, ruta.replace("/audio/", ""));
          if (fs.existsSync(p)) {
            const ext = p.split(".").pop().toLowerCase();
            return serveAudioStream(req, res, p, mimeMap[ext] || "audio/mpeg");
          }
        }
      }
    }

    return res.status(404).send("Archivo no encontrado");
  } catch (error) {
    return res.status(500).send(error.message);
  }
});

app.post(["/llamadas/:id/audio-punto-b", "/upload-audio-b/:id"], async (req, res) => {
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
    await fs.promises.writeFile(filepath, buf);
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

// Ruta plana para subir audio principal — el ID va en el body (evita sub-paths que Nginx puede bloquear)
app.post("/subirllamadaaudio", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "");
    if (!id || !SAFE_ID.test(id)) return res.json({ success: false, error: "id inválido" });
    const audioBase64 = asString(body.audioBase64, "");
    const mimeType = asString(body.mimeType, "audio/mp4");
    if (!audioBase64) return res.json({ success: false, error: "audioBase64 requerido" });
    const ext = mimeType.includes("wav") ? "wav" : mimeType.includes("amr") ? "amr" : mimeType.includes("mp3") ? "mp3" : "m4a";
    const filepath = path.join(UPLOADS_DIR, `${id}.${ext}`);
    let buf;
    try { buf = Buffer.from(audioBase64, "base64"); } catch (_) { return res.json({ success: false, error: "audioBase64 inválido" }); }
    if (buf.length > 30 * 1024 * 1024) return res.json({ success: false, error: "Audio supera 30MB" });
    await fs.promises.writeFile(filepath, buf);
    const rutaRelativa = `/audio/${id}.${ext}`;
    await runExecute(`UPDATE ${TABLES.llamadas} SET rutaGrabacion = @path WHERE id = @id`, (r) => { r.input("path", rutaRelativa); r.input("id", id); });
    return res.json({ success: true, id, rutaGrabacion: rutaRelativa, audioUrl: rutaRelativa });
  } catch (err) {
    return res.json({ success: false, error: err.message });
  }
});

// Ruta plana para subir audio punto B
app.post("/subirllamadaaudiob", async (req, res) => {
  try {
    const body = req.body || {};
    const id = asString(body.id, "");
    if (!id || !SAFE_ID.test(id)) return res.json({ success: false, error: "id inválido" });
    const audioBase64 = asString(body.audioBase64, "");
    const mimeType = asString(body.mimeType, "audio/mp4");
    if (!audioBase64) return res.json({ success: false, error: "audioBase64 requerido" });
    const ext = mimeType.includes("wav") ? "wav" : mimeType.includes("amr") ? "amr" : mimeType.includes("mp3") ? "mp3" : "m4a";
    const filename = `${id}_b.${ext}`;
    const filepath = path.join(UPLOADS_DIR, filename);
    let buf;
    try { buf = Buffer.from(audioBase64, "base64"); } catch (_) { return res.json({ success: false, error: "audioBase64 inválido" }); }
    if (buf.length > 30 * 1024 * 1024) return res.json({ success: false, error: "Audio supera 30MB" });
    await fs.promises.writeFile(filepath, buf);
    const rutaRelativa = `/audio/${filename}`;
    await runExecute(`UPDATE ${TABLES.llamadas} SET rutaGrabacionPuntoB = @path WHERE id = @id`, (r) => { r.input("path", rutaRelativa); r.input("id", id); });
    return res.json({ success: true, id, rutaGrabacionPuntoB: rutaRelativa, audioUrl: rutaRelativa });
  } catch (err) {
    return res.json({ success: false, error: err.message });
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
    if (Object.prototype.hasOwnProperty.call(body, "cumplioMeta")) {
      updates.cumplioMeta = asInt(body.cumplioMeta, 0);
    }
    if (Object.prototype.hasOwnProperty.call(body, "coincidenciaPpvcRvc")) {
      updates.coincidenciaPpvcRvc = asInt(body.coincidenciaPpvcRvc, 0);
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
    const fecha = asNullableString(req.query.fecha);
    const supervisorId = asNullableString(req.query.supervisorId);
    const conditions = [];
    if (fecha) {
      conditions.push("fecha = @fecha");
    } else {
      const resuelta = asInt(req.query.resuelta, 0);
      conditions.push("resuelta = @resuelta");
    }
    if (supervisorId) conditions.push("supervisorId = @supervisorId");
    const sqlText = `SELECT * FROM ${TABLES.alertas} WHERE ${conditions.join(" AND ")} ORDER BY fecha DESC`;
    const result = await runQuery(sqlText, (request) => {
      if (fecha) request.input("fecha", fecha);
      else request.input("resuelta", asInt(req.query.resuelta, 0));
      if (supervisorId) request.input("supervisorId", supervisorId);
    });
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

// Retorna la ubicación más reciente de cada usuario (últimas 2 horas)
app.get("/ubicaciones/live", async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(`
      SELECT
        u.id, u.vendedorId, u.latitud, u.longitud, u.timestamp, u.fecha,
        COALESCE(s.nombre, v.nombre, u.nombre, u.vendedorId) AS nombre,
        COALESCE(s.cargo, u.cargo, 'VENDEDOR') AS cargo
      FROM ${TABLES.ubicaciones} u
      INNER JOIN (
        SELECT vendedorId, MAX([timestamp]) AS maxTs
        FROM ${TABLES.ubicaciones}
        WHERE TRY_CONVERT(DATETIME2, [timestamp], 127) >= DATEADD(HOUR, -2, GETUTCDATE())
          AND latitud IS NOT NULL AND latitud <> 0
          AND longitud IS NOT NULL AND longitud <> 0
        GROUP BY vendedorId
      ) latest ON u.vendedorId = latest.vendedorId AND u.[timestamp] = latest.maxTs
      LEFT JOIN ${TABLES.supervisores} s ON s.id = u.vendedorId
      LEFT JOIN ${TABLES.vendedores}   v ON v.id = u.vendedorId
      ORDER BY u.[timestamp] DESC
    `);
    return res.json(result.recordset || []);
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
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
      nombre: asString(body.nombre, ""),
      cargo: asString(body.cargo, ""),
    };
    const mode = await upsertById(TABLES.ubicaciones, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
});

// Fallback GET — para cuando Nginx bloquea POST (WAF restriction)
async function _handleUbicacion(vendedorId, latitud, longitud, fecha, nombre, cargo, res) {
  try {
    if (!vendedorId) return res.status(400).json({ success: false, error: "vendedorId requerido" });
    const id = `loc_${vendedorId}`;
    const payload = {
      vendedorId,
      fecha: fecha || todayIsoDate(),
      latitud: parseFloat(latitud) || 0,
      longitud: parseFloat(longitud) || 0,
      timestamp: new Date().toISOString(),
      nombre: nombre || "",
      cargo: cargo || "",
    };
    const mode = await upsertById(TABLES.ubicaciones, id, payload);
    return res.json({ success: true, id, mode });
  } catch (error) {
    return res.status(400).json({ success: false, error: error.message });
  }
}

app.get("/ubicaciones", async (req, res) => {
  if (!req.query.v && !req.query.vendedorId) {
    return res.status(400).json({ success: false, error: "Usa /ubicaciones/live para consultar" });
  }
  const q = req.query;
  return _handleUbicacion(q.vendedorId || q.v, q.latitud || q.lat, q.longitud || q.lng, q.fecha || q.f, q.nombre || q.n, q.cargo || q.c, res);
});

// ── ENDPOINT: gestionar destinatarios de correo ──────────────────────────────
app.get("/reports/recipients", (_req, res) => {
  return res.json({ recipients: loadRecipients() });
});

app.post("/reports/recipients", (req, res) => {
  try {
    const { recipients } = req.body || {};
    if (!Array.isArray(recipients) || recipients.length === 0) {
      return res.status(400).json({ success: false, error: "recipients debe ser un array con al menos un correo" });
    }
    const valid = recipients.filter(r => typeof r === "string" && r.includes("@"));
    if (valid.length === 0) return res.status(400).json({ success: false, error: "Ningún correo válido" });
    saveRecipients(valid);
    return res.json({ success: true, recipients: valid });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── ENDPOINT: recibir DOCX y enviarlo por correo ─────────────────────────────
app.post("/reports/send-docx", async (req, res) => {
  try {
    const { filename, base64, title, desde, hasta } = req.body || {};
    if (!base64 || !filename) return res.status(400).json({ success: false, error: "Faltan datos" });
    const to = getRecipientsString();
    const periodo = desde && hasta && desde !== hasta ? `del ${desde} al ${hasta}` : (desde || "hoy");
    await transporter.sendMail({
      from: `"Minuto a Minuto 📞" <${GMAIL_USER}>`,
      to,
      subject: `📄 ${title || filename.replace(".docx", "")} — ${periodo}`,
      html: baseTemplate({
        title: title || filename.replace(".docx", ""),
        subtitle: `Período: ${periodo}`,
        badge: "INFORME IA",
        body: `<p style="color:${BRAND.text2};margin:0 0 16px;">Se adjunta el informe ejecutivo generado con Inteligencia Artificial: <strong style="color:${BRAND.text};">${filename}</strong></p>
               <p style="color:${BRAND.text2};font-size:12px;">Sistema de Seguimiento Comercial — Minuto a Minuto</p>`,
      }),
      attachments: [{ filename, content: Buffer.from(base64, "base64"), contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }],
    });
    return res.json({ success: true, to, filename });
  } catch (err) {
    console.error("[reports/send-docx]", err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── ENDPOINT: enviar reporte de prueba ────────────────────────────────────────
app.get("/reports/test", async (req, res) => {
  try {
    const to = asString(req.query.to, REPORT_TO);
    const type = asString(req.query.type, "daily");
    if (type === "weekly") {
      await sendWeeklyReport(getPool, TABLES, to);
    } else if (type === "monthly") {
      await sendMonthlyReport(getPool, TABLES, to);
    } else if (type === "test") {
      await sendTestEmail(to);
    } else {
      await sendDailyReport(getPool, TABLES, to);
    }
    return res.json({ success: true, message: `Reporte '${type}' enviado a ${to}` });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
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
      "POST /ubicaciones",
      "GET /ubicaciones/live",
      "GET /reports/recipients",
      "POST /reports/recipients",
      "POST /reports/send-docx",
      "GET /reports/test",
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

    // 0. Crear tablas base si no existen (supervisores, vendedores, alertas)
    await pool.request().query(`
      IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'supervisores')
      CREATE TABLE [supervisores] (
        [id]          NVARCHAR(200) NOT NULL PRIMARY KEY,
        [nombre]      NVARCHAR(300) NOT NULL,
        [cargo]       NVARCHAR(100) NOT NULL DEFAULT 'COACH',
        [ciudad]      NVARCHAR(200) NULL,
        [alias]       NVARCHAR(100) NULL,
        [zona]        NVARCHAR(200) NULL,
        [sapCode]     NVARCHAR(100) NULL,
        [codigo]      NVARCHAR(100) NULL,
        [superiorId]  NVARCHAR(200) NULL
      )
    `);
    console.log("[migration] tabla supervisores OK");

    await pool.request().query(`
      IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'vendedores')
      CREATE TABLE [vendedores] (
        [id]          NVARCHAR(200) NOT NULL PRIMARY KEY,
        [nombre]      NVARCHAR(300) NOT NULL,
        [ciudad]      NVARCHAR(200) NULL,
        [alias]       NVARCHAR(100) NULL,
        [zona]        NVARCHAR(200) NULL,
        [sapCode]     NVARCHAR(100) NULL,
        [codigo]      NVARCHAR(100) NULL,
        [coachId]     NVARCHAR(200) NULL
      )
    `);
    console.log("[migration] tabla vendedores OK");

    await pool.request().query(`
      IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'alertas')
      CREATE TABLE [alertas] (
        [id]        NVARCHAR(200) NOT NULL PRIMARY KEY,
        [tipo]      NVARCHAR(100) NOT NULL,
        [mensaje]   NVARCHAR(MAX) NULL,
        [vendedor]  NVARCHAR(300) NULL,
        [coach]     NVARCHAR(300) NULL,
        [kam]       NVARCHAR(300) NULL,
        [fecha]     NVARCHAR(50)  NULL,
        [estado]    NVARCHAR(50)  NULL DEFAULT 'PENDIENTE',
        [resuelta]  INT           NOT NULL DEFAULT 0
      )
    `);
    console.log("[migration] tabla alertas OK");

    await pool.request().query(`
      IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ubicaciones')
      CREATE TABLE [ubicaciones] (
        [id]          NVARCHAR(200) NOT NULL PRIMARY KEY,
        [vendedorId]  NVARCHAR(200) NOT NULL,
        [fecha]       NVARCHAR(50)  NULL,
        [latitud]     FLOAT         NULL,
        [longitud]    FLOAT         NULL,
        [timestamp]   NVARCHAR(50)  NULL,
        [nombre]      NVARCHAR(300) NULL,
        [cargo]       NVARCHAR(100) NULL
      )
    `);
    // Agregar columnas nombre/cargo si la tabla ya existía sin ellas
    for (const col of [{ name: "nombre", type: "NVARCHAR(300) NULL" }, { name: "cargo", type: "NVARCHAR(100) NULL" }]) {
      try {
        await pool.request().query(`
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='ubicaciones' AND COLUMN_NAME='${col.name}')
          ALTER TABLE [ubicaciones] ADD [${col.name}] ${col.type}
        `);
      } catch (_) {}
    }
    console.log("[migration] tabla ubicaciones OK");

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
      { name: "fechaCreacion", type: "NVARCHAR(50)  NULL" },
      { name: "latitud", type: "FLOAT         NULL" },
      { name: "longitud", type: "FLOAT         NULL" },
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

    // 5. Columnas de Sistema (Alias, Zona, SapCode) para login y sync
    const userTables = ['supervisores', 'vendedores'];
    for (const table of userTables) {
      const cols = [
        { name: "alias", type: "NVARCHAR(100) NULL" },
        { name: "zona", type: "NVARCHAR(200) NULL" },
        { name: "sapCode", type: "NVARCHAR(100) NULL" },
        { name: "codigo", type: "NVARCHAR(100) NULL" } // Contraseña
      ];
      if (table === 'supervisores') cols.push({ name: "superiorId", type: "NVARCHAR(200) NULL" });
      if (table === 'vendedores') cols.push({ name: "coachId", type: "NVARCHAR(200) NULL" });

      for (const col of cols) {
        try {
          await pool.request().query(`
            IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${table}' AND COLUMN_NAME = '${col.name}')
            BEGIN
              ALTER TABLE [${table}] ADD [${col.name}] ${col.type}
            END
          `);
        } catch (colErr) {
          console.warn(`[migration] fallo en ${table}.${col.name}:`, colErr.message);
        }
      }
    }
    console.log("[migration] Estructura de tablas OK");
  } catch (err) {
    console.warn("[migration] error en migración:", err.message);
  }
}

async function startServer() {
  console.log("\n" + "=".repeat(60));
  console.log("  API MINUTO A MINUTO v2.3.0");
  console.log("=".repeat(60));
  console.log("-".repeat(60));
  console.log(`  Puerto: ${port}`);
  console.log(`  Host SQL: ${dbConfig.server}:${dbConfig.port}`);
  console.log(`  DB SQL: ${dbConfig.database}`);
  console.log("=".repeat(60) + "\n");
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

      // Mapa nombre de coach → id en supervisores
      const supsResult = await pool.request().query(`SELECT id, nombre FROM ${TABLES.supervisores}`);
      const coachIdMap = {};
      supsResult.recordset.forEach(s => { coachIdMap[s.nombre] = s.id; });

      for (const v of vendsSap.recordset) {
        if (!nombresQueLlamaron.has(v.nombre)) {
          const msg = `${v.nombre} no ha hecho ninguna llamada antes de las 8:20`;
          const supervisorId = coachIdMap[v.coach] || null;
          await pool.request()
            .input("id", crypto.randomUUID())
            .input("tipo", "vendedorSinLlamada8am")
            .input("mensaje", msg)
            .input("supervisorId", supervisorId)
            .input("vendedorId", null)
            .input("zona", "")
            .input("resuelta", 0)
            .input("fecha", hoy)
            .query(`
              IF NOT EXISTS (SELECT 1 FROM ${TABLES.alertas} WHERE mensaje = @mensaje AND fecha = @fecha)
              INSERT INTO ${TABLES.alertas} (id, tipo, mensaje, vendedorId, supervisorId, zona, resuelta, fecha)
              VALUES (@id, @tipo, @mensaje, @vendedorId, @supervisorId, @zona, @resuelta, @fecha)
            `);
        }
      }
    } catch (err) {
      console.error("[cron] Error en tarea 8:20 AM:", err.message);
    }
  });

  // ── Reporte diario: lunes-viernes a las 6:00 PM (Colombia UTC-5 = 23:00 UTC)
  cron.schedule("0 23 * * 1-5", () => {
    console.log("[cron] Enviando reporte diario...");
    sendDailyReport(getPool, TABLES).catch(e => console.error("[cron] reporte diario:", e.message));
  });

  // ── Reporte semanal: cada lunes a las 7:00 AM (Colombia = 12:00 UTC)
  cron.schedule("0 12 * * 1", () => {
    console.log("[cron] Enviando reporte semanal...");
    sendWeeklyReport(getPool, TABLES).catch(e => console.error("[cron] reporte semanal:", e.message));
  });

  // ── Reporte mensual: día 1 de cada mes a las 7:00 AM (Colombia = 12:00 UTC)
  cron.schedule("0 12 1 * *", () => {
    console.log("[cron] Enviando reporte mensual...");
    sendMonthlyReport(getPool, TABLES).catch(e => console.error("[cron] reporte mensual:", e.message));
  });
}

module.exports = { app, startServer, getPool };

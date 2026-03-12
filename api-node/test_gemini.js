/**
 * Script para verificar que Gemini funciona correctamente.
 * Envía un audio WAV minimal (1s silencio) y prueba transcripción.
 *
 * Uso:
 *   node test_gemini.js   (lee GEMINI_API_KEY de .env)
 *   GEMINI_API_KEY=xxx node test_gemini.js
 */

require("dotenv").config({ path: require("path").join(__dirname, ".env") });

const apiKey = process.env.GEMINI_API_KEY || "";
if (!apiKey) {
  console.error("ERROR: Define GEMINI_API_KEY en .env o como variable de entorno");
  process.exit(1);
}

// Audio WAV minimal válido (~1s silencio 8kHz mono 16-bit)
function getMinimalWavBase64() {
  const sampleRate = 8000;
  const numSamples = sampleRate;
  const dataSize = numSamples * 2;
  const headerSize = 44;
  const buf = Buffer.alloc(headerSize + dataSize);
  let off = 0;
  buf.write("RIFF", off); off += 4;
  buf.writeUInt32LE(36 + dataSize, off); off += 4;
  buf.write("WAVE", off); off += 4;
  buf.write("fmt ", off); off += 4;
  buf.writeUInt32LE(16, off); off += 4;
  buf.writeUInt16LE(1, off); off += 2;
  buf.writeUInt16LE(1, off); off += 2;
  buf.writeUInt32LE(sampleRate, off); off += 4;
  buf.writeUInt32LE(sampleRate * 2, off); off += 4;
  buf.writeUInt16LE(2, off); off += 2;
  buf.writeUInt16LE(16, off); off += 2;
  buf.write("data", off); off += 4;
  buf.writeUInt32LE(dataSize, off);
  return buf.toString("base64");
}

const models = process.env.GEMINI_MODEL
  ? [process.env.GEMINI_MODEL]
  : ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"];

async function test() {
  const audioB64 = getMinimalWavBase64();
  console.log("Probando transcripción Gemini...\n");

  for (const model of models) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const body = {
        contents: [{
          role: "user",
          parts: [
            { inlineData: { mimeType: "audio/wav", data: audioB64 } },
            { text: "Transcribe este audio. Devuelve solo el texto o 'silencio' si no hay voz." },
          ],
        }],
        generationConfig: { temperature: 0.1, maxOutputTokens: 256 },
      };

      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const data = await res.json();

      if (!res.ok) {
        const err = data?.error?.message || data?.message || res.statusText;
        console.log(`  ${model}: FALLO - ${err}`);
        continue;
      }

      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || "(sin texto)";
      console.log(`  ${model}: OK`);
      console.log(`    Respuesta: "${text.substring(0, 80)}${text.length > 80 ? "..." : ""}"`);
      console.log("\n  Gemini funciona correctamente.");
      process.exit(0);
    } catch (e) {
      console.log(`  ${model}: Error - ${e.message}`);
    }
  }

  console.error("\n  Ningún modelo respondió. Revisa GEMINI_API_KEY y la conexión.");
  process.exit(1);
}

test();

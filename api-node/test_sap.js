const sql = require('mssql');

const sapConfig = {
  user: 'sa',
  password: 'Sky2022*!',
  server: '192.168.2.244',
  database: 'RBOSKY3',
  port: 1433,
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  connectionTimeout: 15000,
  requestTimeout: 15000,
};

async function main() {
  console.log('Conectando a SAP DB RBOSKY3 en 192.168.2.244...');
  const pool = await sql.connect(sapConfig);
  console.log('✅ Conexión exitosa!');

  // 1. Test: tablas existen?
  const tablas = await pool.request().query(`
    SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME IN ('OCRD','OSLP')
  `);
  console.log('Tablas encontradas:', tablas.recordset.map(r => r.TABLE_NAME));

  // 2. Test: query principal de cartera (primeros 5)
  const cartera = await pool.request().query(`
    SELECT TOP 5
      T0.[CardCode]   AS cardCode,
      T0.[CardName]   AS cardName,
      T0.[CardFName]  AS cardFName,
      T1.[SlpName]    AS slpName,
      T2.[Name]       AS coach,
      T3.[Name]       AS kam
    FROM OCRD T0
    INNER JOIN OSLP T1 ON T0.[SlpCode] = T1.[SlpCode]
    INNER JOIN [dbo].[@COACH] T2 ON T0.[U_COACH] = T2.[Code]
    INNER JOIN [dbo].[@SKY_NEGOCIADOR] T3 ON T0.[U_NEGOCIADOR] = T3.[Code]
    WHERE T0.[validFor] = 'Y'
    ORDER BY T0.[CardName]
  `);
  console.log('\\n✅ Query cartera (primeros 5):');
  console.table(cartera.recordset);

  // 3. Test: lista de COACHes únicos
  const coaches = await pool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre
    FROM [dbo].[@COACH] T
    INNER JOIN OCRD C ON C.[U_COACH] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
    ORDER BY T.[Name]
  `);
  console.log('\\n✅ COACHes únicos:');
  coaches.recordset.forEach(r => console.log(' -', r.nombre));

  // 4. Test: lista de KAMs únicos
  const kams = await pool.request().query(`
    SELECT DISTINCT T.[Name] AS nombre
    FROM [dbo].[@SKY_NEGOCIADOR] T
    INNER JOIN OCRD C ON C.[U_NEGOCIADOR] = T.[Code]
    WHERE C.[validFor] = 'Y' AND T.[Name] IS NOT NULL AND T.[Name] <> ''
    ORDER BY T.[Name]
  `);
  console.log('\\n✅ KAMs únicos:');
  kams.recordset.forEach(r => console.log(' -', r.nombre));

  await pool.close();
  console.log('\\n✅ Todo OK! El servidor puede conectarse a SAP sin problemas.');
}

main().catch(err => {
  console.error('\\n❌ ERROR:', err.message);
  console.error('Código:', err.code || 'N/A');
  process.exit(1);
});

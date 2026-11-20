// Convierte el reporte JSON de ESLint al formato nativo de Warnings Next Generation (Jenkins), para que
// Jenkins muestre cada aviso, su tendencia y aplique los topes de calidad (avisos totales y nuevos).
// Uso: node ci/eslint-a-issues.js [reportes/eslint.json] [reportes/eslint-issues.json]
const fs = require('node:fs');
const path = require('node:path');

const entrada = process.argv[2] || 'reportes/eslint.json';
const salida = process.argv[3] || 'reportes/eslint-issues.json';
const severidades = { 1: 'NORMAL', 2: 'ERROR' };

const resultados = fs.existsSync(entrada) ? JSON.parse(fs.readFileSync(entrada, 'utf8')) : [];
const issues = [];
for (const archivo of resultados) {
  for (const m of archivo.messages) {
    issues.push({
      fileName: path.relative(process.cwd(), archivo.filePath).split(path.sep).join('/'),
      lineStart: m.line || 0,
      columnStart: m.column || 0,
      severity: severidades[m.severity] || 'NORMAL',
      type: m.ruleId || 'eslint',
      category: 'ESLint',
      message: m.message,
    });
  }
}
fs.writeFileSync(salida, JSON.stringify({ issues }, null, 2));
console.log(`ESLint: ${issues.length} aviso(s) en ${resultados.length} archivo(s).`);

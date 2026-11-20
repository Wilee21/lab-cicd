// Calcula la cobertura de líneas a partir de un reporte LCOV y la compara con el mínimo de
// ci/topes-calidad.properties. Sale con código 1 si la cobertura queda por debajo del tope.
// Uso: node ci/revisar-cobertura.js [reportes/lcov.info] [ci/topes-calidad.properties]
const fs = require('node:fs');

const archivoLcov = process.argv[2] || 'reportes/lcov.info';
const archivoTopes = process.argv[3] || 'ci/topes-calidad.properties';

function leerTopes(ruta) {
  const topes = {};
  for (const linea of fs.readFileSync(ruta, 'utf8').split(/\r?\n/)) {
    const l = linea.trim();
    if (!l || l.startsWith('#') || !l.includes('=')) continue;
    const [clave, valor] = l.split('=', 2);
    topes[clave.trim()] = Number(valor.trim());
  }
  return topes;
}

function coberturaLineas(ruta) {
  let encontradas = 0;
  let cubiertas = 0;
  for (const linea of fs.readFileSync(ruta, 'utf8').split(/\r?\n/)) {
    if (linea.startsWith('LF:')) encontradas += Number(linea.slice(3));
    if (linea.startsWith('LH:')) cubiertas += Number(linea.slice(3));
  }
  return encontradas === 0 ? 0 : (cubiertas / encontradas) * 100;
}

const tope = leerTopes(archivoTopes).coberturaLineas;
const cobertura = coberturaLineas(archivoLcov);
const texto = `${cobertura.toFixed(2)} %`;
fs.writeFileSync('reportes/cobertura.txt', `${cobertura.toFixed(2)}\n`);

if (Number.isFinite(tope) && cobertura < tope) {
  console.error(`Cobertura de líneas: ${texto}, por debajo del tope de ${tope} % (ci/topes-calidad.properties).`);
  process.exit(1);
}
console.log(`Cobertura de líneas: ${texto} (tope: ${Number.isFinite(tope) ? `${tope} %` : 'sin tope'}).`);

// Compara los resultados de SonarQube (reportes/sonarqube-*.json, de ci/sonarqube.sh) con los topes de
// ci/topes-calidad.properties. Muestra cada hallazgo con su archivo y línea, deja el resumen en
// reportes/sonarqube-resumen.txt y sale con código 1 si algún número supera su tope.
// Uso: node ci/revisar-sonarqube.js
const fs = require('node:fs');

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

const leer = (ruta) => JSON.parse(fs.readFileSync(ruta, 'utf8'));
const medidas = Object.fromEntries(
  leer('reportes/sonarqube-medidas.json').component.measures.map((m) => [m.metric, m.value])
);
const issues = leer('reportes/sonarqube-issues.json').issues || [];
const hotspots = leer('reportes/sonarqube-hotspots.json').hotspots || [];

// SonarQube reciente agrupa por "calidad del software"; las métricas clásicas se usan si están.
const numero = (...claves) => {
  for (const c of claves) {
    if (medidas[c] === undefined) continue;
    const v = medidas[c];
    // Las métricas software_quality_* pueden venir como JSON con el total.
    if (typeof v === 'string' && v.startsWith('{')) return Number(JSON.parse(v).total || 0);
    return Number(v);
  }
  return 0;
};

const resultados = [
  ['Bugs (confiabilidad)', numero('bugs', 'software_quality_reliability_issues'), 'sonarBugs'],
  ['Vulnerabilidades', numero('vulnerabilities', 'software_quality_security_issues'), 'sonarVulnerabilidades'],
  ['Security Hotspots', hotspots.length, 'sonarHotspots'],
  ['Code smells (mantenibilidad)', numero('code_smells', 'software_quality_maintainability_issues'), 'sonarCodeSmells'],
];
const topes = leerTopes('ci/topes-calidad.properties');

const lineas = ['SonarQube: resultados frente a ci/topes-calidad.properties'];
let fallas = 0;
for (const [nombre, valor, clave] of resultados) {
  const tope = topes[clave];
  const excede = Number.isFinite(tope) && valor > tope;
  if (excede) fallas++;
  lineas.push(`  ${excede ? 'FALLA' : 'ok   '} ${nombre}: ${valor} (tope: ${Number.isFinite(tope) ? tope : 'sin tope'})`);
}
if (medidas.coverage !== undefined) lineas.push(`  info  Cobertura según SonarQube: ${medidas.coverage} %`);
if (medidas.ncloc !== undefined) lineas.push(`  info  Líneas de código analizadas: ${medidas.ncloc}`);

const ubicacion = (x) => `${(x.component || '').split(':').pop()}:${x.line || '-'}`;
if (hotspots.length) {
  lineas.push('', 'Security Hotspots:');
  for (const h of hotspots) lineas.push(`  - [${h.vulnerabilityProbability}] ${ubicacion(h)} ${h.message} (${h.ruleKey})`);
}
if (issues.length) {
  lineas.push('', 'Hallazgos:');
  for (const i of issues) lineas.push(`  - [${i.severity || ''}] ${ubicacion(i)} ${i.message} (${i.rule})`);
}

const texto = lineas.join('\n');
fs.writeFileSync('reportes/sonarqube-resumen.txt', `${texto}\n`);
console.log(texto);
if (fallas > 0) {
  console.error(`\nSonarQube: ${fallas} tope(s) superado(s). Corregir el código o, si es un falso positivo, documentarlo.`);
  process.exit(1);
}

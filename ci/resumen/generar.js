// Genera la página "Resumen" de cada ejecución de Jenkins (reportes/resumen/index.html) y la línea que
// aparece en la lista de ejecuciones (reportes/resumen/descripcion.txt). Responde de un vistazo si la rama
// se puede integrar y, si no, qué hay que arreglar, sin necesidad de recorrer el registro completo.
//
// Lee los reportes que dejan las etapas anteriores en reportes/ y las variables de entorno que pasa el
// Jenkinsfile: RESULTADO, RAMA, BUILD_NUMBER, GIT_COMMIT, VERSION, ETIQUETA, IMAGEN, FRENOS y BUILD_URL.
// Se puede probar sin Jenkins:  RESULTADO=SUCCESS node ci/resumen/generar.js
const fs = require('node:fs');
const path = require('node:path');

const env = process.env;
const salida = path.join('reportes', 'resumen');
fs.mkdirSync(salida, { recursive: true });

const leer = (ruta) => (fs.existsSync(ruta) ? fs.readFileSync(ruta, 'utf8') : null);
const pct = (n) => n.toFixed(1).replace('.', ',');
const html = (t) => String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

// --- Datos de la ejecución ---
const topes = {};
for (const linea of (leer('ci/topes-calidad.properties') || '').split(/\r?\n/)) {
  const l = linea.trim();
  if (l && !l.startsWith('#') && l.includes('=')) {
    const [k, v] = l.split('=', 2);
    topes[k.trim()] = Number(v.trim());
  }
}

const eslint = JSON.parse(leer('reportes/eslint-issues.json') || '{"issues":[]}').issues;

const junit = leer('reportes/junit.xml') || '';
const pruebas = (junit.match(/<testcase\b/g) || []).length;
const fallidas = [...junit.matchAll(/<testcase[^>]*name="([^"]*)"[^>]*>\s*<failure[^>]*message="([^"]*)"/g)].map((m) => ({
  nombre: m[1],
  error: m[2],
}));

const coberturaTexto = (leer('reportes/cobertura.txt') || '').trim();
const cobertura = coberturaTexto ? Number(coberturaTexto) : null;

let secretos = [];
const sarif = leer('reportes/gitleaks.sarif');
if (sarif) {
  for (const run of JSON.parse(sarif).runs || []) {
    for (const r of run.results || []) {
      const ubicacion = r.locations?.[0]?.physicalLocation;
      secretos.push({
        regla: r.ruleId,
        archivo: ubicacion?.artifactLocation?.uri || '?',
        linea: ubicacion?.region?.startLine || '?',
      });
    }
  }
}

const resultado = env.RESULTADO || 'SUCCESS';
const rama = env.RAMA || 'local';
const commit = (env.GIT_COMMIT || 'local').slice(0, 7);
const frenos = (env.FRENOS || '').split(';').filter(Boolean);

// --- Motivos de falla ---
const motivos = [];
for (const linea of (leer('reportes/costos.txt') || '').split(/\r?\n/)) {
  if (linea.startsWith('COSTOS: ')) motivos.push(`Revisión de costos: ${linea.slice(8)}.`);
}
const audit = leer('reportes/npm-audit.txt') || '';
const vulnerables = audit.match(/(\d+) (high|critical)/gi);
if (vulnerables) motivos.push(`npm audit encontró vulnerabilidades: ${vulnerables.join(', ')}.`);
if (secretos.length) motivos.push(`Gitleaks encontró ${secretos.length} posible(s) secreto(s) en el historial.`);
if (fallidas.length) motivos.push(`${fallidas.length} prueba(s) fallaron.`);
if (Number.isFinite(topes.eslint) && eslint.length > topes.eslint) {
  motivos.push(`ESLint tiene ${eslint.length} aviso(s); el tope es ${topes.eslint}.`);
} else if (frenos.includes('ESLint')) {
  motivos.push('ESLint tiene avisos nuevos respecto a main.');
}
if (cobertura !== null && Number.isFinite(topes.coberturaLineas) && cobertura < topes.coberturaLineas) {
  motivos.push(`La cobertura de líneas es ${pct(cobertura)} %; el mínimo es ${topes.coberturaLineas} %.`);
}
for (const etapa of frenos.filter((f) => f !== 'ESLint' && f !== 'Gitleaks')) {
  if (!motivos.some((m) => m.toLowerCase().includes(etapa.toLowerCase().split(' ')[0]))) {
    motivos.push(`No terminó la etapa "${etapa}".`);
  }
}
if (resultado !== 'SUCCESS' && motivos.length === 0) motivos.push('La ejecución no terminó correctamente; revisar el registro.');

const paso = resultado === 'SUCCESS';
const veredicto = paso
  ? rama === 'main'
    ? 'Imagen publicada en el registro'
    : 'Se puede integrar a main'
  : motivos.length === 1
    ? `Falló: ${motivos[0].replace(/\.$/, '')}`
    : `Falló por ${motivos.length} motivos`;

// --- Página ---
const fila = (nombre, valor, tope, ok) =>
  `<tr><td>${html(nombre)}</td><td>${html(valor)}</td><td>${html(tope)}</td><td class="${ok ? 'ok' : 'mal'}">${ok ? 'Cumple' : 'No cumple'}</td></tr>`;

const detalleEslint = eslint.length
  ? `<h3>Avisos de ESLint</h3><table><thead><tr><th>Archivo</th><th>Línea</th><th>Regla</th><th>Mensaje</th></tr></thead><tbody>${eslint
      .map((i) => `<tr><td>${html(i.fileName)}</td><td>${i.lineStart}</td><td>${html(i.type)}</td><td>${html(i.message)}</td></tr>`)
      .join('')}</tbody></table>`
  : '';
const detallePruebas = fallidas.length
  ? `<h3>Pruebas que fallaron</h3><ul>${fallidas.map((f) => `<li><strong>${html(f.nombre)}</strong>: ${html(f.error)}</li>`).join('')}</ul>`
  : '';
const detalleSecretos = secretos.length
  ? `<h3>Posibles secretos (valores ocultos)</h3><ul>${secretos.map((s) => `<li>${html(s.archivo)}, línea ${s.linea}: ${html(s.regla)}</li>`).join('')}</ul>`
  : '';

const pagina = `<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Resumen de la ejecución</title>
<link rel="stylesheet" href="resumen.css"></head>
<body>
<header class="${paso ? 'paso' : 'fallo'}">
  <p class="contexto">${html(rama)} · ejecución #${html(env.BUILD_NUMBER || '-')} · commit ${html(commit)}</p>
  <h1>${html(veredicto)}</h1>
  ${env.IMAGEN ? `<p class="imagen">Imagen: <code>${html(env.IMAGEN)}:${html(env.VERSION || '')}</code>${env.ETIQUETA ? ` · <code>${html(env.ETIQUETA)}</code>` : ''}</p>` : ''}
  ${env.BUILD_URL ? `<p><a href="${html(env.BUILD_URL)}console">Ver el registro completo</a></p>` : ''}
</header>
<main>
${
  paso
    ? ''
    : `<section><h2>Qué arreglar</h2><ul class="motivos">${motivos.map((m) => `<li>${html(m)}</li>`).join('')}</ul>${detalleSecretos}${detallePruebas}${detalleEslint}</section>`
}
<section><h2>Calidad frente a los topes</h2>
<table><thead><tr><th>Revisión</th><th>Valor</th><th>Tope</th><th>Estado</th></tr></thead><tbody>
${fila('Avisos de ESLint', eslint.length, `máximo ${topes.eslint ?? '-'}`, !(eslint.length > topes.eslint) && !frenos.includes('ESLint'))}
${fila('Cobertura de líneas', cobertura === null ? 'sin dato' : `${pct(cobertura)} %`, `mínimo ${topes.coberturaLineas ?? '-'} %`, cobertura !== null && !(cobertura < topes.coberturaLineas))}
${fila('Pruebas', `${pruebas - fallidas.length} de ${pruebas} aprobadas`, 'todas', pruebas > 0 && fallidas.length === 0)}
${fila('Secretos en el historial', secretos.length, 'ninguno', secretos.length === 0)}
</tbody></table>
<p class="nota">Los topes están en <code>ci/topes-calidad.properties</code> y funcionan como un trinquete: si un número mejora, el tope se ajusta en el mismo commit.</p>
</section>
</main></body></html>
`;
fs.writeFileSync(path.join(salida, 'index.html'), pagina);
fs.copyFileSync(path.join(__dirname, 'resumen.css'), path.join(salida, 'resumen.css'));

const partes = [commit, veredicto];
if (pruebas) partes.push(`${pruebas} pruebas`);
if (cobertura !== null) partes.push(`${pct(cobertura)} %`);
fs.writeFileSync(path.join(salida, 'descripcion.txt'), partes.join(' · '));
console.log(`Resumen: ${partes.join(' · ')}`);

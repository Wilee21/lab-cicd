// Pruebas en vivo: se ejecutan contra un servicio ya desplegado (variable BASE_URL), no contra el código.
// Las corre cada noche el job "pruebas-en-vivo" de Jenkins (ci/PruebasEnVivo.Jenkinsfile) sobre la última
// imagen publicada; VERSION_ESPERADA permite comprobar que responde la versión que se quiso desplegar.
const { test } = require('node:test');
const assert = require('node:assert/strict');

const base = process.env.BASE_URL;
const versionEsperada = process.env.VERSION_ESPERADA;

test('el servicio está disponible y reporta su versión', { skip: !base && 'falta BASE_URL' }, async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  const salud = await res.json();
  assert.equal(salud.estado, 'ok');
  assert.notEqual(salud.commit, 'local', 'la imagen debe traer el commit con el que se construyó');
  if (versionEsperada) assert.equal(salud.version, versionEsperada);
});

test('el catálogo responde con cursos válidos', { skip: !base && 'falta BASE_URL' }, async () => {
  const res = await fetch(`${base}/api/cursos`);
  assert.equal(res.status, 200);
  const cursos = await res.json();
  assert.ok(cursos.length > 0);
  for (const curso of cursos) {
    assert.equal(typeof curso.id, 'number');
    assert.ok(curso.nombre);
  }
});

test('un curso inexistente responde 404', { skip: !base && 'falta BASE_URL' }, async () => {
  const res = await fetch(`${base}/api/cursos/999999`);
  assert.equal(res.status, 404);
});

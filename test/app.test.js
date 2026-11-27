// Pruebas de integración con el ejecutor nativo de Node.js (node:test), sin dependencias adicionales.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { crearApp } = require('../src/app');

let servidor;
let base;

before(async () => {
  servidor = crearApp().listen(0);
  await new Promise((r) => servidor.once('listening', r));
  base = `http://127.0.0.1:${servidor.address().port}`;
});

after(() => servidor.close());

test('GET / responde con la página de inicio', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /Catálogo de cursos/);
});

test('GET /health responde ok', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  const cuerpo = await res.json();
  assert.equal(cuerpo.estado, 'ok');
  assert.ok(cuerpo.version, 'la respuesta incluye la versión');
  assert.ok(cuerpo.commit, 'la respuesta incluye el commit');
});

test('GET /api/cursos devuelve la lista de cursos', async () => {
  const cursos = await (await fetch(`${base}/api/cursos`)).json();
  assert.ok(Array.isArray(cursos));
  assert.ok(cursos.length > 0);
});

test('GET /api/cursos/:id devuelve un curso existente', async () => {
  const curso = await (await fetch(`${base}/api/cursos/1`)).json();
  assert.equal(curso.nombre, 'Fundamentos DevOps');
});

test('GET /api/cursos/:id responde 404 si el curso no existe', async () => {
  const res = await fetch(`${base}/api/cursos/999`);
  assert.equal(res.status, 404);
});

test('GET /api/admin rechaza una contraseña incorrecta', async () => {
  const res = await fetch(`${base}/api/admin`, { headers: { 'x-admin-password': 'otra' } });
  assert.equal(res.status, 401);
});

test('GET /api/admin responde con la contraseña correcta', async () => {
  const res = await fetch(`${base}/api/admin`, { headers: { 'x-admin-password': 'Adm1n-Catalogo-2026*' } });
  assert.equal(res.status, 200);
});

// Pruebas con el runner nativo de Node (node:test): no requieren dependencias extra.
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

test('GET /health responde ok', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).estado, 'ok');
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

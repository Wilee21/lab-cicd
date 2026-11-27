// API de referencia: catálogo de cursos almacenado en memoria. Se omite la base de datos de forma deliberada,
// ya que el objeto del laboratorio son los pipelines de CI/CD.
const express = require('express');
// DEMOSTRACIÓN DE SEGURIDAD (rama demo/vulnerabilidad-intencional, NO se fusiona):
// 1) lodash 4.17.15 tiene vulnerabilidades conocidas (CVE-2020-8203, CVE-2021-23337): npm audit y Trivy.
// 2) Una contraseña quemada en el código: SonarQube (Security Hotspot) y Gitleaks.
const _ = require('lodash');

const ADMIN_PASSWORD = 'Adm1n-Catalogo-2026*';

const cursos = [
  { id: 1, nombre: 'Fundamentos DevOps', creditos: 2 },
  { id: 2, nombre: 'Arquitectura de Software', creditos: 3 },
  { id: 3, nombre: 'Gerencia de Proyectos', creditos: 2 },
];

function crearApp() {
  const app = express();
  app.use(express.json());

  app.get('/', (_req, res) => {
    res.send('<h1>Catálogo de cursos</h1><p>Consulta <a href="/api/cursos">/api/cursos</a>.</p>');
  });

  // Endpoint de salud: lo utiliza el HEALTHCHECK de Docker y, en fases posteriores, Kubernetes y el monitoreo.
  // Trazabilidad: la versión y el commit los fija el pipeline al construir la imagen (Dockerfile).
  app.get('/health', (_req, res) =>
    res.json({
      estado: 'ok',
      version: process.env.APP_VERSION || 'local',
      commit: process.env.GIT_COMMIT || 'local',
    }),
  );

  app.get('/api/cursos', (_req, res) => res.json(_.sortBy(cursos, 'id')));

  app.get('/api/admin', (req, res) => {
    if (req.get('x-admin-password') !== ADMIN_PASSWORD) return res.status(401).json({ error: 'No autorizado' });
    return res.json({ cursos: cursos.length });
  });

  app.get('/api/cursos/:id', (req, res) => {
    const curso = cursos.find((c) => c.id === Number(req.params.id));
    if (!curso) return res.status(404).json({ error: 'Curso no encontrado' });
    return res.json(curso);
  });

  return app;
}

module.exports = { crearApp };

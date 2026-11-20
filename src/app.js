// API de referencia: catálogo de cursos almacenado en memoria. Se omite la base de datos de forma deliberada,
// ya que el objeto del laboratorio son los pipelines de CI/CD.
const express = require('express');

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

  app.get('/api/cursos', (_req, res) => res.json(cursos));

  app.get('/api/cursos/:id', (req, res) => {
    const curso = cursos.find((c) => c.id === Number(req.params.id));
    if (!curso) return res.status(404).json({ error: 'Curso no encontrado' });
    return res.json(curso);
  });

  return app;
}

module.exports = { crearApp };

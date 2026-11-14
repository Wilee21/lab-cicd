// API de ejemplo: un catálogo de cursos en memoria. No tiene base de datos para que el foco esté en el pipeline.
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

  // Usado por Docker (HEALTHCHECK) y, más adelante, por Kubernetes y el monitoreo.
  app.get('/health', (_req, res) => res.json({ estado: 'ok', version: process.env.APP_VERSION || 'local' }));

  app.get('/api/cursos', (_req, res) => res.json(cursos));

  app.get('/api/cursos/:id', (req, res) => {
    const curso = cursos.find((c) => c.id === Number(req.params.id));
    if (!curso) return res.status(404).json({ error: 'Curso no encontrado' });
    return res.json(curso);
  });

  return app;
}

module.exports = { crearApp };

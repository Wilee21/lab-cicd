# Catálogo de cursos: laboratorio de CI/CD

App web de ejemplo (Node.js + Express) para practicar integración y entrega continua en el curso Fundamentos DevOps. La app es intencionalmente pequeña: el foco está en los pipelines.

- **CI con GitHub Actions** (`.github/workflows/ci.yml`): corre en cada push y pull request.
- **CD con Jenkins** (`Jenkinsfile`): clona, prueba, construye la imagen Docker y la publica en un registro: Docker Hub o un registro local que se levanta junto con Jenkins.
- **Jenkins como código** (`jenkins/`): Docker + Configuration as Code (JCasC). Cualquier persona lo levanta igual en su equipo.

## Flujo CI/CD

```mermaid
flowchart LR
  dev[Desarrollador] -->|push / pull request| gh[GitHub]
  gh --> ci[GitHub Actions<br/>lint · pruebas · audit · build]
  gh -->|cada 5 min revisa main| jk[Jenkins]
  jk --> t[Lint y pruebas<br/>docker build --target test]
  t --> b[Construir imagen<br/>usuario/catalogo-cursos:1.0.N]
  b --> p[Publicar en el registro<br/>Docker Hub o localhost:5000]
  p --> d[Desplegar<br/>Kubernetes, fase 2]
```

| Etapa | Dónde | Qué hace |
| --- | --- | --- |
| Checkout | Actions y Jenkins | Descarga el código del commit que se va a probar. |
| Instalar dependencias | Actions (`npm ci`) y Jenkins (Dockerfile, etapa `test`) | Instala exactamente las versiones de `package-lock.json`. |
| Análisis estático | ESLint | Detecta errores y malas prácticas antes de ejecutar el código. |
| Pruebas | `node --test` | Prueba los endpoints `/health` y `/api/cursos`. |
| Auditoría de dependencias | `npm audit` (Actions) | Avisa de vulnerabilidades altas o críticas en las librerías. |
| Imagen Docker | Jenkins | Construye la imagen final, sin dependencias de desarrollo y sin root. |
| Publicación | Jenkins → registro | Sube la imagen con su versión (`1.0.<build>`) y `latest` a Docker Hub o al registro local. Solo desde `main`. |

## Correr la app en tu equipo

```bash
npm ci
npm test         # pruebas
npm run lint     # análisis estático
npm start        # http://localhost:3000
```

Con Docker:

```bash
docker build -t catalogo-cursos .
docker run -p 3000:3000 catalogo-cursos
```

## Levantar Jenkins (práctica local)

Requisitos: Docker Desktop encendido. La cuenta de Docker Hub es opcional: `docker-compose.yml` también levanta un registro local (`registry:2`) en el puerto 5000.

1. Copia `jenkins/.env.example` como `jenkins/.env` y llena los valores. **El `.env` no se sube a Git.**
   - `REGISTRY_HOST=localhost:5000`: publica en el registro local, sin cuenta ni token.
   - `REGISTRY_HOST=docker.io`: publica en Docker Hub con `DOCKERHUB_USER` y `DOCKERHUB_TOKEN`.
2. Desde la carpeta `jenkins/`:

   ```bash
   docker compose up -d --build
   ```

3. Entra a <http://localhost:8080> (o el puerto de `JENKINS_PORT`) con el usuario `admin` y la clave que pusiste en `.env`.
4. El job `catalogo-cursos-cd` ya está creado. Ejecútalo con **Build Now**; después, Jenkins revisa `main` cada 5 minutos.

Para ver las imágenes publicadas en el registro local: <http://localhost:5000/v2/_catalog>.

Para apagarlo: `docker compose down`. Para borrar también su historial: `docker compose down -v`.

## Seguridad

- No hay secretos en el repositorio. La clave de Jenkins y el token de Docker Hub viven en `jenkins/.env`, que está en `.gitignore`.
- En Jenkins, el token se usa con `withCredentials`, así que aparece enmascarado en los registros.
- La imagen final corre con el usuario `node`, no con root.
- Jenkins tiene acceso al Docker del equipo (socket montado) para construir imágenes. Es práctico para un laboratorio local, pero en un servidor real conviene usar agentes aparte.

## Próximas fases

1. **Despliegue:** manifiestos de Kubernetes y la etapa `Desplegar` del Jenkinsfile aplicándolos al clúster.
2. **Seguridad:** escaneo de la imagen (por ejemplo, Trivy) y de secretos (Gitleaks) en el pipeline.
3. **Monitoreo:** métricas y alertas sobre el endpoint `/health`.

## Evidencias

Las capturas de los pipelines en ejecución van en `docs/capturas/` (GitHub Actions y Jenkins).

# Documentación técnica: pipelines CI/CD del catálogo de cursos

**Actividad 3. Laboratorio técnico (Unidad 2) · Fundamentos DevOps**

## 1. Objetivo

Configurar dos pipelines para una aplicación web alojada en GitHub:

- **CI (integración continua) con GitHub Actions:** compilar, probar y validar el código en cada push o pull request.
- **CD (entrega continua) con Jenkins:** clonar el repositorio, construir una imagen Docker y publicarla en un registro (Docker Hub o un registro local), lista para desplegarse en cualquier entorno.

## 2. Aplicación

API sencilla en Node.js 20 con Express que expone un catálogo de cursos:

| Endpoint | Respuesta |
| --- | --- |
| `GET /` | Página de inicio |
| `GET /health` | Estado de la app y versión desplegada |
| `GET /api/cursos` | Lista de cursos |
| `GET /api/cursos/:id` | Un curso, o 404 si no existe |

## 3. Herramientas y justificación

| Herramienta | Uso | Por qué |
| --- | --- | --- |
| GitHub | Repositorio y pull requests | Es donde vive el código y donde el equipo revisa los cambios. |
| GitHub Actions | CI | Está integrado al repositorio, se configura con un YAML y no requiere servidor propio. |
| Jenkins | CD | Permite controlar dónde y cómo se construye y publica, y se define como código con JCasC. |
| Docker | Empaquetado | La app corre igual en el computador del desarrollador, en el pipeline y en producción. |
| Docker Hub | Registro de imágenes | Registro público y gratuito, accesible desde cualquier clúster de Kubernetes. |
| Docker Registry (`registry:2`) | Registro local | Mismo protocolo que Docker Hub, corre en el equipo y permite probar la publicación sin cuenta. |
| ESLint | Análisis estático | Detecta errores antes de ejecutar el código. |
| node:test | Pruebas | Runner nativo de Node: no agrega dependencias. |
| npm audit | Seguridad | Revisa vulnerabilidades conocidas en las dependencias. |

## 4. Pipeline de CI: GitHub Actions

Archivo: `.github/workflows/ci.yml`. Se ejecuta en cada `push` (todas las ramas) y en cada `pull_request`.

1. **Checkout del código** (`actions/checkout@v4`).
2. **Configurar Node.js 20** con caché de npm.
3. **Instalar dependencias** con `npm ci`, que respeta las versiones exactas de `package-lock.json`.
4. **Análisis estático** con ESLint.
5. **Pruebas** con `npm test`.
6. **Auditoría de dependencias** con `npm audit --audit-level=high`.
7. **Verificar que la imagen Docker construye**, para detectar errores del Dockerfile antes de que lleguen a Jenkins.

Si cualquier paso falla, el commit o el pull request queda marcado en rojo en GitHub.

## 5. Pipeline de CD: Jenkins

Archivo: `Jenkinsfile`.

| Stage | Qué hace |
| --- | --- |
| Clonar repositorio | `checkout scm` descarga el commit de `main`. |
| Lint y pruebas | `docker build --target test`: instala dependencias, corre ESLint y las pruebas dentro de Docker. Si fallan, el pipeline se detiene. |
| Construir imagen Docker | `docker build --target runtime` con la versión `1.0.<número de build>` y la etiqueta `latest`. |
| Publicar imagen en el registro | Sube las dos etiquetas al registro de `REGISTRY_HOST`. Con Docker Hub inicia sesión con la credencial `dockerhub` (enmascarada); con el registro local (`localhost:5000`) no necesita credenciales. Solo se ejecuta para `main`. |
| Desplegar | Reservado para la fase 2 (Kubernetes). Hoy deja registrada la imagen lista para desplegar. |

Al final, Jenkins cierra la sesión del registro y borra la imagen temporal de pruebas.

El registro de destino se elige en `jenkins/.env` sin tocar el Jenkinsfile: el mismo pipeline sirve para practicar en local y para publicar en Docker Hub.

### Dockerfile de dos etapas

- **`test`:** instala todas las dependencias y corre lint y pruebas. Así Jenkins no necesita tener Node instalado.
- **`runtime`:** imagen final, solo con dependencias de producción, con el usuario `node` (no root) y un `HEALTHCHECK` sobre `/health`.

### Jenkins como código

La carpeta `jenkins/` contiene todo lo necesario para levantar Jenkins igual en cualquier equipo:

- `Dockerfile`: imagen oficial de Jenkins con el cliente de Docker y los plugins de `plugins.txt`.
- `casc.yaml`: usuario administrador, credencial de Docker Hub y el job `catalogo-cursos-cd`, creado automáticamente con Job DSL.
- `docker-compose.yml`: levanta Jenkins (puerto 8080, configurable con `JENKINS_PORT`) y el registro local en el puerto 5000. Tiene un nombre de proyecto propio (`lab-cicd`) para no mezclarse con otros Jenkins del equipo.
- `.env.example`: plantilla de los secretos. El `.env` real no se sube a Git.

## 6. Evidencias

| Evidencia | Archivo |
| --- | --- |
| Ejecución de GitHub Actions | `docs/capturas/github-actions.png` |
| Ejecución del pipeline en Jenkins | `docs/capturas/jenkins.png` |
| Consola del build en Jenkins | `docs/capturas/jenkins-consola.png` |
| Imagen publicada en el registro | `docs/capturas/registro-local.png` |

## 7. Próximas fases

1. Desplegar la imagen en un clúster de Kubernetes desde la etapa `Desplegar`.
2. Agregar escaneo de seguridad de la imagen y de secretos.
3. Habilitar monitoreo sobre el endpoint `/health`.

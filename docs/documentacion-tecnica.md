# Documentación técnica: pipelines de CI/CD del catálogo de cursos

**Actividad 3. Laboratorio técnico (Unidad 2) · Fundamentos DevOps**

## 1. Objetivo

Configurar dos pipelines para una aplicación web alojada en GitHub, como primera fase del proyecto del curso:

- **Integración continua (CI) con GitHub Actions:** compilar, probar y validar el código en cada push o pull request.
- **Entrega continua (CD) con Jenkins:** clonar el repositorio, construir una imagen Docker y publicarla en un registro de imágenes (Docker Hub o un registro local), de modo que quede disponible para su despliegue en cualquier entorno.

## 2. Relación con las actividades anteriores del curso

Este laboratorio corresponde a la primera fase del proyecto del curso, desarrollado bajo la metodología de aprendizaje basado en proyectos. Las fases siguientes incorporan el despliegue en Kubernetes con controles de seguridad y, posteriormente, el monitoreo de la aplicación.

**Actividad 1 (foro de debate).** La comparación de herramientas de CI/CD concluyó que el factor determinante no es la herramienta, sino que el pipeline esté definido como código, versionado y disponible para revisión del equipo. El laboratorio aplica ese criterio con las dos herramientas analizadas: GitHub Actions para la integración continua y Jenkins con JCasC para la entrega continua.

### 2.1 Propuesta de la Actividad 2

En la Actividad 2 (trabajo grupal) se diseñó una arquitectura de herramientas DevOps para la aplicación móvil de una plataforma educativa, desarrollada con Kotlin Multiplatform y alojada en GitLab. El punto de partida era una integración continua funcional en Jenkins, ejecutado en Docker y gestionado con JCasC, con análisis estático y pruebas automatizadas en cada rama.

El diagnóstico identificó cinco brechas:

1. Distribución manual de los artefactos a QA y a los usuarios piloto.
2. Ausencia de despliegue continuo hacia las tiendas de aplicaciones.
3. Falta de observabilidad en producción.
4. Ausencia de controles automáticos de seguridad sobre dependencias y credenciales.
5. Dependencia de un computador local para ejecutar Jenkins.

Para cerrarlas, la propuesta incorporó OWASP Dependency-Check y Gitleaks, credenciales cifradas en Jenkins, Firebase App Distribution, Fastlane, Firebase Crashlytics y la migración de Jenkins a un servidor en la nube, en una adopción gradual de cuatro fases.

![Arquitectura de herramientas DevOps propuesta en la Actividad 2](arquitectura-actividad2.png)

*Arquitectura propuesta en la Actividad 2. Los bloques con trazo continuo representan componentes en uso y los de trazo discontinuo, componentes propuestos.*

### 2.2 Correspondencia con el laboratorio

El proyecto del curso exige una aplicación web alojada en GitHub que en las fases siguientes se desplegará en Kubernetes. Por esa razón, el laboratorio no trabaja sobre la aplicación móvil, sino sobre un servicio web de referencia del mismo dominio (un catálogo de cursos), desarrollado sin código ni datos de la organización. Sobre ese servicio se aplican los mismos principios de la propuesta, y los componentes propios del entorno móvil se sustituyen por su equivalente para una aplicación web.

| Componente (Actividad 2) | Equivalente en el laboratorio | Estado |
| --- | --- | --- |
| Control de versiones: GitLab con merge requests | GitHub con pull requests; plantilla de pull request con lista de verificación. | Implementado |
| Integración continua: Jenkins en Docker con JCasC | Jenkins multibranch en Docker con JCasC (`jenkins/`) y GitHub Actions como segunda línea de validación. | Implementado |
| Calidad de código con topes (trinquete) y avisos nuevos | ESLint con tope en `ci/topes-calidad.properties` y falla ante un aviso nuevo frente a `main` (Warnings Next Generation). | Implementado |
| Análisis estático en cada rama | SonarQube Community Build en un contenedor temporal, con la cobertura de las pruebas y topes de bugs, vulnerabilidades, Security Hotspots y code smells. | Implementado |
| Pruebas automatizadas y cobertura con mínimo (Kover) | `node:test` con reportes JUnit y cobertura de líneas con mínimo del 100 %. | Implementado |
| Revisión de costos antes de compilar | `ci/revisar-costos.sh` como primera etapa de ambos pipelines. | Implementado |
| Seguridad: Gitleaks | Gitleaks sobre todo el historial en Jenkins y en GitHub Actions. | Implementado |
| Seguridad: revisión de dependencias (OWASP Dependency-Check) | Trivy sobre las dependencias, el Dockerfile y la imagen construida, junto con `npm audit` y Dependabot (ver 2.3). | Implementado, con cambio de herramienta |
| Gestión de credenciales fuera del repositorio | Secretos en el Administrador de credenciales de Windows (DPAPI) y credencial cifrada en Jenkins; usuarios `admin` y `lector`. | Implementado |
| Entrega continua a QA: Firebase App Distribution | Publicación de la imagen versionada en un registro (Docker Hub o local). | Implementado |
| Trazabilidad entre commit, compilación y versión | Etiquetas `1.0.<n>` y `<rama>-<commit>-<n>`, etiquetas OCI y `/health` con versión y commit. | Implementado |
| Resumen de cada ejecución | Página Resumen con veredicto, qué arreglar y calidad frente a los topes, más una línea por ejecución. | Implementado |
| Avisos ante fallas | Avisos de Windows cuando una rama o las pruebas en vivo fallan o se arreglan. | Implementado |
| Pruebas nocturnas en emulador | Job `pruebas-en-vivo` cada noche contra la última imagen publicada; prueba de humo en cada ejecución. | Implementado |
| Publicación en tiendas con aprobación explícita | Stage `Desplegar` con aprobación (`input`); la aplicación al clúster se agrega en la fase 2. | Parcial; fase 2 |
| Monitoreo: Firebase Crashlytics | Métricas y alertas sobre `/health` y el comportamiento del servicio. | Fase 3 |
| Planeación: tablero Kanban y tickets con criterios | Plantilla de historia de usuario con criterios de aceptación en GitHub Issues. | Implementado |

La firma del APK y la distribución por tiendas son propias de la aplicación móvil; en el servicio web, su función la cumplen la publicación de la imagen y el despliegue en Kubernetes.

El laboratorio también conserva el flujo operativo definido en la Actividad 2: el cambio se desarrolla en una rama, la integración continua lo valida antes de la revisión por pares, la entrega continua construye y publica un artefacto versionado tras la fusión y, en las fases siguientes, el despliegue y el monitoreo cierran el ciclo de retroalimentación.

### 2.3 Cambios frente a la arquitectura propuesta y su justificación

El diseño de la Actividad 2 se tomó como punto de partida y no como una especificación cerrada. Al llevarlo a la práctica se hicieron los siguientes cambios:

| Propuesta (Actividad 2) | Implementación | Motivo del cambio |
| --- | --- | --- |
| Aplicación móvil en Kotlin Multiplatform, alojada en GitLab | Servicio web en Node.js alojado en GitHub | El proyecto del curso exige una aplicación web en GitHub que en las fases siguientes se despliegue en Kubernetes. Los principios de la propuesta se mantienen sobre un servicio del mismo dominio. |
| OWASP Dependency-Check para las dependencias | Trivy, más `npm audit` y Dependabot | Dependency-Check necesita una clave de la API del NVD y descargar su base completa en cada entorno, lo que hace lenta y frágil la ejecución en GitHub Actions. Trivy cubre con una sola herramienta las dependencias, la configuración del Dockerfile y la imagen final, no requiere cuenta y es la herramienta usada como referencia en el curso. |
| Análisis estático con los analizadores del proyecto móvil | ESLint y SonarQube Community Build | ESLint detecta errores de programación, pero no reglas de seguridad como credenciales escritas en el código. SonarQube agrega esa revisión y la medición de cobertura y mantenibilidad. Se ejecuta como un contenedor temporal en lugar de SonarCloud o un servidor permanente, para no depender de cuentas externas ni generar costos. |
| Migración de Jenkins a un servidor en la nube | Jenkins en Docker en el equipo local, publicado solo en `127.0.0.1` | El laboratorio se limita a herramientas gratuitas (`ci/revisar-costos.sh` lo verifica en cada ejecución). La definición como código (JCasC y Docker Compose) permite trasladar Jenkins a un servidor sin cambios en el pipeline cuando el proyecto lo requiera. |
| Firebase App Distribution y Fastlane | Publicación de la imagen versionada en un registro | Son herramientas de distribución de aplicaciones móviles; en un servicio web, su función la cumple el registro de imágenes. |
| Firebase Crashlytics | Endpoint `/health`, base para el monitoreo de la fase 3 | El monitoreo corresponde a la tercera fase del proyecto. |

## 3. Aplicación

API desarrollada en Node.js 24 con Express que expone un catálogo de cursos:

| Endpoint | Respuesta |
| --- | --- |
| `GET /` | Página de inicio |
| `GET /health` | Estado de la aplicación, versión y commit de la imagen en ejecución |
| `GET /api/cursos` | Listado de cursos |
| `GET /api/cursos/:id` | Detalle de un curso, o código 404 si no existe |

## 4. Herramientas y justificación

| Herramienta | Uso | Justificación |
| --- | --- | --- |
| GitHub | Repositorio, pull requests e historias de usuario | Centraliza el código fuente, la revisión de cambios y los requerimientos. |
| GitHub Actions | CI | Está integrado al repositorio, se configura mediante un archivo YAML y no requiere infraestructura propia. |
| Jenkins (multibranch) | CI/CD por rama | Ofrece control sobre el entorno de construcción y publicación; su configuración se versiona con JCasC. |
| Warnings Next Generation y JUnit | Topes de calidad y resultados | Aplican los topes, distinguen avisos nuevos de los existentes y muestran tendencias. |
| Docker | Empaquetado y herramientas | Garantiza que la aplicación y las herramientas se ejecuten igual en cualquier entorno. |
| Docker Hub o Docker Registry (`registry:2`) | Registro de imágenes | Docker Hub es público; el registro local implementa el mismo protocolo sin depender de una cuenta externa. |
| ESLint | Análisis estático | Identifica errores y malas prácticas antes de la ejecución del código. |
| SonarQube Community Build | Análisis estático de calidad y seguridad | Detecta bugs, vulnerabilidades (por ejemplo, contraseñas escritas en el código) y code smells, y calcula la cobertura. Se levanta en un contenedor temporal en cada ejecución, sin cuentas ni costos. |
| Trivy | Seguridad de dependencias, Dockerfile e imagen | Escanea `package-lock.json`, la configuración del Dockerfile y los paquetes de la imagen construida contra bases de vulnerabilidades conocidas; falla con hallazgos altos o críticos que tengan corrección. |
| `node:test` | Pruebas y cobertura | Ejecutor nativo de Node.js con reportes JUnit y LCOV; no incorpora dependencias adicionales. |
| Gitleaks | Seguridad | Detecta secretos en todo el historial de Git. |
| `npm audit` y Dependabot | Seguridad | Identifican vulnerabilidades conocidas y proponen actualizaciones de dependencias. |
| Administrador de credenciales de Windows | Secretos | Cifra los secretos con DPAPI, fuera del repositorio y de los archivos de configuración. |

## 5. Pipeline de CI: GitHub Actions

Archivo: `.github/workflows/ci.yml`. Se ejecuta en cada `push` (en todas las ramas) y en cada `pull_request`, con las mismas reglas que Jenkins, organizado en tres jobs:

| Job | Pasos | Frena la ejecución si… |
| --- | --- | --- |
| Calidad (pruebas y SonarQube) | Checkout, revisión de costos, Node.js 24, `npm ci`, ESLint, pruebas con cobertura, análisis con SonarQube (`ci/sonarqube.sh`) y comparación con los topes (`ci/revisar-sonarqube.js`). | Falla una prueba, la cobertura baja del mínimo o SonarQube supera un tope. |
| Seguridad (secretos y dependencias) | Gitleaks sobre todo el historial, `npm audit` de las dependencias de producción y Trivy sobre las dependencias y el Dockerfile (`ci/trivy.sh fs`). Las tres revisiones se ejecutan aunque una falle, para reportar todos los hallazgos. | Hay secretos o vulnerabilidades altas o críticas. |
| Imagen Docker (construcción y Trivy) | Construye la imagen final y la escanea con Trivy (`ci/trivy.sh imagen`). Solo corre si los dos jobs anteriores pasan. | La imagen tiene vulnerabilidades altas o críticas con corrección. |

Cada job guarda sus reportes como artefacto de la ejecución (JUnit, LCOV, SonarQube, npm audit, Trivy y Gitleaks). Si alguno falla, el commit o el pull request se marca como fallido en GitHub y su autor recibe la notificación.

**SonarQube sin cuentas.** `ci/sonarqube.sh` inicia un servidor SonarQube Community Build en un contenedor, espera a que esté disponible, crea un token de análisis, ejecuta `sonar-scanner` con la configuración de `sonar-project.properties` (incluida la cobertura de `reportes/lcov.info`) y descarga las medidas, los hallazgos y los Security Hotspots. Al terminar elimina el servidor. El mismo script funciona en GitHub Actions y en Jenkins.

**Hallazgo real durante la implementación.** En su primera ejecución, Trivy encontró 6 vulnerabilidades altas en la imagen. No estaban en las dependencias de la aplicación, sino en el `npm` que incluye la imagen base de Node.js. Como la aplicación no usa `npm` en ejecución, la etapa final del Dockerfile lo retira junto con `npx` y `corepack`, lo que elimina los hallazgos y reduce la superficie de ataque de la imagen.

## 6. Pipeline de CI/CD: Jenkins

Archivo: `Jenkinsfile`, ejecutado por el job multibranch `catalogo-cursos` para cada rama con commits nuevos. Todas las ramas se validan, se construyen y se prueban; solo `main` publica la imagen.

| Stage | Descripción | Frena la ejecución si… |
| --- | --- | --- |
| Revisar costos | Plugins aprobados, sin agentes en la nube, Jenkins solo en `127.0.0.1` e imágenes base esperadas. | Aparece algo que pueda generar costos o exponer Jenkins. |
| Instalar dependencias | `npm ci` en un contenedor de Node.js 24 que comparte el workspace (`ci/en-node.sh`). | Falla la instalación. |
| Calidad y seguridad (en paralelo) | ESLint, Gitleaks sobre el historial, `npm audit` de las dependencias de producción y Trivy sobre las dependencias y el Dockerfile. | Hay secretos o vulnerabilidades altas; los avisos de ESLint se evalúan contra su tope. |
| Pruebas y cobertura | `node:test` con reportes JUnit y LCOV; `ci/revisar-cobertura.js` compara con el mínimo. | Falla una prueba o la cobertura baja del mínimo. |
| Análisis estático (SonarQube) | `ci/sonarqube.sh` con la cobertura de la etapa anterior y `ci/revisar-sonarqube.js`. | Hay bugs, vulnerabilidades, Security Hotspots o code smells por encima de su tope. |
| Construir imagen Docker | Imagen con versión, commit y etiquetas OCI. | Falla la construcción. |
| Escanear imagen (Trivy) | `ci/trivy.sh imagen` sobre la imagen recién construida. | Tiene vulnerabilidades altas o críticas con corrección. |
| Prueba de humo | Arranca la imagen y comprueba `/health` (versión y commit esperados) y `/api/cursos`. | La imagen no responde como se espera. |
| Publicar imagen en el registro | Solo `main`: etiquetas `1.0.<n>`, `<rama>-<commit>-<n>` y `latest`. | Falla la publicación. |
| Desplegar | Solo `main` con el parámetro `DESPLEGAR`: solicita una aprobación explícita. | No se aprueba. |

Al finalizar, Jenkins registra los avisos de ESLint y de Gitleaks con sus quality gates, publica la página Resumen, archiva los reportes y cierra la sesión del registro.

### Topes de calidad

Los topes de `ci/topes-calidad.properties` (0 avisos de ESLint, 100 % de cobertura de líneas y, en SonarQube, 0 bugs, 0 vulnerabilidades, 0 Security Hotspots y 0 code smells) funcionan como un trinquete: la ejecución falla si un número empeora y, cuando un cambio lo mejora, el tope se ajusta en el mismo commit. Además, cada rama se compara con la última ejecución de `main` (`discoverReferenceBuild`) y falla con un solo aviso nuevo, aunque el total siga dentro del tope.

### Página Resumen

Cada ejecución publica la pestaña Resumen (`ci/resumen/generar.js`) con el veredicto, la lista de qué arreglar y la calidad frente a los topes, y deja una línea por ejecución en la lista del job, por ejemplo `4284927 · Imagen publicada en el registro · 5 pruebas · 100,0 %`.

### Pruebas en vivo

El job `pruebas-en-vivo` (`ci/PruebasEnVivo.Jenkinsfile`) se ejecuta cada noche y a demanda: descarga la última imagen publicada, la arranca y ejecuta contra ella las pruebas de `test/en-vivo/`. La descripción de cada ejecución registra la versión y el commit de la imagen probada.

### Dockerfile multietapa

- **`test`:** instala todas las dependencias y ejecuta el análisis estático y las pruebas, de modo que el código puede validarse con Docker como único requisito.
- **`runtime`:** imagen final, con dependencias de producción únicamente, ejecutada con el usuario `node` (sin privilegios de root), con la versión y el commit como variables y etiquetas OCI, y un `HEALTHCHECK` sobre `/health`.

### Jenkins como código, secretos y avisos

- `Dockerfile` y `plugins.txt`: imagen oficial de Jenkins con el cliente de Docker y los plugins aprobados.
- `casc.yaml`: usuarios `admin` y `lector` con permisos por usuario (`matrix-auth`), credencial de Docker Hub y los jobs `catalogo-cursos` (multibranch) y `pruebas-en-vivo`, generados con Job DSL.
- `docker-compose.yml`: Jenkins y el registro local publicados solo en `127.0.0.1`, con un nombre de proyecto propio (`lab-cicd`).
- `secretos/` y `arrancar-jenkins.ps1`: los secretos se guardan en el Administrador de credenciales de Windows y se entregan a Docker Compose solo en memoria.
- `avisos/`: tarea programada que muestra un aviso de Windows cuando una ejecución falla o se arregla.

## 7. Demostración: el pipeline detecta una vulnerabilidad intencional

Para comprobar que los controles de seguridad funcionan, la rama `demo/vulnerabilidad-intencional` introduce dos problemas a propósito y se propone a `main` mediante el pull request #6, que **no se fusiona**:

1. La dependencia `lodash 4.17.15`, con vulnerabilidades conocidas.
2. Una contraseña escrita en `src/app.js` (`ADMIN_PASSWORD`), usada por un endpoint de administración.

| Herramienta | Resultado |
| --- | --- |
| `npm audit` | 1 vulnerabilidad alta en lodash. |
| Trivy | 4 vulnerabilidades altas en lodash 4.17.15, entre ellas CVE-2020-8203 (prototype pollution) y CVE-2021-23337 (inyección de comandos). |
| SonarQube | `src/app.js:9`: posible contraseña escrita en el código (regla `javascript:S2068`); supera el tope de 0 vulnerabilidades. |
| Gitleaks | No la detecta: su regla genérica no clasifica este valor como secreto. |

Los jobs de calidad y de seguridad fallan, el de imagen no se ejecuta y el pull request queda marcado como fallido, de modo que el cambio no llega a `main`. El resultado de Gitleaks muestra por qué la arquitectura combina varias herramientas: cada una cubre un tipo de riesgo distinto y ninguna basta por sí sola.

## 8. Evidencias

| Evidencia | Archivo |
| --- | --- |
| Ejecución del pipeline de CI en GitHub Actions (tres jobs en verde) | `docs/capturas/github-actions.png` |
| Resultado de SonarQube frente a los topes | `docs/capturas/sonarqube.png` |
| Escaneo de la imagen con Trivy | `docs/capturas/trivy-imagen.png` |
| Pull request de demostración bloqueado por el pipeline | `docs/capturas/demo-pr-bloqueado.png` |
| Hallazgos de la demostración en SonarQube y Trivy | `docs/capturas/demo-sonarqube.png` y `docs/capturas/demo-trivy.png` |
| Vista de stages del pipeline en Jenkins (`main`) | `docs/capturas/jenkins.png` |
| Ramas del job multibranch (incluida una rama detenida por la revisión de costos) | `docs/capturas/jenkins-ramas.png` |
| Página Resumen de una ejecución exitosa | `docs/capturas/resumen-exito.png` |
| Página Resumen de una ejecución que falla por los topes | `docs/capturas/resumen-fallo.png` |
| Pruebas en vivo sobre la imagen publicada | `docs/capturas/pruebas-en-vivo.png` |
| Trazabilidad de la imagen publicada (etiquetas OCI y `/health`) | `docs/capturas/trazabilidad.png` |
| Imagen publicada en el registro | `docs/capturas/registro-local.png` |

## 9. Próximas fases del proyecto

| Fase del curso | Alcance | Continuidad con la Actividad 2 |
| --- | --- | --- |
| Fase 2: Kubernetes | Manifiestos de Kubernetes aplicados desde el stage `Desplegar`, que ya exige aprobación, y escaneo de esos manifiestos con Trivy. | Completa el paso controlado a producción. |
| Fase 3: monitoreo | Métricas y alertas sobre el endpoint `/health` y el comportamiento del servicio en el clúster. | Equivale, para el servicio web, al monitoreo propuesto con Firebase Crashlytics. |

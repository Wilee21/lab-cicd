// Pipeline de CI/CD del catálogo de cursos (job multibranch "catalogo-cursos" de jenkins/casc.yaml).
// Corre en cada rama con commits nuevos. Valida, construye y prueba la imagen en todas las ramas; solo
// main publica en el registro y, con aprobación explícita, despliega.
//
// Qué frena la ejecución: la revisión de costos, un secreto en el historial (Gitleaks), una dependencia
// de producción con vulnerabilidades altas o críticas, una prueba que falla, la cobertura bajo su mínimo,
// más avisos de ESLint que su tope o cualquier aviso NUEVO respecto a la última ejecución de main, y una
// prueba de humo fallida sobre la imagen construida. Los topes están en ci/topes-calidad.properties.
def topes = [:]

pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    booleanParam(name: 'DESPLEGAR', defaultValue: false,
      description: 'Solo en main: solicita la aprobación para desplegar la imagen publicada.')
  }

  environment {
    REGISTRO = "${env.REGISTRY_HOST ?: 'docker.io'}"
    IMAGEN = "${env.REGISTRY_HOST ?: 'docker.io'}/${env.DOCKERHUB_USER}/catalogo-cursos"
  }

  stages {
    stage('Revisar costos') {
      steps {
        // La salida queda en reportes/ para que la página Resumen muestre el motivo exacto.
        sh 'mkdir -p reportes && sh ci/revisar-costos.sh > reportes/costos.txt 2>&1; s=$?; cat reportes/costos.txt; exit $s'
        script {
          topes = leerTopes(readFile('ci/topes-calidad.properties'))
          echo "Topes de calidad: ${topes}"
          // Trazabilidad: versión, etiqueta con rama, commit y ejecución, y el commit en la descripción.
          env.SHA7 = env.GIT_COMMIT.take(7)
          def rama = env.BRANCH_NAME.replaceAll('[^A-Za-z0-9._-]', '-').toLowerCase()
          env.VERSION = env.BRANCH_NAME == 'main' ? "1.0.${env.BUILD_NUMBER}" : "1.0.${env.BUILD_NUMBER}-${rama}"
          env.ETIQUETA = "${rama}-${env.SHA7}-${env.BUILD_NUMBER}"
          currentBuild.description = "${env.SHA7} · en curso"
        }
        sh 'git log -1 --format="%h %an: %s"'
      }
    }

    stage('Instalar dependencias') {
      steps {
        sh 'sh ci/en-node.sh "npm ci --no-audit --no-fund"'
      }
    }

    stage('Calidad y seguridad') {
      parallel {
        stage('ESLint') {
          steps {
            // ESLint solo deja su reporte; los topes los aplica Jenkins al registrar los avisos (post).
            sh 'sh ci/en-node.sh "npx eslint . --format json --output-file reportes/eslint.json || true; node ci/eslint-a-issues.js"'
          }
        }
        stage('Secretos (Gitleaks)') {
          steps {
            sh 'sh ci/gitleaks.sh'
          }
        }
        stage('Dependencias (npm audit)') {
          steps {
            sh 'sh ci/en-node.sh "npm audit --omit=dev --audit-level=high" > reportes/npm-audit.txt 2>&1; s=$?; cat reportes/npm-audit.txt; exit $s'
          }
        }
      }
    }

    stage('Pruebas y cobertura') {
      steps {
        sh 'sh ci/en-node.sh "npm run -s test:cobertura && node ci/revisar-cobertura.js"'
      }
      post {
        always {
          junit(allowEmptyResults: true, testResults: 'reportes/junit.xml')
        }
      }
    }

    stage('Construir imagen Docker') {
      steps {
        sh '''
          docker build --target runtime \
            --build-arg APP_VERSION="$VERSION" \
            --build-arg GIT_COMMIT="$GIT_COMMIT" \
            --label org.opencontainers.image.source="$GIT_URL" \
            -t "$IMAGEN:$VERSION" -t "$IMAGEN:$ETIQUETA" .
        '''
      }
    }

    stage('Prueba de humo') {
      // Arranca la imagen recién construida y comprueba que responde con la versión y el commit esperados.
      steps {
        sh '''
          docker run -d --name "humo-$ETIQUETA" "$IMAGEN:$VERSION"
          for intento in $(seq 1 20); do
            docker exec "humo-$ETIQUETA" wget -qO- http://localhost:3000/health > reportes/humo-health.json 2>/dev/null && break
            sleep 1
          done
          cat reportes/humo-health.json
          grep -q "\\"version\\":\\"$VERSION\\"" reportes/humo-health.json
          grep -q "\\"commit\\":\\"$GIT_COMMIT\\"" reportes/humo-health.json
          docker exec "humo-$ETIQUETA" wget -qO- http://localhost:3000/api/cursos | grep -q '"nombre"'
          echo "Prueba de humo: la imagen responde con la versión $VERSION y el commit $SHA7."
        '''
      }
      post {
        always {
          sh 'docker rm -f "humo-$ETIQUETA" >/dev/null 2>&1 || true'
        }
      }
    }

    stage('Publicar imagen en el registro') {
      when { branch 'main' }
      steps {
        script {
          def publicar = '''
            docker tag "$IMAGEN:$VERSION" "$IMAGEN:latest"
            docker push "$IMAGEN:$VERSION"
            docker push "$IMAGEN:$ETIQUETA"
            docker push "$IMAGEN:latest"
          '''
          if (env.REGISTRO.startsWith('localhost')) {
            // Registro local del laboratorio: no requiere autenticación.
            sh publicar
          } else {
            withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
              sh 'echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin "$REGISTRO"'
              sh publicar
            }
          }
        }
      }
    }

    stage('Desplegar') {
      // Fase 2 del proyecto: aplicar los manifiestos al clúster. El paso a producción requiere una
      // aprobación explícita, como en la arquitectura de la Actividad 2.
      when {
        allOf {
          branch 'main'
          expression { params.DESPLEGAR }
        }
      }
      steps {
        input message: "¿Aprobar el despliegue de ${env.IMAGEN}:${env.VERSION}?", ok: 'Aprobar'
        echo "Despliegue aprobado para ${env.IMAGEN}:${env.VERSION}. La aplicación al clúster se agrega en la fase 2."
      }
    }
  }

  post {
    always {
      script {
        if (!topes) {
          topes = fileExists('ci/topes-calidad.properties') ? leerTopes(readFile('ci/topes-calidad.properties')) : [:]
        }
        // Referencia para separar los avisos nuevos de los existentes: la última ejecución de main.
        discoverReferenceBuild(referenceJob: "${env.JOB_NAME.split('/')[0]}/main")
        def frenos = []
        def revisar = { nombre, cuerpo ->
          def antes = currentBuild.currentResult
          cuerpo()
          if (antes != 'FAILURE' && currentBuild.currentResult == 'FAILURE') {
            frenos << nombre
          }
        }
        revisar('ESLint') {
          recordIssues(id: 'eslint', name: 'ESLint', skipBlames: true, enabledForFailure: true,
            tool: issues(pattern: 'reportes/eslint-issues.json', id: 'eslint', name: 'ESLint'),
            qualityGates: tope(topes.eslint))
        }
        revisar('Gitleaks') {
          recordIssues(id: 'gitleaks', name: 'Secretos (Gitleaks)', skipBlames: true, enabledForFailure: true,
            tool: sarif(pattern: 'reportes/gitleaks.sarif', id: 'gitleaks', name: 'Gitleaks'),
            qualityGates: [[threshold: 1, type: 'TOTAL', criticality: 'FAILURE']])
        }
        env.FRENOS = frenos.join(';')
      }
      // Página "Resumen" y la línea de la lista de ejecuciones.
      withEnv(["RESULTADO=${currentBuild.currentResult}", "RAMA=${env.BRANCH_NAME}",
               'PASAR_VARIABLES=RESULTADO RAMA BUILD_NUMBER GIT_COMMIT VERSION ETIQUETA IMAGEN FRENOS BUILD_URL']) {
        sh 'sh ci/en-node.sh "node ci/resumen/generar.js" || true'
      }
      script {
        if (fileExists('reportes/resumen/index.html')) {
          publishHTML(target: [
            reportName: 'Resumen', reportTitles: 'Resumen de la ejecución',
            reportDir: 'reportes/resumen', reportFiles: 'index.html',
            keepAll: true, alwaysLinkToLastBuild: true, allowMissing: true
          ])
          currentBuild.description = readFile(file: 'reportes/resumen/descripcion.txt', encoding: 'UTF-8').trim()
        }
      }
      archiveArtifacts(artifacts: 'reportes/**', allowEmptyArchive: true)
      sh 'docker logout "$REGISTRO" >/dev/null 2>&1 || true'
    }
  }
}

// Lee "clave=número" de ci/topes-calidad.properties (sin comentarios ni líneas vacías).
def leerTopes(texto) {
  def mapa = [:]
  texto.readLines().each { linea ->
    def l = linea.trim()
    if (l && !l.startsWith('#') && l.contains('=')) {
      def partes = l.split('=', 2)
      mapa[partes[0].trim()] = partes[1].trim()
    }
  }
  return mapa
}

// Quality gates de Warnings Next Generation: falla con un solo aviso nuevo respecto a main, o con uno
// más que el tope (red de seguridad cuando todavía no hay ejecución de referencia).
def tope(maximo) {
  def gates = [[threshold: 1, type: 'NEW', criticality: 'FAILURE']]
  if (maximo != null) {
    gates << [threshold: (maximo as int) + 1, type: 'TOTAL', criticality: 'FAILURE']
  }
  return gates
}

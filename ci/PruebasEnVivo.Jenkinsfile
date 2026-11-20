// Pruebas en vivo (job "pruebas-en-vivo" de jenkins/casc.yaml, cada noche y a demanda).
// No prueba el código del repositorio, sino la última imagen publicada en el registro: la descarga, la
// arranca y ejecuta contra ella las pruebas de test/en-vivo/. Detecta problemas que solo aparecen en el
// artefacto ya publicado (una imagen incompleta, una variable faltante o un error al arrancar).
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 15, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  parameters {
    string(name: 'ETIQUETA', defaultValue: 'latest', description: 'Etiqueta de la imagen que se va a probar.')
  }

  environment {
    IMAGEN = "${env.REGISTRY_HOST ?: 'docker.io'}/${env.DOCKERHUB_USER}/catalogo-cursos"
    CONTENEDOR = "en-vivo-${env.BUILD_NUMBER}"
    // En la primera ejecución los parámetros aún no existen (Jenkins los registra al leer este archivo).
    ETIQUETA_IMAGEN = "${params.ETIQUETA ?: 'latest'}"
  }

  stages {
    stage('Descargar y arrancar la imagen') {
      steps {
        sh '''
          mkdir -p reportes
          docker pull "$IMAGEN:$ETIQUETA_IMAGEN"
          docker run -d --name "$CONTENEDOR" "$IMAGEN:$ETIQUETA_IMAGEN"
          for intento in $(seq 1 20); do
            docker exec "$CONTENEDOR" wget -qO- http://localhost:3000/health > reportes/health.json 2>/dev/null && break
            sleep 1
          done
          cat reportes/health.json
        '''
        script {
          def campo = { nombre -> sh(returnStdout: true, script: "sed -n 's/.*\"${nombre}\":\"\\([^\"]*\\)\".*/\\1/p' reportes/health.json").trim() }
          currentBuild.description = "${env.ETIQUETA_IMAGEN} · versión ${campo('version')} · commit ${campo('commit').take(7)}"
        }
      }
    }

    stage('Pruebas en vivo') {
      steps {
        // El contenedor de Node comparte la red del servicio: la API responde en localhost:3000.
        sh '''
          docker run --rm --volumes-from "$HOSTNAME" -w "$PWD" -u "$(id -u):$(id -g)" \
            --network "container:$CONTENEDOR" -e BASE_URL=http://localhost:3000 \
            node:24-alpine sh -c "npm run -s test:en-vivo"
        '''
      }
    }
  }

  post {
    always {
      junit(allowEmptyResults: true, testResults: 'reportes/junit-en-vivo.xml')
      sh 'docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true'
    }
  }
}

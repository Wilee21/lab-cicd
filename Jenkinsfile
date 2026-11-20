// Pipeline de entrega continua (CD). Corre en el Jenkins de la carpeta jenkins/.
// Publica en el registro de REGISTRY_HOST: "docker.io" (Docker Hub) o "localhost:5000" (registro local
// de docker-compose, sin cuenta). Docker Hub usa la credencial "dockerhub", que JCasC crea desde el .env.
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '15'))
  }

  environment {
    REGISTRO = "${env.REGISTRY_HOST ?: 'docker.io'}"
    IMAGEN = "${env.REGISTRY_HOST ?: 'docker.io'}/${env.DOCKERHUB_USER}/catalogo-cursos"
    VERSION = "1.0.${env.BUILD_NUMBER}"
  }

  stages {
    stage('Clonar repositorio') {
      steps {
        checkout scm
        sh 'git log -1 --oneline'
      }
    }

    stage('Lint y pruebas') {
      steps {
        // Usa la etapa "test" del Dockerfile: no hace falta instalar Node en Jenkins.
        sh 'docker build --target test -t catalogo-cursos:test-${BUILD_NUMBER} .'
      }
    }

    stage('Construir imagen Docker') {
      steps {
        sh '''
          docker build --target runtime \
            --build-arg APP_VERSION=${VERSION} \
            -t ${IMAGEN}:${VERSION} -t ${IMAGEN}:latest .
        '''
      }
    }

    stage('Publicar imagen en el registro') {
      // Solo se publica lo que llega a main (GIT_BRANCH lo define checkout scm: "origin/main").
      when { expression { env.GIT_BRANCH?.endsWith('main') } }
      steps {
        script {
          if (env.REGISTRO.startsWith('localhost')) {
            // Registro local de práctica: no pide usuario ni token.
            sh 'docker push ${IMAGEN}:${VERSION} && docker push ${IMAGEN}:latest'
          } else {
            withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
              sh '''
                echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                docker push ${IMAGEN}:${VERSION}
                docker push ${IMAGEN}:latest
              '''
            }
          }
        }
      }
    }

    stage('Desplegar') {
      // Fase 2 del proyecto: aplicar los manifiestos de Kubernetes con la nueva versión.
      steps {
        echo "Imagen lista para desplegar: ${IMAGEN}:${VERSION}. El despliegue en Kubernetes se agrega en la fase 2."
      }
    }
  }

  post {
    always {
      sh 'docker logout ${REGISTRO} || true'
      sh 'docker image rm catalogo-cursos:test-${BUILD_NUMBER} || true'
    }
  }
}

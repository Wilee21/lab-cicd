# Imagen de Jenkins del laboratorio: imagen oficial, cliente de Docker y plugins definidos en plugins.txt.
FROM jenkins/jenkins:lts-jdk21
USER root
# Solo se instala el cliente de Docker: los contenedores se ejecutan en el motor del equipo anfitrión (socket montado).
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
USER jenkins
# Se omite el asistente inicial: la configuración completa proviene de casc.yaml.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
# casc.yaml va fuera de /var/jenkins_home: esa carpeta es un volumen persistente y Docker solo copia en él
# el contenido de la imagen la primera vez, por lo que los cambios posteriores no se aplicarían.
ENV CASC_JENKINS_CONFIG=/opt/jenkins-casc/casc.yaml
COPY casc.yaml /opt/jenkins-casc/casc.yaml

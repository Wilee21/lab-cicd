# Jenkins de práctica: imagen oficial + cliente de Docker + plugins fijos en plugins.txt.
FROM jenkins/jenkins:lts-jdk21
USER root
# Solo el cliente de Docker: los contenedores corren en el Docker del equipo (socket montado).
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
USER jenkins
# Sin asistente inicial: toda la configuración viene de casc.yaml.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml

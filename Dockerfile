# Etapa 1: dependencias completas, análisis estático y pruebas. Permite validar el código con Docker
# como único requisito:  docker build --target test .
FROM node:26-alpine AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run lint && npm test

# Etapa 2: imagen final, con dependencias de producción únicamente y sin privilegios de root.
FROM node:26-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
# Trazabilidad: el pipeline fija la versión y el commit; la aplicación los expone en /health y quedan
# también como etiquetas OCI de la imagen (docker inspect).
ARG APP_VERSION=local
ARG GIT_COMMIT=local
ENV APP_VERSION=$APP_VERSION GIT_COMMIT=$GIT_COMMIT
LABEL org.opencontainers.image.title="catalogo-cursos" \
      org.opencontainers.image.version=$APP_VERSION \
      org.opencontainers.image.revision=$GIT_COMMIT
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "src/server.js"]

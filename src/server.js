const { crearApp } = require('./app');

const puerto = Number(process.env.PORT) || 3000;
crearApp().listen(puerto, () => console.log(`Catálogo de cursos escuchando en el puerto ${puerto}`));

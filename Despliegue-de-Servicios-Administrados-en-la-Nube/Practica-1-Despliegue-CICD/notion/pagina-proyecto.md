# Práctica CI/CD con GitHub Actions

## Resumen

Web de login con un pipeline completo: lint y tests en cada push, publicación en GitHub Pages y copia automática a un bucket de Amazon S3.

## Enlaces

- Repositorio: https://github.com/PauLopNun/login-app-cicd
- GitHub Pages: https://paulopnun.github.io/login-app-cicd/
- Sitio web en S3: http://login-cicd-paulopez-2627.s3-website-us-east-1.amazonaws.com/
- Repositorio del curso: https://github.com/PauLopNun/curso-servicios-nube

## Flujo de ramas

- `main`: producción, solo recibe merges tras pasar el CI.
- `develop`: integración.
- `feature/*` y `fix/*`: se borran tras el merge.

## Pipeline

1. Push a `develop` o `main`: CI con html-validate, stylelint, ESLint y Jest.
2. CI en verde en `main`: despliegue en GitHub Pages.
3. Push a `main`: `s3.yml` copia la web al bucket con `aws s3 sync --delete`.

## Seguridad

Las credenciales de AWS están solo en los Secrets del repositorio. Con AWS Academy caducan al cerrar el laboratorio y hay que renovarlas.

## Cómo importarlo en Notion

Importar `tablero-tareas.csv` crea una base de datos que se puede ver como tablero agrupando por Estado.

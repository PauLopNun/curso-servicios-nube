<div align="center">

# Práctica 1 - Despliegue con CI/CD

![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-222222?style=for-the-badge&logo=githubpages&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon%20S3-569A31?style=for-the-badge&logo=amazons3&logoColor=white)
![Jest](https://img.shields.io/badge/Jest-C21325?style=for-the-badge&logo=jest&logoColor=white)

**UP de Despliegue de servicios administrados en la nube**

</div>

## Dónde está el código

El código de esta práctica está en su **propio repositorio**, porque el pipeline de GitHub Actions necesita tener los workflows en la raíz y quedaba mejor separado del resto del curso:

**https://github.com/PauLopNun/login-app-cicd**

En esta carpeta del curso queda el enunciado, las capturas de la entrega y la primera versión de la app.

| Enlace | Dirección |
|:--|:--|
| Repositorio | https://github.com/PauLopNun/login-app-cicd |
| Web en GitHub Pages | https://paulopnun.github.io/login-app-cicd/ |
| Web en S3 | http://login-cicd-paulopez-2627.s3-website-us-east-1.amazonaws.com/ |

## Qué se pide

El enunciado ([PDF](material/enunciado-cicd-github-actions-s3.pdf)) parte de una página de login ya hecha y pide montar un ciclo completo de integración y despliegue continuo:

1. Subir el proyecto a GitHub y organizar las ramas (`main` y `develop`).
2. Un workflow de CI que revise el código (HTML, CSS y JavaScript) y pase los tests con Jest.
3. Despliegue automático en GitHub Pages cuando el CI termina bien.
4. Tarea final: un workflow que copie los archivos a un bucket de Amazon S3 en cada push a `main`, guardando las credenciales en los Secrets de GitHub.
5. Ampliación opcional: servir la web directamente desde S3 como sitio estático.

## Qué se ha hecho

- Repositorio `login-app-cicd` con las ramas `main` y `develop`.
- `ci.yml`: html-validate, stylelint, ESLint y 6 tests de Jest. Hubo que ajustar el CSS y las configuraciones de los linters hasta dejarlo en verde.
- `deploy-pages.yml`: publicación en GitHub Pages después de un CI correcto.
- `s3.yml`: `aws s3 sync` con `--delete` y exclusiones, con los cinco Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION` y `S3_BUCKET`).
- Bucket `login-cicd-paulopez-2627` en `us-east-1`, creado con el acceso público bloqueado.
- Ampliación: alojamiento de sitio web estático en el bucket, con una política de solo lectura.
- Tres pushes a `main` comprobando que el bucket se actualiza (cambios en el texto del botón de login).
- Documentación del proyecto en Notion.

Como se usa AWS Academy, las credenciales caducan al cerrar el laboratorio y los Secrets hay que renovarlos en cada sesión.

## Entrega

Documento para entregar: [`entrega/cicd_p1_lopez_nunez.docx`](entrega/cicd_p1_lopez_nunez.docx), con las capturas, el `s3.yml` y los enlaces. El workflow suelto está en [`entrega/s3.yml`](entrega/s3.yml).

El detalle de cada entregable del enunciado:

| Pide el enunciado | Dónde está |
|:--|:--|
| Captura del bucket creado | [`capturas/04-bucket-antes.jpg`](capturas/04-bucket-antes.jpg) |
| Captura de los Secrets (solo nombres) | [`capturas/01-secrets-github.jpg`](capturas/01-secrets-github.jpg) |
| `s3.yml` y ejecución correcta en Actions | [`capturas/03-s3-yml.jpg`](capturas/03-s3-yml.jpg), [`capturas/02-actions-copia-a-s3.jpg`](capturas/02-actions-copia-a-s3.jpg), [`capturas/06-ejecucion-correcta.jpg`](capturas/06-ejecucion-correcta.jpg) |
| Bucket antes y después de un segundo push con cambios | [`capturas/04-bucket-antes.jpg`](capturas/04-bucket-antes.jpg) y [`capturas/05-bucket-despues.jpg`](capturas/05-bucket-despues.jpg) |
| Ampliación: sitio web estático | [`capturas/07-s3-hosting-web-estatico.jpg`](capturas/07-s3-hosting-web-estatico.jpg) |
| Documentación en Notion | [`capturas/08-notion-pagina.jpg`](capturas/08-notion-pagina.jpg), [`capturas/09-notion-tablero-tareas.jpg`](capturas/09-notion-tablero-tareas.jpg) |

Un resumen en texto de las ejecuciones, los Secrets y el contenido del bucket está en [`evidencias/resumen-ejecucion.md`](evidencias/resumen-ejecucion.md).

## Contenido de esta carpeta

| Ruta | Descripción |
|:--|:--|
| [`entrega/`](entrega) | Documento para entregar y `s3.yml` |
| [`material/`](material) | Enunciado en PDF |
| [`capturas/`](capturas) | Capturas de la entrega |
| [`evidencias/`](evidencias) | Resumen de las ejecuciones |
| [`app/`](app) | Primera versión de la página de login, antes de pasarla al repositorio propio |

La carpeta `app/` tiene su propio workflow en la raíz de este repositorio (`.github/workflows/ci-despliegue-practica-1.yml`), una validación sencilla que se hizo antes de pasar la práctica al repositorio nuevo. Para probar esa versión en local: `cd app && python3 -m http.server 8080` y abrir `http://localhost:8080`.

---

[Volver a la asignatura](../README.md)

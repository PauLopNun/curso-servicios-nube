<div align="center">

# Práctica 1 - Despliegue con CI/CD

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

</div>

## Objetivo

Actividad de prueba de despliegue: una web estática con un formulario de login que se usa como aplicación de ejemplo para montar un flujo de integración y despliegue continuo (CI/CD).

## Aplicación

Formulario de inicio de sesión con validación en el navegador:

- El correo debe tener un formato válido
- La contraseña debe tener al menos 8 caracteres
- Las credenciales se comprueban contra un usuario de demostración definido en `app/js/app.js`
- Admite modo oscuro según la preferencia del sistema

## Probar en local

```bash
cd app
python3 -m http.server 8080
```

Abrir `http://localhost:8080`.

## Integración continua

El workflow [`ci-despliegue-practica-1.yml`](../../.github/workflows/ci-despliegue-practica-1.yml) está en la raíz del repositorio, porque GitHub Actions solo lee los workflows de `.github/workflows/` en la raíz. Con `paths` se ejecuta únicamente cuando cambia algo de esta práctica, y con `working-directory` todos los comandos se lanzan desde esta carpeta. También se puede lanzar a mano desde la pestaña Actions. Tiene dos trabajos:

| Trabajo | Qué comprueba |
|:--|:--|
| `validar` | Valida `index.html` con html-validate y la sintaxis de `app.js` con `node --check` |
| `prueba-humo` | Sirve la web con `python3 -m http.server`, comprueba que la página, el CSS y el JS responden con 200 y que el formulario de login está en la página |

`prueba-humo` solo se ejecuta si `validar` termina bien.

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`app/index.html`](app/index.html) | Página de login |
| [`app/css/style.css`](app/css/style.css) | Estilos |
| [`app/js/app.js`](app/js/app.js) | Validación del formulario y comprobación de credenciales |
| [`../../.github/workflows/ci-despliegue-practica-1.yml`](../../.github/workflows/ci-despliegue-practica-1.yml) | Workflow de integración continua |

---

[Volver a la asignatura](../README.md)

<div align="center">

# Actividad 3.4 - Sitio web estático en Amazon S3

![S3](https://img.shields.io/badge/AWS-S3-569A31?style=for-the-badge&logoColor=white)
![CLI](https://img.shields.io/badge/AWS-CLI-232F3E?style=for-the-badge&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-Canvas-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![Estado](https://img.shields.io/badge/Estado-Completado-brightgreen?style=for-the-badge)

Entregada en Aules como **Tarea 1.7**, junto con la [Práctica 1.8](../Practica-1.8-S3-Access-Points).

</div>

## Objetivo

Desplegar un sitio web estático en Amazon S3 usando la AWS CLI desde Visual Studio Code, configurando el bucket con acceso público y política de bucket adecuada.

## Recursos

- **Bucket S3:** `website-pln-1234`
- **Región:** `us-east-1`
- **URL:** `http://website-pln-1234.s3-website-us-east-1.amazonaws.com`
- **Web:** Pac-Man en HTML5 Canvas (fuente: [luciopanepinto/pacman](https://github.com/luciopanepinto/pacman))

## Pasos realizados

### 1. Crear el bucket S3

```bash
aws s3api create-bucket \
  --bucket website-pln-1234 \
  --region us-east-1
```

### 2. Desactivar Block Public Access

```bash
aws s3api put-public-access-block \
  --bucket website-pln-1234 \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

### 3. Habilitar hosting estático

```bash
aws s3 website s3://website-pln-1234 \
  --index-document index.html \
  --error-document generic.html
```

### 4. Aplicar política de bucket pública

```bash
aws s3api put-bucket-policy \
  --bucket website-pln-1234 \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Principal": "*",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::website-pln-1234/*"
    }]
  }'
```

### 5. Subir el sitio web

```bash
cd website/
aws s3 sync . s3://website-pln-1234
```

### 6. Reto - Crear página `acerca.html`

Página personal con estética arcade retro y fondo de estrellas animado en Canvas, accesible en:

```
http://website-pln-1234.s3-website-us-east-1.amazonaws.com/acerca.html
```

### 7. Re-sincronizar tras cambios

```bash
aws s3 sync . s3://website-pln-1234
```

## Estructura del sitio

```
website/
├── index.html       ← Pac-Man jugable (HTML5 Canvas)
├── acerca.html      ← Página personal (reto)
├── css/             ← Estilos
├── js/              ← Lógica del juego
├── img/             ← Imágenes y controles
└── sound/           ← Audio (no incluido en el repo)
```

## Verificación

```bash
# Comprobar identidad AWS
aws sts get-caller-identity

# Listar buckets
aws s3 ls

# Comprobar contenido del bucket
aws s3 ls s3://website-pln-1234
```

## Contenido

| Ruta | Descripción |
|:--|:--|
| [`scripts/politica-bucket.json`](scripts/politica-bucket.json) | Política de bucket con lectura pública de los objetos |
| [`capturas/`](capturas) | Consola de S3, VS Code, terminal y navegador (incluido el error 403) |
| [`entrega/LopezPau_Tarea1-7_1-8.pdf`](entrega/LopezPau_Tarea1-7_1-8.pdf) | Documento entregado (Tarea 1.7 y extra 1.8) |
| [`enunciado.md`](enunciado.md) | Resumen del enunciado |

---

[Volver a la asignatura](../README.md)

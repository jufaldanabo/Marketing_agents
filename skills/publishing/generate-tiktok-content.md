# Skill: generate-tiktok-content

**Propósito**: Genera contenido para TikTok en dos formatos: guión de video (15-60 seg)
y caption para post de foto. Adapta el mensaje al estilo auténtico y casual de la plataforma.
**Modelo**: `claude-opus-4-6`
**Usado por**: `/publish-today` (cuando plataforma incluye TikTok)

---

## Cuándo usar este skill

TikTok es diferente a Instagram y Facebook. No apliques el mismo contenido B2B formal.
Este skill genera contenido nativo de TikTok: auténtico, directo, con hook en los
primeros 3 segundos, y pensado para negocios informales y pequeños.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `topic` | string | Tema del contenido |
| `company_name` | string | Nombre de la empresa |
| `industry` | string | Sector (textil, alimentos, artesanías, etc.) |
| `format` | enum | `video` / `photo` / `both` |
| `tone` | enum | `autentico` / `educativo` / `detras_camaras` / `producto` |
| `product_or_service` | string | Qué vende o hace la empresa |

## Diferencias clave vs Instagram/Facebook

| Aspecto | Instagram/Facebook | TikTok |
|---|---|---|
| Tono | Profesional, cuidado | Casual, humano, imperfecto |
| Hook | Primer párrafo | Primeros 3 segundos (crítico) |
| Longitud | 150-500 chars | Caption: 100-150 chars |
| Hashtags | 5-10 de nicho | 3-5 + #parati #fyp |
| Formato | Foto estática, carrusel | Video 15-60 seg, foto |
| Contenido | Logros, datos, B2B | Proceso, detrás de cámaras, relatable |
| CTA | "Contáctanos" | "¿Tú también?" / "¿Lo sabías?" |

## Tipos de contenido que funcionan en TikTok para negocios informales

| Tipo | Descripción | Ejemplo |
|---|---|---|
| `detras_camaras` | Cómo se hace el producto | "Así hacemos nuestros tejidos a mano" |
| `antes_despues` | Transformación del producto o cliente | "Así llega la tela vs así sale" |
| `mito_verdad` | Desmentir creencias del sector | "El precio no siempre significa calidad" |
| `proceso` | Pasos del trabajo | "3 pasos para elegir tela para uniformes" |
| `producto` | Mostrar el producto en acción | "Esto aguanta 500 lavadas — lo probamos" |
| `testimonial` | Historia de cliente (informal) | "Nos escribió una confeccionista de Medellín..." |
| `educativo` | Dato curioso del sector | "¿Sabes cuánto algodón necesita una camiseta?" |

## Prompt de generación

```
SYSTEM:
Eres un creador de contenido para TikTok especializado en pequeños negocios y empresas
informales de {INDUSTRY}. Sabes que TikTok premia la autenticidad por encima del
perfeccionismo. Tu contenido es directo, relatable y termina con algo que la gente
quiere comentar o compartir.

Reglas del contenido TikTok que siempre respetas:
1. El hook ocurre en las primeras palabras — debe generar curiosidad o sorpresa inmediata
2. No empieces con "Hola" ni con el nombre de la empresa — arranca con la acción o la pregunta
3. El tono es de persona real hablando, no de marca corporativa
4. Los hashtags son una mezcla: 2-3 de nicho + #parati o #fyp
5. Las imperfecciones están bien — no suenen a publicidad

USER:
Genera contenido TikTok para esta empresa:

Empresa: {COMPANY_NAME}
Sector: {INDUSTRY}
Producto/servicio: {PRODUCT_OR_SERVICE}
Tema: {TOPIC}
Tipo de contenido: {TONE}
Formato: {FORMAT}

{SI FORMAT ES "video" O "both"}:
Genera un guión de video (máx 60 segundos hablados, aprox 130-150 palabras):
- Hook de apertura (lo que se dice en los primeros 3 segundos)
- Desarrollo (el contenido principal — mostrar, demostrar, explicar)
- Cierre con pregunta o call-to-action que invite a comentar

{SI FORMAT ES "photo" O "both"}:
Genera un caption para post de foto/imagen:
- 100-150 caracteres máximo
- Empieza con el gancho
- 1 emoji como máximo en el caption (no spamear emojis)
- Hashtags en línea separada al final

Devuelve JSON:
{
  "video": {
    "hook": "las primeras palabras exactas que se dicen",
    "script": "guión completo hablado (sin stage directions)",
    "duration_seconds": 0,
    "text_overlay": ["texto que aparece en pantalla", "segunda pantalla si aplica"],
    "sound_style": "descripción del tipo de audio que funciona: trending upbeat / voz en off silencio / música latina / etc.",
    "description": "caption para el video (100-150 chars)",
    "hashtags": ["hashtag1", "hashtag2", "parati", "fyp"]
  },
  "photo": {
    "caption": "texto del post de foto (100-150 chars sin hashtags)",
    "hashtags": ["hashtag1", "hashtag2", "parati"],
    "image_description": "qué mostrar en la foto o qué diseñar"
  }
}

Si format es solo "video", omite la clave "photo".
Si format es solo "photo", omite la clave "video".
```

## Ejemplos de output esperado

### Empresa textil — formato video — tipo detrás de cámaras

```json
{
  "video": {
    "hook": "Así se hace la tela que probablemente tienes puesta ahora mismo",
    "script": "Esto que ven es algodón crudo. En 4 horas va a convertirse en tela lista para confección. Primero entra a la cardadora — aquí se limpian las fibras. Luego el hilo. Luego el tejido. ¿Lo más curioso? El 30% del precio final está solo en este paso. Por eso cuando ven una tela 'económica', pregúntenle a su proveedor cómo hace esto.",
    "duration_seconds": 38,
    "text_overlay": ["Algodón crudo → tela en 4 horas", "El paso que define el precio"],
    "sound_style": "música industrial suave de fondo, voz en off clara",
    "description": "El paso del proceso que pocos proveedores te explican 👀",
    "hashtags": ["#textil", "#confeccion", "#proveedores", "#parati"]
  }
}
```

### Empresa de alimentos — formato foto — tipo producto

```json
{
  "photo": {
    "caption": "500 porciones por hora. Esto no es artesanal, es industrial con alma.",
    "hashtags": ["#alimentos", "#produccion", "#pymes", "#fyp"],
    "image_description": "Línea de producción en movimiento, primer plano del producto terminado con empaque"
  }
}
```

## Variaciones de tono

| Tono | Cómo suena | Cuándo usar |
|---|---|---|
| `autentico` | "Llevamos 8 años haciendo esto y todavía nos pasa que..." | Siempre que sea posible |
| `educativo` | "Lo que pocos saben del sector es que..." | Datos del sector, mitos |
| `detras_camaras` | "Así empieza nuestro día en el taller..." | Proceso productivo |
| `producto` | "Esto aguanta X — lo probamos" | Demos, comparativas |

## Notas importantes

- TikTok penaliza el contenido que parece copiado de Instagram — siempre adaptar
- Para videos: la duración ideal es 15-35 segundos para pequeños negocios (completen rate mayor)
- Los guiones son para hablar, no para leer en pantalla — usar lenguaje coloquial
- El `sound_style` es sugerencia — el negocio elige el audio según lo que tenga disponible
- Si el negocio no tiene capacidad de grabar videos, recomendar formato foto en la respuesta

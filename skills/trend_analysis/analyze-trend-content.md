# Skill: analyze-trend-content

**Propósito**: Analiza por qué cada pieza de contenido viral funcionó — identifica
los mecanismos de éxito (formato, gancho, narrativa, timing) y los articula en 2-3
líneas accionables para el equipo de marketing.
**Modelo**: `claude-sonnet-4-6` con `thinking: adaptive`
**Usado por**: `agents/trend-analyst-agent.md`, `commands/trend-ranking.md`

---

## Cuándo usar este skill

Usar después de `fetch-youtube-trends.md` y `fetch-tiktok-trends.md`.
Recibe los datos crudos de videos y genera el análisis "por qué funcionó"
para cada video que aparecerá en los rankings.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `youtube_data` | dict | Output completo de fetch-youtube-trends |
| `tiktok_data` | dict | Output completo de fetch-tiktok-trends |
| `company_context` | dict | Contenido de `.claude/company-context.json` |
| `top_n` | int | Cuántos videos analizar por ranking (los de mayor engagement) |

---

## Lógica de selección de videos a analizar

Antes de llamar al modelo, seleccionar los videos con mayor engagement:

1. Combinar todos los videos de `youtube_data.by_topic[]` y `by_competitor[]`
2. Para YouTube: seleccionar los `top_n` con mayor `stats.views` (o `stats.comments` o `stats.likes`)
3. Para TikTok: seleccionar los `top_n` con mayor `engagement_estimated.views`
4. Si un video tiene `stats.*` = null, incluirlo de todas formas pero al final de la lista
5. Eliminar duplicados por `video_id` o `url`

El análisis se hace sobre los **top_n videos únicos** de mayor engagement de YouTube
más los **top_n de TikTok** — no sobre todos los recopilados.

---

## Prompt de análisis

```
SYSTEM:
Eres un analista de contenido viral especializado en marketing B2B y marketing
de redes sociales en el sector {INDUSTRY}.

Tu trabajo es diseccionar por qué un video funcionó (obtuvo muchas vistas,
comentarios o reacciones) e identificar los patrones replicables.

REGLAS:
- No describes el contenido — analizas los MECANISMOS de éxito
- Eres conciso: exactamente 2-3 líneas por video
- Solo citas hechos observables del título, descripción y métricas disponibles
- No especulas sobre lo que "probablemente" haya ocurrido sin evidencia
- Si las métricas son nulas (canal ocultó datos), analiza solo desde el título y descripción
- El análisis debe ser útil para alguien que quiere crear contenido similar

USER:
Analiza por qué estos videos obtuvieron alto rendimiento en {PLATAFORMA} sobre
el tema "{TOPIC}" en el período {FECHA_INICIO} – {FECHA_FIN}.

EMPRESA CLIENTE: {COMPANY_NAME}
SECTOR: {INDUSTRY}
PRODUCTO/SERVICIO: {PRODUCT}

VIDEOS A ANALIZAR:
{LISTA_DE_VIDEOS}

Para cada video, proporciona:
- "por_que_funciono": 2-3 líneas explicando los mecanismos de éxito concretos.
  Menciona: tipo de gancho, formato narrativo, elemento diferenciador.
- "patron_identificado": una etiqueta del patrón principal (ver lista abajo).
- "factores_clave": lista de 2-4 factores específicos que contribuyeron al éxito.

Lista de patrones válidos:
  tutorial_paso_a_paso, revelacion_proceso_industrial, dato_sorprendente,
  comparacion_antes_despues, testimonio_cliente, problema_comun,
  tendencia_aprovechada, posicion_controversial, detras_de_escena,
  caso_de_exito_con_cifras

Devuelve JSON válido con este esquema exacto:
{
  "analyses": [
    {
      "video_id_or_url": "...",
      "platform": "youtube|tiktok",
      "topic": "...",
      "por_que_funciono": "...",
      "patron_identificado": "...",
      "factores_clave": ["...", "...", "..."]
    }
  ]
}
```

---

## Patrones de éxito (referencia)

El modelo reconoce estos patrones cuando los observa en el título y contexto:

| Patrón | Señal observable | Por qué genera engagement |
|---|---|---|
| `tutorial_paso_a_paso` | Título con "cómo", "paso a paso", "guía" | Alto valor percibido, SEO, compartible |
| `revelacion_proceso_industrial` | Muestra maquinaria, producción, fábrica | Genera confianza en compradores B2B |
| `dato_sorprendente` | Estadística inesperada en el título | Rompe el scroll, genera debate en comentarios |
| `comparacion_antes_despues` | Contraste explícito en título o thumbnail | Fácil de consumir, muy compartible |
| `testimonio_cliente` | Historia real de cliente con resultados | Prueba social, genera leads directos |
| `problema_comun` | Identifica un pain point conocido | Reconocimiento inmediato ("yo también") |
| `tendencia_aprovechada` | Conecta con noticia o trend del momento | Alcance orgánico elevado por timing |
| `posicion_controversial` | Toma postura que genera debate | Comentarios polarizados = más alcance |
| `detras_de_escena` | Muestra el interior del proceso/empresa | Humaniza la marca, genera cercanía |
| `caso_de_exito_con_cifras` | Resultados concretos con números | Credibilidad alta, compartido por decisores |

---

## Output esperado

```json
{
  "platform": "youtube",
  "topic": "confección industrial",
  "analyses": [
    {
      "video_id_or_url": "dQw4w9WgXcQ",
      "platform": "youtube",
      "topic": "confección industrial",
      "por_que_funciono": "El gancho fue una pregunta retórica sobre eficiencia que apeló directamente al dolor del dueño de taller. El formato tutorial con casos reales de 3 fábricas aportó credibilidad local. La duración de 12 min fue suficiente para el SEO de YouTube pero manejable para el buyer B2B.",
      "patron_identificado": "tutorial_paso_a_paso",
      "factores_clave": [
        "pregunta retórica como gancho de dolor en los primeros 8 segundos",
        "casos reales con nombres y cifras de fabricantes locales",
        "duración 10-15 min favorecida por el algoritmo de YouTube",
        "thumbnail con contraste numérico antes/después de productividad"
      ]
    }
  ]
}
```

---

## Filtro de relevancia

Antes de incluir un video en el análisis, verificar que el tema sea **central**
al contenido, no apenas mencionado:

**Incluir** si:
- El título principal menciona el tema o un sinónimo directo
- La descripción muestra que el tema es el núcleo del video
- El canal es del sector {INDUSTRY} o de sus clientes directos

**Excluir** si:
- El tema aparece de pasada en un video sobre algo diferente
- Es publicidad disfrazada de contenido orgánico (señal: URL de e-commerce en título)
- El contenido está en inglés Y el mercado objetivo de la empresa es exclusivamente hispanohablante

Si un video se excluye, registrarlo en el output con `"excluded": true` y la razón.

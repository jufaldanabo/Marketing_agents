# Command: /trend-ranking

**Propósito**: Analiza qué videos sobre los temas clave de tu sector están
funcionando mejor esta semana en YouTube y TikTok. Genera 3 rankings de YouTube
(más vistos, más comentados, más reacciones) + top TikTok, con análisis de por
qué funcionó cada pieza e ideas concretas para replicar en tu empresa.
**Modelo**: `claude-sonnet-4-6` con `thinking: adaptive`
**Skills usados**: `fetch-youtube-trends`, `fetch-tiktok-trends`, `analyze-trend-content`,
`generate-trend-ideas`, `build-trend-report`

---

## Cuándo ejecutar

| Momento | Por qué |
|---|---|
| Miércoles 08:00 (automático) | El equipo de contenido recibe ideas para planificar la semana |
| Antes de planificar el calendario de contenido | Nutre la parrilla con tendencias reales del sector |
| Cuando se quiere evaluar qué formatos están funcionando | Diagnóstico rápido de tendencias |

---

## Instrucciones para Claude

Eres el **Agente Analista de Tendencias** de {COMPANY_NAME}.
Tu misión es convertir lo que está funcionando en redes en ideas accionables para el equipo.

---

### Paso 0 — Cargar variables de entorno

```bash
# Local: carga .env si existe | Railway/cron: no-op (vars ya en entorno)
[ -f .env ] && export $(grep -v '^#' .env | xargs)
```

---

### Paso 1 — Cargar contexto de empresa

Lee `.claude/company-context.json` con la herramienta `Read`.

Si el archivo no existe → mostrar mensaje y detener:
```
⚠️ No se encontró .claude/company-context.json
   Ejecuta /init primero para configurar el contexto de la empresa.
```

Extraer y guardar en variables locales:
- `company.name` → `COMPANY_NAME`
- `company.industry` → `INDUSTRY`
- `company.product` → `PRODUCT`
- `company.tone` → `TONE`
- `company.location` → `LOCATION`
- `icp.industry_target` → `INDUSTRY_TARGET`
- `icp.geography` → `GEOGRAPHY`
- `icp.company_size` → `COMPANY_SIZE`
- `icp.decision_maker_role` → `DECISION_MAKER_ROLE`
- `company.value_proposition` → `VALUE_PROPOSITION`
- `market.trend_topics` → `TREND_TOPICS_FROM_CONTEXT` (si existe)
- `market.trend_competitors_yt` → `COMPETITORS_YT_FROM_CONTEXT` (si existe)
- `market.trend_competitors_tt` → `COMPETITORS_TT_FROM_CONTEXT` (si existe)

---

### Paso 2 — Configurar parámetros de la sesión

Resolver valores con esta prioridad:
1. Flags CLI (si el usuario los pasó al invocar el comando)
2. Variables de entorno (`.env`)
3. Valores de `company-context.json`
4. Defaults del sistema

```
topics          = --topics CLI flag
                  || env TREND_TOPICS
                  || TREND_TOPICS_FROM_CONTEXT
                  || "sin temas configurados"

lookback_days   = --days CLI flag || env TREND_LOOKBACK_DAYS || 7
top_n           = env TREND_TOP_N || 10
competitors_yt  = --competitors-yt CLI flag || env TREND_COMPETITORS_YT || []
competitors_tt  = --competitors-tt CLI flag || env TREND_COMPETITORS_TT || []
youtube_key     = env YOUTUBE_API_KEY || ""
```

**Mostrar al usuario la configuración resuelta:**

```
📊 TREND RANKING — Configuración de esta ejecución
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Empresa: {COMPANY_NAME} | Sector: {INDUSTRY}

  • Temas:             {topics o "⚠️ no configurado"}
  • Período:           últimos {lookback_days} días
  • Videos por ranking: {top_n}
  • Competidores YT:   {competitors_yt o "ninguno"}
  • Competidores TT:   {competitors_tt o "ninguno"}
  • YouTube API Key:   {✅ configurada / ⚠️ NO CONFIGURADA}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
¿Usar esta configuración o cambiar algo para esta ejecución?

  → ok / enter        Continuar con esta configuración
  → temas: X, Y, Z   Cambiar los temas a buscar
  → días: 14          Cambiar el período de búsqueda
  → yt: @A, @B        Agregar canales YouTube de competidores
  → tt: @C, @D        Agregar usuarios TikTok de competidores

O pasa flags al invocar el comando:
  /trend-ranking --topics "sostenibilidad textil, fast fashion"
  /trend-ranking --days 14
  /trend-ranking --competitors-yt "@CanalA,@CanalB"
```

Procesar la respuesta del usuario y actualizar los parámetros según lo indicado.

**Si no hay temas configurados**, preguntar:
```
⚠️ No hay temas configurados (TREND_TOPICS vacío).
   ¿Qué temas quieres analizar esta semana?
   (Ejemplo: "confección industrial, telas técnicas, moda sostenible")
```

---

### Paso 2.5 — Validar YouTube API Key

Si `youtube_key` está vacía o no configurada:

```
⚠️ YOUTUBE_API_KEY no está configurada.
   Sin esta clave, el análisis solo cubrirá TikTok (con datos estimados).

   Para obtenerla (gratuita, 5 minutos):
   1. Ve a console.cloud.google.com
   2. APIs & Services → Library → YouTube Data API v3 → Enable
   3. Credentials → Create Credentials → API Key
   4. Agrega YOUTUBE_API_KEY=tu-key en el archivo .env

   ¿Continuar solo con TikTok? (sí / no)
```

- Si responde **sí** → continuar, omitir Paso 5 (YouTube), señalar en reporte
- Si responde **no** → mostrar instrucciones y terminar

---

### Paso 3 — Calcular período de análisis

```bash
# macOS
FECHA_HOY=$(date +%Y-%m-%d)
FECHA_LIMITE=$(date -v-${lookback_days}d +%Y-%m-%dT00:00:00Z)
FECHA_LIMITE_CORTA=$(date -v-${lookback_days}d +%Y-%m-%d)
MES_ACTUAL=$(date +"%B %Y")   # ej. "julio 2026"

# Linux (Railway)
FECHA_HOY=$(date +%Y-%m-%d)
FECHA_LIMITE=$(date -d "-${lookback_days} days" +%Y-%m-%dT00:00:00Z)
FECHA_LIMITE_CORTA=$(date -d "-${lookback_days} days" +%Y-%m-%d)
MES_ACTUAL=$(date +"%B %Y")
```

Mostrar en consola:
```
📅 Período de análisis: {FECHA_LIMITE_CORTA} — {FECHA_HOY} ({lookback_days} días)
```

---

### Paso 4 — Parsear temas y competidores

```
topics_list         = topics.split(",").map(t => t.trim()).filter(t => t.length > 0)
competitors_yt_list = competitors_yt ? competitors_yt.split(",").map(t => t.trim()) : []
competitors_tt_list = competitors_tt ? competitors_tt.split(",").map(t => t.trim()) : []
top_n_int           = parseInt(top_n) || 10
```

---

### Paso 5 — Recolectar tendencias de YouTube

> **🔒 INSTRUCCIÓN OBLIGATORIA — Read explícito:**
> Usar la herramienta `Read` para leer el archivo
> `skills/trend_analysis/fetch-youtube-trends.md`
> ANTES de ejecutar las llamadas a YouTube API.
> NO improvisar las llamadas de memoria. Seguir las instrucciones del skill al pie de la letra.

Ejecutar `skills/trend_analysis/fetch-youtube-trends.md` con:

```
topics          → {topics_list}
lookback_days   → {lookback_days}
top_n           → {top_n_int}
YOUTUBE_API_KEY → {youtube_key}
competitors_yt  → {competitors_yt_list}
FECHA_LIMITE    → {FECHA_LIMITE}
```

Guardar el resultado como `youtube_data`.

Mostrar en consola al completar:
```
✅ YouTube: {N} videos recopilados para {M} temas | Cuota usada: ~{QUOTA} units
```

Si el skill devuelve error `keyInvalid` → detener con mensaje claro sobre la API key.
Si devuelve error `quotaExceeded` → continuar con TikTok y señalar en el reporte.

---

### Paso 6 — Recolectar tendencias de TikTok

> **🔒 INSTRUCCIÓN OBLIGATORIA — Read explícito:**
> Usar la herramienta `Read` para leer el archivo
> `skills/trend_analysis/fetch-tiktok-trends.md`
> ANTES de ejecutar las búsquedas.

Ejecutar `skills/trend_analysis/fetch-tiktok-trends.md` con:

```
topics          → {topics_list}
lookback_days   → {lookback_days}
top_n           → {top_n_int}
competitors_tt  → {competitors_tt_list}
MES_ACTUAL      → {MES_ACTUAL}
AÑO_ACTUAL      → {AÑO de FECHA_HOY}
```

Guardar el resultado como `tiktok_data`.

Mostrar en consola:
```
✅ TikTok: {N} videos encontrados (datos estimados vía WebSearch)
```

---

### Paso 7 — Analizar por qué funcionó cada pieza

> **🔒 INSTRUCCIÓN OBLIGATORIA — Read explícito:**
> Usar la herramienta `Read` para leer el archivo
> `skills/trend_analysis/analyze-trend-content.md`
> ANTES de ejecutar el análisis.

Ejecutar `skills/trend_analysis/analyze-trend-content.md` con:

```
youtube_data    → {youtube_data}
tiktok_data     → {tiktok_data}
company_context → {contenido de .claude/company-context.json}
top_n           → {top_n_int}
```

Guardar el resultado como `trend_analyses`.

Mostrar en consola:
```
✅ Análisis de contenido completado: {N} videos analizados
```

---

### Paso 8 — Generar ideas adaptadas a la empresa

> **🔒 INSTRUCCIÓN OBLIGATORIA — Read explícito:**
> Usar la herramienta `Read` para leer el archivo
> `skills/trend_analysis/generate-trend-ideas.md`
> ANTES de generar las ideas.

Ejecutar `skills/trend_analysis/generate-trend-ideas.md` con:

```
trend_analyses  → {trend_analyses}
company_context → {company_context}
platform        → "both"
ideas_per_video → 2
```

Guardar el resultado como `trend_ideas`.

Mostrar en consola:
```
✅ Ideas generadas: {N} ideas ({N_BAJA} baja dificultad, {N_MEDIA} media, {N_ALTA} alta)
```

---

### Paso 9 — Armar y guardar el reporte

> **🔒 INSTRUCCIÓN OBLIGATORIA — Read explícito:**
> Usar la herramienta `Read` para leer el archivo
> `skills/trend_analysis/build-trend-report.md`
> ANTES de armar el reporte.

Ejecutar `skills/trend_analysis/build-trend-report.md` con:

```
youtube_data    → {youtube_data}
tiktok_data     → {tiktok_data}
analyses        → {trend_analyses}
ideas           → {trend_ideas}
topics          → {topics_list}
company_context → {company_context}
top_n           → {top_n_int}
fecha_inicio    → {FECHA_LIMITE_CORTA}
fecha_fin       → {FECHA_HOY}
```

El skill genera y guarda:
- `.claude/intel/trends-{FECHA_HOY}.md` — reporte completo legible
- `.claude/intel/trends-{FECHA_HOY}.json` — datos estructurados

Guardar el `telegram_summary` del output del skill como `TELEGRAM_MSG`.

---

### Paso 10 — Enviar resumen a Telegram

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
{
  "chat_id": "{TELEGRAM_CHAT_ID}",
  "text": "{TELEGRAM_MSG}",
  "parse_mode": "Markdown",
  "disable_web_page_preview": true
}
```

Si el envío falla (error 401, 400 o sin vars de Telegram configuradas):
- Mostrar el resumen en consola
- No interrumpir el flujo — el reporte ya está guardado en disco

---

### Paso 11 — Confirmación final en consola

Mostrar el contenido completo del reporte `.md` generado.

Luego mostrar el resumen de ejecución:

```
══════════════════════════════════════════════════
✅ TREND RANKING COMPLETADO

📅 Período: {FECHA_LIMITE_CORTA} — {FECHA_HOY}
🏢 Empresa: {COMPANY_NAME}
📊 Temas analizados: {TOPICS_LIST}
🎯 Plataformas: {YouTube ✅ / ❌ sin key} + TikTok ✅

📁 Archivos generados:
   • .claude/intel/trends-{FECHA_HOY}.md  ← reporte legible
   • .claude/intel/trends-{FECHA_HOY}.json ← datos estructurados

📱 Resumen Telegram: {✅ enviado / ❌ falló — revisar TELEGRAM_BOT_TOKEN}

💡 Ideas priorizadas:
   🟢 Baja dificultad: {N} ideas — ejecutables esta semana
   🟡 Media dificultad: {N} ideas — planificar para 2 semanas
   🔴 Alta dificultad: {N} ideas — incluir en plan mensual

ℹ️  Próxima ejecución: miércoles próximo
ℹ️  Para inteligencia de precios y competidores: /market-intel (lunes 09:00)
══════════════════════════════════════════════════
```

---

## Variables requeridas

| Variable | Fuente | Requerida | Descripción |
|---|---|---|---|
| `YOUTUBE_API_KEY` | `.env` | Sí (para YouTube) | Google Cloud → YouTube Data API v3 (gratuita) |
| `TREND_TOPICS` | `.env` o `company-context.json` | Sí | Temas a analizar, separados por coma |
| `TELEGRAM_BOT_TOKEN` | `.env` | No | Para envío del resumen semanal |
| `TELEGRAM_CHAT_ID` | `.env` | No | Destino del resumen |
| `TREND_LOOKBACK_DAYS` | `.env` | No (default: 7) | Días hacia atrás |
| `TREND_TOP_N` | `.env` | No (default: 10) | Videos por ranking |
| `TREND_COMPETITORS_YT` | `.env` o `company-context.json` | No | Handles de canales YouTube, ej. `@canal1,@canal2` |
| `TREND_COMPETITORS_TT` | `.env` o `company-context.json` | No | Usuarios TikTok, ej. `@usuario1,@usuario2` |

## Archivos del sistema

| Archivo | Se crea en | Se lee en | Propósito |
|---|---|---|---|
| `.claude/intel/trends-{fecha}.md` | `/trend-ranking` ⑨ | — | Reporte completo con rankings e ideas |
| `.claude/intel/trends-{fecha}.json` | `/trend-ranking` ⑨ | — | Datos estructurados para análisis posterior |

## Flags CLI disponibles

```bash
/trend-ranking                                          # Ejecutar con configuración de .env
/trend-ranking --topics "tema1, tema2"                  # Sobrescribir temas para esta ejecución
/trend-ranking --days 14                                # Ampliar período a 14 días
/trend-ranking --competitors-yt "@CanalA,@CanalB"       # Agregar canales YouTube
/trend-ranking --competitors-tt "@usuario1,@usuario2"   # Agregar usuarios TikTok
/trend-ranking --no-interactive                         # Modo cron: usar defaults sin preguntar
```

## Comportamiento ante errores

| Error | Acción |
|---|---|
| Sin `YOUTUBE_API_KEY` | Ofrecer continuar solo con TikTok |
| Cuota YouTube agotada (403) | Continuar con TikTok, señalar en reporte |
| Sin resultados para un tema | Señalar en reporte, sugerir ampliar período |
| Video con métricas ocultas | Incluir en ranking con nota, excluir de ordenamiento numérico |
| Error de Telegram | Mostrar resumen en consola, no interrumpir |
| Sin `TREND_TOPICS` | Preguntar al usuario antes de continuar |

## Notas

- YouTube Data API v3 es completamente gratuita. Una ejecución típica usa ~400-700 units
  de las 10,000 disponibles por día — más que suficiente para uso semanal.
- Los datos de TikTok son estimados. Su valor está en los PATRONES de formato y narrativa,
  no en las cifras exactas de engagement.
- Complementa `/market-intel` (lunes): tendencias de contenido viral + inteligencia de precios
  y competidores = visión completa del entorno de mercado.

## Programación automática

```bash
# Railway / cron — cada miércoles a las 08:00
0 8 * * 3 cd /ruta/al/proyecto && claude --command trend-ranking --no-interactive
```

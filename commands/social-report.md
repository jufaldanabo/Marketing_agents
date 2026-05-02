# /social-report — Reporte Nocturno de Redes Sociales

Revisa comentarios, mensajes directos y métricas del día en Instagram y Facebook.
Genera un resumen inteligente y lo envía por Telegram.
Ideal para ejecutar automáticamente cada noche (ej. 22:00).

---

## Instrucciones para Claude

Eres el **Agente de Monitoreo Social**. Tu trabajo es revisar la actividad
del día en redes sociales, identificar lo más importante y notificar al equipo.

### Paso 0 — Cargar variables de entorno

```bash
# Local: carga .env si existe | Railway: no-op (vars ya en entorno)
[ -f .env ] && export $(grep -v '^#' .env | xargs)
```

---

### Paso 1 — Recopilar comentarios de Instagram

**Obtener posts recientes (últimas 24h):**
```
GET https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/media
  fields=id,caption,timestamp,comments_count,like_count
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Para cada post con comentarios, obtenerlos:**
```
GET https://graph.facebook.com/v18.0/{POST_ID}/comments
  fields=id,text,username,timestamp,replies
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Obtener mensajes directos (Instagram DMs):**
```
GET https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/conversations
  fields=participants,messages{message,from,created_time}
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

### Paso 2 — Recopilar comentarios de Facebook

**Obtener posts recientes:**
```
GET https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/posts
  fields=id,message,created_time,comments{message,from,created_time},reactions.summary(true)
  access_token={FACEBOOK_ACCESS_TOKEN}
```

**Obtener mensajes de la página:**
```
GET https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/conversations
  fields=participants,messages{message,from,created_time}
  access_token={FACEBOOK_ACCESS_TOKEN}
```

### Paso 3 — Obtener métricas del día

**Instagram Insights:**
```
GET https://graph.facebook.com/v18.0/{INSTAGRAM_BUSINESS_ACCOUNT_ID}/insights
  metric=reach,impressions,profile_views,follower_count
  period=day
  access_token={INSTAGRAM_ACCESS_TOKEN}
```

**Facebook Page Insights:**
```
GET https://graph.facebook.com/v18.0/{FACEBOOK_PAGE_ID}/insights
  metric=page_impressions,page_reach,page_fans,page_post_engagements
  period=day
  access_token={FACEBOOK_ACCESS_TOKEN}
```

### Paso 4 — Analizar con Claude

Usa `claude-sonnet-4-6` para analizar toda la información:

```
SYSTEM:
Eres un analista de redes sociales B2B. Analizas comentarios y métricas
para identificar oportunidades de negocio, quejas que necesitan respuesta
y tendencias importantes. Eres conciso y orientado a la acción.

USER:
Analiza la actividad de hoy en redes sociales:

EMPRESA: {COMPANY_NAME}
FECHA: {HOY}

DATOS DE INSTAGRAM:
{datos_instagram_json}

DATOS DE FACEBOOK:
{datos_facebook_json}

MÉTRICAS:
{metricas_json}

Genera un reporte con estas secciones:
1. 🎯 RESUMEN EJECUTIVO (2-3 líneas)
2. 💬 COMENTARIOS QUE REQUIEREN RESPUESTA (lista con prioridad alta/media)
3. 📩 MENSAJES DIRECTOS PENDIENTES (si hay alguno)
4. 📊 MÉTRICAS DEL DÍA (vs ayer si hay datos)
5. 🔥 OPORTUNIDADES IDENTIFICADAS
6. ⚠️ ALERTAS (quejas, menciones negativas, etc.)
7. ✅ ACCIONES RECOMENDADAS PARA MAÑANA

Sé específico y accionable. Máximo 500 palabras.
```

### Paso 5 — Enviar por Telegram

Envía el reporte al chat de Telegram:

```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
  chat_id={TELEGRAM_CHAT_ID}
  text={REPORTE_FORMATEADO}
  parse_mode=Markdown
```

**Formato del mensaje Telegram:**
```
🌙 *REPORTE NOCTURNO — {EMPRESA}*
📅 {FECHA} | {HORA}

{RESUMEN_EJECUTIVO}

💬 *COMENTARIOS PENDIENTES ({N})*
{LISTA_COMENTARIOS}

📊 *MÉTRICAS DEL DÍA*
• Instagram: 👁️ {reach} alcance | ❤️ {likes} likes
• Facebook: 👁️ {impressions} impresiones | 🤝 {engagement} interacciones

🔥 *OPORTUNIDADES*
{OPORTUNIDADES}

⚠️ *ALERTAS*
{ALERTAS}

✅ *PARA MAÑANA*
{ACCIONES}

_Generado automáticamente por Marketing Agents Toolkit_
```

### Paso 6 — Mostrar en consola

Además de Telegram, mostrar el reporte completo en la terminal de Claude Code.

---

## Variables requeridas

| Variable | Fuente | Descripción |
|---|---|---|
| `INSTAGRAM_ACCESS_TOKEN` | Variable de entorno | Token de Instagram |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | Variable de entorno | ID cuenta Instagram |
| `FACEBOOK_ACCESS_TOKEN` | Variable de entorno | Token de Facebook |
| `FACEBOOK_PAGE_ID` | Variable de entorno | ID página Facebook |
| `TELEGRAM_BOT_TOKEN` | Variable de entorno | Token del bot Telegram |
| `TELEGRAM_CHAT_ID` | Variable de entorno | Chat/grupo destino |

## Comportamiento

- Si no hay actividad nueva: enviar igual el reporte con métricas básicas
- Si falla Telegram: mostrar el reporte en consola e indicar el error
- Si falla una API (IG o FB): continuar con la otra y señalarlo en el reporte
- Guardar reporte en `.claude/reports/{FECHA}.md` del proyecto empresa

## Programación automática

Para ejecutar cada noche a las 22:00, agregar al crontab del servidor:
```bash
0 22 * * * cd /ruta/proyecto && claude --command social-report --no-interactive
```

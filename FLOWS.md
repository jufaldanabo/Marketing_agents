# Marketing Agents — Flujo de Ejecución

Diagramas de flujo de los 4 agentes, sus commands y los skills que ejecutan.
Se renderizan en GitHub y en VS Code (extensión: Mermaid Preview).

---

## 1. Ecosistema completo

Visión general de cómo se conectan commands → skills → APIs externas.

```mermaid
flowchart LR
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef setup fill:#7F8C8D,stroke:#515a5a,color:#fff

    subgraph SETUP["⚙️ Setup"]
        direction TB
        i1["/init"]:::setup
        i2["/setup-check"]:::setup
        i3["/security-audit"]:::setup
        i4["/setup-railway"]:::setup
    end

    subgraph PUB["📸 Agente Publicador"]
        direction TB
        c1["/publish-today"]:::cmd
        c2["/check-approvals"]:::cmd
    end

    subgraph MON["👁️ Agente Monitor"]
        direction TB
        c3["/social-report"]:::cmd
        c4["/respond-comments"]:::cmd
    end

    subgraph INT["🔍 Agente Analista"]
        c5["/market-intel"]:::cmd
    end

    subgraph PRO["🎯 Agente Prospector"]
        direction TB
        c6["/prospect-leads"]:::cmd
        c7["/followup-leads"]:::cmd
    end

    subgraph SKILLS_P["Skills de Publicación"]
        direction TB
        s1["generate-b2b-content"]:::skill
        s2["generate-image-ai ✨"]:::skill
        s3["publish-instagram"]:::skill
        s4["publish-facebook"]:::skill
        s5["content-approval"]:::skill
        s_tik["publish-tiktok"]:::skill
    end

    subgraph SKILLS_M["Skills de Monitoreo"]
        direction TB
        s6["respond-comments"]:::skill
        s7["check-token-expiry"]:::skill
        s8["send-telegram"]:::skill
    end

    subgraph SKILLS_I["Skills de Inteligencia"]
        direction TB
        s9["monitor-prices"]:::skill
        s10["track-competitors"]:::skill
    end

    subgraph SKILLS_PR["Skills de Prospección"]
        direction TB
        s11["search-leads"]:::skill
        s12["qualify-leads"]:::skill
        s13["outreach-message"]:::skill
        s14["follow-up-sequence"]:::skill
        s15["handle-positive-response"]:::skill
    end

    subgraph APIS["🌐 APIs Externas"]
        direction TB
        a1["fal.ai / DALL-E"]:::api
        a2["Instagram\nGraph API"]:::api
        a3["Facebook\nGraph API"]:::api
        a4["Telegram Bot"]:::api
        a5["WebSearch"]:::api
    end

    c1 --> s1 & s2 & s3 & s4 & s5
    c2 --> s3 & s4
    c3 --> s6 & s7 & s8
    c4 --> s6 & s8
    c5 --> s9 & s10 & s8
    c6 --> s11 & s12 & s13 & s15
    c7 --> s14 & s8

    s2 --> a1
    s3 --> a2
    s4 --> a3
    s_tik --> a2
    s5 --> a4
    s8 --> a4
    s9 & s10 & s11 --> a5
    s15 --> a4
```

---

## 2. Configuración inicial (una sola vez)

Se ejecuta al instalar el plugin en un nuevo proyecto de empresa.

```mermaid
flowchart TD
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef ok fill:#27AE60,stroke:#1e8449,color:#fff

    INSTALL(["bash install.sh\no /plugin install"])
    --> CMDS["Commands copiados\n.claude/commands/*.md"]

    CMDS --> INIT["/init"]:::cmd
    INIT --> CTX["Genera\n.claude/company-context.json\n+ .env.example"]:::file

    CTX --> SETUP["/setup-check"]:::cmd
    SETUP --> ENV["Lee .env\nValida todas las variables"]
    ENV --> DEC1{"¿Todo OK?"}

    DEC1 -->|"✅ Credenciales válidas"| SEC
    DEC1 -->|"❌ Faltan variables"| FIX["Muestra qué falta\ny cómo obtenerlo"]
    FIX --> SETUP

    SEC["/security-audit"]:::cmd
    --> SECOK["Valida: .env en .gitignore\ntokens no hardcodeados\npermisos correctos"]

    SECOK --> DEC2{"¿Despliegue\nautomático?"}
    DEC2 -->|"✅ Sí"| RAIL["/setup-railway"]:::cmd
    DEC2 -->|"❌ No"| DONE

    RAIL --> CRON["Crea cron jobs en Railway\n/publish-today 08:00\n/social-report 22:00\n/market-intel lunes"]
    CRON --> DONE(["✅ Listo para operar"])
```

---

## 3. Publicación diaria — `/publish-today`

El flujo más completo del toolkit. Lo ejecuta el agente `content-publisher` cada mañana.

```mermaid
flowchart TD
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef dec fill:#E74C3C,stroke:#c0392b,color:#fff

    START(["/publish-today\n[tema opcional]"]):::cmd

    START --> S1["① Cargar contexto\ncompany-context.json\nnombre, sector, tono, país"]:::file

    S1 --> S2["② Leer historial\nposts/history.json\núltimos 7 posts → no repetir tópico"]:::file

    S2 --> S3["③ Cargar parrilla\ncontent-calendar.json\n6 categorías con pesos"]:::file

    S3 --> S4["④ Detectar contexto del día\nWebSearch: fecha especial en el país"]:::api

    S4 --> DEC1{"¿Fecha especial\nhoy?"}:::dec
    DEC1 -->|"🗓️ Sí (ej. 8 marzo)"| CAT_ESP["Categoría forzada:\nFecha especial / coyuntura"]
    DEC1 -->|"❌ No"| CAT_ROT["Categoría por rotación:\nla menos usada en 7 días"]

    CAT_ESP & CAT_ROT --> S5["⑤ Selección de tópico"]

    S5 --> DEC2{"¿Fuente\ndel tópico?"}:::dec
    DEC2 -->|"CLI arg\n/publish-today 'tema'"| TOP_A["Usar argumento\ndel usuario"]
    DEC2 -->|"Calendar con\ntópicos pendientes"| TOP_B["Siguiente tópico\nde la parrilla"]
    DEC2 -->|"Sin predefinidos"| TOP_C["Generar autónomamente\nbasado en categoría\ny contexto de empresa"]

    TOP_A & TOP_B & TOP_C --> S6A

    S6A["⑥A Análisis de brand kit\n.claude/brand-images/\n→ leer con visión"]:::file

    S6A --> DEC3{"¿Imágenes\nen la carpeta?"}:::dec
    DEC3 -->|"✅ Sí"| VISION["Extraer paleta,\nestilo, mood\n→ brand-style.json"]:::file
    DEC3 -->|"❌ No"| S6B
    VISION --> S6B

    S6B["⑥B Generar imagen con IA\nskill: generate-image-ai"]:::skill

    S6B --> DEC4{"¿API key\ndisponible?"}:::dec
    DEC4 -->|"FAL_KEY"| FAL["fal.ai FLUX Schnell\n~$0.003/imagen · 3 seg\n→ URL pública persistente"]:::api
    DEC4 -->|"OPENAI_API_KEY"| DALLE["DALL-E 3\n~$0.04/imagen · 10 seg\n→ URL pública 60min"]:::api
    DEC4 -->|"Sin key"| NOGEN["Solo prompt_externo\npara Artlist / Midjourney"]

    FAL & DALLE & NOGEN --> S7

    S7["⑦ Generar contenido\nskill: generate-b2b-content\n• Instagram caption + hashtags\n• Facebook mensaje"]:::skill

    S7 --> S8["⑧ Preview completo\nImagen generada + textos\ncon formato final"]

    S8 --> DEC5{"¿Usuario\nconfirma?"}:::dec
    DEC5 -->|"✏️ Editar"| S7
    DEC5 -->|"❌ No"| DRAFT["Guardar borrador\npublished: false"]
    DEC5 -->|"✅ Sí"| S9

    S9["⑨ Publicar en Instagram\nskill: publish-instagram\nGraph API v21.0"]:::skill
    --> S10["⑩ Publicar en Facebook\nskill: publish-facebook\nGraph API v21.0"]:::skill
    --> S11["⑪ Guardar historial\nposts/history.json → 30 posts max\nposts/images/date.json → metadata imagen"]:::file
    --> DONE(["✅ Publicado\nPróxima categoría sugerida"])
```

### Variante: Con aprobación por Telegram

Para equipos donde el manager debe aprobar el contenido antes de publicar.

```mermaid
flowchart LR
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold

    A(["/publish-today"]) --> B["Generar contenido\n(pasos 1–7)"]
    B --> C["content-approval\nskill"]:::skill
    C --> D["Telegram Bot\n📱 Draft enviado\ncon botones Aprobar/Rechazar"]:::api
    D --> E{"Manager\ndecide"}
    E -->|"✅ Aprobar"| F["/check-approvals"]:::cmd
    E -->|"❌ Rechazar"| G["Draft descartado\n.claude/drafts/ limpiado"]
    F --> H["publish-instagram\npublish-facebook\nskills"]:::skill
    H --> I(["✅ Publicado"])
```

---

## 4. Monitoreo nocturno — `/social-report` + `/respond-comments`

El agente `social-monitor` lo ejecuta automáticamente cada noche.

```mermaid
flowchart TD
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff
    classDef dec fill:#E74C3C,stroke:#c0392b,color:#fff

    REPORT(["/social-report"]):::cmd & RESPOND(["/respond-comments"]):::cmd

    REPORT --> M1["Leer métricas\nInstagram + Facebook\nGraph API v21.0"]:::api
    M1 --> M2["check-token-expiry\nVerificar vencimiento\nde tokens Meta"]:::skill

    M2 --> DEC_TOK{"¿Token\nvence pronto?"}:::dec
    DEC_TOK -->|"< 3 días 🔴"| ALERT_RED["Alerta CRÍTICA\na Telegram"]:::api
    DEC_TOK -->|"< 10 días 🟠"| ALERT_ORG["Alerta URGENTE\na Telegram"]:::api
    DEC_TOK -->|"< 30 días 🟡"| ALERT_YEL["Aviso a Telegram"]:::api
    DEC_TOK -->|"✅ OK"| M3

    ALERT_RED & ALERT_ORG & ALERT_YEL --> M3

    M3["Leer comentarios nuevos\nInstagram + Facebook\ndesde última revisión"]

    RESPOND --> M3

    M3 --> M4["respond-comments\nClasificar cada comentario\npositivo / negativo / spam / pregunta"]:::skill

    M4 --> M5["Generar respuestas\npor categoría y tono\nde la empresa"]

    M5 --> DEC_PUB{"¿Publicar\nrespuestas?"}:::dec
    DEC_PUB -->|"✅ Modo automático"| PUB_COM["Publicar respuestas\nGraph API"]:::api
    DEC_PUB -->|"📋 Modo borrador"| DRAFT_COM["Guardar en\n.claude/responses/"]:::file

    PUB_COM & DRAFT_COM --> M6

    M6["send-telegram\nReporte nocturno completo:\n• Alcance, likes, comentarios\n• Estado de tokens\n• Resumen de comentarios\n• Respuestas publicadas"]:::skill
    --> DONE(["📱 Manager notificado\nen Telegram"])
```

---

## 5. Inteligencia de mercado — `/market-intel`

El agente `market-analyst` lo ejecuta semanalmente (lunes).

```mermaid
flowchart LR
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff

    START(["/market-intel"]):::cmd

    START --> P["monitor-prices\nMonitorear precios de\nmaterias primas clave"]:::skill
    START --> C["track-competitors\nRastrear actividad pública\nde competidores"]:::skill

    P --> WS1["WebSearch\nprecios spot, bolsas,\nnoticias del sector"]:::api
    C --> WS2["WebSearch\nredes sociales, web,\nnovedades competidores"]:::api

    WS1 --> REP["Generar reporte integrado\nVariación de precios vs semana anterior\nMovimientos de competidores\nRecomendaciones de acción"]
    WS2 --> REP

    REP --> SAVE[".claude/intel/\ndate-report.json"]:::file
    REP --> TEL["send-telegram\nReporte ejecutivo\nen Telegram"]:::skill
    TEL --> DONE(["📱 Reporte enviado"])
```

---

## 6. Prospección B2B — `/prospect-leads` + `/followup-leads`

El agente `sales-prospector`. El ciclo completo puede tomar 2–3 semanas.

```mermaid
flowchart TD
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff
    classDef dec fill:#E74C3C,stroke:#c0392b,color:#fff

    START(["/prospect-leads"]):::cmd

    START --> L1["search-leads\nBuscar empresas que\ncoincidan con el ICP\nen LinkedIn, directorios, web"]:::skill
    L1 --> WS["WebSearch\nBúsquedas segmentadas\npor sector + geografía"]:::api

    WS --> L2["qualify-leads\nPuntuar cada lead\n0–100 según criterios ICP"]:::skill

    L2 --> DEC1{"¿Score\ndel lead?"}:::dec
    DEC1 -->|"🟢 > 70\nAlta prioridad"| L3
    DEC1 -->|"🟡 40–70\nMedia prioridad"| L3
    DEC1 -->|"🔴 < 40\nDescartar"| DISC["Guardar como\ndescartado"]:::file

    L3["outreach-message\nGenerar mensaje de\nprimer contacto personalizado\nbasado en el perfil del lead"]:::skill

    L3 --> SAVE1[".claude/leads/\ndate-leads.json"]:::file
    L3 --> MANUAL["👤 Envío manual\npor email/LinkedIn\ndel manager"]

    MANUAL --> DEC2{"¿Respuesta\nen 5–7 días?"}:::dec
    DEC2 -->|"✅ Respuesta positiva"| POS
    DEC2 -->|"❌ Sin respuesta"| FU

    FU --> FOLLOWUP(["/followup-leads"]):::cmd
    FOLLOWUP --> L4["follow-up-sequence\nGenerar secuencia\nmulti-toque:\nTouch 2 → Touch 3 → Touch 4"]:::skill
    L4 --> SAVE2[".claude/leads/\nfollowup-log.json"]:::file
    L4 --> MANUAL2["👤 Envío manual\ndel manager"]

    MANUAL2 --> DEC3{"¿Respuesta\npositiva?"}:::dec
    DEC3 -->|"✅ Sí"| POS
    DEC3 -->|"❌ No tras\n4 toques"| ARCH["Archivar lead\npor ahora"]:::file

    POS["handle-positive-response\nGestionar respuesta positiva:\n• Mensaje de seguimiento\n• Propuesta de reunión"]:::skill
    --> TEL["send-telegram\nNotificación al manager\n'Lead caliente: {empresa}'"]:::skill
    --> DONE(["🎯 Lead en pipeline\nde ventas"])
```

---

## 7. Cadencia de ejecución

| Frecuencia | Horario | Command | Agente | Acción |
|---|---|---|---|---|
| **Diario** | 08:00 | `/publish-today` | `content-publisher` | Genera y publica contenido en Instagram y Facebook |
| **Diario** | 22:00 | `/social-report` | `social-monitor` | Revisa métricas, comentarios y tokens; notifica en Telegram |
| **Bajo demanda** | — | `/respond-comments` | `social-monitor` | Genera y publica respuestas a comentarios |
| **Bajo demanda** | — | `/check-approvals` | `content-publisher` | Publica borradores aprobados por Telegram |
| **Semanal** | Lunes 09:00 | `/market-intel` | `market-analyst` | Reporte de precios y actividad de competidores |
| **Semanal** | Miércoles 08:00 | `/trend-ranking` | `trend-analyst` | Rankings de contenido viral YouTube + TikTok con ideas para replicar |
| **Semanal** | Martes | `/prospect-leads` | `sales-prospector` | Busca y califica nuevos leads |
| **Multi-toque** | +5d, +10d, +15d | `/followup-leads` | `sales-prospector` | Seguimiento a leads sin respuesta |

---

## 8. Archivos de estado del sistema

Estos archivos persisten entre ejecuciones y actúan como la "memoria" del toolkit.

| Archivo | Se crea en | Se lee en | Propósito |
|---|---|---|---|
| `.claude/company-context.json` | `/init` | Todos los commands | Contexto de empresa: nombre, sector, tono, ICP |
| `.claude/posts/history.json` | `/publish-today` ⑪ | `/publish-today` ② | Historial de 30 posts — evita repetición de tópicos |
| `.claude/posts/{fecha}.json` | `/publish-today` ⑪ | `/check-approvals` | Post del día: caption, IDs, estado de publicación |
| `.claude/posts/images/{fecha}.json` | `/publish-today` ⑥B | — | Metadatos de imagen generada: URL, prompt, provider |
| `.claude/content-calendar.json` | `/publish-today` ③ (auto) | `/publish-today` ③ | Parrilla de 6 categorías + tópicos predefinidos |
| `.claude/brand-images/` | Usuario (manual) | `/publish-today` ⑥A | 5–10 fotos de marca para análisis visual |
| `.claude/brand-images/brand-style.json` | `/publish-today` ⑥A | `/publish-today` ⑥A | Análisis de marca: paleta, estilo, mood (cache 30d) |
| `.claude/leads/{fecha}.json` | `/prospect-leads` | `/followup-leads` | Leads calificados con scores y estado de contacto |
| `.claude/intel/{fecha}.json` | `/market-intel` | — | Reporte de precios y competidores archivado |
| `.claude/intel/trends-{fecha}.md` | `/trend-ranking` | — | Reporte de rankings de contenido viral con análisis e ideas |
| `.claude/intel/trends-{fecha}.json` | `/trend-ranking` | — | Datos estructurados de tendencias YouTube + TikTok |
| `.claude/responses/` | `/respond-comments` | `/check-approvals` | Borradores de respuestas pendientes de aprobación |
| `.claude/drafts/` | `content-approval` skill | `/check-approvals` | Borradores de posts pendientes de aprobación manager |
| `_telegram_offset.json` | `/check-approvals` | `/check-approvals` | Offset de Telegram para no procesar updates duplicados |

---

## 9. Variables de entorno por agente

| Variable | Setup | Publicador | Monitor | Analista | Prospector |
|---|---|---|---|---|---|
| `ANTHROPIC_API_KEY` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `INSTAGRAM_ACCESS_TOKEN` | ✅ check | ✅ | ✅ | — | — |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | ✅ check | ✅ | ✅ | — | — |
| `FACEBOOK_ACCESS_TOKEN` | ✅ check | ✅ | ✅ | — | — |
| `FACEBOOK_PAGE_ID` | ✅ check | ✅ | ✅ | — | — |
| `FACEBOOK_APP_ID` | ✅ check | — | ✅ token check | — | — |
| `FACEBOOK_APP_SECRET` | ✅ check | — | ✅ token check | — | — |
| `TELEGRAM_BOT_TOKEN` | ✅ check | ✅ approval | ✅ | ✅ | ✅ |
| `TELEGRAM_CHAT_ID` | ✅ check | ✅ approval | ✅ | ✅ | ✅ |
| `FAL_KEY` | — | ✅ imagen IA | — | — | — |
| `OPENAI_API_KEY` | — | ✅ imagen IA | — | — | — |
| `TIKTOK_ACCESS_TOKEN` | opcional | opcional | — | — | — |
| `SENDER_NAME` / `SENDER_ROLE` | — | — | — | — | ✅ |

### Variables exclusivas del Agente Trend Analyst

| Variable | Trend Analyst | Notas |
|---|---|---|
| `YOUTUBE_API_KEY` | ✅ requerida | Google Cloud → YouTube Data API v3 (gratuita) |
| `TREND_TOPICS` | ✅ requerida | Temas a analizar, separados por coma |
| `TELEGRAM_BOT_TOKEN` | ✅ resumen | Mismo token que usan otros agentes |
| `TELEGRAM_CHAT_ID` | ✅ resumen | Mismo chat ID |
| `TREND_COMPETITORS_YT` | opcional | Handles de canales YouTube de competidores |
| `TREND_COMPETITORS_TT` | opcional | Usuarios de TikTok de competidores |
| `TREND_LOOKBACK_DAYS` | opcional | Default: 7 |
| `TREND_TOP_N` | opcional | Default: 10 |

---

## 10. Análisis de tendencias — `/trend-ranking`

El agente `trend-analyst` lo ejecuta semanalmente (miércoles 08:00).

```mermaid
flowchart TD
    classDef cmd fill:#2E86AB,stroke:#1a5276,color:#fff,font-weight:bold
    classDef skill fill:#27AE60,stroke:#1e8449,color:#fff
    classDef api fill:#F39C12,stroke:#b7770d,color:#fff,font-weight:bold
    classDef file fill:#8E44AD,stroke:#6c3483,color:#fff
    classDef dec fill:#E74C3C,stroke:#c0392b,color:#fff

    START(["/trend-ranking\n[--topics --days --competitors]"]):::cmd

    START --> CFG["② Configuración interactiva\nUsar defaults .env o cambiar\npara esta ejecución"]

    CFG --> DEC_KEY{"¿YOUTUBE_API_KEY\nconfigurada?"}:::dec
    DEC_KEY -->|"✅ Sí"| YT
    DEC_KEY -->|"❌ No"| SKIP_YT["Continuar solo con TikTok\n(con confirmación del usuario)"]

    YT["③ fetch-youtube-trends\n• Búsqueda por tema: order=viewCount\n• Estadísticas: views, likes, comments\n• Búsqueda por canal competidor\n  (opcional)"]:::skill
    YT --> YT_API["YouTube Data API v3\nGratuita — 10,000 units/día\nSearch: 100u · Video details: 1u"]:::api

    SKIP_YT --> TT
    YT --> TT

    TT["④ fetch-tiktok-trends\n• WebSearch: 4 búsquedas por tema\n• oEmbed: título y thumbnail\n• Engagement estimado de snippets\n⚠️ datos orientativos, no oficiales"]:::skill
    TT --> WS["WebSearch\n+ TikTok oEmbed API\n(sin credenciales requeridas)"]:::api

    YT --> AN
    TT --> AN

    AN["⑤ analyze-trend-content\nPor cada video en el top:\n• por_que_funciono: 2-3 líneas\n• patron_identificado\n• factores_clave: lista"]:::skill

    AN --> ID["⑥ generate-trend-ideas\n2 ideas por video analizado\nadaptadas a la empresa:\n• titulo_sugerido\n• gancho exacto\n• formato concreto\n• dificultad: baja/media/alta"]:::skill

    ID --> REP["⑦ build-trend-report\n3 rankings YouTube:\n  🏆 Más vistos\n  💬 Más comentados\n  ❤️ Más likes\nTop TikTok por tema\nPatrones dominantes\nIdeas por dificultad"]:::skill

    REP --> SAVE[".claude/intel/\ntrends-{fecha}.md\ntrends-{fecha}.json"]:::file
    REP --> TEL["Telegram\nResumen ejecutivo\n≤ 4,096 caracteres"]:::api
    TEL --> DONE(["📊 Rankings e ideas\nentregados al equipo de marketing"])
```

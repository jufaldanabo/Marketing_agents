---
description: Analiza videos virales de YouTube y TikTok sobre los temas del sector del cliente y genera ideas de contenido adaptadas al brand kit. Phase 3 del flujo de agencia.
argument-hint: "[topics='tema1,tema2'] [--platform youtube|tiktok|both] [--lookback-days 7] [--top-n 10]"
allowed-tools: [Read, Write, Task, Bash]
---

# Command: /trend-ranking

**Propósito**: Investigar qué contenido viral está funcionando en YouTube y TikTok sobre los temas del sector del cliente, analizar los patrones ganadores, y generar ideas de contenido ejecutables adaptadas al brand kit del cliente.

**Agente invocado**: `trend-analyst` (vía Task tool)

**Fase del flujo de agencia**: **3 — Planeación de contenido** (complementa a `content-planner` con ideas basadas en virales reales)

---

## Cuándo ejecutar

- **Semanal (miércoles 08:00)**: automatizado vía Railway cron para alimentar el próximo ciclo de parrilla
- **Antes de `/content-calendar`**: para que el planner tenga ideas frescas basadas en virales
- **On-demand**: cuando necesitas inspiración rápida para un tópico específico
- **Después de un lanzamiento**: comparar qué formatos funcionaron en el sector

---

## Precondiciones

1. `_core/load-brief` → necesitas `brief.company.industry`, `brief.company.platforms`
2. `_core/load-brand-kit` → para alinear ideas con voz de marca
3. `_core/preflight-check --domains anthropic,telegram,youtube` → **YOUTUBE_API_KEY es obligatorio**
   - Sin la key, el agente opera solo con TikTok y lo señala en el reporte
   - Para obtenerla gratis: ver instrucciones al final de este documento

---

## Flujo

### Paso 1 — Interpretar argumentos

- `topics` (string): temas a investigar separados por coma; default = inferir del brief
- `--platform`: `youtube | tiktok | both` (default `both`)
- `--lookback-days N` (int): ventana temporal; default `7`
- `--top-n N` (int): cantidad de videos por ranking; default `10`

Si no se pasan temas, el agente los infiere de `brief.company.industry` + `brief.buyer_persona.pain_points`.

### Paso 2 — Delegar al agente

```
Task(
  subagent_type: "trend-analyst",
  description: "Analyze YouTube + TikTok trends and generate content ideas",
  prompt: """
    Investiga tendencias virales para el cliente del brief activo.

    Parámetros:
    - Topics: {topics or 'auto-infer'}
    - Platform: {platform}
    - Lookback days: {lookback_days}
    - Top N per ranking: {top_n}

    Pipeline esperado (ver agents/trend-analyst-agent.md):
    1. Determinar temas (del arg o auto-inferir del brief)
    2. fetch-youtube-trends (si YOUTUBE_API_KEY disponible)
    3. fetch-tiktok-trends (siempre que platform incluya tiktok)
    4. analyze-trend-content → por qué funcionaron
    5. generate-trend-ideas → 5-10 ideas adaptadas a brand kit
    6. build-trend-report → .claude/state/trends/{YYYY-MM-DD}.md + .json
    7. telegram-notify con resumen ejecutivo
    8. Emit trend_insights event al content-planner

    Si YouTube quota exceeded o TikTok sin resultados, operar en degraded mode
    y señalarlo en el reporte.
  """
)
```

### Paso 3 — Presentar resultado al usuario

```
🎥 ANÁLISIS DE TENDENCIAS COMPLETADO — {brand.name} — {FECHA}

📊 FUENTES ANALIZADAS
  YouTube: {X} videos (quota restante: {Y}/10,000)
  TikTok: {Z} videos (datos estimados)

🏆 TOP 3 VIRALES
  1. {título} — {views} views — {platform}
  2. {título} — {views} views — {platform}
  3. {título} — {views} views — {platform}

🔍 PATRONES DETECTADOS
  Hooks ganadores: {lista}
  Formatos dominantes: {lista}
  Mejor horario: {si detectado}

💡 IDEAS GENERADAS: {N} ejecutables
  {resumen de las 3 top con hook + formato + producción estimada}

📄 ARCHIVOS GENERADOS
  Reporte completo: .claude/state/trends/{YYYY-MM-DD}.md
  Datos crudos: .claude/state/trends/{YYYY-MM-DD}.json

📧 Resumen enviado por Telegram.

➡️ SIGUIENTE PASO
  Las ideas se incorporarán automáticamente en el próximo /content-calendar
  vía evento trend_insights al content-planner.
```

---

## Argumentos

| Arg | Tipo | Default | Descripción |
|---|---|---|---|
| `topics` | string | inferido del brief | Lista de temas separados por coma |
| `--platform` | enum | `both` | `youtube` / `tiktok` / `both` |
| `--lookback-days` | int | 7 | Ventana temporal |
| `--top-n` | int | 10 | Videos por ranking |

---

## Ejemplos de uso

```
/trend-ranking                                          # inferir temas del brief
/trend-ranking topics="telas sostenibles, moda circular"
/trend-ranking --platform tiktok --lookback-days 14
/trend-ranking topics="panadería artesanal" --top-n 5
```

---

## Setup inicial — YouTube API Key (gratuita)

Solo la primera vez:

1. Ir a [Google Cloud Console](https://console.cloud.google.com/)
2. Crear un proyecto nuevo o seleccionar uno existente
3. **APIs & Services → Library** → buscar "YouTube Data API v3" → **Enable**
4. **APIs & Services → Credentials → Create Credentials → API Key**
5. Copiar la key y agregar a `.env`: `YOUTUBE_API_KEY=AIza...`
6. (Opcional) Restringir la key solo a YouTube Data API v3

**Cuota gratuita**: 10,000 units/día. Una ejecución típica usa 400-700 units — alcanza para 15+ ejecuciones diarias (muy por encima del uso real).

---

## Notas

- **Datos de YouTube son oficiales y exactos** (API Data v3). **Datos de TikTok son estimados** (WebSearch + oEmbed) — el reporte lo señala explícitamente.
- Si YouTube API quota se agota, el agente continúa con TikTok y lo documenta en el reporte.
- Las ideas generadas se adaptan a recursos PYME: teléfono + CapCut, sin producción profesional obligatoria.
- El evento `trend_insights` emitido al final queda en cola para el próximo `/content-calendar` — el `content-planner` lo consume automáticamente.
- Toda la lógica de los 5 skills del pipeline (fetch-youtube, fetch-tiktok, analyze, generate-ideas, build-report) está en `agents/trend-analyst-agent.md` — este command solo delega.

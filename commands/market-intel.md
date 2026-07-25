# /market-intel — Inteligencia de Mercado

Monitorea precios de materias primas y actividad pública de competidores.
Genera un informe de inteligencia competitiva para la empresa.
Se puede ejecutar bajo demanda o programar semanalmente.

---

## Instrucciones para Claude

Eres el **Agente de Inteligencia de Mercado**. Tu trabajo es recopilar
información pública sobre precios de insumos y movimientos de competidores,
y convertirla en inteligencia accionable para el equipo directivo.

### Paso 0 — Cargar variables de entorno

```bash
# Local: carga .env si existe | Railway: no-op (vars ya en entorno)
[ -f .env ] && export $(grep -v '^#' .env | xargs)
```

---

### Paso 1 — Recopilar contexto

Pregunta al usuario si no está en el CLAUDE.md del proyecto:

```
¿Qué información necesitas hoy?
1. Precios de materias primas
2. Actividad de competidores
3. Ambas (reporte completo)

¿Para qué sector/industria? (ej. textil, cuero, manufactura)
¿Qué materias primas monitorear? (ej. algodón, poliéster, lana)
¿Qué competidores rastrear? (nombres de empresas o URLs)
```

### Paso 2 — Monitorear precios de materias primas

Usa la herramienta **WebSearch** para buscar precios actuales:

**Búsquedas a realizar:**
```
"{MATERIA_PRIMA} price today 2026"
"precio {MATERIA_PRIMA} mercado internacional hoy"
"{MATERIA_PRIMA} commodity price index"
"cotton/polyester/wool futures price {MES} {AÑO}"
```

**Fuentes prioritarias a consultar con WebFetch:**
- Investing.com (commodities)
- IndexMundi (precios históricos)
- Fibre2Fashion (sector textil)
- ITMF (International Textile Manufacturers Federation)
- Cotlook (algodón)
- FAO (materias primas agrícolas)

Para cada materia prima, recopilar:
- Precio actual (USD por kg o tonelada métrica)
- Variación vs semana pasada (%)
- Variación vs hace 1 mes (%)
- Tendencia general (bajista / estable / alcista)
- Factores que explican el movimiento

### Paso 3 — Rastrear actividad de competidores

**Para cada competidor, buscar:**

```
"{COMPETIDOR} noticias recientes"
"{COMPETIDOR} lanzamiento producto 2026"
"{COMPETIDOR} site:instagram.com OR site:facebook.com"
"{COMPETIDOR} cambio precio OR descuento OR promoción"
```

**Verificar sus redes sociales:**
- Último post en Instagram (tema, frecuencia, engagement estimado)
- Último post en Facebook
- Cambios recientes en su sitio web (si hay URL disponible)
- Noticias de prensa o comunicados

**Señales de alerta a identificar:**
- Nuevos productos o servicios
- Cambios de precio o descuentos agresivos
- Campañas especiales o eventos
- Expansión a nuevos mercados
- Contrataciones o reestructuración

### Paso 4 — Generar informe con Claude

Usa `claude-opus-4-6` con thinking adaptativo:

```
SYSTEM:
Eres un analista de inteligencia de mercado especializado en {INDUSTRIA}.
Eres objetivo, preciso y orientado a la toma de decisiones estratégicas.
Identificas implicaciones de negocio, no solo describes hechos.

USER:
Genera un informe de inteligencia de mercado basado en estos datos:

EMPRESA CLIENTE: {COMPANY_NAME}
SECTOR: {INDUSTRY}
FECHA: {HOY}

DATOS DE PRECIOS:
{datos_precios_recopilados}

DATOS DE COMPETIDORES:
{datos_competidores_recopilados}

Estructura el informe así:

# INFORME DE INTELIGENCIA DE MERCADO
## {COMPANY_NAME} — {FECHA}

### RESUMEN EJECUTIVO
(3-4 líneas con los hallazgos más críticos)

### PRECIOS DE MATERIAS PRIMAS
Para cada materia prima:
- Precio actual y variación
- Tendencia a corto plazo
- Implicación para {COMPANY_NAME}

### ACTIVIDAD COMPETITIVA
Para cada competidor:
- Movimientos recientes
- Nivel de amenaza: Alto / Medio / Bajo
- Oportunidad detectada (si aplica)

### OPORTUNIDADES DE MERCADO
(basadas en los datos recopilados)

### RIESGOS A VIGILAR
(próximas 2-4 semanas)

### RECOMENDACIONES ESTRATÉGICAS
(3-5 acciones concretas priorizadas)

---
Fuentes utilizadas: {LISTA_DE_FUENTES}
Datos con fecha: {FECHA_DE_DATOS}
```

### Paso 5 — Distribuir el informe

**Mostrar en consola** el informe completo.

**Enviar resumen ejecutivo por Telegram** (si está configurado):
```
POST https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage
  chat_id={TELEGRAM_CHAT_ID}
  text=📊 *INTELIGENCIA DE MERCADO — {EMPRESA}*\n{RESUMEN_EJECUTIVO}
  parse_mode=Markdown
```

**Guardar informe completo:**
```
.claude/intel/{FECHA}-market-report.md
```

---

## Variables requeridas

| Variable | Fuente | Descripción |
|---|---|---|
| `COMPANY_NAME` | Variable de entorno o pregunta | Nombre de la empresa |
| `INDUSTRY` | Variable de entorno o pregunta | Sector industrial |
| `COMMODITIES` | Variable de entorno o pregunta | Lista de materias primas a monitorear |
| `COMPETITORS` | Variable de entorno o pregunta | Lista de competidores |
| `TELEGRAM_BOT_TOKEN` | Variable de entorno (opcional) | Para envío de resumen |
| `TELEGRAM_CHAT_ID` | Variable de entorno (opcional) | Destino del resumen |

## Herramientas que usa Claude

- **WebSearch**: Buscar precios y noticias actuales
- **WebFetch**: Leer páginas específicas de fuentes de datos
- **Write**: Guardar el informe en el sistema de archivos

## Programación sugerida

```bash
# Ejecutar cada lunes a las 7:00 AM
0 7 * * 1 cd /ruta/proyecto && claude --command market-intel --no-interactive
```

## Notas importantes

- Los datos de precios son orientativos (fuentes públicas, no en tiempo real)
- Para datos financieros en tiempo real, integrar con APIs de pago (Bloomberg, Reuters)
- Los análisis de competidores se basan únicamente en información pública
- Respetar términos de uso de cada sitio web consultado

## Complemento recomendado

Para **tendencias de contenido viral** en YouTube y TikTok sobre los mismos temas del sector:

```bash
/trend-ranking   # Corre los miércoles 08:00 — rankings de videos con más vistas,
                 # comentarios y reacciones + ideas para replicar en la empresa
```

`/market-intel` cubre precios de insumos e inteligencia competitiva (para dirección).
`/trend-ranking` cubre qué formatos de contenido están funcionando mejor esta semana (para el equipo de marketing).
Juntos forman la inteligencia de mercado completa del toolkit.

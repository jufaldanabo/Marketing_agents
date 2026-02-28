# Skill: track-competitors

**Propósito**: Rastrea actividad pública de competidores en redes sociales y prensa.
**Herramientas**: WebSearch + WebFetch de Claude
**Usado por**: `intelligence-agent.md`, `/market-intel`

---

## Cuándo usar este skill

Usar para monitorear los movimientos públicos de competidores:
lanzamientos, precios, campañas, contrataciones y presencia en redes sociales.
Solo información públicamente disponible — no scraping invasivo.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `competitors` | list | Lista de competidores | ["Empresa A", "empresa-b.com"] |
| `industry` | string | Sector para contextualizar | "textil" |
| `lookback_days` | int | Días hacia atrás a revisar | 7 (por defecto) |

## Proceso de búsqueda por competidor

Para cada competidor en `competitors`:

### 1. Noticias y actividad reciente
```
WebSearch: "{COMPETIDOR} noticias {MES} {AÑO}"
WebSearch: "{COMPETIDOR} lanzamiento producto 2026"
WebSearch: "{COMPETIDOR} {INDUSTRY} novedades"
WebSearch: '"{COMPETIDOR}" site:prensaweb.com OR site:periodicoindustrial.com'
```

### 2. Redes sociales públicas
```
WebSearch: "{COMPETIDOR} instagram"
WebFetch: https://www.instagram.com/{HANDLE_COMPETIDOR}/  (si es público)

WebSearch: "{COMPETIDOR} facebook page"
WebFetch: https://www.facebook.com/{PAGE_COMPETIDOR}/  (si es público)
```

### 3. Sitio web (cambios recientes)
```
WebFetch: https://{WEBSITE_COMPETIDOR}
WebSearch: "{COMPETIDOR} site:{WEBSITE} -site:wikipedia"
```

### 4. Señales de precios o promociones
```
WebSearch: "{COMPETIDOR} precio descuento oferta 2026"
WebSearch: "{COMPETIDOR} nueva colección temporada"
WebSearch: "{COMPETIDOR} expansión nuevos mercados"
```

## Señales de alerta a identificar

### Alta prioridad 🔴
- Nuevo producto o línea que compite directamente
- Reducción de precios o campaña de descuentos agresiva
- Alianza estratégica o fusión/adquisición
- Expansión a mercados donde opera {COMPANY_NAME}
- Campaña viral o cobertura de prensa masiva

### Media prioridad 🟡
- Cambios en comunicación o posicionamiento de marca
- Nuevas contrataciones clave (CEO, Director Comercial)
- Aumento o disminución notable de actividad en redes
- Cambios en su sitio web (nueva navegación, productos, precios visibles)

### Baja prioridad 🟢
- Posts regulares en redes sociales sin novedad
- Participación en ferias o eventos del sector
- Contenido educativo o de marca empleadora

## Estructura de datos a recopilar

```json
{
  "competitor": "Empresa Rival S.A.",
  "website": "empresarival.com",
  "social_media": {
    "instagram": "@empresarival",
    "facebook": "EmpresaRivalSA"
  },
  "recent_activity": [
    {
      "date": "2026-02-25",
      "channel": "Instagram",
      "type": "product_launch",
      "description": "Lanzaron nueva línea de telas anti-bacteriales",
      "engagement_estimate": "alto",
      "threat_level": "high"
    }
  ],
  "pricing_signals": "Sin cambios detectados esta semana",
  "overall_activity_level": "alta",
  "threat_level": "medium",
  "opportunity": "No tienen presencia en el segmento premium sostenible",
  "sources": ["instagram.com/empresarival", "google.com/search?q=..."]
}
```

## Prompt de análisis para Claude

```
SYSTEM:
Eres un analista de inteligencia competitiva especializado en {INDUSTRY}.
Eres objetivo y basas tus conclusiones en evidencia pública concreta.
Distingues entre hechos observados, inferencias razonables y especulación.

USER:
Analiza la siguiente información pública recopilada sobre los competidores de {COMPANY_NAME}:

EMPRESA CLIENTE: {COMPANY_NAME}
SECTOR: {INDUSTRY}
PERÍODO: últimos {LOOKBACK_DAYS} días

DATOS RECOPILADOS:
{DATOS_DE_BUSQUEDA}

Para cada competidor, proporciona:
1. Resumen de actividad reciente (qué hicieron esta semana)
2. Nivel de actividad vs período anterior: Alta / Normal / Baja
3. Nivel de amenaza para {COMPANY_NAME}: 🔴 Alta / 🟡 Media / 🟢 Baja
4. Razón del nivel de amenaza (1-2 líneas)
5. Oportunidad detectada (si hay un hueco que {COMPANY_NAME} puede aprovechar)
6. Acciones que te parecen meritorias de seguimiento

Sé específico y cita qué observaste concretamente.
Si no encontraste actividad relevante, indicarlo claramente.
No especules más allá de lo observado.
```

## Consideraciones éticas y legales

- **Solo información pública**: redes sociales públicas, sitios web, prensa
- **No web scraping invasivo**: usar WebSearch y WebFetch estándar
- **No datos personales**: no recopilar información de empleados individuales
- **No acceso no autorizado**: si un sitio requiere login, no intentar acceder
- **Respeto a términos de uso**: respetar `robots.txt` y términos de cada sitio

## Output esperado

```markdown
## ACTIVIDAD COMPETITIVA
Período: 20/02/2026 – 27/02/2026

### Empresa Rival S.A.
- **Actividad reciente**: Lanzaron nueva línea "EcoRival" de telas recicladas...
- **Nivel de actividad**: Alta (vs Normal en semanas anteriores)
- **Amenaza para {COMPANY_NAME}**: 🔴 Alta
  - Razón: Están entrando directamente en el segmento sostenible donde operamos
- **Oportunidad**: Todavía no tienen certificación GOTS, lo cual nos diferencia
- **Fuente**: Instagram @empresarival (publicación del 25/02/2026)
```

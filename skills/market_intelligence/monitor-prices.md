# Skill: monitor-prices

**Propósito**: Busca y recopila precios actuales de materias primas usando búsqueda web.
**Herramientas**: WebSearch + WebFetch de Claude
**Usado por**: `intelligence-agent.md`, `/market-intel`

---

## Cuándo usar este skill

Usar cuando necesites precios actualizados de materias primas (commodities)
para el informe de inteligencia de mercado.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `commodities` | list | Lista de materias primas | ["algodón", "poliéster", "lana"] |
| `industry` | string | Sector para contextualizar | "textil" |
| `currency` | string | Moneda de reporte | "USD" (por defecto) |

## Proceso de búsqueda

### Para cada materia prima en `commodities`:

**1. Búsqueda de precio actual:**
```
WebSearch: "{COMMODITY} price today {AÑO}"
WebSearch: "precio {COMMODITY} mercado internacional {MES} {AÑO}"
WebSearch: "{COMMODITY} commodity index current"
```

**2. Búsqueda de tendencia:**
```
WebSearch: "{COMMODITY} price forecast 2026"
WebSearch: "{COMMODITY} market outlook {MES} {AÑO}"
```

**3. Fuentes prioritarias para WebFetch:**

| Materia Prima | Fuente Prioritaria | URL |
|---|---|---|
| Algodón | Cotlook | cotlook.com |
| Algodón | ICAC | icac.org |
| Poliéster | Fibre2Fashion | fibre2fashion.com |
| Lana | IWTO | iwto.org |
| Seda | JCFA | jcfa-jp.org |
| Cuero | Leather Panel | leatherpanel.org |
| General textil | ITMF | itmf.org |
| Commodities general | Investing.com | investing.com/commodities |
| Históricos | IndexMundi | indexmundi.com |

## Estructura de datos a recopilar

Para cada materia prima, extraer:

```json
{
  "commodity": "algodón",
  "unit": "USD/lb",
  "current_price": 0.82,
  "previous_week": 0.80,
  "previous_month": 0.85,
  "weekly_change_pct": 2.5,
  "monthly_change_pct": -3.5,
  "trend": "alcista",
  "trend_factors": [
    "Sequía en principales zonas productoras de India",
    "Demanda fuerte de China para temporada de verano"
  ],
  "source": "Cotlook A Index",
  "source_date": "2026-02-27",
  "reliability": "alta"
}
```

## Prompt de análisis para Claude

Después de recopilar los datos de búsqueda, usar este prompt:

```
SYSTEM:
Eres un analista de commodities especializado en materias primas del sector {INDUSTRY}.
Eres preciso, citas tus fuentes y separas claramente hechos de interpretaciones.

USER:
Analiza los siguientes datos de precios de materias primas para el sector {INDUSTRY}:

{DATOS_RECOPILADOS_DE_BUSQUEDA}

Para cada materia prima, proporciona:
1. Precio actual en {CURRENCY}/kg (o la unidad más común del mercado)
2. Variación semanal y mensual en porcentaje
3. Tendencia (alcista/estable/bajista) con nivel de confianza
4. 2-3 factores que explican el movimiento actual
5. Implicación específica para {COMPANY_NAME} en el sector {INDUSTRY}

Si no encuentras precio actual de alguna materia prima, indicar "Sin datos disponibles"
y la última fecha conocida. No inventar cifras.

Formato de respuesta: JSON estructurado según este esquema:
{SCHEMA}
```

## Validación de datos

Antes de incluir un precio en el informe, verificar:
- [ ] La fuente tiene fecha de hoy o de los últimos 3 días
- [ ] El precio está en una unidad estándar del mercado
- [ ] No hay contradicción significativa (>5%) con otra fuente confiable
- [ ] El movimiento de precio es plausible (no >20% en una semana sin noticias)

Si hay contradicción entre fuentes: reportar ambas con sus fuentes.

## Unidades de referencia por commodity

| Materia Prima | Unidad Estándar | Fuente de Referencia |
|---|---|---|
| Algodón | USD/libra (lb) | Cotlook A Index |
| Poliéster | USD/tonelada | Asian market |
| Lana (merina) | USD/kg | AWEX EMI (Australia) |
| Seda | USD/kg | China commodity exchange |
| Nylon | USD/tonelada | Asian market |
| Cuero bovino | USD/pie² | Hidenet |
| Lino | EUR/tonelada | European market |

## Output esperado

```markdown
## PRECIOS DE MATERIAS PRIMAS
Fecha de datos: 2026-02-27

### Algodón
- Precio actual: USD 0.82/lb
- Variación semanal: +2.5% ↑
- Variación mensual: -3.5% ↓
- Tendencia: Alcista (confianza: alta)
- Factores: [lista]
- Implicación: [impacto en costos de producción]
- Fuente: Cotlook A Index (27/02/2026)

### Poliéster
[...]
```

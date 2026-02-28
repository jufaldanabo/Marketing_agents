# Skill: qualify-leads

**Propósito**: Evalúa y puntúa cada lead según su ajuste con el ICP y probabilidad de conversión.
**Herramientas**: Claude API + WebSearch para enriquecer datos
**Usado por**: `prospecting-agent.md`, `/prospect-leads`

---

## Cuándo usar este skill

Usar después de `search-leads.md` para filtrar y priorizar los prospectos
encontrados antes de invertir tiempo en el outreach.

## Inputs requeridos

| Input | Tipo | Descripción |
|---|---|---|
| `leads_list` | list | Lista de leads del skill search-leads |
| `product` | string | Producto/servicio que vende la empresa |
| `icp` | dict | Perfil del cliente ideal definido |
| `max_leads` | int | Máximo de leads a calificar (defecto: 20) |

## Sistema de scoring (100 puntos)

### Dimensión 1 — Ajuste de perfil (40 pts)

| Criterio | Puntos | Cómo evaluar |
|---|---|---|
| Sector coincide exactamente | 15 pts | ¿Es exactamente {INDUSTRY_TARGET}? |
| Sector relacionado / adyacente | 8 pts | ¿Podría necesitar {PRODUCT}? |
| Tamaño de empresa ideal | 10 pts | ¿Coincide con {COMPANY_SIZE}? |
| Geografía objetivo | 10 pts | ¿Está en {GEOGRAPHY}? |
| Tecnología/proceso compatible | 5 pts | ¿Su proceso productivo usa {PRODUCT}? |

### Dimensión 2 — Intención de compra (35 pts)

| Criterio | Puntos | Señales a buscar |
|---|---|---|
| Señal activa de compra | 20 pts | Publicó buscando proveedor, RFQ, licitación |
| Crecimiento reciente | 10 pts | Expansión, nueva planta, nueva línea |
| Interés en sostenibilidad | 5 pts | Menciona certificaciones, ESG, sostenibilidad |

### Dimensión 3 — Accesibilidad (25 pts)

| Criterio | Puntos | Cómo evaluar |
|---|---|---|
| Decisor identificado | 10 pts | Nombre + cargo del decisor encontrado |
| Canal de contacto disponible | 10 pts | LinkedIn, email, teléfono en web |
| Tamaño de empresa (facilidad) | 5 pts | Mediana empresa = más fácil que corporativo |

## Clasificación por score

| Score | Categoría | Acción |
|---|---|---|
| 80-100 | 🔥 Hot Lead | Prioridad máxima — contactar esta semana |
| 60-79 | ✅ Warm Lead | Prioridad alta — contactar este mes |
| 40-59 | 🟡 Cold Lead | Bajo interés inmediato — nutrir con contenido |
| <40 | ❌ Descartado | No encaja con el ICP actual |

## Prompt de calificación para Claude

```
SYSTEM:
Eres un especialista en ventas B2B con experiencia en {INDUSTRY}.
Evalúas prospectos con criterio comercial riguroso.
Eres honesto: prefieres una lista corta de leads calificados que una larga de mal calificados.

USER:
Califica estos leads para {COMPANY_NAME}, que vende {PRODUCT}.

PERFIL DEL CLIENTE IDEAL (ICP):
- Sector: {INDUSTRY_TARGET}
- Tamaño: {COMPANY_SIZE}
- Geografía: {GEOGRAPHY}
- Cargo del decisor: {DECISION_MAKER_ROLE}
- Problema que resolvemos: {PROBLEM_SOLVED}
- Propuesta de valor: {VALUE_PROPOSITION}

LEADS A CALIFICAR:
{LEADS_JSON}

Para cada lead, puntúa en estas dimensiones (total 100 puntos):
1. Ajuste de perfil (40 pts): sector, tamaño, geografía, compatibilidad
2. Intención de compra (35 pts): señales activas, crecimiento, contexto
3. Accesibilidad (25 pts): decisor identificado, canal disponible

Devuelve JSON con este formato:
{
  "leads": [
    {
      "company_name": "...",
      "score": 85,
      "category": "hot|warm|cold|discard",
      "breakdown": {
        "fit": 32,
        "intent": 30,
        "accessibility": 23
      },
      "strengths": ["razón 1", "razón 2"],
      "weaknesses": ["limitación 1"],
      "priority_rank": 1,
      "recommended_action": "Contactar esta semana via LinkedIn — mencionar su búsqueda de proveedor GOTS",
      "best_channel": "linkedin | email | telefono | referido"
    }
  ],
  "summary": {
    "total_evaluated": 15,
    "hot": 3,
    "warm": 5,
    "cold": 4,
    "discarded": 3,
    "top_opportunity": "descripción del mejor lead"
  }
}
```

## Enriquecimiento de datos durante calificación

Si falta información para calificar bien un lead, usar WebSearch:

```
WebSearch: "{EMPRESA} facturación OR empleados OR tamaño"
WebSearch: "{EMPRESA} expansión OR crecimiento OR inversión 2025 2026"
WebSearch: "{EMPRESA} sostenibilidad OR certificación OR proveedor"
WebFetch: {WEBSITE_EMPRESA} → sección "Clientes", "Proveedores", "Nosotros"
```

## Señales de compra a buscar activamente (trigger events)

| Señal | Impacto en score | Cómo encontrarla |
|---|---|---|
| Publicó oferta de proveedor | +20 pts | LinkedIn, portal de compras |
| Lanzó nueva línea de producto | +15 pts | Prensa, web empresa |
| Ganó certificación ambiental | +10 pts | Prensa, web empresa |
| Contrató nuevo gerente de compras | +10 pts | LinkedIn |
| Abrió nueva planta o sede | +15 pts | Prensa local |
| Perdió su proveedor actual | +25 pts | Menciones en redes o prensa |
| Participó en feria del sector | +8 pts | Web de la feria |

## Output esperado

```markdown
## LEADS CALIFICADOS
Empresa: {COMPANY_NAME} | Producto: {PRODUCT}
Evaluados: {N} | Fecha: {FECHA}

### 🔥 HOT LEADS (prioridad esta semana)

**1. Confecciones El Valle S.A.S. — Score: 88/100**
- Ajuste: 35/40 | Intención: 33/35 | Acceso: 20/25
- Fortalezas: Buscando proveedor GOTS activamente, tamaño ideal, decisor identificado
- Acción: Contactar a María González por LinkedIn esta semana
- Mensaje sugerido: [ver skill outreach-message]

**2. [...]**

### ✅ WARM LEADS (prioridad este mes)
[...]

### 📊 RESUMEN
- Hot: 3 leads | Warm: 5 leads | Cold: 4 leads | Descartados: 3
- Mejor oportunidad: Confecciones El Valle (buscando proveedor activo)
```

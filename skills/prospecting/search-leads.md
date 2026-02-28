# Skill: search-leads

**Propósito**: Busca empresas y contactos que coincidan con el perfil de cliente ideal (ICP).
**Herramientas**: WebSearch + WebFetch de Claude
**Usado por**: `prospecting-agent.md`, `/prospect-leads`

---

## Cuándo usar este skill

Usar cuando necesites encontrar prospectos B2B que podrían comprar
el producto o servicio de la empresa. Se basa solo en información pública.

## Inputs requeridos

| Input | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `product` | string | Qué vende la empresa | "telas recicladas para moda" |
| `industry_target` | string | Sector del cliente ideal | "fabricantes de ropa" |
| `geography` | string | País o región objetivo | "Colombia, Perú, Ecuador" |
| `company_size` | string | Tamaño de empresa objetivo | "mediana empresa (50-500 empleados)" |
| `decision_maker_role` | string | Cargo del decisor | "Gerente de Compras, Director de Producción" |

## Proceso de búsqueda

### Fase 1 — Definir el ICP (Ideal Customer Profile)

Antes de buscar, Claude debe construir el perfil del cliente ideal:

```
Producto/servicio: {PRODUCT}
¿Quién necesita esto? → {INDUSTRY_TARGET}
¿Por qué lo necesitaría? → [problema que resuelve]
¿Quién decide la compra? → {DECISION_MAKER_ROLE}
¿Qué tamaño de empresa? → {COMPANY_SIZE}
¿Dónde están? → {GEOGRAPHY}
¿Hay señales que indican que están listos para comprar? → [trigger events]
```

### Fase 2 — Búsquedas de empresas

**Directorio de empresas por sector:**
```
WebSearch: "empresas {INDUSTRY_TARGET} {GEOGRAPHY} directorio"
WebSearch: "{INDUSTRY_TARGET} manufacturers {GEOGRAPHY} list"
WebSearch: "proveedores {INDUSTRY_TARGET} {GEOGRAPHY}"
WebSearch: "site:linkedin.com/company {INDUSTRY_TARGET} {GEOGRAPHY}"
```

**Ferias y asociaciones del sector:**
```
WebSearch: "feria {INDUSTRY_TARGET} {GEOGRAPHY} 2025 2026 empresas participantes"
WebSearch: "asociación {INDUSTRY_TARGET} {GEOGRAPHY} empresas miembro"
WebSearch: "cámara comercio {GEOGRAPHY} {INDUSTRY_TARGET}"
```

**Señales de compra (trigger events):**
```
WebSearch: "{INDUSTRY_TARGET} {GEOGRAPHY} expansión nueva planta 2025 2026"
WebSearch: "{INDUSTRY_TARGET} {GEOGRAPHY} sostenibilidad certificación"
WebSearch: "{INDUSTRY_TARGET} {GEOGRAPHY} licitación proveedor"
```

**LinkedIn público:**
```
WebSearch: 'site:linkedin.com "{INDUSTRY_TARGET}" "{GEOGRAPHY}" empresa'
WebSearch: 'site:linkedin.com "{DECISION_MAKER_ROLE}" "{INDUSTRY_TARGET}" "{GEOGRAPHY}"'
```

### Fase 3 — Validar cada empresa encontrada

Para cada empresa candidata, hacer WebFetch de su sitio web y verificar:

```
¿Coincide con el ICP?
✓ ¿Están en el sector {INDUSTRY_TARGET}?
✓ ¿Tienen el tamaño aproximado {COMPANY_SIZE}?
✓ ¿Están en {GEOGRAPHY}?
✓ ¿Podrían necesitar {PRODUCT}?
✓ ¿Hay señales de que estén comprando / creciendo?
```

### Fase 4 — Encontrar al decisor

Para cada empresa calificada:
```
WebSearch: '"{NOMBRE_EMPRESA}" {DECISION_MAKER_ROLE} linkedin'
WebSearch: '"{NOMBRE_EMPRESA}" gerente compras OR director producción'
WebFetch: sitio web de la empresa → buscar sección "Equipo" o "Nosotros"
```

## Estructura de datos de un lead

```json
{
  "company_name": "Confecciones El Valle S.A.S.",
  "website": "confeccionesvalle.com",
  "industry": "fabricante de ropa",
  "country": "Colombia",
  "city": "Medellín",
  "size_estimate": "mediana (estimado 80-200 empleados)",
  "contact": {
    "name": "María González",
    "role": "Gerente de Compras",
    "linkedin": "linkedin.com/in/maria-gonzalez-xxx",
    "email": null,
    "phone": null
  },
  "why_good_fit": "Fabrican ropa deportiva y han mencionado interés en materiales sostenibles",
  "trigger_event": "Publicaron en LinkedIn buscando proveedores con certificación GOTS",
  "score": 85,
  "source": "LinkedIn + sitio web empresa",
  "found_date": "2026-02-27",
  "status": "nuevo"
}
```

## Fuentes de información recomendadas

| Fuente | Tipo | Qué encontrar |
|---|---|---|
| LinkedIn (público) | Red social | Empresas, cargos, contactos |
| Sitio web empresa | Web | Tamaño, productos, equipo |
| Google Maps Business | Directorio | Empresas locales por sector |
| Cámaras de comercio | Directorio | Registro de empresas |
| Asociaciones del sector | Directorio | Miembros del gremio |
| Ferias del sector | Eventos | Empresas participantes |
| Prensa especializada | Noticias | Empresas en crecimiento |

## Criterios de exclusión

No incluir como prospecto si:
- La empresa ya es cliente de {COMPANY_NAME}
- Es competidor directo
- Tiene menos de 10 empleados (microempresa)
- No tiene presencia web verificable
- Está en liquidación o tiene noticias negativas recientes

## Output esperado

Lista de leads estructurada lista para la fase de calificación:

```markdown
## LEADS ENCONTRADOS
Búsqueda: {PRODUCT} → {INDUSTRY_TARGET} en {GEOGRAPHY}
Fecha: {FECHA}
Total encontrados: {N}

### Lead 1 — Confecciones El Valle S.A.S.
- País: Colombia | Ciudad: Medellín
- Sector: Fabricante de ropa deportiva
- Tamaño: Mediana empresa
- Contacto: María González — Gerente de Compras
- LinkedIn: [url]
- Por qué encaja: [razón]
- Señal de compra: [trigger]
- Score preliminar: 85/100

[...]
```

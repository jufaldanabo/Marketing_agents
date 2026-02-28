# Command: /security-audit

**Propósito**: Audita el proyecto contra las reglas de seguridad y buenas prácticas
del toolkit: Meta API, Anthropic API, web scraping y Telegram.
**Modelo**: `claude-sonnet-4-6`
**Skills usados**: `validate-security.md`

---

## Flujo de ejecución

### Paso 1 — Identificar el alcance de la auditoría

Leer los archivos del proyecto para entender qué hay desplegado:

```
Archivos a inspeccionar:
├── deploy/scheduler.py          ← Código Python principal
├── deploy/railway.toml          ← Configuración de despliegue
├── deploy/Dockerfile            ← Entorno de ejecución
├── .gitignore                   ← Exclusiones de git
├── .env.example                 ← Variables (verificar que NO sea .env real)
├── commands/*.md                ← Instrucciones de los agentes
└── skills/**/*.md               ← Building blocks
```

Si `deploy/scheduler.py` no existe: indicar que el proyecto aún no tiene
código de despliegue y ofrecer ejecutar `/setup-railway` primero.

### Paso 2 — Verificar checks críticos (🔴)

**2a. Secrets hardcodeados**

Buscar en todos los archivos `.py`, `.md`, `.toml`, `.yaml`:

```
Patrones peligrosos a detectar:
- access_token = "IG..."
- api_key = "sk-ant-..."
- bot_token = "1234..."
- password = "..."
- Cualquier string que empiece con: sk-ant, IGQ, EAA, Bearer
```

Usar `Grep` para buscar estos patrones. Si se encuentran → 🔴 CRÍTICO.

**2b. .gitignore**

Leer `.gitignore` y verificar que incluye:
- `.env` (y variantes: `.env.local`, `.env.*`)
- `.claude/`
- `*.log`

Si no existe `.gitignore` → 🔴 CRÍTICO.

**2c. .env trackeado por git**

Ejecutar: `git ls-files .env .env.local` — si hay output → 🔴 CRÍTICO.

**2d. validate_env() en scheduler**

En `deploy/scheduler.py`, verificar que existe una función que valide
todas las variables de entorno requeridas al inicio.

### Paso 3 — Verificar checks altos (🟠)

Leer `deploy/scheduler.py` y verificar:

- **Token expiration check**: ¿Hay llamada a `/debug_token` de Meta API?
- **bypassPermissions condicional**: ¿Se activa solo cuando `RAILWAY_ENVIRONMENT=production`?
- **Error re-raise**: ¿Los `except` hacen `raise` después de notificar a Telegram?
- **max_tokens definido**: ¿Cada agente tiene un límite de tokens configurado?
- **os.environ[] vs os.getenv()**: ¿Usa `environ[]` (falla rápido) o `getenv()` (falla tarde)?

Leer los archivos `.md` de commands y verificar:
- **No precios en comentarios**: ¿El prompt de `respond-comments.md` prohíbe explícitamente publicar precios?
- **Modelos apropiados**: ¿Los skills de clasificación usan `claude-haiku-4-5`?

### Paso 4 — Verificar checks medios (🟡)

- **Rate limiting Meta API**: ¿Hay backoff exponencial en las llamadas a Graph API?
- **WebFetch limitado**: ¿Los skills de prospección limitan a ≤10 empresas por sesión?
- **Telegram chat_id validado**: ¿Hay función de setup que verifica el destinatario?
- **Retención de datos**: ¿Los archivos guardados en `.claude/` incluyen `retain_until`?
- **No PII en Telegram**: ¿Las notificaciones usan solo conteos/metadata, no datos personales?

### Paso 5 — Verificar checks bajos (🟢)

- **Logs sin contenido de prompts**: ¿El logging usa solo metadata (longitud, modelo, tiempo)?
- **Staging con dry-run**: ¿`railway.toml` o `scheduler.py` distingue staging de producción?
- **cleanup_expired()**: ¿Existe una función de limpieza de datos viejos?
- **Permisos de Meta verificados**: ¿Se llama a `/me/permissions` al inicio?

### Paso 6 — Generar reporte

Presentar el reporte de auditoría con el formato del skill `validate-security.md`:

```
## 🔒 SECURITY AUDIT — Marketing Agents Toolkit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fecha: {FECHA}
Archivos analizados: {N}
Entorno detectado: {development/staging/production}

### 🔴 CRÍTICOS — {N} encontrados
{Si N=0}: ✅ Ninguno encontrado

{Si N>0}:
  1. [deploy/scheduler.py:23] Token hardcodeado detectado
     → INSTAGRAM_TOKEN = "IGQVJXx..."
     → Reemplazar con: os.environ["INSTAGRAM_ACCESS_TOKEN"]

### 🟠 ALTOS — {N} encontrados
  1. [deploy/scheduler.py] Falta validate_env() al inicio
     → Agregar función que verifique todas las variables antes de ejecutar

  2. [deploy/scheduler.py] bypassPermissions siempre activo
     → Condicionar a RAILWAY_ENVIRONMENT == "production"

### 🟡 MEDIOS — {N} encontrados
  [...]

### 🟢 BAJOS — {N} encontrados
  [...]

### ✅ APROBADOS
  ✓ No hay secrets hardcodeados en archivos .md
  ✓ .gitignore excluye .env y .claude/
  ✓ max_tokens definido por agente
  ✓ No se detectó PII en plantillas de Telegram

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VEREDICTO: {ICONO} {ESTADO}

{Si 0 críticos y 0 altos}:
✅ APTO PARA PRODUCCIÓN — 0 bloqueadores encontrados

{Si hay críticos}:
🔴 NO DESPLEGAR — Corregir {N} issue(s) crítico(s) primero

{Si solo altos}:
🟠 CORREGIR ANTES DE PRODUCCIÓN — {N} issue(s) de alta prioridad
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

¿Deseas que corrija automáticamente los issues encontrados? (S/N)
```

### Paso 7 — Corrección automática (opcional)

Si el usuario acepta correcciones automáticas, aplicar los fixes
que sean seguros de automatizar:

**Fixes automáticos seguros:**
- Agregar entradas faltantes al `.gitignore`
- Cambiar `os.getenv()` → `os.environ[]` en `scheduler.py`
- Agregar `raise` al final de bloques `except` que lo omiten
- Agregar `max_turns` faltantes

**Fixes que requieren revisión manual:**
- Secrets hardcodeados → mostrar la línea, el usuario debe reemplazar
- Prompts que podrían revelar precios → mostrar contexto para que el usuario evalúe
- Cambios de arquitectura (agregar `validate_env`, `check_token_validity`, etc.)

Para cada fix automático aplicado, mostrar:
```
✅ Corregido: [descripción]
   Archivo: {path}:{line}
   Cambio: {antes} → {después}
```

## Opciones del command

```bash
/security-audit                    # Auditoría completa
/security-audit --critical-only    # Solo checks críticos (más rápido)
/security-audit --fix              # Audita y aplica fixes automáticos seguros
/security-audit --pre-deploy       # Versión estricta antes de hacer push a Railway
/security-audit deploy/scheduler.py # Auditar solo un archivo específico
```

## Cuándo ejecutar

| Momento | Comando recomendado |
|---|---|
| Antes de primer deploy a Railway | `/security-audit --pre-deploy` |
| Después de actualizar credenciales | `/security-audit --critical-only` |
| Al agregar un nuevo skill o command | `/security-audit` |
| Revisión mensual de seguridad | `/security-audit` |
| Antes de onboarding de nuevo cliente | `/security-audit --pre-deploy` |

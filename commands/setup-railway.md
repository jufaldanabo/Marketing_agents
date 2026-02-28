# Command: /setup-railway

**Propósito**: Genera todos los archivos necesarios para desplegar el toolkit en Railway
con los agentes programados automáticamente como cron jobs.
**Modelo**: `claude-opus-4-6`
**Skills usados**: `schedule-railway.md`

---

## Qué hace este command

1. Crea la carpeta `deploy/` con el scheduler Python y configuración de Railway
2. Programa cada agente con su horario (personalizable por timezone)
3. Genera instrucciones paso a paso para el despliegue
4. Configura el `.gitignore` para no subir datos sensibles

## Flujo de ejecución

### Paso 1 — Recopilar configuración

Preguntar al usuario si no está en CLAUDE.md:

```
Para configurar el despliegue necesito algunos datos:

1. ¿Cuál es tu timezone?
   A) UTC-5 (Colombia, Ecuador, Perú)
   B) UTC-6 (México)
   C) UTC-4 (Venezuela, Bolivia)
   D) UTC+1 (España)
   E) UTC+0 (UK, otro)

2. ¿Qué agentes quieres programar? (todos por defecto)
   □ Publisher Agent    — publica contenido diario
   □ Social Report      — reporte nocturno de métricas
   □ Respond Comments   — responde comentarios
   □ Market Intelligence — analiza precios y competidores
   □ Prospecting        — busca nuevos leads (requiere config extra)
   □ Follow-up Leads    — seguimiento a leads sin respuesta

3. ¿Tienes horarios preferidos? (opcional — se usan defaults si no)
   Ejemplo: "publicar a las 9am", "reporte a las 11pm"
```

### Paso 2 — Calcular horarios en UTC

Convertir los horarios preferidos del usuario a UTC según su timezone.

**Horarios recomendados por defecto (Colombia UTC-5):**

| Agente | Hora local | Cron UTC |
|---|---|---|
| publisher | 8:00am L-V | `0 13 * * 1-5` |
| social-report | 10:00pm diario | `0 3 * * *` |
| respond-comments am | 9:00am L-V | `0 14 * * 1-5` |
| respond-comments pm | 3:00pm L-V | `0 20 * * 1-5` |
| market-intel | 7:00am lunes | `0 12 * * 1` |
| prospecting | 8:00am viernes | `0 13 * * 5` |
| followup-leads | 9:00am Mar-Jue | `0 14 * * 2,4` |

### Paso 3 — Crear estructura de archivos

Crear la carpeta `deploy/` si no existe, y generar cada archivo usando
el contenido exacto definido en el skill `schedule-railway.md`:

```
deploy/
├── scheduler.py
├── requirements.txt
├── railway.toml          ← con los horarios ajustados al timezone del usuario
├── Dockerfile
├── .env.example
└── README-deploy.md
```

Al generar `railway.toml`, usar los cron schedules calculados en el Paso 2.
Comentar (con `#`) los servicios que el usuario no seleccionó.

### Paso 4 — Actualizar .gitignore

Verificar si existe `.gitignore` en la raíz del proyecto.
Si no existe, crearlo. Agregar estas líneas si no están presentes:

```gitignore
# Datos de empresa y sesiones de Claude Code
.claude/

# Variables de entorno con credenciales
.env
.env.local
.env.*.local

# Logs del scheduler
*.log
deploy/logs/

# Resultados de ejecuciones (pueden contener datos sensibles)
.claude/runs/
.claude/reports/
.claude/posts/
.claude/leads/
.claude/intel/
```

### Paso 5 — Mostrar resumen y próximos pasos

```
## ✅ RAILWAY DEPLOYMENT CONFIGURADO
Timezone: UTC-5 (Colombia)

ARCHIVOS GENERADOS:
✅ deploy/scheduler.py       — Scheduler principal (Claude Agent SDK)
✅ deploy/requirements.txt   — Python: claude-agent-sdk, anthropic, httpx
✅ deploy/railway.toml       — 7 cron services configurados
✅ deploy/Dockerfile         — Python 3.12 + Node.js + Claude Code CLI
✅ deploy/.env.example       — 18 variables requeridas
✅ deploy/README-deploy.md   — Guía completa de despliegue
✅ .gitignore                — Excluye .claude/ y .env

SERVICIOS PROGRAMADOS (hora local Colombia):
┌─────────────────────────┬──────────────────────────┬────────────────┐
│ Servicio                │ Horario                  │ Cron (UTC)     │
├─────────────────────────┼──────────────────────────┼────────────────┤
│ publisher-agent         │ Lun-Vie 8:00am           │ 0 13 * * 1-5   │
│ social-report           │ Diario 10:00pm           │ 0 3 * * *      │
│ respond-comments-am     │ Lun-Vie 9:00am           │ 0 14 * * 1-5   │
│ respond-comments-pm     │ Lun-Vie 3:00pm           │ 0 20 * * 1-5   │
│ market-intel            │ Lunes 7:00am             │ 0 12 * * 1     │
│ prospecting             │ Viernes 8:00am           │ 0 13 * * 5     │
│ followup-leads          │ Mar y Jue 9:00am         │ 0 14 * * 2,4   │
└─────────────────────────┴──────────────────────────┴────────────────┘

══════════════════════════════════════════════════════

PRÓXIMOS PASOS:

1️⃣  CONFIGURAR VARIABLES DE ENTORNO
    Copia deploy/.env.example → .env y completa los valores.
    Ver sección "Variables requeridas" en README-deploy.md.

2️⃣  PROBAR LOCALMENTE ANTES DE SUBIR
    pip install -r deploy/requirements.txt
    python deploy/scheduler.py publisher

3️⃣  SUBIR A GITHUB
    git add deploy/ .gitignore
    git commit -m "Add Railway deployment configuration"
    git push

4️⃣  CREAR PROYECTO EN RAILWAY
    railway login
    railway init
    railway up

5️⃣  CONFIGURAR VARIABLES EN RAILWAY
    En el dashboard: Project Settings → Shared Variables
    Agregar todas las variables del .env (sin los valores de .env.example)

6️⃣  VERIFICAR CON TRIGGER MANUAL
    En Railway dashboard → servicio → "Trigger Run"
    Verificar que llega notificación por Telegram ✅

══════════════════════════════════════════════════════

⚠️  IMPORTANTE ANTES DE SUBIR:
    • Nunca subas .env al repositorio
    • Los tokens de Instagram expiran cada 60 días — renovar antes
    • En Railway usa "Shared Variables" para que todos los servicios
      compartan las mismas credenciales
```

## Opciones del command

```bash
/setup-railway                    # Configura todo con preguntas interactivas
/setup-railway --timezone utc-5   # Especifica timezone sin preguntar
/setup-railway --dry-run          # Muestra qué archivos crearía sin crearlos
/setup-railway --update-schedules # Solo actualiza los horarios en railway.toml
```

## Variables de entorno requeridas para Railway

El comando verifica que todas estas variables estén en `.env.example`:

**Esenciales (sin estas no corre nada):**
- `ANTHROPIC_API_KEY`
- `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID`
- `COMPANY_NAME` + `INDUSTRY`

**Para publishing:**
- `INSTAGRAM_ACCESS_TOKEN` + `INSTAGRAM_BUSINESS_ACCOUNT_ID`
- `FACEBOOK_ACCESS_TOKEN` + `FACEBOOK_PAGE_ID`

**Para market intelligence:**
- `COMMODITIES` + `COMPETITORS`

**Para prospecting:**
- `PRODUCT` + `INDUSTRY_TARGET` + `GEOGRAPHY`
- `SENDER_NAME` + `SENDER_ROLE`

## Notas técnicas

### Por qué usa Claude Agent SDK y no la API directa

Los agentes necesitan herramientas del sistema:
- `WebSearch` / `WebFetch` — para precios, competidores, leads
- `Read` / `Write` — para guardar reportes y leer historial
- `Bash` — para llamadas a la Instagram/Facebook API

El Agent SDK ejecuta Claude Code en modo autónomo con `bypassPermissions=True`,
lo que permite que corra sin intervención humana en los cron jobs de Railway.

### Tokens de acceso y seguridad

Los tokens de Instagram/Facebook expiran. Para manejar esto en producción:
1. Configurar un cron adicional para renovar tokens (cada 50 días)
2. O usar un token de larga duración (60 días) y renovar manualmente
3. El scheduler envía alerta por Telegram 10 días antes del vencimiento (si se configura)

### Costo estimado en Railway

- Plan Hobby ($5/mes base): suficiente para empezar
- Estimado real con 7 servicios activos: ~$12-18/mes
- Cada ejecución de ~10 minutos consume aprox. $0.03-0.05 en Railway

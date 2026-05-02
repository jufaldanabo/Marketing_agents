# Skill: schedule-railway

**Propósito**: Genera todos los archivos necesarios para desplegar el toolkit en Railway
con los agentes programados automáticamente (cron jobs).
**Modelo**: `claude-opus-4-6`
**Usado por**: `/setup-railway`

---

## Arquitectura del despliegue

```
Railway Project
│
├── [Cron Service] publisher-agent     → corre diario 8am L-V
├── [Cron Service] social-report       → corre diario 10pm
├── [Cron Service] respond-comments    → corre diario 9am y 3pm
├── [Cron Service] market-intel        → corre lunes 7am
└── [Cron Service] prospecting         → corre viernes 8am (opcional)

Todos los servicios usan el mismo código del repo.
Cada uno ejecuta: python deploy/scheduler.py <nombre-agente>
```

**Por qué funciona así:**
- Los archivos `.md` del toolkit son los prompts completos de cada agente
- `scheduler.py` los lee y los ejecuta vía Claude Agent SDK en modo autónomo
- Railway cron services corren el mismo código con diferente argumento
- Los resultados se guardan localmente Y se envían por Telegram

---

## Archivos que este skill genera

Cuando Claude Code ejecuta este skill, debe crear:

```
deploy/
├── scheduler.py          ← Entry point principal (lo ejecutan los cron jobs)
├── requirements.txt      ← Dependencias Python
├── railway.toml          ← Configuración de Railway + schedules
├── Dockerfile            ← Para que Railway tenga el entorno correcto
├── .env.example          ← Variables requeridas (sin valores reales)
└── README-deploy.md      ← Instrucciones de despliegue paso a paso
```

---

## Contenido de cada archivo a generar

### 1. `deploy/scheduler.py`

```python
#!/usr/bin/env python3
"""
Marketing Agents Scheduler
Ejecuta los agentes del toolkit de forma autónoma en Railway.

Uso:
    python deploy/scheduler.py publisher
    python deploy/scheduler.py social-report
    python deploy/scheduler.py market-intel
    python deploy/scheduler.py respond-comments
    python deploy/scheduler.py prospecting

O via variable de entorno:
    AGENT_NAME=publisher python deploy/scheduler.py
"""

import os
import sys
import asyncio
import json
import httpx
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()  # Local: carga .env | Railway: no-op (vars ya en entorno)

try:
    from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage, SystemMessage
except ImportError:
    print("ERROR: claude_agent_sdk no instalado. Ejecuta: pip install claude-agent-sdk")
    sys.exit(1)


# ─── Configuración de agentes ────────────────────────────────────────────────

AGENTS = {
    "publisher": {
        "cmd_file": "commands/publish-today.md",
        "description": "Genera y publica contenido B2B en Instagram y Facebook",
        "allowed_tools": ["Read", "Write", "WebFetch", "WebSearch", "Bash"],
        "max_turns": 30,
    },
    "social-report": {
        "cmd_file": "commands/social-report.md",
        "description": "Reporte nocturno de métricas y comentarios",
        "allowed_tools": ["Read", "Write", "WebFetch", "Bash"],
        "max_turns": 20,
    },
    "respond-comments": {
        "cmd_file": "commands/respond-comments.md",
        "description": "Genera y publica respuestas a comentarios",
        "allowed_tools": ["Read", "Write", "WebFetch", "Bash"],
        "max_turns": 25,
    },
    "market-intel": {
        "cmd_file": "commands/market-intel.md",
        "description": "Informe de inteligencia de mercado semanal",
        "allowed_tools": ["Read", "Write", "WebFetch", "WebSearch", "Bash"],
        "max_turns": 40,
    },
    "prospecting": {
        "cmd_file": "commands/prospect-leads.md",
        "description": "Búsqueda y calificación de nuevos leads B2B",
        "allowed_tools": ["Read", "Write", "WebFetch", "WebSearch", "Bash"],
        "max_turns": 35,
    },
    "followup": {
        "cmd_file": "commands/followup-leads.md",
        "description": "Seguimiento a leads sin respuesta",
        "allowed_tools": ["Read", "Write", "Bash"],
        "max_turns": 20,
    },
}

# ─── Logging ─────────────────────────────────────────────────────────────────

def log(agent_name: str, message: str, level: str = "INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] [{level}] [{agent_name}] {message}"
    print(line)

    log_dir = Path(".claude/logs")
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{agent_name}-{datetime.now().strftime('%Y-%m')}.log"
    with open(log_file, "a") as f:
        f.write(line + "\n")


# ─── Notificación Telegram ────────────────────────────────────────────────────

async def send_telegram(message: str):
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")
    if not token or not chat_id:
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    try:
        async with httpx.AsyncClient() as client:
            await client.post(url, json={
                "chat_id": chat_id,
                "text": message,
                "parse_mode": "Markdown"
            }, timeout=10)
    except Exception as e:
        print(f"Telegram error: {e}")


# ─── Ejecución del agente ─────────────────────────────────────────────────────

async def run_agent(agent_name: str) -> bool:
    if agent_name not in AGENTS:
        log(agent_name, f"Agente desconocido. Disponibles: {list(AGENTS.keys())}", "ERROR")
        return False

    cfg = AGENTS[agent_name]
    cmd_path = Path(cfg["cmd_file"])

    if not cmd_path.exists():
        log(agent_name, f"Archivo no encontrado: {cmd_path}", "ERROR")
        return False

    prompt = cmd_path.read_text(encoding="utf-8")
    started_at = datetime.now()
    log(agent_name, f"Iniciando — {cfg['description']}")

    await send_telegram(
        f"🤖 *{agent_name}* iniciado\n"
        f"_{cfg['description']}_\n"
        f"⏰ {started_at.strftime('%H:%M')} UTC"
    )

    result_text = None
    success = False

    try:
        async for message in query(
            prompt=prompt,
            options=ClaudeAgentOptions(
                cwd=str(Path.cwd()),
                allowed_tools=cfg["allowed_tools"],
                permission_mode="bypassPermissions",
                allow_dangerously_skip_permissions=True,
                max_turns=cfg["max_turns"],
            )
        ):
            if isinstance(message, ResultMessage):
                result_text = message.result
                success = True

    except Exception as e:
        log(agent_name, f"Error durante ejecución: {e}", "ERROR")
        await send_telegram(
            f"❌ *{agent_name}* falló\n"
            f"`{str(e)[:200]}`"
        )
        return False

    elapsed = (datetime.now() - started_at).seconds
    minutes = elapsed // 60
    seconds = elapsed % 60

    if success:
        log(agent_name, f"Completado en {minutes}m {seconds}s")

        # Guardar resultado
        result_dir = Path(f".claude/runs/{datetime.now().strftime('%Y-%m-%d')}")
        result_dir.mkdir(parents=True, exist_ok=True)
        result_file = result_dir / f"{agent_name}.txt"
        result_file.write_text(result_text or "", encoding="utf-8")

        await send_telegram(
            f"✅ *{agent_name}* completado\n"
            f"⏱ {minutes}m {seconds}s\n"
            f"📁 `.claude/runs/{datetime.now().strftime('%Y-%m-%d')}/{agent_name}.txt`"
        )
    else:
        log(agent_name, "El agente terminó sin resultado", "WARN")

    return success


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Acepta el nombre del agente como argumento o variable de entorno
    agent = (
        os.getenv("AGENT_NAME")
        or (sys.argv[1] if len(sys.argv) > 1 else None)
    )

    if not agent:
        print("Uso: python deploy/scheduler.py <nombre-agente>")
        print(f"Agentes disponibles: {', '.join(AGENTS.keys())}")
        sys.exit(1)

    success = asyncio.run(run_agent(agent))
    sys.exit(0 if success else 1)
```

---

### 2. `deploy/requirements.txt`

```
claude-agent-sdk>=0.1.0
anthropic>=0.40.0
httpx>=0.27.0
python-dotenv>=1.0.0
```

---

### 3. `deploy/railway.toml`

```toml
# Railway configuration — Marketing Agents Toolkit
# Documentación: https://docs.railway.app/reference/config-as-code

[build]
builder = "DOCKERFILE"
dockerfilePath = "deploy/Dockerfile"

# ─── Agente Publicador ────────────────────────────────────────────────────────
# Publica contenido B2B en Instagram y Facebook
# Horario: Lunes a viernes a las 8:00am UTC
[[services]]
name = "publisher-agent"

[services.deploy]
startCommand = "python deploy/scheduler.py publisher"
cronSchedule = "0 8 * * 1-5"

# ─── Reporte Social ───────────────────────────────────────────────────────────
# Analiza métricas y comentarios del día
# Horario: Todos los días a las 22:00 UTC (10pm)
[[services]]
name = "social-report"

[services.deploy]
startCommand = "python deploy/scheduler.py social-report"
cronSchedule = "0 22 * * *"

# ─── Responder Comentarios ────────────────────────────────────────────────────
# Responde comentarios pendientes en IG y FB
# Horario: Días de semana a las 9am y 3pm UTC
[[services]]
name = "respond-comments-am"

[services.deploy]
startCommand = "python deploy/scheduler.py respond-comments"
cronSchedule = "0 9 * * 1-5"

[[services]]
name = "respond-comments-pm"

[services.deploy]
startCommand = "python deploy/scheduler.py respond-comments"
cronSchedule = "0 15 * * 1-5"

# ─── Inteligencia de Mercado ──────────────────────────────────────────────────
# Monitorea precios y competidores
# Horario: Todos los lunes a las 7am UTC
[[services]]
name = "market-intel"

[services.deploy]
startCommand = "python deploy/scheduler.py market-intel"
cronSchedule = "0 7 * * 1"

# ─── Prospección de Leads ─────────────────────────────────────────────────────
# Busca y califica nuevos leads B2B
# Horario: Viernes a las 8am UTC (semanal)
[[services]]
name = "prospecting"

[services.deploy]
startCommand = "python deploy/scheduler.py prospecting"
cronSchedule = "0 8 * * 5"

# ─── Seguimiento a Leads ─────────────────────────────────────────────────────
# Genera mensajes de seguimiento para leads sin respuesta
# Horario: Martes y jueves a las 9am UTC
[[services]]
name = "followup-leads"

[services.deploy]
startCommand = "python deploy/scheduler.py followup"
cronSchedule = "0 9 * * 2,4"
```

**Ajuste de horarios según timezone:**
- UTC+0 (UK): schedules listos
- UTC-5 (Colombia/Bogotá): restar 5 horas a los horarios
- UTC-6 (México/CDMX): restar 6 horas
- UTC+1 (España): sumar 1 hora

---

### 4. `deploy/Dockerfile`

```dockerfile
FROM python:3.12-slim

# Instalar Claude Code CLI (requerido por Agent SDK)
RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Directorio de trabajo
WORKDIR /app

# Instalar dependencias Python
COPY deploy/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el toolkit completo
COPY . /app

# Variables de entorno que Railway inyectará
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

CMD ["python", "deploy/scheduler.py"]
```

---

### 5. `deploy/.env.example`

```env
# ── API Keys ──────────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY=sk-ant-api03-...

# ── Instagram Graph API ───────────────────────────────────────────────────────
INSTAGRAM_ACCESS_TOKEN=IGQVJXx...
INSTAGRAM_BUSINESS_ACCOUNT_ID=17841400...

# ── Facebook Graph API ────────────────────────────────────────────────────────
FACEBOOK_ACCESS_TOKEN=EAAGm0P...
FACEBOOK_PAGE_ID=123456789

# ── Telegram Bot ──────────────────────────────────────────────────────────────
TELEGRAM_BOT_TOKEN=7123456789:AAHx...
TELEGRAM_CHAT_ID=-100123456789

# ── Configuración de la empresa ───────────────────────────────────────────────
COMPANY_NAME=Mi Empresa S.A.
INDUSTRY=textil
DEFAULT_TONE=professional
BRAND_VOICE=Expertos en materiales textiles sostenibles. Tono profesional pero cercano.

# ── Inteligencia de Mercado ───────────────────────────────────────────────────
COMMODITIES=algodón,poliéster,lana,fibras recicladas
COMPETITORS=empresa-a.com,empresa-b.com

# ── Prospección ───────────────────────────────────────────────────────────────
PRODUCT=Telas recicladas certificadas GOTS
INDUSTRY_TARGET=confección,moda sostenible,fabricantes de ropa
GEOGRAPHY=Colombia,México,Perú
SENDER_NAME=Juan García
SENDER_ROLE=Gerente Comercial

# ── Scheduler (Railway los inyecta automáticamente) ───────────────────────────
# AGENT_NAME=publisher   ← Railway configura esto por servicio
```

---

### 6. `deploy/README-deploy.md`

````markdown
# Despliegue en Railway — Marketing Agents Toolkit

## Requisitos previos

- Cuenta en [Railway](https://railway.app)
- CLI de Railway: `npm install -g @railway/cli`
- Repositorio en GitHub con el toolkit

## Paso 1 — Preparar el repositorio

Asegúrate de que el repo tenga esta estructura:
```
tu-proyecto/
├── commands/
├── agents/
├── skills/
├── deploy/
│   ├── scheduler.py
│   ├── requirements.txt
│   ├── railway.toml
│   ├── Dockerfile
│   └── .env.example
└── CLAUDE.md
```

**IMPORTANTE**: Agregar `.claude/` al `.gitignore` para no subir datos de empresa:
```
.claude/
.env
*.log
```

## Paso 2 — Crear el proyecto en Railway

```bash
# Login en Railway
railway login

# Crear nuevo proyecto
railway init

# Conectar con GitHub (recomendado para auto-deploy)
# En el dashboard de Railway: New Project → Deploy from GitHub repo
```

## Paso 3 — Configurar variables de entorno

En el dashboard de Railway, ir a cada servicio → Variables:

```bash
# O via CLI (aplica a todos los servicios del proyecto)
railway variables set ANTHROPIC_API_KEY=sk-ant-...
railway variables set INSTAGRAM_ACCESS_TOKEN=IGQ...
railway variables set FACEBOOK_ACCESS_TOKEN=EAA...
# ... (ver .env.example para la lista completa)
```

**Tip**: Railway permite compartir variables entre servicios con "Shared Variables".
Configura las variables en Project Settings → Shared Variables.

## Paso 4 — Desplegar

```bash
# Deploy desde la CLI
railway up

# O conectar con GitHub para auto-deploy en cada push
```

Railway detecta el `railway.toml` y crea automáticamente todos los servicios cron.

## Paso 5 — Verificar que funciona

1. En el dashboard, ir a cada servicio
2. Click en "Trigger" para ejecutar manualmente
3. Ver los logs en tiempo real
4. Revisar que llegan notificaciones por Telegram

## Horarios configurados (UTC)

| Agente | Horario | Frecuencia |
|---|---|---|
| publisher-agent | 8:00am | Lunes a viernes |
| social-report | 10:00pm | Todos los días |
| respond-comments | 9:00am y 3:00pm | Lunes a viernes |
| market-intel | 7:00am | Lunes |
| prospecting | 8:00am | Viernes |
| followup-leads | 9:00am | Martes y jueves |

**Ajuste para Colombia (UTC-5)**: todos los horarios son 5 horas antes.
Ejemplo: publisher a 8am UTC = 3am Colombia → cambiar a `0 13 * * 1-5` para 8am Colombia.

## Personalizar horarios

Editar `deploy/railway.toml` → sección `cronSchedule`:

```toml
# Formato: minuto hora día-mes mes día-semana
# Ejemplos:
"0 13 * * 1-5"   # 8am Colombia (UTC-5), lunes a viernes
"0 3 * * *"      # 10pm Colombia, todos los días
"0 12 * * 1"     # 7am Colombia, lunes
```

Herramienta útil: https://crontab.guru

## Costos estimados en Railway

- Plan Hobby: $5/mes base + uso de recursos
- Cada cron job consume ~5-10 min de CPU por ejecución
- Estimado con 6 servicios a frecuencia normal: ~$10-15/mes

## Logs y monitoreo

Los resultados se guardan en `.claude/runs/{fecha}/{agente}.txt`.
Railway también mantiene logs de cada ejecución en el dashboard.

Adicionalmente, cada agente envía notificación por Telegram al iniciar y al completar.

## Troubleshooting

| Error | Causa | Solución |
|---|---|---|
| `claude_agent_sdk not found` | Dependencia no instalada | Verificar requirements.txt y rebuild |
| `ANTHROPIC_API_KEY not found` | Variable no configurada | Agregar en Railway Variables |
| `claude: command not found` | Claude Code CLI no instalado | Verificar Dockerfile |
| Agente no completa | `max_turns` muy bajo | Aumentar en `scheduler.py` |
| Error de API Instagram | Token expirado | Renovar token (duran 60 días) |
````

---

## Cómo Claude Code debe ejecutar este skill

Cuando el usuario corra `/setup-railway`, Claude debe:

1. **Verificar** que existe la carpeta `deploy/` y crearla si no existe
2. **Generar** cada archivo con el contenido exacto de este skill
3. **Personalizar** `railway.toml` según la empresa:
   - Preguntar timezone si no está definida
   - Ajustar los `cronSchedule` si el usuario da horarios específicos
   - Comentar servicios que no apliquen (ej. prospecting si no está configurado)
4. **Verificar** que `.gitignore` excluye `.claude/` y `.env`
5. **Mostrar** las instrucciones de despliegue del `README-deploy.md`

## Variables que personalizar por empresa

Al generar los archivos, reemplazar estos valores si están disponibles en CLAUDE.md:

| Placeholder | Variable de entorno | Default |
|---|---|---|
| `lunes a viernes 8am` | `PUBLISH_SCHEDULE` | `0 8 * * 1-5` |
| `todos los días 10pm` | `REPORT_SCHEDULE` | `0 22 * * *` |
| `lunes 7am` | `INTEL_SCHEDULE` | `0 7 * * 1` |
| `viernes 8am` | `PROSPECT_SCHEDULE` | `0 8 * * 5` |

## Output esperado al ejecutar el skill

```
## RAILWAY DEPLOYMENT CONFIGURADO

Archivos generados:
✅ deploy/scheduler.py       — Scheduler principal
✅ deploy/requirements.txt   — Dependencias Python
✅ deploy/railway.toml       — Configuración + 6 cron services
✅ deploy/Dockerfile         — Entorno de ejecución
✅ deploy/.env.example       — Variables requeridas
✅ deploy/README-deploy.md   — Instrucciones paso a paso

Servicios programados:
📅 publisher-agent      → Lun-Vie 8:00 UTC
📅 social-report        → Todos los días 22:00 UTC
📅 respond-comments-am  → Lun-Vie 9:00 UTC
📅 respond-comments-pm  → Lun-Vie 15:00 UTC
📅 market-intel         → Lunes 7:00 UTC
📅 prospecting          → Viernes 8:00 UTC
📅 followup-leads       → Mar-Jue 9:00 UTC

Próximos pasos:
1. Revisar deploy/railway.toml y ajustar horarios a tu timezone
2. Agregar .claude/ y .env al .gitignore
3. Subir el repo a GitHub
4. Seguir instrucciones en deploy/README-deploy.md
```

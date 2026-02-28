# Skill: validate-security

**Propósito**: Valida reglas de seguridad y buenas prácticas específicas del toolkit:
Meta Graph API, Anthropic API, web scraping y notificaciones Telegram.
**Modelo**: `claude-sonnet-4-6`
**Usado por**: `/security-audit`

---

## Severidades

| Nivel | Acción requerida |
|---|---|
| 🔴 CRÍTICO | Bloquea el despliegue — riesgo de fuga de credenciales o pérdida de cuenta |
| 🟠 ALTO | Debe corregirse antes de producción — puede causar costos descontrolados o brechas |
| 🟡 MEDIO | Corregir en el siguiente sprint — degradación de servicio o riesgo latente |
| 🟢 BAJO | Buena práctica — mejora mantenibilidad o eficiencia |

---

## CATEGORÍA 1 — Gestión de credenciales

### REGLA 1.1 — Nunca hardcodear secrets en código o prompts
**Severidad**: 🔴 CRÍTICO
**Aplica a**: `deploy/scheduler.py`, todos los archivos `.md` de commands/skills

Cualquier token, API key o contraseña en el código queda expuesta en el repositorio
de git, logs de CI/CD y en cualquier fork. Un token de Instagram comprometido permite
publicar como la empresa o leer todos los DMs.

```python
# ❌ INCORRECTO — token hardcodeado
INSTAGRAM_TOKEN = "IGQVJXxE4nBmZAQ5eWtFaE..."

def publish_post(caption):
    requests.post(
        "https://graph.facebook.com/v18.0/media",
        params={"access_token": "IGQVJXxE4nBmZAQ5eWtFaE..."}
    )
```

```python
# ✅ CORRECTO — variables de entorno
import os
from dotenv import load_dotenv

load_dotenv()
INSTAGRAM_TOKEN = os.environ["INSTAGRAM_ACCESS_TOKEN"]  # falla si no existe

def publish_post(caption):
    token = os.environ["INSTAGRAM_ACCESS_TOKEN"]
    requests.post(
        "https://graph.facebook.com/v18.0/media",
        params={"access_token": token}
    )
```

---

### REGLA 1.2 — Usar `os.environ[]` (KeyError) no `os.getenv()` (None silencioso)
**Severidad**: 🟠 ALTO
**Aplica a**: `deploy/scheduler.py`, cualquier script de despliegue

`os.getenv("KEY")` retorna `None` si la variable no existe — el error aparece
más tarde como "NoneType is not iterable" o el API recibe `None` como token.
`os.environ["KEY"]` falla inmediatamente con mensaje claro.

```python
# ❌ INCORRECTO — falla silencioso
token = os.getenv("INSTAGRAM_ACCESS_TOKEN")
# Si la variable no existe: token = None
# El error real aparece en la llamada a la API, difícil de diagnosticar

response = requests.post(url, params={"access_token": token})
# Meta retorna: {"error": {"code": 190, "message": "Invalid OAuth..."}}
```

```python
# ✅ CORRECTO — falla rápido y claro
import os

REQUIRED_VARS = [
    "ANTHROPIC_API_KEY",
    "INSTAGRAM_ACCESS_TOKEN",
    "INSTAGRAM_BUSINESS_ACCOUNT_ID",
    "FACEBOOK_ACCESS_TOKEN",
    "FACEBOOK_PAGE_ID",
    "TELEGRAM_BOT_TOKEN",
    "TELEGRAM_CHAT_ID",
]

def validate_env():
    missing = [v for v in REQUIRED_VARS if not os.environ.get(v)]
    if missing:
        raise EnvironmentError(
            f"Variables de entorno faltantes: {', '.join(missing)}\n"
            f"Ver deploy/.env.example para la lista completa."
        )

# Llamar al inicio del scheduler, antes de cualquier otra cosa
validate_env()
```

---

### REGLA 1.3 — El archivo `.env` nunca debe subirse a git
**Severidad**: 🔴 CRÍTICO
**Aplica a**: Raíz del proyecto, `.gitignore`

```bash
# ❌ INCORRECTO — .gitignore incompleto o ausente
# (repositorio sin .gitignore)
git add .env  # accidente común
git commit -m "add config"
git push  # credenciales ahora en GitHub para siempre
```

```bash
# ✅ CORRECTO — .gitignore con todas las exclusiones
# Verificar con: cat .gitignore | grep -E "\.env|\.claude"

# .gitignore
.env
.env.local
.env.*.local
.claude/          # contiene posts, leads, reportes con datos reales
deploy/logs/
*.log

# Verificación antes de cada push:
git diff --cached --name-only | grep -E "\.env$|access_token|api_key"
# Si hay output → abortar el commit
```

---

## CATEGORÍA 2 — Meta Graph API (Instagram + Facebook)

### REGLA 2.1 — Validar expiración de tokens antes de publicar
**Severidad**: 🟠 ALTO
**Aplica a**: `skills/publishing/publish-instagram.md`, `deploy/scheduler.py`

Los tokens de Instagram de larga duración expiran en 60 días.
Si expiran durante un cron job de Railway, el agente falla silenciosamente
y no se publica nada — sin notificar al usuario.

```python
# ❌ INCORRECTO — publicar sin verificar el token
def publish_to_instagram(caption, image_url):
    response = requests.post(
        f"https://graph.facebook.com/v18.0/{ACCOUNT_ID}/media",
        params={
            "image_url": image_url,
            "caption": caption,
            "access_token": INSTAGRAM_TOKEN,
        }
    )
    return response.json()
    # Si el token expiró: retorna error 190 — nadie se entera
```

```python
# ✅ CORRECTO — verificar token antes de usarlo
import httpx
from datetime import datetime, timedelta

async def check_token_validity(token: str) -> dict:
    """Verifica si el token es válido y cuándo expira."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://graph.facebook.com/debug_token",
            params={
                "input_token": token,
                "access_token": token,  # o app_id|app_secret
            }
        )
    data = resp.json().get("data", {})
    expires_at = data.get("expires_at", 0)
    days_left = (expires_at - datetime.now().timestamp()) / 86400

    return {
        "is_valid": data.get("is_valid", False),
        "expires_at": datetime.fromtimestamp(expires_at),
        "days_left": int(days_left),
    }

async def publish_with_token_check(caption, image_url):
    status = await check_token_validity(INSTAGRAM_TOKEN)

    if not status["is_valid"]:
        await send_telegram("🔴 Token de Instagram EXPIRADO. Renovar en Meta Developer.")
        raise ValueError("Token inválido — publicación abortada")

    if status["days_left"] < 10:
        await send_telegram(
            f"⚠️ Token de Instagram expira en {status['days_left']} días. "
            f"Renovar antes del {status['expires_at'].strftime('%d/%m/%Y')}."
        )

    # Continuar con la publicación...
```

---

### REGLA 2.2 — Manejar rate limits de Meta API con backoff
**Severidad**: 🟡 MEDIO
**Aplica a**: `skills/publishing/publish-instagram.md`, `skills/social_monitoring/`

Meta limita a 200 llamadas/hora por token. Publicar + leer comentarios + DMs
puede consumir el límite si no se manejan correctamente los reintentos.

```python
# ❌ INCORRECTO — retry sin espera
def get_comments(media_id):
    for _ in range(3):
        response = requests.get(url, params=params)
        if response.status_code == 200:
            return response.json()
    # Si hay rate limit, los 3 reintentos fallan igual de rápido
```

```python
# ✅ CORRECTO — exponential backoff respetando el header Retry-After
import time
import httpx

async def meta_api_call(url: str, params: dict, max_retries: int = 3):
    """Llamada a Meta API con manejo de rate limits."""
    for attempt in range(max_retries):
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params, timeout=30)

        if resp.status_code == 200:
            return resp.json()

        if resp.status_code == 429:  # Rate limit
            retry_after = int(resp.headers.get("Retry-After", 60 * (2 ** attempt)))
            print(f"Rate limit Meta API. Esperando {retry_after}s (intento {attempt+1})")
            time.sleep(retry_after)
            continue

        if resp.status_code in (400, 403):
            error = resp.json().get("error", {})
            raise ValueError(f"Meta API error {error.get('code')}: {error.get('message')}")

    raise RuntimeError(f"Meta API no respondió después de {max_retries} intentos")
```

---

### REGLA 2.3 — Nunca publicar precios en comentarios públicos
**Severidad**: 🟠 ALTO
**Aplica a**: `skills/social_monitoring/respond-comments.md`, prompts de agentes

Publicar precios en comentarios visibles crea compromisos legales,
permite a competidores ver la estructura de precios y reduce el margen
de negociación. Es una regla de negocio B2B crítica.

```
# ❌ INCORRECTO — prompt que podría incluir precios
SYSTEM: Eres el community manager. Responde con información completa.
USER: El cliente pregunta "¿cuánto cuesta el metro de tela reciclada GOTS?"

# Respuesta peligrosa que el modelo podría generar:
"¡Hola! El metro de tela reciclada GOTS nos está a $8.500 COP
para pedidos menores a 500m..."
```

```
# ✅ CORRECTO — regla explícita en el prompt del skill
SYSTEM:
Eres el community manager B2B de {COMPANY_NAME}.

REGLAS DE ORO (NUNCA ROMPER):
1. NUNCA publicar precios, descuentos ni condiciones comerciales en comentarios públicos
2. NUNCA mencionar nombres de clientes actuales
3. SIEMPRE mover consultas de precio a DM o WhatsApp
4. Si el modelo genera una respuesta con precio → rechazarla y regenerar

ANTE CONSULTA DE PRECIO, responder SIEMPRE con:
"¡Hola {NOMBRE}! Los precios varían según volumen y especificación.
Te escribimos por DM ahora mismo con la info 📩"
```

---

### REGLA 2.4 — Validar permisos de la app antes de operaciones críticas
**Severidad**: 🟡 MEDIO
**Aplica a**: `deploy/scheduler.py`, setup inicial

```python
# ❌ INCORRECTO — asumir que los permisos están configurados
def setup():
    print("Iniciando agente publicador...")
    # El agente intentará publicar y fallará con error críptico
    # si falta el permiso instagram_content_publish
```

```python
# ✅ CORRECTO — verificar permisos al inicio
REQUIRED_PERMISSIONS = {
    "publisher": ["instagram_content_publish", "pages_manage_posts"],
    "monitoring": ["instagram_manage_comments", "pages_read_engagement"],
    "respond":    ["instagram_manage_comments", "pages_manage_engagement"],
}

async def check_permissions(token: str, agent: str) -> list[str]:
    """Retorna lista de permisos faltantes."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://graph.facebook.com/me/permissions",
            params={"access_token": token}
        )
    granted = {p["permission"] for p in resp.json().get("data", [])
               if p["status"] == "granted"}
    required = set(REQUIRED_PERMISSIONS.get(agent, []))
    return list(required - granted)  # [] si todos los permisos están OK

# En el scheduler:
missing = await check_permissions(INSTAGRAM_TOKEN, agent_name)
if missing:
    await send_telegram(f"❌ Permisos faltantes para {agent_name}: {missing}")
    sys.exit(1)
```

---

## CATEGORÍA 3 — Anthropic API

### REGLA 3.1 — Establecer `max_tokens` apropiado por tarea
**Severidad**: 🟠 ALTO
**Aplica a**: `deploy/scheduler.py`, cualquier llamada directa a la API

Sin `max_tokens`, Claude puede generar respuestas extremadamente largas
que cuestan significativamente más de lo esperado. En producción con cron
jobs diarios, esto se multiplica por el número de ejecuciones.

```python
# ❌ INCORRECTO — sin límite de tokens
response = client.messages.create(
    model="claude-opus-4-6",
    messages=[{"role": "user", "content": long_prompt}]
    # max_tokens no especificado → default puede ser muy alto
)
```

```python
# ✅ CORRECTO — max_tokens ajustado por tipo de tarea
MAX_TOKENS_BY_AGENT = {
    "publisher":        4096,   # caption + hashtags, no necesita más
    "social-report":    8192,   # reporte estructurado puede ser largo
    "respond-comments": 2048,   # respuestas cortas, múltiples comentarios
    "market-intel":    16384,   # análisis profundo justifica más tokens
    "prospecting":      8192,   # lista de leads + mensajes de contacto
}

response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=MAX_TOKENS_BY_AGENT.get(agent_name, 4096),
    messages=[{"role": "user", "content": prompt}]
)

# Monitorear uso real para ajustar:
actual_tokens = response.usage.output_tokens
if actual_tokens > MAX_TOKENS_BY_AGENT[agent_name] * 0.9:
    log(agent_name, f"⚠️ Uso cercano al límite: {actual_tokens} tokens", "WARN")
```

---

### REGLA 3.2 — Usar el modelo correcto para cada tarea
**Severidad**: 🟡 MEDIO
**Aplica a**: Todos los archivos de skills y commands

Usar `claude-opus-4-6` para clasificar spam de comentarios cuesta ~25x más
que `claude-haiku-4-5` sin beneficio real en calidad.

```
# ❌ INCORRECTO — opus para todas las tareas
skills/publishing/generate-b2b-content.md  → claude-opus-4-6  ✅ (correcto)
skills/social_monitoring/respond-comments.md → claude-opus-4-6  ❌ (excesivo)
skills/social_monitoring/send-telegram.md  → claude-opus-4-6  ❌ (absurdo)
```

```
# ✅ CORRECTO — modelo apropiado por complejidad de tarea

claude-opus-4-6   → Generación de contenido creativo B2B
                  → Análisis estratégico de mercado
                  → Prospección y calificación de leads
                  → Planificación de secuencias de seguimiento

claude-sonnet-4-6 → Respuestas a comentarios (requiere tono y personalización)
                  → Reportes de métricas (estructuración de datos)
                  → Follow-up de leads (mensajes humanos pero repetitivos)

claude-haiku-4-5  → Clasificación de tipo de comentario (spam/positivo/negativo)
                  → Extracción de datos de respuestas de API
                  → Validaciones simples y filtros
```

---

### REGLA 3.3 — No loguear prompts completos que contengan datos de clientes
**Severidad**: 🔴 CRÍTICO
**Aplica a**: `deploy/scheduler.py`, cualquier sistema de logging

Los prompts pueden contener comentarios de usuarios, nombres de leads,
datos de empresas. Guardarlos en logs puede violar GDPR/habeas data.

```python
# ❌ INCORRECTO — logear el prompt completo
def run_agent(agent_name, prompt):
    log.info(f"Ejecutando {agent_name} con prompt: {prompt}")
    # El prompt puede contener: "El usuario @maria_hernandez preguntó sobre
    # precios y dejó su teléfono 300-123-4567..."
```

```python
# ✅ CORRECTO — loguear solo metadata, nunca el contenido
def run_agent(agent_name: str, prompt: str):
    log.info(f"[{agent_name}] Iniciando | prompt_chars={len(prompt)} | "
             f"model={MODEL} | max_tokens={MAX_TOKENS}")

    # Si necesitas debug, loguear solo las primeras palabras (sin datos personales)
    preview = prompt[:50].replace("\n", " ")
    log.debug(f"[{agent_name}] Prompt preview: '{preview}...'")

    # NUNCA: log.debug(f"Prompt completo: {prompt}")
```

---

### REGLA 3.4 — Manejar `bypassPermissions` con consciencia
**Severidad**: 🟠 ALTO
**Aplica a**: `deploy/scheduler.py`

`permission_mode="bypassPermissions"` con `allow_dangerously_skip_permissions=True`
es necesario para Railway (no hay humano para aprobar acciones), pero debe
usarse SOLO en el scheduler de producción, nunca en desarrollo local.

```python
# ❌ INCORRECTO — bypassPermissions en desarrollo
# Un bug en el agente puede borrar archivos, hacer llamadas API no deseadas,
# o publicar contenido sin revisión

options = ClaudeAgentOptions(
    permission_mode="bypassPermissions",
    allow_dangerously_skip_permissions=True,
)
# Usar esto en local durante desarrollo es peligroso
```

```python
# ✅ CORRECTO — modo según entorno
import os

IS_PRODUCTION = os.environ.get("RAILWAY_ENVIRONMENT") == "production"
IS_STAGING    = os.environ.get("RAILWAY_ENVIRONMENT") == "staging"

if IS_PRODUCTION:
    permission_mode = "bypassPermissions"
    skip_permissions = True
elif IS_STAGING:
    permission_mode = "acceptEdits"   # acepta edits de archivo, pregunta el resto
    skip_permissions = False
else:
    # Desarrollo local: siempre pedir confirmación
    permission_mode = "default"
    skip_permissions = False

options = ClaudeAgentOptions(
    permission_mode=permission_mode,
    allow_dangerously_skip_permissions=skip_permissions,
    max_turns=MAX_TURNS_BY_AGENT.get(agent_name, 20),
)
```

---

## CATEGORÍA 4 — Web Scraping y WebSearch

### REGLA 4.1 — Respetar robots.txt y términos de servicio
**Severidad**: 🟡 MEDIO
**Aplica a**: `skills/market_intelligence/track-competitors.md`, `skills/prospecting/search-leads.md`

El toolkit usa `WebSearch` y `WebFetch` del Agent SDK — esto hace peticiones
HTTP reales. Violar `robots.txt` o los TOS de sitios puede resultar en bloqueos
de IP o problemas legales.

```
# ❌ INCORRECTO — prompt que instruye scraping agresivo
USER: Descarga todos los productos y precios del sitio competidor.com,
incluyendo las páginas de descuentos para clientes registrados.
Usa paginación automática para obtener todo.
# Problemas: acceso a área privada + scraping masivo + no respeta ToS
```

```
# ✅ CORRECTO — reglas explícitas en los skills de market intelligence
SYSTEM:
Cuando uses WebFetch para investigar competidores o leads:

PERMITIDO:
- Páginas públicas de "Nosotros", "Productos", "Servicios"
- Blogs y artículos publicados
- Comunicados de prensa y noticias
- Perfiles públicos de LinkedIn (lectura, no descarga masiva)
- Directorios industriales públicos

NO PERMITIDO:
- Páginas que requieran login o registro
- APIs privadas o endpoints internos
- Datos detrás de paywalls
- Más de 5-10 páginas del mismo dominio por sesión
- Descargar imágenes, PDFs o archivos en masa

Si un sitio bloquea la solicitud o retorna 403 → no reintentar, registrar como
"acceso no disponible" y continuar con siguiente fuente.
```

---

### REGLA 4.2 — No almacenar datos personales de prospectos sin base legal
**Severidad**: 🔴 CRÍTICO
**Aplica a**: `skills/prospecting/search-leads.md`, `.claude/leads/`

Guardar nombres, emails, teléfonos y cargos de personas en archivos JSON
sin consentimiento puede violar GDPR (Europa), habeas data (Colombia),
Ley Federal de Datos (México), LGPD (Brasil).

```json
// ❌ INCORRECTO — almacenar PII innecesaria
{
  "company": "Confecciones El Valle",
  "contact": {
    "name": "María Hernández",
    "personal_email": "maria.hernandez@gmail.com",
    "personal_phone": "311-234-5678",
    "home_address": "Calle 45 #12-34, Bogotá",
    "linkedin_connections": 847,
    "estimated_salary": "8-12M COP"
  }
}
```

```json
// ✅ CORRECTO — solo datos profesionales públicos y con propósito
{
  "company": "Confecciones El Valle",
  "source": "linkedin_public_profile",
  "collected_date": "2026-02-27",
  "retention_until": "2026-08-27",
  "contact": {
    "name": "María Hernández",
    "role": "Gerente de Compras",
    "professional_email": "compras@confeccioneselvalle.com",
    "linkedin_url": "linkedin.com/in/maria-hernandez-compras"
  },
  "outreach_notes": "Publicó búsqueda de proveedor GOTS en LinkedIn el 2026-02-20"
  // Sin teléfonos personales, emails privados ni datos de redes personales
}
```

---

### REGLA 4.3 — Rate limiting entre llamadas de WebFetch
**Severidad**: 🟡 MEDIO
**Aplica a**: `skills/prospecting/search-leads.md`, `skills/market_intelligence/`

El Agent SDK puede encadenar muchas llamadas `WebFetch` seguidas.
Sin delays, puede triggear anti-bot de los sitios objetivo.

```
# ❌ INCORRECTO — prompt que instruye fetch masivo
USER: Busca información de estas 50 empresas: [lista].
Para cada una, visita su web, su LinkedIn, su página de clientes y su blog.
# → 200+ requests en segundos → IP bloqueada
```

```
# ✅ CORRECTO — instrucciones de rate limiting en el skill
SYSTEM:
Al usar WebFetch para investigar múltiples empresas:
- Procesa máximo 10 empresas por sesión
- Entre cada empresa, razona brevemente antes de continuar (simula pausa natural)
- Si un sitio retorna 429, 403 o error de conexión → omitir y continuar con siguiente
- No visitar más de 3 URLs del mismo dominio en una misma sesión
- Priorizar fuentes públicas agregadas (LinkedIn, Camara de Comercio, Portafolio)
  sobre sitios individuales de empresa
```

---

## CATEGORÍA 5 — Telegram

### REGLA 5.1 — Nunca enviar datos sensibles por Telegram
**Severidad**: 🟠 ALTO
**Aplica a**: `skills/social_monitoring/send-telegram.md`, `deploy/scheduler.py`

Telegram no es un canal seguro para datos de negocio sensibles.
Los mensajes pueden leerse en múltiples dispositivos, backups de nube, etc.

```python
# ❌ INCORRECTO — enviar datos sensibles en notificación
await send_telegram(
    f"🚨 Error en publisher\n"
    f"Token: {INSTAGRAM_TOKEN}\n"     # ← NUNCA
    f"Error: {full_exception_trace}"  # puede contener tokens en el stack
)

# También incorrecto: incluir datos de leads en el resumen
await send_telegram(
    f"Nuevos leads:\n"
    f"• María Hernández - 311-234-5678 - maria@gmail.com\n"  # PII en Telegram
)
```

```python
# ✅ CORRECTO — solo metadata y resúmenes, sin datos sensibles
await send_telegram(
    f"🚨 Error en *{agent_name}*\n"
    f"Tipo: {type(error).__name__}\n"          # nombre del error, no el trace
    f"Mensaje: {str(error)[:100]}\n"           # primeros 100 chars
    f"Ver logs: `.claude/logs/{agent_name}-{date}.log`"
)

# Para leads: solo conteo y categorías, nunca PII
await send_telegram(
    f"✅ Prospección completada\n"
    f"🔥 Hot leads: 3 | ✅ Warm: 5 | 🟡 Cold: 4\n"
    f"📁 Detalle en `.claude/leads/{date}/`"
)
```

---

### REGLA 5.2 — Validar `TELEGRAM_CHAT_ID` antes de enviar
**Severidad**: 🟡 MEDIO
**Aplica a**: `deploy/scheduler.py`, `skills/social_monitoring/send-telegram.md`

Un `CHAT_ID` incorrecto puede enviar reportes de negocio a un chat equivocado
(grupo público, usuario desconocido), exponiendo datos de la empresa.

```python
# ❌ INCORRECTO — enviar sin validar el destinatario
async def send_telegram(message: str):
    chat_id = os.getenv("TELEGRAM_CHAT_ID")  # puede ser None o incorrecto
    await bot.send_message(chat_id=chat_id, text=message)
```

```python
# ✅ CORRECTO — validar que el chat existe y es el correcto en el setup
async def validate_telegram_config():
    """Verificar que el bot puede contactar al chat correcto."""
    token = os.environ["TELEGRAM_BOT_TOKEN"]
    chat_id = os.environ["TELEGRAM_CHAT_ID"]

    async with httpx.AsyncClient() as client:
        # Verificar token
        me = await client.get(f"https://api.telegram.org/bot{token}/getMe")
        if not me.json().get("ok"):
            raise ValueError("TELEGRAM_BOT_TOKEN inválido")

        # Enviar mensaje de prueba para confirmar chat_id
        test = await client.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={
                "chat_id": chat_id,
                "text": "🤖 Marketing Agents conectado correctamente.",
                "parse_mode": "Markdown"
            }
        )
        if not test.json().get("ok"):
            error = test.json().get("description", "")
            raise ValueError(f"TELEGRAM_CHAT_ID inválido: {error}")

# Llamar durante /setup-railway y en el primer run de Railway
```

---

## CATEGORÍA 6 — Logs y datos en `.claude/`

### REGLA 6.1 — Retención de datos con fecha de expiración
**Severidad**: 🟡 MEDIO
**Aplica a**: `deploy/scheduler.py`, todos los commands que guardan datos

Los archivos en `.claude/` acumulan datos indefinidamente.
Los leads y reportes contienen datos de personas reales que deben tener
un período de retención definido (máx. 6 meses recomendado).

```python
# ❌ INCORRECTO — guardar sin fecha de expiración ni limpieza
def save_lead(lead_data):
    with open(f".claude/leads/{lead['company']}.json", "w") as f:
        json.dump(lead_data, f)
# Los archivos se acumulan para siempre
```

```python
# ✅ CORRECTO — incluir fecha de retención y limpiar periódicamente
from datetime import datetime, timedelta
import json
from pathlib import Path

RETENTION_DAYS = {
    "leads": 180,    # 6 meses
    "reports": 90,   # 3 meses
    "posts": 365,    # 1 año (historial de publicaciones)
    "runs": 30,      # 30 días (logs de ejecución)
}

def save_with_retention(data: dict, folder: str, filename: str):
    """Guarda datos con metadata de retención."""
    retention = RETENTION_DAYS.get(folder, 90)
    data["_meta"] = {
        "created_at": datetime.now().isoformat(),
        "retain_until": (datetime.now() + timedelta(days=retention)).isoformat(),
        "data_category": folder,
    }
    path = Path(f".claude/{folder}/{datetime.now().strftime('%Y-%m-%d')}")
    path.mkdir(parents=True, exist_ok=True)
    (path / filename).write_text(json.dumps(data, indent=2, ensure_ascii=False))

def cleanup_expired():
    """Ejecutar semanalmente para eliminar datos expirados."""
    for folder in [".claude/leads", ".claude/reports", ".claude/runs"]:
        for file in Path(folder).rglob("*.json"):
            try:
                data = json.loads(file.read_text())
                retain_until = data.get("_meta", {}).get("retain_until")
                if retain_until and datetime.fromisoformat(retain_until) < datetime.now():
                    file.unlink()
            except Exception:
                pass  # archivo sin metadata → ignorar
```

---

## CATEGORÍA 7 — Despliegue en Railway

### REGLA 7.1 — Nunca usar `dontAsk` o `bypassPermissions` en staging
**Severidad**: 🟠 ALTO
**Aplica a**: `deploy/railway.toml`, `deploy/scheduler.py`

Railway permite crear environments (production, staging). El staging
debe poder ejecutar los agentes pero con restricciones para evitar
publicaciones accidentales en las cuentas reales de la empresa.

```toml
# ❌ INCORRECTO — mismo config para staging y producción
[services.deploy]
startCommand = "python deploy/scheduler.py publisher"
# No distingue si está en staging o prod → puede publicar en IG real desde staging
```

```toml
# ✅ CORRECTO — variable de entorno por environment en Railway
[services.deploy]
startCommand = "python deploy/scheduler.py publisher"

# En Railway: configurar variable RAILWAY_ENVIRONMENT por environment
# production → RAILWAY_ENVIRONMENT=production
# staging    → RAILWAY_ENVIRONMENT=staging (Railway lo inyecta automáticamente)
```

```python
# En scheduler.py: comportamiento diferente por environment
IS_PRODUCTION = os.environ.get("RAILWAY_ENVIRONMENT") == "production"

if not IS_PRODUCTION:
    # En staging: ejecutar el agente pero NO publicar
    # Solo genera el contenido y lo guarda localmente
    print("[STAGING] Agente ejecutado en modo dry-run. No se publicó nada.")
    prompt = prompt + "\n\nIMPORTANTE: Estás en ambiente de staging. " \
                      "Genera el contenido completo pero al final SIMULA " \
                      "las publicaciones sin llamar a la API de Meta."
```

---

### REGLA 7.2 — Alertar ante fallos, no fallar silenciosamente
**Severidad**: 🟠 ALTO
**Aplica a**: `deploy/scheduler.py`

En Railway, si un cron job falla sin notificación, pueden pasar días
sin publicaciones o reportes sin que nadie se entere.

```python
# ❌ INCORRECTO — try/except que silencia errores
async def run_agent(agent_name):
    try:
        result = await execute_agent(agent_name)
        return result
    except Exception:
        pass  # El cron job "terminó bien" pero no hizo nada
```

```python
# ✅ CORRECTO — capturar, notificar Y re-lanzar para que Railway marque como failed
async def run_agent(agent_name: str) -> str:
    try:
        result = await execute_agent(agent_name)
        await send_telegram(f"✅ *{agent_name}* completado")
        return result

    except EnvironmentError as e:
        # Credenciales mal configuradas
        await send_telegram(f"🔴 *{agent_name}* — Config inválida\n`{e}`")
        raise  # Railway verá exit code != 0

    except httpx.TimeoutException:
        await send_telegram(f"⏱ *{agent_name}* — Timeout (Meta/Telegram API)")
        raise

    except Exception as e:
        # Error inesperado
        await send_telegram(
            f"❌ *{agent_name}* falló inesperadamente\n"
            f"Error: `{type(e).__name__}: {str(e)[:150]}`\n"
            f"Revisar logs en Railway dashboard"
        )
        raise  # SIEMPRE re-lanzar para que Railway registre el fallo
```

---

## Checklist de auditoría rápida

Claude Code debe verificar estos puntos al ejecutar `/security-audit`:

### Críticos (🔴) — Bloquean despliegue
- [ ] No hay tokens ni API keys hardcodeados en ningún archivo `.md`, `.py` o `.toml`
- [ ] `.gitignore` excluye `.env`, `.claude/` y `*.log`
- [ ] El archivo `.env` no está trackeado por git (`git ls-files .env` → vacío)
- [ ] Los prompts no incluyen instrucciones para revelar precios en comentarios públicos
- [ ] Los logs no incluyen datos personales ni credentials

### Altos (🟠) — Corregir antes de producción
- [ ] `validate_env()` verifica todas las variables al inicio del scheduler
- [ ] Hay verificación de expiración de token de Instagram (60 días)
- [ ] `bypassPermissions` solo activo en `RAILWAY_ENVIRONMENT=production`
- [ ] Los errores notifican por Telegram Y re-lanzan la excepción (exit code != 0)
- [ ] `max_tokens` definido por agente (no usar default)

### Medios (🟡) — Corregir antes del siguiente sprint
- [ ] Rate limiting en llamadas a Meta API (backoff exponencial)
- [ ] WebFetch no excede 10 empresas por sesión de prospecting
- [ ] `TELEGRAM_CHAT_ID` validado en el setup inicial
- [ ] Los datos de leads tienen campo `retain_until` (máx. 6 meses)
- [ ] Modelo apropiado por tipo de tarea (haiku para clasificación simple)

### Bajos (🟢) — Buenas prácticas
- [ ] Logs incluyen `agent_name`, timestamp y duración (no contenido de prompts)
- [ ] `railway.toml` tiene environment staging con dry-run activado
- [ ] `cleanup_expired()` programado semanalmente para borrar datos viejos
- [ ] Permisos de Meta API verificados al inicio de cada agente

## Output de la auditoría

```markdown
## SECURITY AUDIT — Marketing Agents Toolkit
Fecha: {FECHA} | Entorno: {development/staging/production}

### 🔴 CRÍTICOS (0 encontrados / N encontrados)
[Si hay: listar cada hallazgo con archivo, línea y cómo corregir]

### 🟠 ALTOS (N encontrados)
- deploy/scheduler.py:45 — `os.getenv()` en lugar de `os.environ[]` para INSTAGRAM_TOKEN
  Corrección: cambiar a `INSTAGRAM_TOKEN = os.environ["INSTAGRAM_ACCESS_TOKEN"]`

### 🟡 MEDIOS (N encontrados)
[...]

### 🟢 BAJOS (N encontrados)
[...]

### ✅ APROBADOS
- No se encontraron secrets hardcodeados ✅
- .gitignore correcto ✅
- max_tokens definido en todos los agentes ✅

VEREDICTO: {APTO PARA PRODUCCIÓN / CORREGIR CRÍTICOS ANTES DE DESPLEGAR}
```

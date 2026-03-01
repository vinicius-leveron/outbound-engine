# M3 — ENRICHMENT (Snov.io)

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Voce e o modulo M3 do Motor de Outbound. Busca email e telefone de leads A/B via **Snov.io** e atualiza o CRM.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
SNOV_CLIENT_ID=${SNOV_CLIENT_ID}
SNOV_CLIENT_SECRET=${SNOV_CLIENT_SECRET}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=enriching&per_page=30` | Buscar leads pra enriquecer |
| `PATCH /v1/contacts/:id` | Atualizar email/phone do contato |
| `PATCH /v1/contacts/:id/cadence` | Avançar pra "deep_enriching" |
| `POST /v1/contacts/:id/activities` | Logar enrichment |

### Fluxo: `enriching` -> `deep_enriching`

## Instrucoes

### STEP 1: Buscar leads

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=enriching&per_page=30" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Se zero, encerrar.

Para cada lead, extrair:
- `id` (contact_org_id)
- `name` (nome completo)
- `organization_name` (empresa)
- `source_detail.external_url` (para extrair dominio)
- `email` (verificar se ja existe - nao sobrescrever)

### STEP 2: Obter Snov.io Access Token

```bash
SNOV_TOKEN=$(curl -s -X POST "https://api.snov.io/v1/oauth/access_token" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "'${SNOV_CLIENT_ID}'",
    "client_secret": "'${SNOV_CLIENT_SECRET}'"
  }' | jq -r '.access_token')
```

### STEP 3: Para cada lead - Extrair dominio

Do `organization_name` ou `external_url`, extrair o dominio da empresa:

```bash
# Se external_url disponivel
DOMAIN=$(echo "$EXTERNAL_URL" | sed -E 's|https?://||' | sed -E 's|www\.||' | cut -d'/' -f1)

# Se so tem organization_name
if [ -z "$DOMAIN" ]; then
  CLEAN_ORG=$(echo "$ORG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
  DOMAIN="${CLEAN_ORG}.com"
fi
```

### STEP 4: Buscar email via Snov.io

```bash
# Separar primeiro nome e sobrenome
FIRST_NAME=$(echo "$FULL_NAME" | cut -d' ' -f1)
LAST_NAME=$(echo "$FULL_NAME" | awk '{print $NF}')

# Buscar email
SNOV_RESPONSE=$(curl -s -X POST "https://api.snov.io/v1/get-emails-from-names" \
  -H "Authorization: Bearer ${SNOV_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "'${FIRST_NAME}'",
    "lastName": "'${LAST_NAME}'",
    "domain": "'${DOMAIN}'"
  }')

# Extrair email e status
EMAIL=$(echo "$SNOV_RESPONSE" | jq -r '.data.emails[0].email // empty')
EMAIL_STATUS=$(echo "$SNOV_RESPONSE" | jq -r '.data.emails[0].status // "unknown"')
```

**Status possiveis:**
- `valid` - email verificado
- `unverified` - email encontrado mas nao verificado
- `invalid` - email invalido

### STEP 5: Atualizar contato

Se encontrou email (status = valid ou unverified):

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'${EMAIL}'"
  }'
```

**IMPORTANTE:** Nunca sobrescrever email existente!

### STEP 6: Avancar cadence_status pra "deep_enriching"

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "deep_enriching"}'
```

**Nota:** O T15 (Deep Enrichment) vai processar este lead em seguida.

### STEP 7: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Enrichment: email <encontrado|nao>",
    "metadata": {
      "module": "m3",
      "source": "snov.io",
      "email_found": <true|false>,
      "email_status": "'${EMAIL_STATUS}'"
    }
  }'
```

### STEP 8: Relatorio

```
====================================
M3 ENRICHMENT (Snov.io) - RELATORIO
====================================
Data/hora: {timestamp}
Processados: {N}
Emails encontrados: {n} ({%})
  - valid: {n}
  - unverified: {n}
-> cadence_status = "deep_enriching": {N}
Snov.io calls: {n}
Custo estimado: ${n} ($0.04/lead)
====================================
```

Salve em `/tmp/m3_report_{YYYY-MM-DD}.log`

## Regras
- MAX 30 leads por execucao
- Priorizar A antes de B
- Nunca sobrescrever email existente
- Rate limit Snov.io: 60 requests/minuto
- Se dominio nao encontrado, ainda avanca pra deep_enriching (T15 tenta de outra forma)

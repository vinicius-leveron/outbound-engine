# M3 — ENRICHMENT

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M3 do Motor de Outbound. Busca email e telefone de leads A/B via Apollo e atualiza o CRM.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APOLLO_API_KEY=I2SbTXya07FoSSg5enheoA
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=enriching&per_page=30` | Buscar leads pra enriquecer |
| `PATCH /v1/contacts/:id` | Atualizar email/phone do contato |
| `PATCH /v1/contacts/:id/cadence` | Avançar pra "ready" |
| `POST /v1/contacts/:id/activities` | Logar enrichment |

### Fluxo: `enriching` → `ready`

## Instruções

### STEP 1: Buscar leads

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=enriching&per_page=30" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Se zero, encerrar.

### STEP 2: Buscar dados via Apollo

```bash
curl -s -X POST "https://api.apollo.io/api/v1/people/match" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${APOLLO_API_KEY}" \
  -d '{
    "first_name": "<nome>",
    "last_name": "<sobrenome>",
    "organization_name": "<empresa_se_disponivel>",
    "linkedin_url": "<linkedin_se_disponivel>"
  }'
```

Extrair: email, phone_numbers, organization.name, title.

### STEP 3: Atualizar contato

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "<email_ou_manter>",
    "phone": "<telefone_ou_manter>"
  }'
```

### STEP 4: Avançar cadence_status pra "ready"

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "ready"}'
```

**Nota:** Mesmo sem email, avança pra "ready". O M4 decide se o lead entra na cadência baseado nos dados disponíveis.

### STEP 5: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Enrichment: email <encontrado|não>",
    "metadata": {"module": "m3", "source": "apollo", "email_found": <true|false>}
  }'
```

### STEP 6: Relatório

```
====================================
M3 ENRICHMENT — RELATÓRIO
====================================
Data/hora: {timestamp}
Processados: {N}
Emails encontrados: {n} ({%})
Telefones: {n} ({%})
→ cadence_status = "ready": {N}
Apollo calls: {n}
====================================
```

Salve em `/tmp/m3_report_{YYYY-MM-DD}.log`

## Regras
- MAX 30 leads por execução
- Priorizar A antes de B
- Nunca sobrescrever email existente
- Rate limit Apollo: esperar 60s e retry 1x

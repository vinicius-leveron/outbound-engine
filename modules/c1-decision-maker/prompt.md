# C1-DECISION-MAKER — Identificacao e Enrichment do Decisor

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Voce e o modulo C1-Decision-Maker do Motor de Outbound. Sua funcao e identificar o melhor decisor em cada escritorio de advocacia (a partir dos dados do C1-Web-Enrich), buscar email via Snov.io, e preparar o lead para prospeccao.

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
| `GET /v1/contacts?cadence_status=web_enriched&tenant=advocacia-tech&per_page=30` | Buscar escritorios pra processar |
| `PATCH /v1/contacts/:id` | Atualizar com dados do decisor |
| `PATCH /v1/contacts/:id/cadence` | Avancar pra "dm_identified" |
| `POST /v1/contacts/:id/activities` | Logar identificacao |

### Fluxo: `web_enriched` -> `dm_identified`

## Hierarquia de Decisores

Ordem de prioridade para escritorios de advocacia:

| Prioridade | Titulo | Score Base |
|------------|--------|------------|
| 1 | Socio-Administrador, Managing Partner | 100 |
| 2 | Socio-Gerente, Diretor Administrativo | 95 |
| 3 | COO, Diretor de Operacoes | 90 |
| 4 | Socio (area Empresarial/Tech/Digital) | 85 |
| 5 | Socio (outras areas) | 75 |
| 6 | Advogado Senior / Of Counsel | 50 |
| 7 | Socio-fundador (escritorio pequeno) | 95 |

**Regra especial:** Se escritorio tem <= 5 membros, ir direto no socio-fundador.

## Instrucoes

### STEP 1: Buscar escritorios

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=web_enriched&tenant=advocacia-tech&per_page=30" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Se zero leads, logar e encerrar.

Para cada escritorio, extrair:
- `id` (contact_org_id)
- `organization_name`
- `source_detail.team_members[]` (lista de membros)
- `source_detail.team_count`
- `source_detail.google_maps.website` (dominio para Snov.io)
- `source_detail` (JSON completo)

### STEP 2: Ranquear membros por score de decisao

Para cada membro em `team_members`:

```python
def calculate_dm_score(member, team_count):
    score = 0
    title = member.get('title', '').lower()
    area = member.get('area', '').lower()

    # Score por titulo
    if any(t in title for t in ['socio-administrador', 'managing partner', 'socio administrador']):
        score = 100
    elif any(t in title for t in ['socio-gerente', 'diretor administrativo', 'socio gerente']):
        score = 95
    elif any(t in title for t in ['coo', 'diretor de operacoes', 'diretor operacoes']):
        score = 90
    elif 'socio' in title or 'partner' in title:
        # Bonus por area tech-friendly
        if any(a in area for a in ['empresarial', 'digital', 'tech', 'startups', 'm&a', 'societario']):
            score = 85
        else:
            score = 75
    elif any(t in title for t in ['senior', 'of counsel']):
        score = 50
    elif 'fundador' in title:
        score = 90 if team_count <= 5 else 80
    else:
        score = 30

    # Bonus: tem email no site
    if member.get('email'):
        score += 5

    # Bonus: tem LinkedIn
    if member.get('linkedin'):
        score += 3

    return min(score, 100)
```

Selecionar o membro com maior score como **decisor principal**.

### STEP 3: Obter Snov.io Access Token

```bash
SNOV_TOKEN=$(curl -s -X POST "https://api.snov.io/v1/oauth/access_token" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "'${SNOV_CLIENT_ID}'",
    "client_secret": "'${SNOV_CLIENT_SECRET}'"
  }' | jq -r '.access_token')
```

### STEP 4: Buscar email do decisor via Snov.io

Se o decisor nao tem email no site:

```bash
# Extrair dominio do website
DOMAIN=$(echo "${WEBSITE_URL}" | sed -E 's|https?://||' | sed -E 's|www\.||' | cut -d'/' -f1)

# Separar nome
FIRST_NAME=$(echo "${DM_NAME}" | cut -d' ' -f2)  # Pular "Dr." ou "Dra."
LAST_NAME=$(echo "${DM_NAME}" | awk '{print $NF}')

# Buscar email
SNOV_RESPONSE=$(curl -s -X POST "https://api.snov.io/v1/get-emails-from-names" \
  -H "Authorization: Bearer ${SNOV_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "'${FIRST_NAME}'",
    "lastName": "'${LAST_NAME}'",
    "domain": "'${DOMAIN}'"
  }')

EMAIL=$(echo "$SNOV_RESPONSE" | jq -r '.data.emails[0].email // empty')
EMAIL_STATUS=$(echo "$SNOV_RESPONSE" | jq -r '.data.emails[0].status // "not_found"')
```

**Fallback se Snov.io nao encontrar:**
Tentar padroes comuns de emails juridicos:
- `nome.sobrenome@dominio.com.br`
- `nome@dominio.com.br`
- `n.sobrenome@dominio.com.br`
- `contato@dominio.com.br` (generico)

### STEP 5: Salvar decisor no CRM

```bash
# Ler source_detail atual
CURRENT_SOURCE_DETAIL=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq '.source_detail')

# Preparar dados do decisor
DECISION_MAKER_DATA='{
  "decision_maker": {
    "name": "'"${DM_NAME}"'",
    "title": "'"${DM_TITLE}"'",
    "area": "'"${DM_AREA}"'",
    "oab": "'"${DM_OAB}"'",
    "email": "'"${DM_EMAIL}"'",
    "email_status": "'"${EMAIL_STATUS}"'",
    "email_source": "'"${EMAIL_SOURCE}"'",
    "linkedin_url": "'"${DM_LINKEDIN}"'",
    "dm_score": '"${DM_SCORE}"',
    "identified_at": "'$(date -Iseconds)'"
  }
}'

# Merge e salvar
MERGED=$(echo "$CURRENT_SOURCE_DETAIL" "$DECISION_MAKER_DATA" | jq -s '.[0] * .[1]')

curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "source_detail": '"$MERGED"',
    "email": "'"${DM_EMAIL}"'",
    "name": "'"${DM_NAME}"'"
  }'
```

**IMPORTANTE:** Tambem atualizar campos raiz do contato:
- `name` = nome do decisor (para personalizacao)
- `email` = email do decisor (para envio)

### STEP 6: Avancar cadence_status

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "dm_identified"}'
```

### STEP 7: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Decisor identificado: '"${DM_NAME}"' ('"${DM_TITLE}"')",
    "metadata": {
      "module": "c1-decision-maker",
      "dm_name": "'"${DM_NAME}"'",
      "dm_title": "'"${DM_TITLE}"'",
      "dm_score": '"${DM_SCORE}"',
      "email_found": '"${EMAIL_FOUND}"',
      "email_source": "'"${EMAIL_SOURCE}"'"
    }
  }'
```

### STEP 8: Relatorio

```
====================================
C1-DECISION-MAKER — RELATORIO
====================================
Data/hora: {timestamp}

PROCESSAMENTO:
  Escritorios processados: {N}
  Com team_members: {N}
  Sem team_members: {N}

DECISORES IDENTIFICADOS:
  Total: {N}
  Por titulo:
    - Socio-Administrador: {n}
    - Socio-Gerente: {n}
    - Socio (area tech): {n}
    - Socio (outras): {n}
    - Outro: {n}

  Score medio: {X}/100

EMAIL ENRICHMENT:
  Emails do site: {n}
  Emails via Snov.io: {n}
    - valid: {n}
    - unverified: {n}
  Emails nao encontrados: {n}

  Taxa de sucesso: {%}

STATUS:
  cadence_status = "dm_identified": {N}
  Snov.io calls: {N}
  Custo Snov.io: ~${X}

Top 5 decisores por score:
1. {nome} ({titulo}) - Score: {score} - {escritorio}
====================================
```

Salve em `logs/c1_decision_maker_report_{YYYY-MM-DD}.log`

## Fluxo de Cadence

```
web_enriched → (C1-DecisionMaker) → dm_identified → (M2-ICP-Scoring) → enriching
```

## Regras

- MAX 30 escritorios por execucao
- Priorizar escritorios com team_members
- Se nenhum membro encontrado, usar email generico (contato@)
- Rate limit Snov.io: 60 requests/minuto
- **NUNCA sobrescrever dados existentes** — apenas ADICIONAR decision_maker

## Fallbacks

| Situacao | Comportamento |
|----------|---------------|
| Sem team_members | Usar contato generico, score = 30 |
| Snov.io nao encontra | Tentar pattern de email comum |
| Pattern nao funciona | Usar contato@ do site |
| Nenhum email | Marcar email_status = "not_found", continuar |

## Exemplo de source_detail FINAL

```json
{
  "google_maps": {
    "place_id": "...",
    "address": "Av. Rio Branco, 123, Florianopolis",
    "website": "https://silvaadvogados.com.br",
    "rating": 4.7,
    "reviews_count": 45
  },
  "website_analysis": {
    "design_score": "modern",
    "has_blog": true,
    "digital_maturity_score": 7
  },
  "practice_areas": ["Empresarial", "Tributario", "M&A"],
  "team_count": 8,
  "team_members": [
    {
      "name": "Dr. Joao Silva",
      "title": "Socio-Administrador",
      "area": "Direito Empresarial",
      "oab": "OAB/SC 12345",
      "email": "joao@silvaadvogados.com.br",
      "is_partner": true
    },
    {"name": "Dra. Maria Santos", "title": "Socia", "area": "Tributario", "is_partner": true}
  ],
  "decision_maker": {
    "name": "Dr. Joao Silva",
    "title": "Socio-Administrador",
    "area": "Direito Empresarial",
    "oab": "OAB/SC 12345",
    "email": "joao@silvaadvogados.com.br",
    "email_status": "valid",
    "email_source": "website",
    "linkedin_url": "linkedin.com/in/joaosilvaadv",
    "dm_score": 100,
    "identified_at": "2025-03-03T10:30:00Z"
  },
  "instagram": {
    "handle": "@silvaadvogados"
  }
}
```

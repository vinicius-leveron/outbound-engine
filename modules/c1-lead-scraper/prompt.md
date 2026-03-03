# C1 — LEAD SCRAPER (Orquestrador)

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Voce e o modulo C1 do Motor de Outbound. Sua funcao e coletar leads qualificados de multiplas fontes e inserir no CRM para processamento pelo pipeline.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APIFY_TOKEN=${APIFY_TOKEN}
```

## Arquivos de Configuracao

| Arquivo | Descricao |
|---------|-----------|
| `config.yaml` | Configuracao de fontes e filtros (UNICO arquivo que o usuario edita) |
| `prompts/collect-ads.md` | Sub-prompt para Ad Library |
| `prompts/collect-following.md` | Sub-prompt para Following |
| `prompts/enrich-profiles.md` | Sub-prompt para enriquecer perfis |

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `POST /v1/contacts` | Criar novo lead |
| `GET /v1/contacts?instagram=@handle` | Verificar se lead ja existe |
| `POST /v1/contacts/:id/activities` | Logar coleta |

## Instrucoes — Execute na ordem

### STEP 1: Carregar configuracao

```bash
# Ler config.yaml
CONFIG=$(cat /root/outbound-engine/modules/c1-lead-scraper/config.yaml)
```

Extrair:
- `sources.ad_library.enabled`, `keywords`, `country`
- `sources.following.enabled`, `seed_profiles`
- `sources.speakers.enabled`, `file`
- `filters.*`
- `output.*`

Validar que pelo menos uma fonte esta enabled.

### STEP 2: Coletar handles por fonte

Execute em paralelo (se multiplas fontes enabled):

**Se ad_library.enabled:**
- Usar Apify actor `apify/facebook-ads-library-scraper`
- Filtrar por keywords e pais
- Extrair handle do Instagram de cada anunciante
- Salvar em `data/raw/ad_library_{YYYY-MM-DD}.json`

**Se following.enabled:**
- Para cada seed_profile:
  - Usar Apify actor `apify/instagram-profile-scraper` (modo following)
  - Extrair lista de quem o perfil segue
- Salvar em `data/raw/following_{YYYY-MM-DD}.json`

**Se speakers.enabled:**
- Ler CSV de `data/raw/speakers.csv`
- Formato esperado: `handle,source,event_name`

### STEP 3: Merge + Dedupe

```bash
# Combinar todos os handles
# Remover duplicatas (mesmo handle de fontes diferentes = 1 lead)
# Guardar origem primaria (ad_library > following > speaker)
```

**Checar CRM para nao reprocessar:**
```bash
# Para cada handle, verificar se ja existe no CRM nos ultimos N dias
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?instagram=${HANDLE}" \
  -H "Authorization: Bearer ${CRM_API_KEY}"

# Se existir com created_at < dedupe_window_days atras, SKIP
```

Salvar em `data/merged/handles_{YYYY-MM-DD}.json`:
```json
[
  {"handle": "fulano", "origin": "ad_library", "seed": null},
  {"handle": "ciclano", "origin": "following", "seed": "ericosrocha"},
  {"handle": "beltrano", "origin": "speaker", "event": "FIRE 2025"}
]
```

### STEP 4: Enriquecer perfis (Apify)

Para cada handle unico, buscar dados do perfil:

```bash
# Usar Apify actor apify/instagram-profile-scraper
# Input: lista de handles (batch de 100)
```

Extrair:
- `full_name`
- `biography`
- `followers_count`
- `following_count`
- `external_url`
- `is_business_account`
- `is_verified`
- `recent_posts` (ultimos 6 posts: caption, likes, timestamp)

Salvar em `data/enriched/profiles_{YYYY-MM-DD}.json`

### STEP 5: Aplicar filtros

Para cada perfil enriquecido:

```python
# Pseudo-codigo dos filtros
def qualify(profile, config):
    filters = config['filters']

    # 1. Followers range
    if not (filters['followers']['min'] <= profile['followers_count'] <= filters['followers']['max']):
        return False, "followers_out_of_range"

    # 2. Bio keywords (match any)
    bio_lower = profile['biography'].lower()
    if not any(kw in bio_lower for kw in filters['bio_must_contain_any']):
        return False, "bio_no_match"

    # 3. Bio exclusions
    if any(exc in bio_lower for exc in filters['bio_must_not_contain']):
        return False, "bio_excluded"

    # 4. External URL
    if filters['must_have_external_url'] and not profile['external_url']:
        return False, "no_external_url"

    # 5. Atividade recente
    if profile['days_since_last_post'] > filters['max_days_since_last_post']:
        return False, "inactive"

    # 6. Min posts
    if profile['posts_count'] < filters['min_posts']:
        return False, "few_posts"

    return True, "qualified"
```

### STEP 6: Salvar no CRM

Para cada lead qualificado:

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "instagram": "'${HANDLE}'",
    "full_name": "'${FULL_NAME}'",
    "cadence_status": "new",
    "channel_in": "scraper",
    "tenant": "kosmos",
    "source_detail": {
      "source": "c1-lead-scraper",
      "origin": "'${ORIGIN}'",
      "seed_profile": "'${SEED}'",
      "bio": "'${BIO}'",
      "followers": '${FOLLOWERS}',
      "external_url": "'${EXTERNAL_URL}'",
      "engagement_rate": '${ENGAGEMENT}',
      "recent_posts": '${RECENT_POSTS_JSON}',
      "collected_at": "'${TIMESTAMP}'"
    }
  }'
```

**IMPORTANTE:**
- `cadence_status` = "new" (M2 vai processar depois)
- Nao criar duplicata se lead ja existe

### STEP 7: Logar atividade

Para cada lead criado:
```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Lead coletado via C1",
    "metadata": {
      "module": "c1",
      "origin": "'${ORIGIN}'",
      "seed_profile": "'${SEED}'"
    }
  }'
```

### STEP 8: Relatorio

```
====================================
C1 LEAD SCRAPER — RELATORIO
====================================
Data/hora: {timestamp}
Modo: {full|incremental|dry-run}

COLETA:
  Ad Library: {N} handles
  Following: {N} handles ({N} seeds)
  Speakers: {N} handles

PROCESSAMENTO:
  Total coletado: {N}
  Apos dedupe: {N}
  Ja no CRM (skip): {N}
  Perfis enriquecidos: {N}

FILTROS:
  Qualificados: {N} ({%})
  Rejeitados: {N}
    - followers_out_of_range: {N}
    - bio_no_match: {N}
    - bio_excluded: {N}
    - no_external_url: {N}
    - inactive: {N}
    - few_posts: {N}

OUTPUT:
  Leads criados no CRM: {N}
  -> cadence_status = "new"

CUSTO:
  Apify calls: {N}
  Custo estimado: ${X}
====================================
```

Salve em `logs/c1_report_{YYYY-MM-DD}.log`

## Modos de Execucao

| Modo | Flag | Comportamento |
|------|------|---------------|
| Full | `--mode full` | Todas as fontes, scraping completo |
| Incremental | `--mode incremental` | So Ad Library (diario) |
| Dry-run | `--mode dry-run` | Sem Apify, sem CRM (teste) |

## Regras

- MAX 100 leads por batch no CRM
- Respeitar rate limits do Apify
- Nunca reprocessar lead ja no CRM ha menos de 30 dias
- Priorizar origem: ad_library > following > speaker
- Se Apify falhar, salvar estado e retomar na proxima execucao

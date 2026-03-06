# T15 — DEEP ENRICHMENT + ANALISE MULTIMODAL

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Modulo de enriquecimento profundo. Comportamento varia por tenant:

- **KOSMOS:** Scrape 3 posts recentes do Instagram via Apify, analisa imagens com Claude (multimodal)
- **OLIVEIRA-DEV:** Scrape Google Maps (reviews) + site do escritório + Instagram (se tiver)

Roda APENAS pra leads A/B. Salva tudo no `source_detail` do CRM (JSONB).

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APIFY_TOKEN=${APIFY_TOKEN}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=deep_enriching&per_page=10` | Buscar leads pra enriquecer |
| `PATCH /v1/contacts/:id` | Atualizar source_detail |
| `PATCH /v1/contacts/:id/cadence` | Avançar pra "ready" |
| `POST /v1/contacts/:id/activities` | Logar enrichment |

### Fluxo: `deep_enriching` -> `ready`

## Instrucoes

### STEP 1: Buscar leads

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=deep_enriching&per_page=10" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Se zero leads, logar e encerrar.

Para cada lead, extrair:
- `id` (contact_org_id)
- `tenant` (kosmos ou oliveira-dev)
- `source_detail` (JSON completo - NAO perder dados existentes)
- `source_detail.instagram` ou username do Instagram
- `classificacao` (A ou B)
- `company_name` (nome do escritório, para oliveira-dev)

**DECISÃO POR TENANT:**
```
SE tenant == "kosmos":
  → Executar STEP 2 (Instagram scraping)
  → Executar STEP 3 (Análise multimodal)

SE tenant == "oliveira-dev":
  → Executar STEP 2-B (Google Maps + Site scraping)
  → Executar STEP 3-B (Análise OLIVEIRA-DEV)
```

---

## KOSMOS: Instagram Enrichment

### STEP 2: Scraping via Apify (por lead)

Para cada lead com Instagram:

#### 2a) Buscar posts do Instagram

```bash
# Iniciar actor run
RUN_ID=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-post-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "directUrls": ["https://www.instagram.com/'${INSTAGRAM_USERNAME}'/"],
    "resultsLimit": 6
  }' | jq -r '.data.id')

# Aguardar conclusao (max 60s)
sleep 30

# Buscar resultados
POSTS=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}/dataset/items?token=${APIFY_TOKEN}")
```

#### 2b) Processar posts

- IGNORAR os 3 primeiros posts (normalmente fixados/pinned)
- Usar posts 4, 5 e 6 (conteudo recente real)
- Para cada post extrair:
  - `caption` (legenda)
  - `type` (carousel/reel/static)
  - `likesCount`
  - `commentsCount`
  - `hashtags`
  - `displayUrl` (URL da imagem)

#### 2c) Download das imagens

```bash
# Download das imagens dos 3 posts
curl -s "${IMAGE_URL_1}" -o /tmp/post_1.jpg
curl -s "${IMAGE_URL_2}" -o /tmp/post_2.jpg
curl -s "${IMAGE_URL_3}" -o /tmp/post_3.jpg
```

### STEP 3: Analise multimodal via Claude

Voce (Claude) tem capacidade multimodal. Use a ferramenta Read para ler as imagens:

```
Read /tmp/post_1.jpg
Read /tmp/post_2.jpg
Read /tmp/post_3.jpg
```

Ao visualizar as imagens + legendas + bio do lead, analise e determine:

```json
{
  "visual_quality": "professional|intermediate|amateur",
  "content_style": "educational|motivational|sales|lifestyle|mixed",
  "tone_of_voice": "motivational|technical|casual|formal",
  "sophistication_level": 1-10,
  "text_in_images": ["textos visiveis nos slides/posts"],
  "product_detected": "descricao do produto/servico se identificado",
  "ctas_detected": ["CTAs visiveis nos posts"],
  "uses_canva": true|false,
  "key_observations": "1-2 frases sobre o perfil para abordagem comercial"
}
```

**Criterios de analise:**

- **visual_quality**:
  - professional = fotos de estudio, design consistente, paleta de cores definida
  - intermediate = bom design mas inconsistente, mix de qualidades
  - amateur = fotos de celular, sem edicao, sem padrao visual

- **content_style**:
  - educational = ensina algo, dicas, tutoriais
  - motivational = frases, inspiracao, mindset
  - sales = foco em vender, CTAs diretos
  - lifestyle = dia a dia, bastidores
  - mixed = combinacao

- **sophistication_level** (1-10):
  - 1-3 = iniciante, conteudo basico
  - 4-6 = intermediario, tem estrutura
  - 7-10 = avancado, produtizacao clara, funil definido

- **uses_canva**: identificar templates tipicos do Canva nos posts

---

## OLIVEIRA-DEV: Google Maps + Site Enrichment

### STEP 2-B: Scraping Google Maps + Site (por lead)

#### 2b-a) Google Maps Reviews

```bash
# Buscar dados do Google Maps do escritório
RUN_ID=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~google-maps-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "searchStringsArray": ["'${COMPANY_NAME}' escritório advocacia"],
    "maxReviews": 5,
    "language": "pt-BR",
    "countryCode": "br"
  }' | jq -r '.data.id')

# Aguardar conclusao (max 60s)
sleep 30

# Buscar resultados
MAPS_DATA=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}/dataset/items?token=${APIFY_TOKEN}")
```

Extrair:
- `rating` (nota geral)
- `reviewsCount` (quantidade de reviews)
- `reviews[]` (últimas 3-5 reviews)
  - `text` (conteúdo da review)
  - `rating` (nota individual)
  - `author` (nome do autor)
- `address`
- `phone`
- `website`

#### 2b-b) Site do Escritório (se disponível)

```bash
# Scrape simples do site
RUN_ID=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~website-content-crawler/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "startUrls": [{"url": "'${WEBSITE_URL}'"}],
    "maxPagesPerCrawl": 5
  }' | jq -r '.data.id')

sleep 30

SITE_DATA=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}/dataset/items?token=${APIFY_TOKEN}")
```

Extrair:
- Lista de advogados (team_size)
- Áreas de atuação
- Se tem portal do cliente (links como "área do cliente", "acompanhe seu processo")

#### 2b-c) Instagram do Escritório (se tiver)

Se `source_detail.instagram` existir, executar scraping igual KOSMOS (posts recentes).

### STEP 3-B: Análise OLIVEIRA-DEV

Analisar dados coletados e gerar:

```json
{
  "google_maps": {
    "rating": 4.8,
    "review_count": 45,
    "recent_reviews": [
      {
        "author": "Maria Silva",
        "text": "Excelente atendimento, sempre me mantiveram informada sobre o andamento do processo",
        "rating": 5
      },
      {
        "author": "João Santos",
        "text": "Escritório organizado, resolveram meu caso rapidamente",
        "rating": 5
      }
    ]
  },
  "website_observations": {
    "team_size": 8,
    "areas": ["família", "sucessões", "imobiliário"],
    "has_client_portal": false,
    "digital_maturity": "low|medium|high"
  },
  "instagram": {
    "handle": "@escritoriosilva",
    "followers": 2500,
    "recent_posts": [
      {"caption": "Vitória no caso...", "likes": 45}
    ]
  },
  "analysis": {
    "detected_pains": ["atendimento ao cliente", "volume de processos"],
    "recommended_service": "portal|gestao",
    "recommended_angle": "atendimento|prazo|tempo_socio|organizacao",
    "key_observations": "Escritório com boa reputação, equipe de 8 advogados, foco em família. Reviews mencionam 'manter informada' - oportunidade para portal de acompanhamento."
  },
  "enriched_at": "2026-03-01T10:00:00Z"
}
```

**Critérios de análise OLIVEIRA-DEV:**

- **detected_pains**: Identificar dores nas reviews e contexto
  - Review menciona "informada/acompanhamento/transparência" → dor de atendimento
  - Review menciona "rápido/eficiente" → escritório já é bom, focar em escalar
  - Team_size > 5 → potencial dor de gestão

- **recommended_service**:
  - `portal` = Portal de acompanhamento (cliente vê status)
  - `gestao` = Sistema de gestão (prazos, organização)

- **recommended_angle** (para sequência de emails):
  - `atendimento` = reduzir ligações de cliente
  - `prazo` = não perder prazos
  - `tempo_socio` = sócio gasta muito tempo em gestão
  - `organizacao` = equipe desalinhada

---

### STEP 4: Salvar no CRM (source_detail JSONB)

**IMPORTANTE:** Fazer MERGE com dados existentes. NAO sobrescrever bio, followers, etc.

```bash
# Ler source_detail atual
CURRENT_SOURCE_DETAIL=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq '.source_detail')

# Preparar dados novos para merge
NEW_DATA='{
  "recent_posts": [
    {"caption": "...", "type": "carousel", "likes": 150, "comments": 12, "hashtags": ["#tag1"]},
    {"caption": "...", "type": "reel", "likes": 320, "comments": 25, "hashtags": ["#tag2"]},
    {"caption": "...", "type": "static", "likes": 85, "comments": 5, "hashtags": []}
  ],
  "claude_analysis": {
    "visual_quality": "intermediate",
    "content_style": "educational",
    "tone_of_voice": "motivational",
    "sophistication_level": 6,
    "text_in_images": ["5 passos para...", "Inscreva-se..."],
    "product_detected": "Mentoria de Produtividade",
    "ctas_detected": ["Link na bio", "Arraste pra cima"],
    "uses_canva": true,
    "key_observations": "Creator educacional, usa Canva, vende mentoria"
  },
  "enriched_at": "'$(date -Iseconds)'"
}'

# Merge e salvar
MERGED=$(echo "$CURRENT_SOURCE_DETAIL" "$NEW_DATA" | jq -s '.[0] * .[1]')

curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"source_detail": '"$MERGED"'}'
```

### STEP 5: Avancar cadence_status pra "ready"

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "ready"}'
```

### STEP 6: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "T15 Deep Enrichment concluido - 3 posts analisados",
    "metadata": {
      "module": "t15",
      "posts_analyzed": 3,
      "has_claude_analysis": true
    }
  }'
```

### STEP 7: Limpar arquivos temporarios

```bash
rm -f /tmp/post_*.jpg
```

### STEP 8: Relatorio

```
====================================
T15 DEEP ENRICHMENT - RELATORIO
====================================
Data/hora: {timestamp}

PROCESSAMENTO:
  Total leads: {N}
  - Classe A: {n}
  - Classe B: {n}

SCRAPING:
  Posts coletados: {n}
  Imagens baixadas: {n}

ANALISE CLAUDE:
  Leads analisados: {n}
  - visual_quality professional: {n}
  - visual_quality intermediate: {n}
  - visual_quality amateur: {n}

FALLBACKS:
  Sem posts publicos: {n}
  Falha no Apify: {n}
  Falha no download: {n}

STATUS:
  cadence_status = "ready": {N}

CUSTO: ~${n} (Apify apenas)
====================================
```

Salve em `/tmp/t15_report_{YYYY-MM-DD}.log`

## Regras

- MAX 10 leads por execucao
- Apify: buscar 6 posts, IGNORAR 3 primeiros (fixados), usar posts 4-6
- Download imagens para /tmp/ → Read com Claude → analise multimodal
- **NUNCA sobrescrever dados existentes** de source_detail (bio, followers, etc.) — apenas ADICIONAR chaves
- Priorizar leads A antes de B
- Limpar /tmp apos cada lead

## Fallbacks

| Situacao | Comportamento |
|----------|---------------|
| Apify falha | Avanca pra ready sem recent_posts |
| Download imagem falha | Analisa so com legendas (sem imagem) |
| Lead sem posts publicos | Avanca pra ready sem enrichment extra |
| Menos de 3 posts disponiveis | Analisa os que tiver |

## Exemplo de source_detail FINAL

### KOSMOS (Criadores de Conteúdo)

```json
{
  "followers_count": 12000,
  "is_business": true,
  "bio": "Coach de produtividade | Ajudo voce a fazer mais em menos tempo",
  "external_url": "https://linktr.ee/coach",
  "recent_posts": [
    {
      "caption": "5 habitos que mudaram minha rotina...",
      "type": "carousel",
      "likes": 150,
      "comments": 12,
      "hashtags": ["#produtividade", "#coaching"]
    },
    {
      "caption": "Voce esta cometendo esse erro?",
      "type": "reel",
      "likes": 320,
      "comments": 25,
      "hashtags": ["#mentoria"]
    },
    {
      "caption": "Resultado da minha aluna Maria...",
      "type": "static",
      "likes": 85,
      "comments": 5,
      "hashtags": ["#depoimento"]
    }
  ],
  "claude_analysis": {
    "visual_quality": "intermediate",
    "content_style": "educational",
    "tone_of_voice": "motivational",
    "sophistication_level": 6,
    "text_in_images": ["5 passos para...", "Inscreva-se na mentoria"],
    "product_detected": "Mentoria de Produtividade - provavelmente Hotmart",
    "ctas_detected": ["Link na bio", "Comenta 'EU QUERO'"],
    "uses_canva": true,
    "key_observations": "Creator educacional com audiencia engajada. Vende mentoria. Usa Canva. Bom candidato pra oferta de automacao."
  },
  "enriched_at": "2025-02-28T10:30:00Z"
}
```

### OLIVEIRA-DEV (Escritórios de Advocacia)

```json
{
  "company_name": "Silva & Associados Advogados",
  "full_name": "Dr. Carlos Silva",
  "email": "carlos@silvaadvogados.com.br",
  "google_maps": {
    "rating": 4.8,
    "review_count": 45,
    "recent_reviews": [
      {
        "author": "Maria Santos",
        "text": "Excelente atendimento, sempre me mantiveram informada sobre o andamento do processo. Recomendo!",
        "rating": 5
      },
      {
        "author": "João Oliveira",
        "text": "Escritório muito organizado e eficiente. Resolveram meu caso de divórcio rapidamente.",
        "rating": 5
      },
      {
        "author": "Ana Costa",
        "text": "Profissionais competentes. Única ressalva é que às vezes demora pra retornar ligação.",
        "rating": 4
      }
    ],
    "address": "Rua das Flores, 123 - Centro, Florianópolis/SC",
    "phone": "(48) 3333-4444"
  },
  "website_observations": {
    "team_size": 8,
    "areas": ["família", "sucessões", "imobiliário"],
    "has_client_portal": false,
    "digital_maturity": "medium"
  },
  "instagram": {
    "handle": "silvaadvogados",
    "followers": 2500,
    "recent_posts": [
      {"caption": "Vitória no caso de divórcio litigioso...", "likes": 45, "type": "static"}
    ]
  },
  "analysis": {
    "detected_pains": ["atendimento ao cliente", "transparência no acompanhamento"],
    "recommended_service": "portal",
    "recommended_angle": "atendimento",
    "key_observations": "Escritório com boa reputação (4.8 estrelas). Reviews mencionam 'manter informada' e 'demora pra retornar' - oportunidade clara para portal de acompanhamento. Equipe de 8 advogados, foco em família."
  },
  "enriched_at": "2026-03-01T10:30:00Z"
}
```

# T15 — DEEP ENRICHMENT + ANALISE MULTIMODAL

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Modulo de enriquecimento profundo. Scrape 3 posts recentes do lead via Apify,
analisa imagens com Claude (multimodal), e salva tudo no `source_detail`
do CRM (JSONB existente). Roda APENAS pra leads A/B.

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
- `source_detail` (JSON completo - NAO perder dados existentes)
- `source_detail.instagram` ou username do Instagram
- `classificacao` (A ou B)

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

# T15 — DEEP ENRICHMENT + ANÁLISE MULTIMODAL

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo T15 do Motor de Outbound da KOSMOS / Oliveira Dev. Sua função é enriquecer leads A/B com dados reais do Instagram (posts recentes) e análise multimodal via Gemini Flash. Os dados são gravados no campo `source_detail` (JSONB existente) do CRM. Roda APENAS para leads com `cadence_status=deep_enriching`.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APIFY_TOKEN=${APIFY_TOKEN}
GEMINI_API_KEY=${GEMINI_API_KEY}
```

## API do CRM (referência)

| Endpoint | Uso neste módulo |
|----------|-----------------|
| `GET /v1/contacts?cadence_status=deep_enriching&per_page=10` | Buscar leads aguardando enrichment profundo |
| `GET /v1/contacts/:id` | Ler source_detail atual do lead |
| `PATCH /v1/contacts/:id` | Atualizar source_detail com dados enriquecidos |
| `PATCH /v1/contacts/:id/cadence` | Avançar cadence_status |
| `POST /v1/contacts/:id/activities` | Logar atividade |

### Fluxo de cadence_status:
- Lead chega: `cadence_status` = "deep_enriching" (vindo do M3)
- T15 processa: enriquece source_detail → seta "ready"

## Instruções — Execute na ordem

### STEP 1: Buscar leads aguardando enrichment profundo

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=deep_enriching&per_page=10" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json"
```

Se zero leads, logue "T15: Nenhum lead para deep enrichment. Encerrando." e pare.

Priorizar leads A antes de B (processar A primeiro).

### STEP 2: Ler source_detail atual

Para cada lead, buscar dados completos:

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json"
```

Extrair `source_detail` atual (bio, followers_count, is_business, external_url).
Extrair `instagram` (username sem @).

**IMPORTANTE**: Se o lead já tem `source_detail.enriched_at`, ele já foi enriquecido. PULAR e avançar direto pra `ready`.

### STEP 3: Scraping via Apify — Posts do Instagram

Para cada lead, buscar posts via Apify actor:

```bash
# Iniciar run do actor
curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-post-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "directUrls": ["https://www.instagram.com/<username>/"],
    "resultsLimit": 6
  }'
```

Aguardar conclusão do run (polling no dataset):

```bash
# Ler resultados
curl -s "https://api.apify.com/v2/datasets/<dataset_id>/items?token=${APIFY_TOKEN}"
```

Dos 6 posts retornados:
- **IGNORAR os 3 primeiros** (normalmente são fixados/pinned no perfil)
- **Usar posts 4, 5 e 6** (conteúdo recente real)

Para cada post (4, 5, 6), extrair:
- `caption` (legenda)
- `type` (GraphImage, GraphSidecar, GraphVideo → static, carousel, reel)
- `likesCount` → likes
- `commentsCount` → comments
- `hashtags`
- `displayUrl` ou `url` → image_url (URL da imagem/thumbnail)

**Se Apify retornar menos de 4 posts**: Usar todos os disponíveis (o lead pode ter poucos posts).
**Se Apify falhar ou timeout**: Logar erro, avançar lead pra `ready` sem enrichment extra.

### STEP 4: Classificar link na bio

Se `source_detail.external_url` existe:

```bash
# Seguir redirects e pegar URL final + conteúdo
LINK_RESPONSE=$(curl -sL -o /dev/null -w "%{url_effective}" "<external_url>")
LINK_BODY=$(curl -sL "<external_url>" | head -c 5000)
```

Classificar o link:
- Contém "linktr.ee" ou "linktree" → `linktree`
- Contém "hotmart", "kiwify", "eduzz", "monetizze" → `landing_page`
- Contém "wa.me" ou "whatsapp" → `whatsapp`
- Domínio próprio com conteúdo institucional → `site_institucional`
- Se 404 ou inacessível → `unreachable`

Buscar presença multi-canal nos posts e bio:
- Menção a YouTube/canal → incluir "youtube" em channels_active
- Menção a podcast → incluir "podcast"
- Menção a newsletter/email → incluir "newsletter"

### STEP 5: Análise multimodal com Gemini 2.0 Flash

Para cada lead com imagens coletadas dos posts:

**a) Download das imagens (máx 3):**
```bash
curl -s "<image_url_post_4>" -o /tmp/t15_post_1.jpg
curl -s "<image_url_post_5>" -o /tmp/t15_post_2.jpg
curl -s "<image_url_post_6>" -o /tmp/t15_post_3.jpg

IMG1=$(base64 -w 0 /tmp/t15_post_1.jpg)
IMG2=$(base64 -w 0 /tmp/t15_post_2.jpg)
IMG3=$(base64 -w 0 /tmp/t15_post_3.jpg)
```

**b) Enviar ao Gemini:**
```bash
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [
        {"text": "Analise este perfil de Instagram de um potencial lead.\n\nBio: <bio_do_lead>\n\nLegenda post 1: <caption_post_4>\nLegenda post 2: <caption_post_5>\nLegenda post 3: <caption_post_6>\n\nAs 3 imagens anexadas são dos posts mais recentes (excluindo fixados).\n\nResponda APENAS em JSON válido com estes campos:\n{\n  \"visual_quality\": \"professional\" | \"intermediate\" | \"amateur\",\n  \"content_style\": \"educational\" | \"motivational\" | \"sales\" | \"lifestyle\",\n  \"tone_of_voice\": \"motivational\" | \"technical\" | \"casual\" | \"formal\",\n  \"sophistication_level\": <1-10>,\n  \"text_in_images\": [\"texto OCR extraído dos slides/imagens\"],\n  \"product_detected\": \"descrição do produto/serviço se vende algo, ou null\",\n  \"ctas_detected\": [\"CTAs visíveis nos slides\"],\n  \"uses_canva\": true | false,\n  \"key_observations\": \"1-2 frases sobre o perfil relevantes para abordagem comercial\"\n}"},
        {"inlineData": {"mimeType": "image/jpeg", "data": "<IMG1>"}},
        {"inlineData": {"mimeType": "image/jpeg", "data": "<IMG2>"}},
        {"inlineData": {"mimeType": "image/jpeg", "data": "<IMG3>"}}
      ]
    }],
    "generationConfig": {"temperature": 0.2}
  }'
```

Parsear o JSON da resposta do Gemini.

**Fallbacks:**
- Se download de imagem falhar: enviar apenas texto (legendas + bio) ao Gemini
- Se Gemini falhar/timeout: salvar `recent_posts` sem `gemini_analysis`
- Se resposta Gemini não for JSON válido: logar erro, continuar sem análise

**Limpar temp:**
```bash
rm -f /tmp/t15_post_*.jpg
```

### STEP 6: Salvar no CRM — Merge em source_detail

Montar o JSON merged (dados existentes + novos):

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "source_detail": {
      "followers_count": <manter_existente>,
      "is_business": <manter_existente>,
      "bio": "<manter_existente>",
      "external_url": "<manter_existente>",
      "recent_posts": [
        {
          "caption": "<legenda_post_4>",
          "type": "<carousel|reel|static>",
          "likes": <N>,
          "comments": <N>,
          "hashtags": ["#tag1", "#tag2"]
        },
        { ... post 5 ... },
        { ... post 6 ... }
      ],
      "link_bio_type": "<linktree|landing_page|whatsapp|site_institucional|unreachable|null>",
      "channels_active": ["instagram", "<youtube|podcast|newsletter se detectado>"],
      "gemini_analysis": {
        "visual_quality": "<professional|intermediate|amateur>",
        "content_style": "<educational|motivational|sales|lifestyle>",
        "tone_of_voice": "<motivational|technical|casual|formal>",
        "sophistication_level": <1-10>,
        "text_in_images": ["texto OCR..."],
        "product_detected": "<produto ou null>",
        "ctas_detected": ["CTA1", "CTA2"],
        "uses_canva": <true|false>,
        "key_observations": "<1-2 frases>"
      },
      "enriched_at": "<ISO timestamp>"
    }
  }'
```

**IMPORTANTE**: NUNCA sobrescrever dados existentes (bio, followers_count, etc.). Sempre ler primeiro, mergear, depois salvar.

### STEP 7: Avançar cadence_status

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "ready"}'
```

### STEP 8: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "T15 Deep Enrichment — <N> posts analisados",
    "metadata": {
      "module": "t15",
      "posts_analyzed": <N>,
      "gemini_used": <true|false>,
      "link_bio_type": "<tipo>"
    }
  }'
```

### STEP 9: Relatório

```
==========================================
T15 DEEP ENRICHMENT — RELATÓRIO
==========================================
Data/hora: {timestamp}
Total processados: {N}
  Posts analisados: {N}
  Gemini chamado: {N} vezes
  Links bio classificados: {N}

Por lead:
  @{username} — {N} posts | Gemini: {ok|falhou} | Link: {tipo}
  ...

Erros: {N}
  {detalhes}
==========================================
```

Salve em `/tmp/t15_report_{YYYY-MM-DD}.log`

## Regras
- MAX 10 leads por execução
- Apify: buscar 6 posts, IGNORAR 3 primeiros (fixados), usar posts 4-6
- Gemini: enviar imagens + legendas + bio (multimodal)
- Se Apify falhar: avançar lead pra `ready` sem enrichment
- Se Gemini falhar: salvar posts sem análise multimodal
- NUNCA sobrescrever dados existentes do source_detail
- Priorizar leads A antes de B
- Se lead já tem `enriched_at` no source_detail: pular (já processado)
- Limpar /tmp após cada lead

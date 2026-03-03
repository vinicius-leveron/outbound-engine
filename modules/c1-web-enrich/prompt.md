# C1-WEB-ENRICH — Analise de Website + Extracao de Equipe

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Voce e o modulo C1-Web-Enrich do Motor de Outbound. Sua funcao e analisar o website dos escritorios de advocacia descobertos pelo C1-Discovery, extrair informacoes da equipe (socios/advogados), identificar areas de atuacao, e detectar sinais de maturidade digital.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APIFY_TOKEN=${APIFY_TOKEN}
```

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `GET /v1/contacts?cadence_status=discovered&tenant=advocacia-tech&per_page=20` | Buscar escritorios pra enriquecer |
| `PATCH /v1/contacts/:id` | Atualizar source_detail com dados do website |
| `PATCH /v1/contacts/:id/cadence` | Avancar pra "web_enriched" |
| `POST /v1/contacts/:id/activities` | Logar enrichment |

### Fluxo: `discovered` -> `web_enriched`

## Instrucoes

### STEP 1: Buscar escritorios

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=discovered&tenant=advocacia-tech&per_page=20" \
  -H "Authorization: Bearer ${CRM_API_KEY}"
```

Se zero leads, logar e encerrar.

Para cada escritorio, extrair:
- `id` (contact_org_id)
- `organization_name`
- `source_detail.google_maps.website` (URL do site)
- `source_detail` (JSON completo - NAO perder dados existentes)

### STEP 2: Scraping do website via Apify

Para cada escritorio com website:

```bash
# Iniciar actor run - Website Content Crawler
RUN_ID=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~website-content-crawler/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "startUrls": [{"url": "'"${WEBSITE_URL}"'"}],
    "maxCrawlPages": 10,
    "crawlerType": "cheerio",
    "includeUrlGlobs": [
      "*/equipe*", "*/team*", "*/socios*", "*/advogados*",
      "*/sobre*", "*/about*", "*/quem-somos*",
      "*/areas*", "*/servicos*", "*/pratica*", "*/atuacao*",
      "*/contato*", "*/contact*"
    ]
  }' | jq -r '.data.id')

# Aguardar conclusao (max 120s)
for i in {1..12}; do
  sleep 10
  STATUS=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}?token=${APIFY_TOKEN}" | jq -r '.data.status')
  if [ "$STATUS" == "SUCCEEDED" ]; then break; fi
  if [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "ABORTED" ]; then
    echo "Apify run falhou: $STATUS"
    break
  fi
done

# Buscar resultados
PAGES=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}/dataset/items?token=${APIFY_TOKEN}")
```

### STEP 3: Processar paginas coletadas

Para cada pagina, classificar e extrair:

#### 3a) Pagina de Equipe/Socios
Buscar padroes: `/equipe`, `/team`, `/socios`, `/advogados`, `/profissionais`

Extrair:
```json
{
  "team_members": [
    {
      "name": "Dr. Joao Silva",
      "title": "Socio-fundador",
      "area": "Direito Empresarial",
      "oab": "OAB/SC 12345",
      "email": "joao@escritorio.com.br",
      "linkedin": "linkedin.com/in/joaosilva",
      "photo_url": "https://..."
    }
  ]
}
```

#### 3b) Pagina Sobre/Institucional
Buscar padroes: `/sobre`, `/about`, `/quem-somos`, `/historia`

Extrair:
- Ano de fundacao
- Numero de advogados
- Descricao institucional
- Diferenciais

#### 3c) Pagina de Areas de Atuacao
Buscar padroes: `/areas`, `/servicos`, `/pratica`, `/atuacao`

Extrair lista de areas:
- Direito Empresarial
- Direito Tributario
- Direito Trabalhista
- Direito Civil
- Direito Digital
- M&A
- Startups
- Propriedade Intelectual
- etc.

#### 3d) Pagina de Contato
Buscar padroes: `/contato`, `/contact`, `/fale-conosco`

Extrair:
- Emails adicionais
- Telefones
- WhatsApp
- Formulario de contato (existe ou nao)

### STEP 4: Analise com Claude (multimodal opcional)

Voce (Claude) deve analisar o HTML/texto das paginas coletadas e determinar:

```json
{
  "website_analysis": {
    "design_score": "modern|dated|basic",
    "has_blog": true|false,
    "has_newsletter": true|false,
    "has_contact_form": true|false,
    "has_whatsapp": true|false,
    "has_chatbot": true|false,
    "tech_signals": ["wordpress", "react", "hotjar", "google analytics"],
    "content_freshness": "active|stale|unknown",
    "estimated_size": "small|medium|large",
    "digital_maturity_score": 1-10
  },
  "practice_areas": ["Empresarial", "Tributario", "Trabalhista"],
  "team_page_url": "https://escritorio.com.br/equipe",
  "team_count": 8,
  "team_members": [
    {
      "name": "Dr. Joao Silva",
      "title": "Socio-Administrador",
      "area": "Direito Empresarial",
      "oab": "OAB/SC 12345",
      "email": "joao@escritorio.com.br",
      "is_partner": true,
      "seniority_score": 90
    },
    {
      "name": "Dra. Maria Santos",
      "title": "Socia",
      "area": "Direito Tributario",
      "oab": "OAB/SC 23456",
      "email": "maria@escritorio.com.br",
      "is_partner": true,
      "seniority_score": 85
    }
  ],
  "instagram_handle": "@escritorio_adv",
  "linkedin_company": "linkedin.com/company/escritorio"
}
```

**Criterios de analise:**

- **design_score**:
  - modern = design responsivo, cores atuais, UX boa
  - dated = design funcional mas antigo (pre-2018)
  - basic = site institucional minimalista ou template generico

- **digital_maturity_score** (1-10):
  - 1-3 = site basico, sem blog, sem redes sociais
  - 4-6 = site decente, tem redes, algum conteudo
  - 7-10 = site moderno, blog ativo, newsletter, chatbot, etc.

- **seniority_score** por membro (1-100):
  - 90-100 = Socio-fundador, Socio-administrador, Managing Partner
  - 70-89 = Socio, Partner
  - 50-69 = Advogado Senior, Of Counsel
  - 30-49 = Advogado Pleno
  - 1-29 = Advogado Junior, Estagiario

### STEP 5: Buscar Instagram do escritorio

Se nao encontrou no site, tentar buscar:

```bash
# Busca no Google
SEARCH_QUERY="${ORGANIZATION_NAME} instagram site:instagram.com"
# Ou usar Apify actor de busca
```

Extrair handle do Instagram se encontrado.

### STEP 6: Salvar no CRM (source_detail JSONB)

**IMPORTANTE:** Fazer MERGE com dados existentes. NAO sobrescrever google_maps.

```bash
# Ler source_detail atual
CURRENT_SOURCE_DETAIL=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq '.source_detail')

# Preparar dados novos
NEW_DATA='{
  "website_analysis": {
    "design_score": "modern",
    "has_blog": true,
    "has_newsletter": false,
    "has_contact_form": true,
    "has_whatsapp": true,
    "digital_maturity_score": 7
  },
  "practice_areas": ["Empresarial", "Tributario", "Trabalhista", "M&A"],
  "team_page_url": "https://escritorio.com.br/equipe",
  "team_count": 8,
  "team_members": [...],
  "instagram": {
    "handle": "@escritorio_adv",
    "source": "website_scrape"
  },
  "web_enriched_at": "'$(date -Iseconds)'"
}'

# Merge e salvar
MERGED=$(echo "$CURRENT_SOURCE_DETAIL" "$NEW_DATA" | jq -s '.[0] * .[1]')

curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"source_detail": '"$MERGED"'}'
```

### STEP 7: Avancar cadence_status

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"cadence_status": "web_enriched"}'
```

### STEP 8: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Website analisado - '"${TEAM_COUNT}"' membros encontrados",
    "metadata": {
      "module": "c1-web-enrich",
      "pages_crawled": '"${PAGES_COUNT}"',
      "team_members_found": '"${TEAM_COUNT}"',
      "practice_areas": '"${AREAS_COUNT}"',
      "digital_maturity": '"${MATURITY_SCORE}"'
    }
  }'
```

### STEP 9: Relatorio

```
====================================
C1-WEB-ENRICH — RELATORIO
====================================
Data/hora: {timestamp}

PROCESSAMENTO:
  Escritorios processados: {N}
  Sites crawleados: {N}
  Sites sem acesso: {N}

EXTRACAO:
  Team pages encontradas: {N}
  Membros de equipe extraidos: {N}
  - Socios: {n}
  - Advogados: {n}

  Areas de atuacao:
  - Empresarial: {n} escritorios
  - Tributario: {n} escritorios
  - Trabalhista: {n} escritorios

MATURIDADE DIGITAL:
  Score medio: {X}/10
  - Modern: {n}
  - Dated: {n}
  - Basic: {n}

  Com blog: {n}
  Com newsletter: {n}
  Com WhatsApp: {n}

SOCIAL:
  Instagram encontrado: {n}
  LinkedIn encontrado: {n}

STATUS:
  cadence_status = "web_enriched": {N}

CUSTO:
  Apify pages crawled: {N}
====================================
```

Salve em `logs/c1_web_enrich_report_{YYYY-MM-DD}.log`

## Fluxo de Cadence

```
discovered → (C1-WebEnrich) → web_enriched → (C1-DecisionMaker) → dm_identified → (M2) → enriching
```

## Regras

- MAX 20 escritorios por execucao
- MAX 10 paginas por website
- Priorizar paginas: equipe > sobre > areas > contato
- **NUNCA sobrescrever dados do google_maps** — apenas ADICIONAR dados
- Se website inacessivel, marcar e continuar
- Extrair emails de membros quando disponiveis

## Fallbacks

| Situacao | Comportamento |
|----------|---------------|
| Site inacessivel | Marcar digital_maturity=1, avancar status |
| Sem pagina de equipe | Avancar sem team_members |
| Apify timeout | Tentar 1x mais, depois skip |
| Site em manutencao | Manter em discovered, tentar proximo ciclo |

# C1-DISCOVERY — Google Maps Scraper para Advocacia

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.

## Contexto
Voce e o modulo C1-Discovery do Motor de Outbound. Sua funcao e descobrir escritorios de advocacia via Google Maps e inserir no CRM para posterior enrichment e prospeccao.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
APIFY_TOKEN=${APIFY_TOKEN}
```

## Arquivos de Configuracao

| Arquivo | Descricao |
|---------|-----------|
| `config.yaml` | Configuracao de busca (cidade, filtros, limites) |

## API do CRM

| Endpoint | Uso |
|----------|-----|
| `POST /v1/contacts` | Criar novo lead (escritorio) |
| `GET /v1/contacts?organization_name={nome}` | Verificar se escritorio ja existe |
| `POST /v1/contacts/:id/activities` | Logar descoberta |

## Instrucoes — Execute na ordem

### STEP 1: Carregar configuracao

```bash
CONFIG=$(cat /root/outbound-engine/modules/c1-discovery/config.yaml)
```

Extrair:
- `search.query` (ex: "escritorio de advocacia")
- `search.location` (ex: "Florianopolis, SC, Brazil")
- `search.max_results` (limite de resultados)
- `filters.*` (filtros opcionais)

### STEP 2: Executar busca no Google Maps via Apify

Usar actor `compass/crawler-google-places`:

```bash
APIFY_RUN=$(curl -s -X POST "https://api.apify.com/v2/acts/compass~crawler-google-places/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "searchStringsArray": ["'"${SEARCH_QUERY}"'"],
    "locationQuery": "'"${SEARCH_LOCATION}"'",
    "maxCrawledPlacesPerSearch": '"${MAX_RESULTS}"',
    "language": "pt-BR",
    "includeWebResults": false,
    "scrapeContacts": true,
    "scrapeImages": false,
    "scrapeReviews": false
  }')

RUN_ID=$(echo "$APIFY_RUN" | jq -r '.data.id')
```

### STEP 3: Aguardar conclusao

```bash
# Poll status ate SUCCEEDED
while true; do
  STATUS=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}?token=${APIFY_TOKEN}" | jq -r '.data.status')
  if [ "$STATUS" == "SUCCEEDED" ]; then
    break
  elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "ABORTED" ]; then
    echo "Apify run falhou: $STATUS"
    exit 1
  fi
  sleep 10
done
```

### STEP 4: Baixar resultados

```bash
RESULTS=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}/dataset/items?token=${APIFY_TOKEN}")
```

Para cada resultado, extrair:
- `title` (nome do escritorio)
- `address` (endereco completo)
- `phone` (telefone)
- `website` (URL do site)
- `url` (URL do Google Maps)
- `totalScore` (rating medio)
- `reviewsCount` (numero de avaliacoes)
- `categoryName` (categoria confirmada)

### STEP 5: Filtrar resultados relevantes

```python
# Pseudo-codigo
def is_relevant(place):
    # 1. Deve ser escritorio de advocacia
    keywords = ["advocacia", "advogado", "advogados", "lawyer", "law firm", "juridico"]
    name_lower = place['title'].lower()
    category = place.get('categoryName', '').lower()

    if not any(kw in name_lower or kw in category for kw in keywords):
        return False, "not_law_firm"

    # 2. Deve ter website (essencial pra enrichment)
    if not place.get('website'):
        return False, "no_website"

    # 3. Deve ter telefone OU website
    if not place.get('phone') and not place.get('website'):
        return False, "no_contact"

    return True, "qualified"
```

### STEP 6: Deduplicar com CRM

Para cada escritorio filtrado, verificar se ja existe:

```bash
# Buscar por nome da organizacao (normalizado)
ORG_NAME_ENCODED=$(echo "$ORG_NAME" | jq -sRr @uri)

EXISTING=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts?organization_name=${ORG_NAME_ENCODED}&tenant=advocacia-tech" \
  -H "Authorization: Bearer ${CRM_API_KEY}")

COUNT=$(echo "$EXISTING" | jq '.meta.total // 0')

if [ "$COUNT" -gt 0 ]; then
  echo "SKIP: $ORG_NAME ja existe no CRM"
  continue
fi
```

### STEP 7: Criar lead no CRM

Para cada escritorio novo:

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "'"${TITLE}"'",
    "phone": "'"${PHONE}"'",
    "cadence_status": "discovered",
    "channel_in": "google_maps",
    "tenant": "advocacia-tech",
    "source_detail": {
      "source": "c1-discovery",
      "google_maps": {
        "place_id": "'"${PLACE_ID}"'",
        "address": "'"${ADDRESS}"'",
        "website": "'"${WEBSITE}"'",
        "rating": '"${RATING}"',
        "reviews_count": '"${REVIEWS}"',
        "category": "'"${CATEGORY}"'",
        "maps_url": "'"${MAPS_URL}"'",
        "location": "'"${SEARCH_LOCATION}"'"
      },
      "collected_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }
  }'
```

**IMPORTANTE:**
- `cadence_status` = "discovered" (C1-WebEnrich vai processar depois)
- `tenant` = "advocacia-tech"
- Nao criar duplicata

### STEP 8: Logar atividade

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "Escritorio descoberto via Google Maps",
    "metadata": {
      "module": "c1-discovery",
      "location": "'"${SEARCH_LOCATION}"'",
      "rating": '"${RATING}"',
      "reviews": '"${REVIEWS}"'
    }
  }'
```

### STEP 9: Relatorio

```
====================================
C1-DISCOVERY — RELATORIO
====================================
Data/hora: {timestamp}
Busca: "{query}" em {location}

COLETA:
  Resultados Google Maps: {N}

FILTROS:
  Escritorios validos: {N}
  Rejeitados: {N}
    - not_law_firm: {N}
    - no_website: {N}
    - no_contact: {N}

  Ja no CRM (skip): {N}

OUTPUT:
  Novos leads criados: {N}
  -> cadence_status = "discovered"

Top 5 por rating:
1. {nome} - {rating} ({reviews} avaliacoes)
2. ...

CUSTO:
  Apify calls: 1
  Resultados processados: {N}
====================================
```

Salve em `logs/c1_discovery_report_{YYYY-MM-DD}.log`

## Fluxo de Cadence

```
discovered → (C1-WebEnrich) → enriched → (C1-DecisionMaker) → ready → (M2) → enriching
```

## Regras

- MAX 100 escritorios por execucao
- Respeitar rate limits do Apify (1 run por vez)
- Nunca reprocessar escritorio ja no CRM
- Priorizar escritorios com website (essencial pra proximo passo)
- Se Apify falhar, logar erro e encerrar graciosamente

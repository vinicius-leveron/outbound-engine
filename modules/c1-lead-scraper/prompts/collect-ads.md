# C1 Sub-Prompt: Coleta Ad Library

## Objetivo
Coletar handles de Instagram de anunciantes da Meta Ad Library que rodam ads de cursos/mentorias.

## Apify Actor
`apify/facebook-ads-library-scraper`

## Configuracao (do config.yaml)
- keywords: lista de termos pra buscar no criativo
- country: pais (BR)
- min_active_days: ads ativos ha pelo menos N dias
- max_results: limite de resultados

## Execucao

### 1. Iniciar Actor

```bash
ACTOR_RUN=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~facebook-ads-library-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "searchTerms": '${KEYWORDS_JSON}',
    "countryCode": "'${COUNTRY}'",
    "adActiveStatus": "active",
    "maxResults": '${MAX_RESULTS}'
  }')

RUN_ID=$(echo "$ACTOR_RUN" | jq -r '.data.id')
```

### 2. Aguardar Conclusao

```bash
while true; do
  STATUS=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}?token=${APIFY_TOKEN}" | jq -r '.data.status')
  if [ "$STATUS" = "SUCCEEDED" ]; then
    break
  elif [ "$STATUS" = "FAILED" ]; then
    echo "ERRO: Actor falhou"
    exit 1
  fi
  sleep 10
done
```

### 3. Baixar Resultados

```bash
DATASET_ID=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}?token=${APIFY_TOKEN}" | jq -r '.data.defaultDatasetId')

curl -s "https://api.apify.com/v2/datasets/${DATASET_ID}/items?token=${APIFY_TOKEN}" > data/raw/ad_library_$(date +%Y-%m-%d).json
```

### 4. Extrair Handles

```bash
# Cada resultado tem page_name e/ou links pro Instagram
# Extrair handle do Instagram de cada anunciante

jq -r '.[].pageInstagramUrl // empty' data/raw/ad_library_*.json | \
  sed 's|https://instagram.com/||' | \
  sed 's|https://www.instagram.com/||' | \
  sed 's|/.*||' | \
  sort -u > data/raw/ad_handles.txt
```

## Output

Arquivo: `data/raw/ad_library_{YYYY-MM-DD}.json`

```json
[
  {"handle": "fulano", "origin": "ad_library", "ad_count": 3, "keywords_matched": ["mentoria"]},
  {"handle": "ciclano", "origin": "ad_library", "ad_count": 1, "keywords_matched": ["curso"]}
]
```

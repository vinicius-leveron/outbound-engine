# C1 Sub-Prompt: Coleta Following dos Grandes

## Objetivo
Coletar handles de quem os grandes infoprodutores seguem (pares e parceiros, nao fas).

## Apify Actor
`apify/instagram-profile-scraper` (modo following)

## Configuracao (do config.yaml)
- seed_profiles: lista de @ dos grandes
- max_per_profile: limite de following por perfil

## Execucao

### 1. Para cada seed_profile

```bash
for SEED in "${SEED_PROFILES[@]}"; do
  # Iniciar Actor
  ACTOR_RUN=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-profile-scraper/runs?token=${APIFY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "usernames": ["'${SEED}'"],
      "resultsType": "following",
      "resultsLimit": '${MAX_PER_PROFILE}'
    }')

  RUN_ID=$(echo "$ACTOR_RUN" | jq -r '.data.id')

  # Aguardar...
  # (mesmo padrao do collect-ads.md)

  # Baixar resultados
  DATASET_ID=$(curl -s "https://api.apify.com/v2/actor-runs/${RUN_ID}?token=${APIFY_TOKEN}" | jq -r '.data.defaultDatasetId')

  curl -s "https://api.apify.com/v2/datasets/${DATASET_ID}/items?token=${APIFY_TOKEN}" >> data/raw/following_raw_$(date +%Y-%m-%d).json
done
```

### 2. Processar Resultados

```bash
# Extrair handles com origem
jq -r --arg seed "$SEED" '.[] | {handle: .username, origin: "following", seed: $seed}' \
  data/raw/following_raw_*.json > data/raw/following_$(date +%Y-%m-%d).json
```

## Output

Arquivo: `data/raw/following_{YYYY-MM-DD}.json`

```json
[
  {"handle": "fulano", "origin": "following", "seed": "ericosrocha"},
  {"handle": "ciclano", "origin": "following", "seed": "leandroladeira"}
]
```

## Notas

- Seguindo dos grandes geralmente sao outros produtores (60-70% ICP)
- Quanto mais seeds, maior diversidade
- Custo: ~$0.50 por perfil seed (2000 following)

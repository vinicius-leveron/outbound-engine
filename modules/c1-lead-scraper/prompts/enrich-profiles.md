# C1 Sub-Prompt: Enriquecer Perfis

## Objetivo
Buscar dados completos de cada handle coletado via Apify.

## Apify Actor
`apify/instagram-profile-scraper`

## Input
Arquivo `data/merged/handles_{YYYY-MM-DD}.json` com handles unicos.

## Execucao

### 1. Preparar batch (max 100 handles)

```bash
HANDLES=$(jq -r '.[].handle' data/merged/handles_*.json | head -100)
```

### 2. Iniciar Actor

```bash
ACTOR_RUN=$(curl -s -X POST "https://api.apify.com/v2/acts/apify~instagram-profile-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "usernames": '${HANDLES_JSON}',
    "resultsType": "details",
    "extendOutputFunction": "async ({ data, item }) => { return { ...item, recentPosts: item.latestPosts?.slice(0, 6) || [] }; }"
  }')

RUN_ID=$(echo "$ACTOR_RUN" | jq -r '.data.id')
```

### 3. Aguardar e Baixar

(mesmo padrao dos outros sub-prompts)

### 4. Processar Resultados

```bash
# Transformar pro formato esperado
jq '[.[] | {
  handle: .username,
  full_name: .fullName,
  biography: .biography,
  followers_count: .followersCount,
  following_count: .followingCount,
  external_url: .externalUrl,
  is_business_account: .isBusinessAccount,
  is_verified: .isVerified,
  posts_count: .postsCount,
  recent_posts: [.recentPosts[]? | {
    caption: .caption,
    likes: .likesCount,
    comments: .commentsCount,
    timestamp: .timestamp,
    type: .type
  }],
  engagement_rate: (if .followersCount > 0 then ((.recentPosts | map(.likesCount) | add) / ((.recentPosts | length) * .followersCount) * 100) else 0 end)
}]' data/raw/profiles_raw_*.json > data/enriched/profiles_$(date +%Y-%m-%d).json
```

## Output

Arquivo: `data/enriched/profiles_{YYYY-MM-DD}.json`

```json
[
  {
    "handle": "fulano",
    "full_name": "Fulano de Tal",
    "biography": "Ajudo empreendedores a escalar | +5000 alunos",
    "followers_count": 85000,
    "following_count": 500,
    "external_url": "https://hotmart.com/fulano",
    "is_business_account": true,
    "is_verified": false,
    "posts_count": 350,
    "recent_posts": [
      {"caption": "Nova turma...", "likes": 1200, "comments": 45, "timestamp": "2026-02-28", "type": "carousel"}
    ],
    "engagement_rate": 3.2
  }
]
```

## Custo

~$0.01 por perfil (100 perfis = $1)

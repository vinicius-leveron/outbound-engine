# C4 — AD LIBRARY BENCHMARK

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo C4 do Motor de Outbound da KOSMOS / Oliveira Dev. Sua função é fazer scraping da Meta Ad Library via Apify para analisar criativos de concorrentes e referências do mercado. Gera um relatório semanal de benchmark criativo com insights acionáveis para produção de conteúdo e ads.

## Credenciais
```
APIFY_TOKEN=${APIFY_API_TOKEN}
```

## Perfis/Páginas para monitorar

### KOSMOS (mercado de criadores de conteúdo)
```
Concorrentes diretos:
- Érico Rocha (ex: ericorochapf)
- Leandro Ladeira (ex: leandroladeira)
- Thiago Nigro (ex: thiago.nigro)
- Ícaro de Carvalho (ex: icarodecarvalho)

Referências internacionais:
- Alex Hormozi (ex: alexhormozi)
- Russell Brunson (ex: russellbrunson)
```
**NOTA:** Substitua pelos page IDs reais do Facebook/Meta. O Vinícius deve confirmar a lista.

## Instruções — Execute na ordem

### STEP 1: Scrape Ad Library via Apify

Use o Apify client para rodar um actor de Ad Library scraping:

```bash
curl -s -X POST "https://api.apify.com/v2/acts/apify~facebook-ads-scraper/runs?token=${APIFY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": ["<nome_pagina_1>", "<nome_pagina_2>"],
    "countryCode": "BR",
    "adType": "ALL",
    "adActiveStatus": "ACTIVE",
    "maxAdsPerQuery": 20
  }'
```

**NOTA:** O actor exato pode variar. Tente:
1. `apify/facebook-ads-scraper`
2. `apify/facebook-ad-library-scraper`
3. Busque no Apify Store por "Meta Ad Library" se nenhum funcionar

Aguarde o run completar e busque os resultados:

```bash
curl -s "https://api.apify.com/v2/actor-runs/{runId}/dataset/items?token=${APIFY_TOKEN}"
```

Salve em `/tmp/c4_ads_raw.json`

### STEP 2: Analisar criativos

Para cada ad encontrado, extraia e analise:

| Campo | O que extrair |
|-------|---------------|
| Advertiser | Nome da página |
| Ad text | Copy principal |
| Media type | Imagem / Vídeo / Carrossel |
| CTA | Botão de ação |
| Landing page | URL de destino |
| Active since | Há quanto tempo roda |
| Platforms | Facebook / Instagram / Audience Network |

### STEP 3: Análise AI — Padrões e Insights

Analise o conjunto de ads e responda:

1. **Formatos mais usados:** Vídeo vs imagem vs carrossel — qual domina?
2. **Padrões de copy:** Quais hooks estão sendo usados? Perguntas? Números? Autoridade?
3. **CTAs mais comuns:** O que estão pedindo no botão?
4. **Ofertas:** O que estão vendendo? Qual o funil (lead magnet, webinar, venda direta)?
5. **Longevidade:** Quais ads rodam há mais tempo? (ads longevos = provavelmente lucrativos)
6. **Oportunidades:** O que ninguém está fazendo que poderia ser testado?

### STEP 4: Gerar relatório

```
====================================
C4 AD LIBRARY BENCHMARK
Semana: {data}
====================================

📊 VISÃO GERAL
  Total ads analisados: {n}
  Advertisers monitorados: {n}
  Ads ativos mais antigos: {ad} (rodando há {n} dias)

🎨 FORMATOS
  Vídeo: {n} ({%})
  Imagem: {n} ({%})
  Carrossel: {n} ({%})

✍️ TOP HOOKS DE COPY
  1. "{hook 1}" — usado por {advertiser}
  2. "{hook 2}" — usado por {advertiser}
  3. "{hook 3}" — usado por {advertiser}

🎯 CTAs MAIS COMUNS
  1. {CTA} — {n} ads
  2. {CTA} — {n} ads

🔥 ADS DESTAQUE (mais longevo = provavelmente lucrativos)
  1. {advertiser}: "{preview da copy}" — Ativo há {n} dias — {formato}
  2. ...
  3. ...

💡 INSIGHTS AI
  1. {insight 1}
  2. {insight 2}
  3. {insight 3}

⚡ OPORTUNIDADES PARA KOSMOS
  1. {oportunidade 1}
  2. {oportunidade 2}
  3. {oportunidade 3}

====================================
```

Salve em `/tmp/c4_report_{YYYY-MM-DD}.log`

### STEP 5: Salvar dados estruturados

Salve um JSON resumido em `/tmp/c4_benchmark_{YYYY-MM-DD}.json` para histórico.

## Regras importantes
- Roda toda segunda às 10h
- Respeitar limites de API do Apify (checar créditos antes)
- Se um actor não funcionar, tentar alternativas e logue qual usou
- Insights devem ser ACIONÁVEIS para produção de conteúdo/ads da KOSMOS
- Não reproduzir copies inteiras — apenas hooks e padrões
- Se Apify retornar poucos resultados, logue e continue com o que tem

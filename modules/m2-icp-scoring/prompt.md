# M2 — ICP SCORING UNIFICADO

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Você é o módulo M2 do Motor de Outbound da KOSMOS / Oliveira Dev. Sua função é pegar leads com score_icp=0 no CRM e classificá-los como A, B ou C usando regras quantitativas + análise qualitativa AI da bio/perfil.

## Credenciais
```
CRM_BASE_URL=${CRM_BASE_URL}
CRM_API_KEY=${CRM_API_KEY}
```

## API do CRM (referência)

Todos os endpoints usam `/v1/contacts`. O `:id` nos endpoints é o `contact_org_id`.

| Endpoint | Uso neste módulo |
|----------|-----------------|
| `GET /v1/contacts?cadence_status=new&per_page=50` | Buscar leads aguardando scoring |
| `PATCH /v1/contacts/:id/score-icp` | Atualizar score e classificação |
| `PATCH /v1/contacts/:id/cadence` | Avançar cadence_status |
| `POST /v1/contacts/:id/activities` | Logar atividade |

Filtros disponíveis no GET: `cadence_status`, `classificacao`, `tenant`, `channel_in`, `per_page`, `page`

### Dados do perfil IG:
Vêm no campo `source_detail` (JSONB) do contato: `followers_count`, `is_business`, `bio`, `external_url`. Preenchidos pelo C1 Lead Scraper.

### Fluxo de cadence_status:
- Lead chega: `cadence_status` = "new"
- M2 processa: atualiza score → seta "enriching" (A/B) ou "archived" (C)

## Instruções — Execute na ordem

### STEP 1: Buscar leads aguardando scoring

```bash
curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=new&per_page=50" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json"
```

Se zero leads, logue "M2: Nenhum lead novo para scoring. Encerrando." e pare.

Para cada lead, extrair dados do perfil de `source_detail`:
- `source_detail.followers_count`
- `source_detail.is_business`
- `source_detail.bio`
- `source_detail.external_url`

### STEP 2: Scoring por regras (quantitativo)

Para cada lead, calcule score 0-100 POR TENANT (campo `tenant` do lead):

#### TENANT: kosmos
ICP: criadores de conteúdo, 2k-300k seguidores, conta business, vendem curso/mentoria/comunidade.

| Critério | Pontos | Condição |
|----------|--------|----------|
| Followers sweet spot | +30 | 2.000-300.000 |
| Followers ok | +15 | 1.000-2.000 OU 300.000-500.000 |
| Followers fora | +0 | < 1.000 ou > 500.000 |
| Conta business | +20 | is_business = true |
| Bio keywords venda | +25 | "curso", "mentoria", "comunidade", "programa", "método", "formação", "academy", "escola", "treinamento", "mastermind", "cohort", "turma", "inscrição", "vagas", "link na bio", "linktr.ee", "hotmart", "eduzz", "kiwify" |
| Bio keywords autoridade | +15 | "especialista", "expert", "mentor", "professor", "coach", "fundador", "CEO", "criador", "autor" |
| Tem link externo | +10 | external_url preenchido |

#### TENANT: oliveira-dev
ICP: construtoras, escritórios de advocacia, empresas B2B.

| Critério | Pontos | Condição |
|----------|--------|----------|
| Conta business | +30 | is_business = true |
| Bio keywords negócio | +30 | "construtora", "advocacia", "advogado", "engenharia", "escritório", "imobiliária", "contabilidade", "contador", "consultoria", "empresa", "CNPJ", "LTDA", "S.A.", "licitação", "obra" |
| Followers range | +20 | 500-50.000 |
| Link externo | +10 | external_url preenchido |
| Bio keywords dor | +10 | "gestão", "processos", "automação", "sistema", "ERP", "CRM", "digital" |

#### TENANT: advocacia-tech
ICP: Escritórios de advocacia para projetos de tecnologia (sistemas, automação, portais).

**IMPORTANTE:** Este tenant vem do pipeline C1 (Google Maps → Web Enrich → Decision Maker).
Os dados estão em `source_detail` com estrutura diferente dos outros tenants.

**Buscar leads:** `cadence_status=dm_identified&tenant=advocacia-tech`

| Critério | Pontos | Condição |
|----------|--------|----------|
| Áreas tech-friendly | +25 | `practice_areas` contém: "Empresarial", "Digital", "Tech", "Startups", "M&A", "Societário", "Propriedade Intelectual" |
| Maturidade digital alta | +20 | `website_analysis.digital_maturity_score` >= 6 |
| Maturidade digital média | +10 | `website_analysis.digital_maturity_score` >= 4 |
| Decisor identificado com email | +20 | `decision_maker.email` preenchido E `decision_maker.email_status` = "valid" ou "unverified" |
| Decisor identificado sem email | +10 | `decision_maker.name` preenchido mas sem email |
| Tem Instagram ativo | +15 | `instagram.handle` preenchido |
| Escritório médio (5-20 advogados) | +10 | `team_count` entre 5 e 20 |

**Dados extras para análise qualitativa:**
- `source_detail.google_maps.rating` (reputação)
- `source_detail.google_maps.reviews_count` (volume de clientes)
- `source_detail.practice_areas[]` (especialidades)
- `source_detail.decision_maker.title` (cargo do decisor)
- `source_detail.website_analysis.has_blog` (produção de conteúdo)

**Análise AI para A/B:**
Incluir na análise:
1. Áreas de atuação e fit com projetos de tech
2. Maturidade digital atual (oportunidade ou já avançado?)
3. Perfil do decisor e sugestão de abordagem
4. Dores prováveis baseado no perfil do escritório

### STEP 3: Classificação

| Classificação | Score | Destino |
|---------------|-------|---------|
| **A** | >= 60 | cadence_status → "enriching" |
| **B** | >= 30 | cadence_status → "enriching" |
| **C** | < 30 | cadence_status → "archived" |

### STEP 4: Análise qualitativa AI (só A e B)

Para A/B: 2-3 frases sobre relevância, potencial de conversão, sugestão de abordagem.
Para C: "Score baixo. Fora do ICP: [motivo]."

### STEP 5: Atualizar score no CRM

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/score-icp" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "score_icp": <score>,
    "classificacao": "<A|B|C>"
  }'
```

### STEP 6: Avançar cadence_status

```bash
curl -s -X PATCH "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/cadence" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "cadence_status": "<enriching|archived>"
  }'
```

### STEP 7: Logar atividade (só A e B)

```bash
curl -s -X POST "${CRM_BASE_URL}/v1/contacts/{contact_org_id}/activities" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "note",
    "title": "ICP Score: <score> — Class: <classificacao>",
    "metadata": {"module": "m2", "score_icp": <score>, "classificacao": "<A|B|C>", "ai_analysis": "<texto>"}
  }'
```

### STEP 8: Relatório

```
====================================
M2 ICP SCORING — RELATÓRIO
====================================
Data/hora: {timestamp}
Total processados: {N}
  KOSMOS: {N} (A:{n} B:{n} C:{n})
  Oliveira-dev: {N} (A:{n} B:{n} C:{n})
  Advocacia-tech: {N} (A:{n} B:{n} C:{n})

A: {n} → enriching
B: {n} → enriching
C: {n} → archived

Top 3 leads A:
1. @{instagram} ou {organization_name} — Score: {score}
====================================
```

Salve em `/tmp/m2_report_{YYYY-MM-DD}.log`

## Regras
- Keywords case-insensitive
- Nunca sobrescrever lead com score_icp > 0
- Se tenant vazio, usar "kosmos" como default
- MAX 50 leads por execução

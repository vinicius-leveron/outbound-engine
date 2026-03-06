# Instagram Sequence KOSMOS (3 Steps, 5 dias)

> **Canal:** Instagram | **Tenant:** kosmos | **Objetivo:** Converter criadores de conteúdo

## Cadência Completa

```
DIA 0   │ Step 1: FOLLOW + LIKE
        │         - Seguir o perfil
        │         - Curtir 1 post recente
        │         - Gera notificação, pessoa pode ver seu perfil
        │
DIA 2   │ Step 2: COMENTÁRIO
        │         - Comentar em post recente
        │         - Usar lógica reativa (RESULT/EDUCATIONAL/BACKSTAGE/etc)
        │         - Outra notificação, mais contexto
        │
DIA 5   │ Step 3: DM
        │         - Agora já tem warmup (2 interações anteriores)
        │         - Reação ao post ou continuação natural
        │         - Pessoa pode já ter visto seu perfil
```

**3 steps, 5 dias total. DM não é mais fria.**

---

## Por que Warmup?

```
PRIORIDADE 1: Pessoa abre a DM (notificação)
PRIORIDADE 2: Pessoa vai no perfil (curiosidade sobre quem mandou)
PRIORIDADE 3: Pessoa responde (bônus, não obrigatório)
```

**O que gera curiosidade:**
- Follow genuíno de alguém que parece do mercado
- Comentário inteligente que mostra entendimento
- Tom de igual pra igual (não de fã, não de vendedor)
- Algo que faz pensar "quem é essa pessoa?"

---

## Step 1: Follow + Like

### Execução (M8)

```
1. Seguir o perfil do lead
2. Curtir 1 post recente (preferencialmente o mais engajado dos últimos 7 dias)
3. NÃO comentar ainda (guarda pro step 2)
4. Logar ação no CRM
```

### Seleção do Post para Like

| Prioridade | Critério |
|------------|----------|
| 1 | Post com mais engajamento (likes + comments) dos últimos 7 dias |
| 2 | Post educativo (carousel, reel tutorial) |
| 3 | Post de resultado (case, aluno) |
| 4 | Qualquer post recente (<7 dias) |

**Skip follow+like se:**
- Último post > 30 dias
- Perfil privado
- Menos de 5 posts total

---

## Step 2: Comentário

**Template:** [comment-warmup.md](comment-warmup.md)

### Resumo da Lógica

| Tipo de Post | Comentário (max 50 chars) |
|--------------|---------------------------|
| RESULTADO | "resultado fala por si 👏" |
| EDUCATIVO | "direto ao ponto 🎯" |
| BASTIDORES | "adorei ver os bastidores" |
| PESSOAL | "demais!" ou "faz sentido" |
| HUMOR | "hahaha real" |
| GENÉRICO | Skip ou "🔥" |

### Regras

- Max 50 caracteres
- Max 1 emoji
- Sem perguntas (guarda pra DM)
- Sem menção a trabalho/proposta
- Tom de seguidor genuíno

---

## Step 3: DM

**Template:** [dm-opener.md](dm-opener.md)

### Contexto Pós-Warmup

A DM agora é enviada depois de:
- Follow (notificação 1)
- Like (notificação 1)
- Comentário (notificação 2)

Lead já pode ter:
- Visto seu perfil
- Notado seu comentário
- Sentido curiosidade

### Prompt de Geração

```
Você está mandando uma DM para {{name}}.

CONTEXTO:
- Bio: {{bio}}
- Produto: {{claude_analysis.product_detected}}
- Último post: "{{recent_posts[0].caption}}"
- Já interagimos: follow + like + comentário

OBJETIVO:
Fazer a pessoa abrir a DM e ir no seu perfil. Resposta é bônus.

REGRAS:
1. Max 200 caracteres
2. Reaja ao post de forma natural
3. Tom de igual pra igual
4. Sem travessão (—)
5. Sem "Oi, tudo bem?"
6. Sem emojis excessivos (max 1, opcional)
7. Sem parecer fã exagerado
8. Sem qualquer menção a trabalho/proposta/parceria

LÓGICA DE CONTEXTO:

SE post é sobre RESULTADO (aluno, cliente, case):
→ Reconheça o número + pergunte sobre o processo
→ Ex: "50k em 3 meses é pesado. ela já tinha audiência ou começou do zero?"

SE post é sobre CONTEÚDO EDUCATIVO:
→ Comente algo específico + pergunta curta
→ Ex: "o erro 3 é o mais comum que vejo. você acha que é mais mindset ou estratégia?"

SE post é sobre BASTIDORES/PRODUÇÃO:
→ Curiosidade sobre o trabalho
→ Ex: "módulo 4 de quantos? to curioso pra saber a estrutura"

SE post é PESSOAL/LIFESTYLE (viagem, família, reflexão):
→ Comentário leve e universal
→ Ex: "bali parece surreal. quanto tempo de viagem?"
→ Ex: "faz sentido. você acha que isso muda com o tempo?"

SE post é MEME/HUMOR:
→ Reação natural + pergunta opcional
→ Ex: "hahaha real demais. acontece muito?"

SE post NÃO TEM CONTEXTO ÚTIL (repost, promoção genérica):
→ FALLBACK baseado na bio:
→ Ex: "{{name}} curti demais seu conteúdo. como você começou nessa área?"
→ Ex: "{{name}} vi que você trabalha com {{produto}}. quanto tempo nesse mercado?"

OUTPUT:
[mensagem direto, sem saudação formal, max 200 chars]
```

---

## Exemplos de DM por Tipo de Post

| Tipo | Caption do Post | DM |
|------|-----------------|-----|
| RESULTADO | "Aluna fez 50k em 3 meses" | {{name}} 50k em 3 meses é pesado. ela já tinha audiência ou começou do zero? |
| EDUCATIVO | "5 erros no lançamento" | o erro 3 é o mais comum que vejo. você acha que é mais mindset ou estratégia? |
| BASTIDORES | "Gravando o módulo 4" | módulo 4 de quantos? to curioso pra saber a estrutura |
| VIAGEM | "Férias em Bali" | bali parece surreal. quanto tempo de viagem? |
| REFLEXÃO | "Hoje aprendi que paciência é tudo" | faz sentido. você acha que isso muda com o tempo ou é constante? |
| MEME | "Quando o cliente some" | hahaha real demais. acontece muito? |
| GENÉRICO | [sem contexto] | {{name}} curti demais seu conteúdo. como você começou nessa área? |

---

## Fallbacks

### Baseado na Bio

```
{{name}} vi que você trabalha com {{produto}}. quanto tempo nesse mercado?
```

### Genérico (último recurso)

```
{{name}} curti demais seu conteúdo. como você começou nessa área?
```

**IMPORTANTE:** Fallback só quando post é repost, promoção de terceiro, ou sem conteúdo relevante.

---

## Fluxo de Decisão M4

```
1. Verificar cadence_step atual
   ├── step 0 → Executar step 1 (follow + like)
   ├── step 1 + 2 dias → Executar step 2 (comentário)
   └── step 2 + 3 dias → Executar step 3 (DM)

2. Para step 3 (DM):
   a. Ler recent_posts[0].caption
   b. Classificar tipo de post:
      ├── RESULT: número, aluno, cliente, case, faturamento
      ├── EDUCATIONAL: erro, dica, tutorial, passo-a-passo
      ├── BACKSTAGE: gravando, bastidores, criando, produzindo
      ├── PERSONAL: viagem, família, reflexão, pessoal
      ├── HUMOR: meme, humor, piada
      └── GENERIC: repost, promoção, sem contexto
   c. Aplicar template do tipo
   d. Se GENERIC → usar fallback (bio ou genérico)
   e. Validar < 200 chars
   f. Enfileirar na DM_Queue
```

---

## Condições de Saída

Lead SAI da cadência quando:

| Condição | Novo Status | Ação |
|----------|-------------|------|
| **Respondeu DM** | `replied` | Notificar humano |
| **Seguiu de volta** | Continuar | Bom sinal, manter na cadência |
| **Bloqueou** | `blocked` | Remover, não retentar |
| **Completou Step 3** | `archived` | Fim natural |

---

## Anti-Patterns (PROIBIDO)

```
❌ "Oi, tudo bem? Vi que você trabalha com X" (genérico demais)
❌ "Tenho uma proposta/parceria pra você" (vendedor)
❌ "Posso te ajudar a faturar mais?" (spam)
❌ "Vi que você é um criador de conteúdo" (óbvio)
❌ Múltiplos emojis 🔥🚀💰🎯
❌ Links de qualquer tipo
❌ Áudio ou figurinha
❌ Mensagem muito longa (>200 chars)
❌ Tom de fã exagerado
❌ Pressão ou urgência
```

---

## Contagem de Caracteres

| Step | Canal | Limite |
|------|-------|--------|
| 1 | Follow + Like | N/A |
| 2 | Comment | 50 chars |
| 3 | DM | 200 chars |

---

## Validação Antes de Cada Step

### Step 1 (Follow + Like)
```
[ ] Perfil é público?
[ ] Tem posts recentes (<30 dias)?
[ ] Não está bloqueado?
```

### Step 2 (Comentário)
```
[ ] Post recente (<7 dias)?
[ ] Post tem engajamento (>10 likes)?
[ ] Caption tem contexto útil?
[ ] Se não → skip pro step 3
```

### Step 3 (DM)
```
[ ] Menos de 200 caracteres?
[ ] Sem saudação formal?
[ ] Referência específica ao conteúdo?
[ ] Tom de igual pra igual?
```

---

## Ajuste por sophistication_level (T15)

| Level | Tom da DM | Exemplo |
|-------|-----------|---------|
| 7-10 | Peer-to-peer, técnico | "50k em 3 meses é pesado. ela já tinha audiência?" |
| 4-6 | Consultivo, curioso | "como você estruturou isso? achei o formato interessante" |
| 1-3 | Didático, acessível | "adorei o conteúdo! como você começou nessa área?" |

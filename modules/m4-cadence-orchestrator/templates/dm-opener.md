# DM Opener (Step 3 - KOSMOS)

> **Canal:** Instagram DM | **Max:** 200 chars | **Objetivo:** Abrir conversa natural após warmup

## Contexto da Cadência

```
DIA 0   │ Step 1: FOLLOW + LIKE
DIA 2   │ Step 2: COMENTÁRIO
DIA 5   │ Step 3: DM ← ESTE TEMPLATE
```

**Importante:** A DM não é mais fria. O lead já recebeu:
- Notificação de follow
- Notificação de like
- Notificação de comentário

O lead pode já ter visto seu perfil e notado suas interações.

---

## Prompt de Geração

```
Você está mandando uma DM para {{name}}.

CONTEXTO:
- Bio: {{bio}}
- Produto: {{claude_analysis.product_detected}}
- Último post: "{{recent_posts[0].caption}}"
- Key observation: {{claude_analysis.key_observations}}
- Já interagimos: follow + like + comentário (warmup completo)

OBJETIVO:
Fazer a pessoa abrir a DM e ir no seu perfil. Resposta é bônus.

REGRAS OBRIGATÓRIAS:
1. Max 200 caracteres
2. Reaja ao post de forma natural
3. Tom de igual pra igual
4. Sem travessão (—)
5. Sem "Oi, tudo bem?"
6. Sem emojis excessivos (max 1, opcional)
7. Sem parecer fã exagerado
8. Sem qualquer menção a trabalho/proposta/parceria
9. ZERO links

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

## Exemplos por Tipo de Post

### RESULTADO (aluno, cliente, case)

| Caption | DM |
|---------|-----|
| "Aluna fez 50k em 3 meses" | {{name}} 50k em 3 meses é pesado. ela já tinha audiência ou começou do zero? |
| "Cliente fechou 200k" | {{name}} 200k é case forte. foi indicação ou ela veio do conteúdo? |
| "Turma formou 150 alunos" | 150 alunos é volume grande. como você estrutura o suporte? |

### EDUCATIVO (dica, erro, tutorial)

| Caption | DM |
|---------|-----|
| "5 erros no lançamento" | o erro 3 é o mais comum que vejo. você acha que é mais mindset ou estratégia? |
| "Como estruturo meu dia" | {{name}} aquele bloco de 2h pro deep work funciona mesmo? to testando aqui |
| "Framework de vendas" | framework interessante. você usa em todo tipo de produto ou tem exceções? |

### BASTIDORES (gravando, criando)

| Caption | DM |
|---------|-----|
| "Gravando o módulo 4" | módulo 4 de quantos? to curioso pra saber a estrutura |
| "Por trás do lançamento" | {{name}} quanto tempo de preparação antes de abrir carrinho? |
| "Editando domingo" | {{name}} você edita tudo ou tem equipe? sempre tive curiosidade |

### PESSOAL/LIFESTYLE

| Caption | DM |
|---------|-----|
| "Férias em Bali" | bali parece surreal. quanto tempo de viagem? |
| "Tempo com família" | necessário demais. como você equilibra com a agenda? |
| "Paciência é tudo" | faz sentido. você acha que isso muda com o tempo ou é constante? |

### HUMOR

| Caption | DM |
|---------|-----|
| "Quando o cliente some" | hahaha real demais. acontece muito? |
| "POV: infoprodutor" | muito isso. qual a parte mais difícil na real? |
| "Segunda chegou" | hahaha eu nessa. você consegue descansar no fim de semana? |

### FALLBACK (sem contexto)

| Situação | DM |
|----------|-----|
| Bio clara | {{name}} vi que você trabalha com {{produto}}. quanto tempo nesse mercado? |
| Genérico | {{name}} curti demais seu conteúdo. como você começou nessa área? |

---

## Ajuste por sophistication_level

| Level | Tom | Exemplo |
|-------|-----|---------|
| 7-10 | Peer-to-peer, técnico | "50k em 3 meses é pesado. ela já tinha audiência?" |
| 4-6 | Consultivo, curioso | "como você estruturou isso? achei o formato interessante" |
| 1-3 | Didático, acessível | "adorei o conteúdo! como você começou nessa área?" |

---

## Anti-Patterns (PROIBIDO)

```
❌ "Oi! Vi que você é da área de X" (genérico)
❌ "Oi, posso te mandar uma proposta?" (vendedor)
❌ "Parabéns pelo trabalho!" (vazio, sem especificidade)
❌ "Tenho uma oportunidade pra você" (spam)
❌ "Gostaria de apresentar minha empresa" (corporativo)
❌ "Trabalho com..." (vendedor)
❌ Links de qualquer tipo
❌ Múltiplos emojis
❌ Mensagem muito longa (>200 chars)
❌ Áudio ou figurinha
❌ Tom de fã exagerado
```

---

## Contagem de Caracteres

| Tipo | Limite |
|------|--------|
| Caracteres | 200 max |
| Emojis | 1 max (opcional) |
| Links | 0 (proibido) |

---

## Validação Antes de Enviar

```
[ ] Menos de 200 caracteres?
[ ] Sem saudação formal ("Oi, tudo bem?")?
[ ] Referência específica ao conteúdo do lead?
[ ] Sem menção a trabalho/negócio/parceria?
[ ] Tom de igual pra igual (não fã, não vendedor)?
[ ] Termina com pergunta genuína?
[ ] Max 1 emoji?
```

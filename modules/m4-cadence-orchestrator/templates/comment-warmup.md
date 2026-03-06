# Comment Warmup (Step 2 - KOSMOS)

> **Canal:** Instagram Comment | **Max:** 50 chars | **Objetivo:** Gerar notificação + mostrar que acompanha

## Contexto da Cadência KOSMOS

```
DIA 0   │ Step 1: FOLLOW + LIKE (M8)
DIA 2   │ Step 2: COMENTÁRIO ← ESTE TEMPLATE
DIA 5   │ Step 3: DM (dm-opener.md)
```

O comentário é a **segunda interação** — o lead já recebeu notificação de follow e like. Agora vê um comentário genuíno.

---

## Prompt de Geração

```
Você está comentando em um post de {{name}}.

POST:
- Caption: "{{recent_posts[0].caption}}"
- Tipo: {{recent_posts[0].type}}
- Likes: {{recent_posts[0].likes}}

OBJETIVO:
Parecer um seguidor genuíno que acompanha o trabalho. Gerar curiosidade sobre quem comentou.

REGRAS OBRIGATÓRIAS:
1. Max 50 caracteres
2. Max 1 emoji (opcional)
3. Sem perguntas (guarda pra DM)
4. Sem menção a trabalho/proposta/parceria
5. Sem parecer fã exagerado ("INCRÍVEL!!!")
6. Sem genérico vazio ("Parabéns!")
7. Tom de seguidor que entende o assunto

LÓGICA POR TIPO DE POST:

SE post é sobre RESULTADO (aluno, cliente, case, faturamento):
→ Reconhecer o resultado de forma sóbria
→ Ex: "resultado fala por si", "case forte", "isso é consistência"

SE post é sobre CONTEÚDO EDUCATIVO (dica, erro, tutorial):
→ Validar o insight principal
→ Ex: "direto ao ponto", "faz total sentido", "erro clássico mesmo"

SE post é sobre BASTIDORES (gravando, criando, produzindo):
→ Curiosidade leve
→ Ex: "adorei ver isso", "os bastidores são os melhores"

SE post é sobre PESSOAL/LIFESTYLE (viagem, família, reflexão):
→ Comentário leve e universal
→ Ex: "demais!", "faz sentido", "necessário"

SE post é sobre MEME/HUMOR:
→ Reação natural
→ Ex: "hahaha real", "muito isso", "todo dia"

SE post é GENÉRICO (repost, promoção):
→ Emoji simples ou skip
→ Ex: "🔥" ou não comentar

OUTPUT:
[comentário direto, max 50 chars]
```

---

## Exemplos por Tipo de Post

### RESULTADO (aluno, cliente, case)

| Caption do Post | Comentário |
|-----------------|------------|
| "Aluna fez 50k em 3 meses..." | resultado fala por si 👏 |
| "Cliente fechou contrato de 200k" | case forte |
| "Turma formou 150 alunos" | isso é consistência |
| "Meu aluno saiu do zero..." | 🔥 |

### EDUCATIVO (dica, erro, tutorial)

| Caption do Post | Comentário |
|-----------------|------------|
| "5 erros no lançamento..." | direto ao ponto 🎯 |
| "O maior erro de quem começa..." | erro clássico mesmo |
| "Como eu estruturo meu dia..." | faz total sentido |
| "3 dicas pra aumentar..." | salvando aqui 📌 |

### BASTIDORES

| Caption do Post | Comentário |
|-----------------|------------|
| "Gravando o módulo 4..." | adorei ver isso |
| "Por trás do lançamento..." | os bastidores são os melhores |
| "Preparando a próxima turma..." | vem coisa boa |
| "Editando conteúdo domingo..." | comprometimento real |

### PESSOAL/LIFESTYLE

| Caption do Post | Comentário |
|-----------------|------------|
| "Férias merecidas em Bali" | demais! |
| "Hoje aprendi que paciência é tudo" | faz sentido |
| "Tempo com a família é sagrado" | necessário |
| "Reflexão do final de semana..." | verdade |

### MEME/HUMOR

| Caption do Post | Comentário |
|-----------------|------------|
| "Quando o cliente some..." | hahaha real |
| "Eu tentando organizar..." | muito isso |
| "Segunda-feira chegou..." | todo dia |
| "POV: você é infoprodutor" | exatamente |

### GENÉRICO (quando não há contexto útil)

| Caption do Post | Comentário |
|-----------------|------------|
| Repost de terceiro | 🔥 |
| Promoção genérica | (skip - não comentar) |
| Carrossel institucional | (skip - não comentar) |

---

## Anti-Patterns (PROIBIDO)

```
❌ "INCRÍVEL!!!" (fã exagerado)
❌ "Parabéns pelo trabalho!" (genérico vazio)
❌ "Você é demais!" (bajulação)
❌ "Posso te mandar uma DM?" (vendedor)
❌ "Tenho uma proposta..." (spam)
❌ "🔥🔥🔥🚀🚀💰💰" (excesso de emoji)
❌ "Que conteúdo maravilhoso!" (over the top)
❌ Perguntas (guarda pra DM)
❌ Qualquer menção a trabalho/negócio
❌ "Legal!" sozinho (muito vazio)
❌ Tags ou menções a outras contas
❌ Links de qualquer tipo
❌ "Segue de volta?" ou similares
```

---

## Regras de Skip

**NÃO comentar se:**
- Post é repost de terceiro sem opinião do criador
- Post é promoção genérica de produto
- Post tem menos de 10 likes (baixo engajamento)
- Último post tem mais de 7 dias
- Post é apenas uma foto sem caption relevante

**Nestes casos:** Pular step 2, manter o follow+like, avançar direto pra DM no dia 5.

---

## Contagem de Caracteres

| Tipo | Limite |
|------|--------|
| Caracteres | 50 max |
| Emojis | 1 max (opcional) |
| Perguntas | 0 (proibido) |
| Menções a negócio | 0 (proibido) |

---

## Limites de Execução (M8)

| Métrica | Limite |
|---------|--------|
| Comentários/dia | Max 10 |
| Intervalo entre comentários | Min 5 min |
| Comentários por lead | 1 (só step 2) |

---

## Validação Antes de Postar

```
[ ] Menos de 50 caracteres?
[ ] Max 1 emoji?
[ ] Sem perguntas?
[ ] Sem menção a trabalho/negócio?
[ ] Tom de seguidor genuíno (não fã exagerado)?
[ ] Faz sentido pro contexto do post?
[ ] Post é recente (<7 dias)?
[ ] Post tem engajamento mínimo (>10 likes)?
```

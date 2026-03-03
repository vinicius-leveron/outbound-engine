# Email Cold (Step 1)

> **Canal:** Email | **Max:** 100 palavras | **Objetivo:** Abertura, gerar curiosidade

## Prompt de Geração

```
Você é um copywriter especializado em outreach para {{tenant}}.

LEAD:
- Nome: {{name}}
- Bio: {{bio}}
- Seguidores: {{followers_count}}
- Produto detectado: {{claude_analysis.product_detected}}
- Estilo de conteúdo: {{claude_analysis.content_style}}
- Nível de sofisticação: {{claude_analysis.sophistication_level}}
- Observações: {{claude_analysis.key_observations}}
- Post recente: "{{recent_posts[0].caption}}"

TAREFA: Escrever email frio (max 100 palavras).

REGRAS OBRIGATÓRIAS:
1. Referenciar algo ESPECÍFICO do conteúdo do lead (post, produto, ou observação)
2. Subject curto (max 5 palavras), curioso, sem parecer marketing
3. NUNCA usar: "posso te ajudar?", "vim oferecer", "temos uma solução"
4. Abrir com gancho sobre o trabalho DELE, não sobre você
5. CTA leve: pergunta ou convite para trocar ideia
6. Ajustar linguagem pelo sophistication_level:
   - 7-10: peer-to-peer, reconhecer expertise, técnico
   - 4-6: consultivo, oferecer perspectiva
   - 1-3: didático, acessível

FORMATO OUTPUT:
Subject: [subject aqui]
---
[corpo do email em HTML simples - só <p> tags]
```

---

## KOSMOS (Criadores de Conteúdo)

### Tom
- Casual, criador-pra-criador
- Como quem acompanha o trabalho há tempo
- Hook: Referência a post/produto específico ou insight da análise T15
- CTA: Pergunta aberta, sem pressão

### Exemplos

**Lead A (Soph 8): Coach de Produtividade, 45k seguidores**
```
Subject: Seu carousel de hábitos

---
<p>Oi Ana,</p>

<p>Vi seu carousel sobre os 5 hábitos que mudaram sua rotina — a parte sobre time blocking foi certeira. Apliquei com um cliente semana passada e o resultado foi imediato.</p>

<p>To trabalhando com alguns criadores de produtividade na parte de automação de funil (aquele gap entre conteúdo e venda que dá trabalho escalar).</p>

<p>Curtia trocar uma ideia rápida sobre o que você ta testando atualmente?</p>

<p>Vinicius</p>
```

**Lead B (Soph 5): Mentora de Confeitaria, 18k seguidores**
```
Subject: Seus bolos virais

---
<p>Oi Carla!</p>

<p>Acompanho seus reels de confeitaria — aquele do bolo de brigadeiro que viralizou foi incrível. Dá pra ver o cuidado nos detalhes.</p>

<p>Trabalho com criadores de culinária na parte de estruturar a jornada do seguidor até virar aluno. Percebi que você já tem a audiência engajada, só falta o funil.</p>

<p>Te interessa uma conversa rápida sobre isso?</p>

<p>Vinicius</p>
```

**Lead C (Soph 3): Nutricionista iniciante, 8k seguidores**
```
Subject: Seus posts de receitas

---
<p>Oi Fernanda!</p>

<p>Curti muito seu post sobre lanches saudáveis pra quem trabalha em escritório — super prático.</p>

<p>Ajudo nutricionistas a transformar seguidores em clientes de consulta. Vi que você tem bastante engajamento, mas talvez falte um caminho claro pro seguidor virar paciente.</p>

<p>Quer trocar uma ideia sobre como fazer isso?</p>

<p>Vinicius</p>
```

---

## OLIVEIRA-DEV (B2B)

### Tom
- Profissional mas acessível, direto ao ponto
- Identificar dor específica do segmento
- CTA: Proposta de valor clara (call/reunião)

### Segmentos e Dores

| Segmento | Dores Comuns |
|----------|-------------|
| Construtoras | Gestão de obras, documentação, comunicação equipe |
| Advocacia | Gestão de processos, deadline, relacionamento cliente |
| Imobiliárias | Follow-up leads, CRM, automação vendas |

### Exemplos

**Lead: Construtora (15 funcionários)**
```
Subject: Gestão de obras na Construtora Silva

---
<p>Oi Carlos,</p>

<p>Vi que a Silva Engenharia ta tocando vários projetos simultâneos — desafio clássico de construtora em crescimento.</p>

<p>Trabalho com construtoras na parte de sistema de gestão: timeline de obra, comunicação com equipe de campo, e documentação. O resultado mais comum é reduzir retrabalho e atraso.</p>

<p>Faz sentido uma call de 15min pra entender se aplica aí?</p>

<p>Vinicius Oliveira</p>
```

**Lead: Escritório de Advocacia**
```
Subject: Gestão de prazos processuais

---
<p>Dra. Mariana,</p>

<p>Percebi que o escritório cresceu — muitos advogados tem dificuldade em escalar a gestão de processos sem perder prazo.</p>

<p>Desenvolvemos sistema de acompanhamento processual com alertas automáticos. Escritórios que implementaram reduziram perda de prazo em 90%.</p>

<p>Posso mostrar em uma call rápida como funciona?</p>

<p>Vinicius Oliveira</p>
```

**Lead: Imobiliária**
```
Subject: Follow-up de leads na Regional

---
<p>Oi Roberto,</p>

<p>Vi que a Regional Imóveis tá com bastante lançamento novo — imagino que o volume de leads aumentou junto.</p>

<p>Trabalho com imobiliárias na parte de automação de follow-up. O padrão do mercado é perder 60% dos leads por demora no contato.</p>

<p>Faz sentido uma conversa de 15min sobre isso?</p>

<p>Vinicius Oliveira</p>
```

---

## Anti-Patterns (PROIBIDO)

- "Oi, tudo bem? Meu nome é X e trabalho com Y" (abertura genérica)
- "Vi que você é um criador de conteúdo" (óbvio demais)
- "Posso te ajudar a faturar mais?" (vendedor)
- "Temos uma solução completa para..." (corporativo)
- Não mencionar NADA específico do perfil do lead
- Subject longo ou clickbait
- Email sem referência a conteúdo real do lead

---

## Ajuste por Sophistication Level

| Level | Tom | Linguagem | Abordagem |
|-------|-----|-----------|-----------|
| 7-10 | Peer-to-peer | Técnica, direta | Reconhecer expertise, trocar ideia como igual |
| 4-6 | Consultivo | Acessível | Oferecer perspectiva, agregar valor |
| 1-3 | Didático | Simples | Explicar benefícios, guiar com clareza |

## Ajuste por Classificação

| Classe | Score | Abordagem | CTA |
|--------|-------|-----------|-----|
| A | >= 60 | Premium, exclusividade | Call personalizada |
| B | 30-59 | Valor, ajuda | Responder email ou call |

# Email Sequence OLIVEIRA-DEV (5 Emails, 21 dias)

> **Canal:** Email | **Tenant:** oliveira-dev | **Objetivo:** Converter escritórios de advocacia

## Cadência

```
DIA 0   │ Email 1: COLD — Observação específica + dor + pergunta
DIA 4   │ Email 2: VALOR — Dado/insight do setor, sem repetir proposta
DIA 9   │ Email 3: ÂNGULO DIFERENTE — Outra dor ou benefício
DIA 14  │ Email 4: PROVA SOCIAL — Case ou dado de mercado
DIA 21  │ Email 5: BREAK-UP — Respeitoso, porta aberta
```

---

## Prompt de Geração

```
Você é um desenvolvedor escrevendo email {{step}} de 5 para escritório de advocacia.

## LEAD
- Nome do decisor: {{full_name}}
- Nome do escritório: {{company_name}}
- Áreas de atuação: {{areas}}
- Tamanho equipe: {{team_size}} advogados

## DADOS DE ENRICHMENT (usar na ordem de prioridade)
1. Review Google Maps: "{{google_maps.recent_reviews[0].text}}"
2. Post Instagram: "{{instagram.recent_posts[0].caption}}"
3. Observação do site: {{website_observations}}
4. Tamanho da equipe: {{team_size}}
5. Área + dor genérica

## EMAILS ANTERIORES (contexto)
{{previous_emails_summary}}

## STEP ATUAL: {{step}}

---

### SE step == 1 (COLD):
OBJETIVO: Abrir conversa com observação específica + dor + pergunta

ESTRUTURA:
1. Abrir com observação específica (review > post > site > equipe > área)
2. Conectar com dor relevante
3. Apresentar o que você faz (1 frase, específico)
4. Terminar com pergunta sobre realidade deles

ESCOLHA DO SERVIÇO:
- Se review/contexto menciona "cliente informado/transparência/acompanhamento" → Portal
- Se review/contexto menciona "rápido/eficiente/organizado/prazo" → Gestão
- Se equipe > 5 advogados → Gestão (problema de escala)
- Se área = família/civil (alto volume clientes) → Portal (muita ligação)
- Se área = empresarial/tributário → Gestão (complexidade)

---

### SE step == 2 (VALOR):
OBJETIVO: Agregar valor sem repetir proposta

ESTRUTURA:
1. Referência leve ao email anterior (sem cobrar)
2. Trazer dado/insight relevante pro setor
3. Conectar com a realidade do escritório
4. Pergunta aberta

TIPOS DE VALOR (escolher baseado no contexto):
- DADO: "Vi um estudo que mostrou que escritórios que X reduzem Y em Z%"
- INSIGHT: "Uma tendência que tenho visto em escritórios de [área]..."
- OBSERVAÇÃO: "Percebi que muitos escritórios de [tamanho] enfrentam..."
- PERGUNTA: "Como vocês lidam com [dor específica] hoje?"

---

### SE step == 3 (ÂNGULO DIFERENTE):
OBJETIVO: Abordar outra dor ou benefício

LÓGICA DE ÂNGULO:
- Se email 1 falou de PRAZO → falar de ATENDIMENTO AO CLIENTE
- Se email 1 falou de ATENDIMENTO → falar de ORGANIZAÇÃO INTERNA
- Se email 1 falou de GESTÃO → falar de TEMPO DO SÓCIO
- Se email 1 falou de PORTAL → falar de REDUÇÃO DE LIGAÇÕES

ESTRUTURA:
1. Não repetir o que já foi dito
2. Nova dor ou novo benefício
3. Conectar com perfil do escritório
4. Pergunta diferente

---

### SE step == 4 (PROVA SOCIAL / CASE):
OBJETIVO: Mostrar resultado concreto

SE TEM CLIENTE:
- Mencionar escritório de referência
- Resultado específico (métrica)
- CTA mais direto (call de 15min)

SE NÃO TEM CLIENTE (usar dado de mercado):
- Dado de pesquisa/estudo
- Benefício mensurável
- CTA para conversa

---

### SE step == 5 (BREAK-UP):
OBJETIVO: Encerrar respeitosamente, deixar porta aberta

ESTRUTURA:
1. Reconhecer que timing pode não ser ideal
2. Sem culpa ou pressão
3. Deixar claro que está disponível
4. Desejar sucesso

---

## REGRAS OBRIGATÓRIAS (TODOS OS STEPS)

1. Max 80 palavras por email
2. Subject max 5 palavras, específico (nunca "Proposta Comercial")
3. SEMPRE usar nome do decisor (nunca "Prezados")
4. SEMPRE HTML simples (só <p> tags)
5. NUNCA: "posso te ajudar?", "solução completa", "automação" (genérico)
6. NUNCA: pressão, urgência artificial, "última chance"
7. Tom: profissional mas humano, sem "venho por meio desta"
8. Cada email deve fazer sentido sozinho (lead pode não ter lido os anteriores)
9. Assinatura sempre: "Vinicius Oliveira"

---

## FORMATO OUTPUT

Subject: [subject aqui]
---
[corpo do email em HTML simples - só <p> tags]
```

---

## Hierarquia de Personalização

| Prioridade | Fonte de Dados | Exemplo de Observação |
|------------|----------------|----------------------|
| 1 | **Google Maps Review** | "Vi o review da cliente sobre organização no acompanhamento do processo dela..." |
| 2 | **Instagram Post** | "Vi o post sobre a vitória no caso X..." |
| 3 | **Site/LinkedIn** | "Vi que vocês expandiram pra área tributária..." |
| 4 | **Tamanho equipe** | "Com 8 advogados, imagino que a gestão de prazos..." |
| 5 | **Área + Dor genérica** | "Escritórios de família costumam ter dificuldade com..." |

**Regra:** Usar a fonte de MAIOR prioridade disponível. Nunca pular pra genérico se tem dado real.

---

## Dois Serviços

| Serviço | Quando Usar | Descrição |
|---------|-------------|-----------|
| **Sistema de Gestão** | Dor detectada: prazos, organização, demandas | "Desenvolvo sistemas de gestão pra escritórios — controle de prazo, organização de demanda, acompanhamento de processo" |
| **Portal de Acompanhamento** | Dor detectada: cliente ligando, transparência | "Desenvolvo portais de acompanhamento processual — cliente acessa, vê o status, não precisa ligar pra perguntar" |

### Detecção de Dor

- Review menciona "informada", "transparência", "acompanhamento" → **Portal**
- Review menciona "rápido", "eficiente", "organizado" → **Gestão**
- Equipe > 5 advogados → **Gestão** (escala)
- Área família/civil (alto volume clientes) → **Portal** (muita ligação)
- Área empresarial/tributário → **Gestão** (complexidade)

---

## Banco de Dores

| Dor | Gatilhos | Serviço | Ângulo |
|-----|----------|---------|--------|
| Prazo perdido | equipe > 5, múltiplas áreas | Gestão | prazo |
| Cliente ligando toda hora | área família/civil, review "atendimento" | Portal | atendimento |
| Sócio sem tempo | equipe > 8, review "corrido" | Gestão | tempo_socio |
| Equipe desalinhada | equipe > 5, sem sistema | Gestão | organizacao |
| Retrabalho | área tributária/empresarial | Gestão | organizacao |
| Transparência com cliente | review "informado/acompanhamento" | Portal | reducao_ligacoes |

---

## Matriz de Ângulos (Email 1 → Email 3)

| Se Email 1 usou | Email 3 deve usar |
|-----------------|-------------------|
| prazo | atendimento ou tempo_socio |
| atendimento | organizacao ou reducao_ligacoes |
| tempo_socio | prazo ou organizacao |
| organizacao | atendimento ou tempo_socio |
| reducao_ligacoes | tempo_socio ou prazo |

---

## Exemplos por Step

### Email 1 (COLD) — Com Review Google Maps

```
Subject: Review da Maria no Google

---
<p>Dr. Carlos,</p>

<p>Vi o review da Maria Silva sobre como vocês mantiveram ela informada durante todo o processo — é raro ver isso em escritório de família.</p>

<p>Desenvolvo portais de acompanhamento pra escritórios aqui de Floripa. O cliente acessa, vê o status, não precisa ligar pra perguntar.</p>

<p>Como vocês fazem esse acompanhamento hoje? É manual?</p>

<p>Vinicius Oliveira</p>
```

### Email 1 (COLD) — Com Post Instagram

```
Subject: Caso do divórcio litigioso

---
<p>Dra. Fernanda,</p>

<p>Vi o post sobre a vitória no divórcio litigioso — caso complexo. Imagino que com casos assim o volume de atualizações pro cliente é alto.</p>

<p>Desenvolvo portais de acompanhamento processual. Cliente acessa, vê movimentação, não precisa ligar toda hora.</p>

<p>Vocês usam algum sistema pra isso ou é tudo manual?</p>

<p>Vinicius Oliveira</p>
```

### Email 1 (COLD) — Com Observação do Site

```
Subject: Expansão pra tributário

---
<p>Dr. Roberto,</p>

<p>Vi que vocês expandiram pra área tributária — com 8 advogados, imagino que a gestão de prazos ficou mais complexa.</p>

<p>Desenvolvo sistemas de gestão pra escritórios aqui de Floripa. Controle de prazo, organização de demanda, acompanhamento centralizado.</p>

<p>Como ta sendo gerenciar com a equipe maior?</p>

<p>Vinicius Oliveira</p>
```

### Email 1 (COLD) — Só Tamanho Equipe

```
Subject: Gestão com 12 advogados

---
<p>Dra. Patricia,</p>

<p>Com 12 advogados, imagino que o desafio de não perder prazo e manter todo mundo alinhado é constante.</p>

<p>Desenvolvo sistemas de gestão processual pra escritórios aqui de Floripa — controle de prazo, distribuição de demanda, visibilidade do que cada um ta tocando.</p>

<p>Vocês usam algum sistema hoje ou é planilha/email?</p>

<p>Vinicius Oliveira</p>
```

### Email 1 (COLD) — Área + Dor Genérica (último recurso)

```
Subject: Gestão em direito de família

---
<p>Dr. Marcos,</p>

<p>Escritórios de família costumam ter um desafio: volume alto de clientes, cada um querendo saber como ta o processo.</p>

<p>Desenvolvo portais de acompanhamento pra escritórios. O cliente acessa, vê o status, vocês não precisam responder as mesmas perguntas todo dia.</p>

<p>Como vocês lidam com isso hoje?</p>

<p>Vinicius Oliveira</p>
```

### Email 2 (VALOR)

```
Subject: Dado sobre prazos

---
<p>Dr. Carlos,</p>

<p>Vi um dado interessante essa semana: escritórios que automatizam controle de prazo reduzem erro humano em 85%.</p>

<p>Imagino que com a equipe de vocês, manter tudo sincronizado deve dar trabalho.</p>

<p>Vocês usam algum sistema pra isso ou é planilha/agenda?</p>

<p>Vinicius Oliveira</p>
```

### Email 3 (ÂNGULO DIFERENTE)

```
Subject: Tempo do sócio

---
<p>Dr. Carlos,</p>

<p>Uma coisa que escuto muito de sócios de escritório: "passo mais tempo apagando incêndio do que advogando".</p>

<p>Com a equipe crescendo, imagino que distribuir demanda e acompanhar tudo consome boa parte do dia.</p>

<p>Quanto tempo você diria que gasta com gestão vs advocacia de fato?</p>

<p>Vinicius Oliveira</p>
```

### Email 4 (PROVA SOCIAL) — Com Cliente

```
Subject: Resultado do escritório Silva

---
<p>Dr. Carlos,</p>

<p>O escritório Silva aqui de Floripa implementou o portal de acompanhamento há 6 meses.</p>

<p>Resultado: reduziram 40% das ligações de cliente perguntando status.</p>

<p>Não sei se faz sentido pra realidade de vocês, mas se quiser ver como funciona, posso mostrar em 15min.</p>

<p>Vinicius Oliveira</p>
```

### Email 4 (PROVA SOCIAL) — Sem Cliente

```
Subject: Padrão do mercado jurídico

---
<p>Dr. Carlos,</p>

<p>Um dado que me chamou atenção: escritórios que digitalizam o acompanhamento processual economizam em média 8 horas/semana por advogado.</p>

<p>Isso é tempo que volta pra atender mais clientes ou pra qualidade de vida mesmo.</p>

<p>Faz sentido uma conversa de 15min pra entender se aplica aí?</p>

<p>Vinicius Oliveira</p>
```

### Email 5 (BREAK-UP)

```
Subject: Fechando

---
<p>Dr. Carlos,</p>

<p>Entendo que pode não ser prioridade agora — agenda de sócio é corrida.</p>

<p>Não vou mais encher sua caixa. Se em algum momento fizer sentido conversar sobre gestão/portal, meu email ta aqui.</p>

<p>Sucesso com o escritório!</p>

<p>Vinicius Oliveira</p>
```

---

## Anti-Patterns (PROIBIDO)

- "Oi, tudo bem? Meu nome é Vinicius e trabalho com automação para escritórios" (zero personalização)
- "Vi que você é da área de advocacia" (óbvio demais)
- "Posso te ajudar a ser mais produtivo?" (vendedor, vago)
- "Temos uma solução completa de gestão jurídica" (corporativo)
- "Automação para escritórios" (genérico demais)
- Email sem mencionar NADA específico do escritório (template puro)
- "Última chance!" (urgência falsa)
- "Você vai perder a oportunidade" (manipulação)
- "Não entendo por que não respondeu" (culpa)

---

## Checklist Antes de Gerar

```
[ ] Tem review do Google Maps? → Usar como gancho
[ ] Tem post do Instagram? → Usar se não tem review
[ ] Tem observação do site? → Usar se não tem post
[ ] Tem tamanho da equipe? → Usar se > 5 advogados
[ ] Qual área principal? → Determinar dor + serviço
[ ] Qual serviço faz mais sentido? (Gestão vs Portal)
[ ] Nome do decisor correto?
[ ] Nome do escritório correto?
[ ] Se step > 1: qual ângulo usar? (verificar matriz)
```

# Email Follow-up (Step 3)

> **Canal:** Email | **Max:** 80 palavras | **Objetivo:** Adicionar valor, reengajar

## Prompt de Geração

```
Você é um copywriter escrevendo email de follow-up.

CONTEXTO:
- Email anterior (step 1) foi sobre: [referência ao conteúdo do lead]
- Ainda sem resposta

LEAD:
- Nome: {{name}}
- Produto detectado: {{claude_analysis.product_detected}}
- Content style: {{claude_analysis.content_style}}
- Key observation: {{claude_analysis.key_observations}}
- Post recente (novo): "{{recent_posts[0].caption}}"

TAREFA: Escrever follow-up (max 80 palavras) que adiciona VALOR, não pressão.

REGRAS OBRIGATÓRIAS:
1. Referenciar email anterior de forma leve (não repetir)
2. Adicionar algo novo: insight, observação, dado, ou pergunta relevante
3. NÃO repetir a mesma oferta/CTA do email anterior
4. Tom: "lembrei de você quando vi X" ou "vi que você postou Y"
5. NUNCA: "você viu meu email?", "estou aguardando", qualquer pressão

FORMATO OUTPUT:
Subject: Re: [subject anterior] ou novo subject curto
---
[corpo em HTML simples - só <p> tags]
```

---

## KOSMOS (Criadores de Conteúdo)

### Tom
- Continuação natural da conversa
- Trazer insight novo ou recurso útil
- Não repetir mensagem anterior
- Referenciar algo novo que o lead postou (se disponível)

### Exemplos

**Follow-up para Coach de Produtividade:**
```
Subject: Re: Seu carousel de hábitos

---
<p>Ana, vi que você lançou mais um conteúdo sobre rotina matinal — parabéns pelo engajamento!</p>

<p>Lembrei da nossa conversa quando um cliente meu implementou automação de follow-up pós-conteúdo. A taxa de conversão de DM pra call subiu 40%.</p>

<p>Se quiser trocar ideia sobre, me avisa.</p>

<p>Vinicius</p>
```

**Follow-up para Mentora de Confeitaria:**
```
Subject: Sobre escalar o curso

---
<p>Carla, vi que abriu vagas pra turma nova — deve ter dado trabalho!</p>

<p>Lembrei de uma estratégia que funciona bem pra nichos de culinária: usar quiz no Instagram pra qualificar antes de abrir carrinho. Reduz muito o suporte depois.</p>

<p>Faz sentido pra você?</p>

<p>Vinicius</p>
```

**Follow-up para Personal Trainer:**
```
Subject: Sobre o lançamento

---
<p>Lucas, vi que você abriu mentoria nova — bacana o formato!</p>

<p>Percebi que criadores fitness que usam automação de nutrição de leads dobram a taxa de aplicação. Basicamente, quem demonstra interesse recebe conteúdo específico antes do pitch.</p>

<p>Quer que eu explique como funciona?</p>

<p>Vinicius</p>
```

---

## OLIVEIRA-DEV (B2B)

### Tom
- Profissional, apresentar case ou dado relevante
- Demonstrar entendimento do setor
- CTA mais direto (call ou demo)

### Exemplos

**Follow-up para Construtora:**
```
Subject: Re: Gestão de obras

---
<p>Carlos, lembrei de você quando vi uma construtora aqui de SP reduzir 30% do retrabalho só com rastreamento de tarefas em campo.</p>

<p>Imagino que com vários projetos simultâneos, qualquer otimização faz diferença no resultado.</p>

<p>Ainda faz sentido uma conversa rápida sobre isso?</p>

<p>Vinicius Oliveira</p>
```

**Follow-up para Escritório de Advocacia:**
```
Subject: Dado sobre prazos

---
<p>Dra. Mariana, vi um estudo essa semana: escritórios que automatizam controle de prazo reduzem erro humano em 85%.</p>

<p>Considerando o volume de processos que vocês tocam, pode fazer diferença significativa.</p>

<p>Quer ver como funciona na prática?</p>

<p>Vinicius Oliveira</p>
```

**Follow-up para Imobiliária:**
```
Subject: Sobre tempo de resposta

---
<p>Roberto, achei um dado interessante: leads de imóvel contactados em menos de 5 minutos convertem 21x mais que os contactados após 30 min.</p>

<p>Com o volume de lançamentos que vocês tem, automação pode fazer muita diferença.</p>

<p>Faz sentido conversar sobre?</p>

<p>Vinicius Oliveira</p>
```

---

## Anti-Patterns (PROIBIDO)

- "Você recebeu meu email?" (pressão)
- "Gostaria de saber se tem interesse" (passivo)
- "Estou aguardando seu retorno" (cobrança)
- Repetir exatamente a mesma proposta do email anterior
- Ignorar o contexto do lead
- Não trazer nenhum valor novo

---

## Dicas de Valor para Adicionar

| Tenant | Tipos de Valor |
|--------|---------------|
| KOSMOS | Insight de mercado, dado de conversão, estratégia testada, referência a post novo |
| Oliveira-dev | Case de cliente similar, dado do setor, ROI específico, estudo/pesquisa |

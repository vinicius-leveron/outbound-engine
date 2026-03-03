# DM Follow-up (Step 4)

> **Canal:** Instagram DM | **Max:** 50 palavras (300 chars) | **Objetivo:** Lembrete leve, retomar conversa

## Prompt de Geração

```
Você é um copywriter escrevendo DM de follow-up no Instagram.

CONTEXTO:
- DM anterior (step 2) foi uma pergunta sobre conteúdo do lead
- Sem resposta ainda

LEAD:
- Nome: {{name}}
- Último post (novo): "{{recent_posts[0].caption}}"
- Key observation: {{claude_analysis.key_observations}}

TAREFA: Escrever follow-up leve (max 50 palavras, max 300 chars) que retoma conversa sem pressão.

REGRAS OBRIGATÓRIAS:
1. Referenciar algo NOVO que o lead postou (se disponível)
2. NÃO mencionar "você não respondeu" ou cobrar resposta
3. Tom de quem lembrou por conta própria
4. Pergunta ou observação genuína
5. ZERO links
6. Max 1 emoji (opcional)
7. Parecer continuação natural, não follow-up forçado

FORMATO OUTPUT:
[mensagem direto]
```

---

## KOSMOS (Criadores de Conteúdo)

### Tom
- Super casual, como amigo
- Pode mencionar post recente como gancho
- Sem pressão ou cobrança
- Natural, como se estivesse compartilhando algo

### Exemplos

**Lead A: Coach de Finanças**
```
Pedro! Vi seu story sobre o erro da previdência — real demais. Aliás, implementei aquela dica do post que comentei, ta funcionando bem. Valeu!
```

**Lead B: Personal Trainer**
```
Ei! Vi seu post novo sobre periodização — muito bom o framework. To testando aquilo do jejum que perguntei, ainda ajustando. Obrigado pela inspiração!
```

**Lead C: Designer de Interiores**
```
Julia! Vi o projeto novo que você postou — adorei a paleta de cores. Aquele conceito de minimalismo que você mencionou ta cada vez mais forte.
```

**Lead D: Coach de Produtividade**
```
Ana! Aplicando aquele método do time blocking que você ensinou. Primeira semana foi caótica mas agora ta fluindo melhor!
```

**Lead E: Mentora de Confeitaria**
```
Carla! Tentei aquela técnica do ganache que você mostrou — não ficou igual o seu mas melhorou muito. Obrigado pelo conteúdo!
```

**Lead F: Nutricionista (sem post novo)**
```
Fernanda! Só passando pra dizer que aquelas dicas de lanche salvaram a semana. Meus colegas já pediram a receita do overnight oats!
```

---

## OLIVEIRA-DEV (B2B)

### Tom
- Breve, profissional mas humanizado
- Mencionar disponibilidade sem pressão
- Sem repetir pitch
- Networking natural

### Exemplos

**Lead: Construtora**
```
Carlos! Vi o post da obra nova — parece que o ritmo ta bom. Lembrei da nossa conversa sobre gestão. Se fizer sentido, continuo por aqui!
```

**Lead: Escritório Advocacia**
```
Dra. Mariana! Vi que o escritório ganhou mais um caso relevante — parabéns! Fico à disposição se surgir interesse em conversar sobre gestão.
```

**Lead: Imobiliária**
```
Roberto! Vi que o lançamento ta vendendo bem — ótimo sinal do mercado aí. Qualquer hora que quiser trocar ideia, é só chamar.
```

---

## Anti-Patterns (PROIBIDO)

- "Oi, você viu minha mensagem?" (cobrança direta)
- "Estou aguardando sua resposta" (pressão)
- "Não sei se você viu mas..." (passivo-agressivo)
- Repetir a mesma pergunta do DM anterior
- Qualquer tipo de pressão ou urgência
- Links ou menção de oferta
- Múltiplos emojis
- Mensagem muito longa

---

## Estratégias de Retomada

| Estratégia | Quando Usar | Exemplo |
|------------|-------------|---------|
| Atualização pessoal | Lead postou algo novo | "Vi seu post novo sobre X — muito bom!" |
| Compartilhar resultado | Você testou algo do lead | "Implementei aquilo que você ensinou, funcionou!" |
| Elogio específico | Lead teve conquista | "Parabéns pela turma nova / projeto / case!" |
| Observação relevante | Sem post novo | "Lembrei de você quando vi X" |

---

## Contagem de Caracteres

| Tipo | Limite |
|------|--------|
| Caracteres | 300 max |
| Palavras | ~50 max |
| Emojis | 1 max (opcional) |
| Links | 0 (proibido) |

# DM Opener (Step 2)

> **Canal:** Instagram DM | **Max:** 50 palavras (300 chars) | **Objetivo:** Abrir conversa natural

## Prompt de Geração

```
Você é um copywriter escrevendo DM de Instagram como seguidor genuíno.

LEAD:
- Nome: {{name}}
- Bio: {{bio}}
- Produto detectado: {{claude_analysis.product_detected}}
- Post recente: "{{recent_posts[0].caption}}"
- Key observation: {{claude_analysis.key_observations}}

TAREFA: Escrever DM opener (max 50 palavras, max 300 caracteres).

REGRAS OBRIGATÓRIAS:
1. Parecer um seguidor que admira o trabalho, NÃO um vendedor
2. Mencionar algo REAL e ESPECÍFICO (post, insight, resultado mencionado)
3. Abrir conversa com pergunta ou comentário genuíno
4. ZERO links
5. Max 1 emoji (opcional)
6. NUNCA: "trabalho com", "oferta", "parceria", "proposta", "oportunidade"
7. Tom casual como se já acompanhasse há tempo

FORMATO OUTPUT:
[mensagem direto, sem subject, sem saudação formal]
```

---

## KOSMOS (Criadores de Conteúdo)

### Tom
- Como seguidor que admira o trabalho
- Sem link, sem venda
- Pergunta ou elogio genuíno sobre conteúdo específico
- Casual, natural

### Exemplos

**Lead A: Coach de Finanças Pessoais**
```
Oi Pedro! Seu post sobre o erro #1 dos iniciantes em investimento bateu forte aqui — cometi esse exatamente. Como você estrutura o conteúdo pra iniciante vs quem já investe?
```

**Lead B: Personal Trainer com Mentoria**
```
Vi seu reel do treino em jejum, muito bom! To tentando implementar mas fico sem energia. Você indica pra todo mundo ou depende do perfil?
```

**Lead C: Designer de Interiores**
```
Julia, aquele projeto do apartamento compacto ficou incrível! Como você consegue manter a identidade visual tão consistente entre projetos diferentes?
```

**Lead D: Coach de Produtividade**
```
Ana! Aquele carousel sobre time blocking mudou minha semana. Você usa alguma ferramenta específica pra gerenciar ou é tudo no papel mesmo?
```

**Lead E: Mentora de Confeitaria**
```
Carla, seus bolos são arte! Aquele de brigadeiro que viralizou... como você consegue a textura do ganache tão perfeita?
```

**Lead F: Nutricionista**
```
Fernanda! Seu post sobre lanches de escritório salvou minha semana. Você tem alguma dica pra quem viaja muito a trabalho?
```

---

## OLIVEIRA-DEV (B2B)

### Tom
- Conexão profissional, networking genuíno
- Mencionar contexto do perfil/empresa
- Pergunta relevante sobre o negócio
- Sem venda direta, interesse genuíno

### Exemplos

**Lead: Construtora**
```
Oi Carlos! Vi o post da entrega do condomínio — projeto bonito. Como vocês fazem a gestão de múltiplas obras simultâneas? To pesquisando sobre o tema pra um projeto.
```

**Lead: Escritório Advocacia**
```
Dra. Mariana, vi que o escritório cresceu bastante esse ano. Como ta sendo gerenciar o volume de processos com a equipe maior? Sempre me interesso por gestão jurídica.
```

**Lead: Imobiliária**
```
Roberto! Vi o lançamento novo que vocês tão divulgando — localização boa. Como ta o mercado aí na região? Tenho acompanhado o setor.
```

**Lead: Arquiteto**
```
Paulo, aquele projeto residencial que você postou ficou muito bom! O cliente pediu referências específicas ou você teve liberdade criativa?
```

---

## Anti-Patterns (PROIBIDO)

- "Oi! Vi que você é da área de X" (genérico)
- "Oi, posso te mandar uma proposta?" (vendedor)
- "Parabéns pelo trabalho!" (vazio, sem especificidade)
- "Tenho uma oportunidade pra você" (spam)
- "Gostaria de apresentar minha empresa" (corporativo)
- Links de qualquer tipo
- Múltiplos emojis
- Mensagem muito longa (>300 chars)
- Áudio ou figurinha

---

## Estruturas que Funcionam

| Estrutura | Exemplo |
|-----------|---------|
| Elogio específico + Pergunta | "Aquele post sobre X foi ótimo! Como você faz Y?" |
| Identificação + Curiosidade | "To tentando fazer X que você mostrou. Funciona pra Y também?" |
| Observação + Interesse | "Vi que você fez X — interessante! Qual foi o resultado?" |
| Conexão + Dúvida genuína | "Seu conteúdo sobre X me ajudou muito. Você indica Z pra quem ta começando?" |

---

## Contagem de Caracteres

| Tipo | Limite |
|------|--------|
| Caracteres | 300 max |
| Palavras | ~50 max |
| Emojis | 1 max (opcional) |
| Links | 0 (proibido) |

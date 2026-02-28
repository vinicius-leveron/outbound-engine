# M7 — MANYCHAT → CRM BRIDGE (Configuração no ManyChat)

> **ANTES DE TUDO**: Execute `source /root/outbound-engine/.env` para carregar as credenciais.


## Contexto
Este módulo NÃO é uma scheduled task do Claude. O ManyChat envia dados diretamente para o CRM via External Request (HTTP) dentro dos flows. Este documento é um guia de configuração.

## Arquitetura

```
Usuário interage no IG → ManyChat captura → Flow processa →
External Request (POST) → CRM Supabase → Lead criado/atualizado
```

Sem módulo intermediário. Sem polling. Real-time.

## Credenciais (para configurar no ManyChat)

```
CRM_BASE_URL: ${CRM_BASE_URL}/v1
CRM_API_KEY: ${CRM_API_KEY}
```

## Configuração Passo a Passo

### 1. Criar Custom Fields no ManyChat

Antes de configurar os flows, crie estes custom fields no ManyChat (Settings → Custom Fields):

| Field Name | Type | Uso |
|------------|------|-----|
| `crm_id` | Text | ID do lead no CRM (preenchido após criação) |
| `crm_synced` | Boolean | Se já foi sincronizado com CRM |
| `icp_class` | Text | Classificação A/B/C (retorno do CRM) |

### 2. Flow: Novo Subscriber → Criar Lead no CRM

Quando um novo subscriber entra (comment-to-DM, story reply, link na bio, etc.):

**Bloco: External Request (HTTP)**

```
Method: POST
URL: ${CRM_BASE_URL}/v1/contacts
Headers:
  Authorization: Bearer ${CRM_API_KEY}
  Content-Type: application/json
Body (JSON):
{
  "nome": "{{first_name}} {{last_name}}",
  "instagram": "{{instagram_username}}",
  "email": "{{email}}",
  "telefone": "{{phone}}",
  "source": "manychat_inbound",
  "tenant": "kosmos",
  "canal_entrada": "manychat",
  "score_icp": 0,
  "cadence_status": "new",
  "fontes": ["manychat_{{flow_name}}"],
  "bio": "",
  "followers_count": null,
  "is_business": null,
  "external_url": null
}
```

**Após sucesso (status 200/201):**
- Salvar response `id` no custom field `crm_id`
- Setar `crm_synced` = true

**Se erro (status 409 = duplicado):**
- Lead já existe → buscar e atualizar (próximo step)

### 3. Flow: Verificar duplicado antes de criar

Antes do POST, faça um GET para checar se o lead já existe:

**Bloco: External Request (HTTP)**

```
Method: GET
URL: ${CRM_BASE_URL}/v1/contacts?instagram={{instagram_username}}
Headers:
  Authorization: Bearer ${CRM_API_KEY}
```

**Condição:**
- Se retornou lead → já existe, salvar `crm_id` e fazer PATCH (merge)
- Se não retornou → criar novo (POST do step anterior)

### 4. Flow: Qualificação Inbound (Perguntas no DM)

Se o flow do ManyChat faz perguntas de qualificação (ex: "Você tem produto digital?", "Quantos seguidores?"), envie as respostas para o CRM:

**Bloco: External Request (HTTP)**

```
Method: PATCH
URL: ${CRM_BASE_URL}/v1/contacts/{{crm_id}}
Headers:
  Authorization: Bearer ${CRM_API_KEY}
  Content-Type: application/json
Body:
{
  "ai_analysis": "Respostas ManyChat: Produto={{resposta1}}, Seguidores={{resposta2}}, Interesse={{resposta3}}"
}
```

### 5. Flow: Tag de Classificação (CRM → ManyChat)

Para sincronizar a classificação do M2 de volta ao ManyChat, você tem duas opções:

**Opção A — Webhook do Supabase:**
Criar uma Edge Function no Supabase que, quando `classificacao` muda, faz POST no ManyChat:

```
POST https://api.manychat.com/fb/subscriber/setCustomFieldByName
Headers:
  Authorization: Bearer {MANYCHAT_API_TOKEN}
Body:
{
  "subscriber_id": {manychat_id},
  "field_name": "icp_class",
  "field_value": "A"
}
```

**Opção B — Manual/Batch:**
Periodicamente exportar leads classificados e importar tags no ManyChat via CSV.

**Recomendação:** Comece com Opção B (simples). Migre para A quando o volume justificar.

### 6. Flows recomendados no ManyChat

| Flow | Trigger | Ação CRM |
|------|---------|----------|
| **Comment-to-DM** | Comentário em post específico | POST /contacts (novo lead) |
| **Story Reply** | Resposta a story | POST /contacts (novo lead) |
| **Bio Link** | Clique no link da bio | POST /contacts (novo lead) |
| **Qualificação** | Após perguntas do bot | PATCH /contacts/{id} (atualiza dados) |
| **Opt-out** | Usuário pede pra sair | PATCH /contacts/{id} (cadence_status = "opted_out") |

## Campos que o ManyChat pode enviar

| Variável ManyChat | Campo CRM | Notas |
|-------------------|-----------|-------|
| `{{first_name}}` | nome | Concatenar com last_name |
| `{{last_name}}` | nome | Concatenar com first_name |
| `{{instagram_username}}` | instagram | Sem @ |
| `{{email}}` | email | Se coletado no flow |
| `{{phone}}` | telefone | Se coletado no flow |
| `{{flow_name}}` | fontes[] | Identifica qual flow gerou o lead |

## Importante
- Este módulo NÃO tem cron — é event-driven via ManyChat
- Remover M7 do crontab (não precisa mais)
- Leads inbound do ManyChat entram com `score_icp = 0` e serão classificados pelo M2 na próxima execução
- Se o ManyChat não conseguir fazer External Request (plano free), considere usar Zapier/Make como bridge

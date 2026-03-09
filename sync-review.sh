#!/bin/bash
# =============================================================================
# SYNC-REVIEW.SH — Sincroniza Review_Queue com CRM
# =============================================================================
#
# Lê a aba Review_Queue da planilha e atualiza o CRM com base no review_status
# preenchido manualmente pelo operador.
#
# Fluxo:
# 1. Humano verifica DMs no Instagram
# 2. Humano preenche review_status na planilha (replied/not_interested/no_response)
# 3. Este script lê a planilha e atualiza o CRM
# 4. Se no_response: muda cadence_status para in_sequence (permite step 4)
#
# Uso: ./sync-review.sh
# Rodar diariamente ou após verificação manual
# =============================================================================

set -e

# Carregar variáveis de ambiente
if [ -f .env ]; then
    source .env
elif [ -f /root/outbound-engine/.env ]; then
    source /root/outbound-engine/.env
else
    echo "ERRO: Arquivo .env não encontrado"
    exit 1
fi

# Validar variáveis obrigatórias
if [ -z "$CRM_BASE_URL" ] || [ -z "$CRM_API_KEY" ]; then
    echo "ERRO: CRM_BASE_URL e CRM_API_KEY são obrigatórios"
    exit 1
fi

if [ -z "$GOOGLE_SHEETS_ID" ] || [ -z "$GOOGLE_OAUTH_CLIENT_ID" ] || [ -z "$GOOGLE_OAUTH_CLIENT_SECRET" ] || [ -z "$GOOGLE_OAUTH_REFRESH_TOKEN" ]; then
    echo "ERRO: Credenciais do Google Sheets são obrigatórias"
    exit 1
fi

echo "=========================================="
echo "SYNC-REVIEW — $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# Obter access token do Google
echo "Obtendo access token do Google..."
SHEETS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
    -d "client_id=${GOOGLE_OAUTH_CLIENT_ID}" \
    -d "client_secret=${GOOGLE_OAUTH_CLIENT_SECRET}" \
    -d "refresh_token=${GOOGLE_OAUTH_REFRESH_TOKEN}" \
    -d "grant_type=refresh_token" | jq -r '.access_token')

if [ "$SHEETS_TOKEN" == "null" ] || [ -z "$SHEETS_TOKEN" ]; then
    echo "ERRO: Falha ao obter access token"
    exit 1
fi

SHEETS_BASE="https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}/values"

# Ler Review_Queue
echo "Lendo Review_Queue..."
REVIEW_DATA=$(curl -s "${SHEETS_BASE}/Review_Queue!A:D" \
    -H "Authorization: Bearer ${SHEETS_TOKEN}")

# Processar cada linha
echo "Processando reviews..."
TOTAL=0
REPLIED=0
NOT_INTERESTED=0
NO_RESPONSE=0
SKIPPED=0

# Extrair linhas (ignorar header)
ROWS=$(echo "$REVIEW_DATA" | jq -c '.values[1:][]' 2>/dev/null || echo "")

if [ -z "$ROWS" ]; then
    echo "Nenhuma linha para processar"
    exit 0
fi

while IFS= read -r row; do
    # Extrair campos: A=username, B=contact_org_id, C=dm_sent_at, D=review_status
    USERNAME=$(echo "$row" | jq -r '.[0] // empty')
    CONTACT_ID=$(echo "$row" | jq -r '.[1] // empty')
    DM_SENT_AT=$(echo "$row" | jq -r '.[2] // empty')
    REVIEW_STATUS=$(echo "$row" | jq -r '.[3] // empty')

    # Pular se não tem contact_id ou review_status vazio
    if [ -z "$CONTACT_ID" ] || [ -z "$REVIEW_STATUS" ]; then
        ((SKIPPED++)) || true
        continue
    fi

    ((TOTAL++)) || true

    echo "  Processando @${USERNAME} (${CONTACT_ID}): ${REVIEW_STATUS}"

    # Determinar novo status no CRM
    case "$REVIEW_STATUS" in
        "replied")
            NEW_STATUS="replied"
            ((REPLIED++)) || true
            ;;
        "not_interested")
            NEW_STATUS="not_interested"
            ((NOT_INTERESTED++)) || true
            ;;
        "no_response")
            NEW_STATUS="in_sequence"  # Volta para permitir step 4
            ((NO_RESPONSE++)) || true
            ;;
        *)
            echo "    Status desconhecido: $REVIEW_STATUS, pulando..."
            continue
            ;;
    esac

    # Atualizar CRM
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/cadence" \
        -H "Authorization: Bearer ${CRM_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"cadence_status\": \"${NEW_STATUS}\"}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "200" ]; then
        echo "    ✓ CRM atualizado: ${NEW_STATUS}"
    else
        echo "    ✗ Erro ao atualizar CRM (HTTP ${HTTP_CODE}): ${BODY}"
    fi

    # Logar atividade
    curl -s -X POST "${CRM_BASE_URL}/v1/contacts/${CONTACT_ID}/activities" \
        -H "Authorization: Bearer ${CRM_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"note\",
            \"title\": \"Review DM: ${REVIEW_STATUS}\",
            \"metadata\": {\"module\": \"sync-review\", \"review_status\": \"${REVIEW_STATUS}\"}
        }" > /dev/null 2>&1

done <<< "$ROWS"

# Relatório
echo ""
echo "=========================================="
echo "RELATÓRIO"
echo "=========================================="
echo "Total processado: ${TOTAL}"
echo "  - Replied: ${REPLIED}"
echo "  - Not interested: ${NOT_INTERESTED}"
echo "  - No response (→ in_sequence): ${NO_RESPONSE}"
echo "Skipped (sem status): ${SKIPPED}"
echo "=========================================="
echo ""

# Sugestão de limpeza
if [ $TOTAL -gt 0 ]; then
    echo "NOTA: Considere limpar as linhas processadas da Review_Queue"
    echo "      ou mover para uma aba de histórico."
fi

echo "Sync completo!"

#!/bin/bash
# ==============================================
# 00 — TEST SETUP: Validar APIs + Criar lead seed
# Roda isso primeiro antes de qualquer teste
# ==============================================

set -e

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "🧪 OUTBOUND ENGINE — TEST SETUP"
echo "=========================================="

# Credenciais
export CRM_BASE_URL="https://peegicizxybjgvuutegc.supabase.co/functions/v1/crm-api"
export CRM_API_KEY="ks_live_3f0bc6b76a5c2a7f6a15253c48964d8cc57d38e27e7946ff"
export RESEND_API_KEY="re_S6Tozy3R_HzgipbWQfbcHHnwCx1oabqsE"
export APOLLO_API_KEY="I2SbTXya07FoSSg5enheoA"
export GOOGLE_SHEETS_ID="1fVXMVvbhzahwKhsBTZTUrbHSYffZ1R3uQQskGb0mHbA"
export GOOGLE_SHEETS_API_KEY="AIzaSyDDTGKRUuibxHFXPHl1ja7eRdPaUI6qGhc"

echo ""
echo "1️⃣  Testando CRM API..."
CRM_RESULT=$(curl -s -w "\n%{http_code}" -X GET "${CRM_BASE_URL}/v1/contacts?per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json")
CRM_CODE=$(echo "$CRM_RESULT" | tail -1)
CRM_BODY=$(echo "$CRM_RESULT" | head -n -1)

if [ "$CRM_CODE" -ge 200 ] && [ "$CRM_CODE" -lt 300 ]; then
  echo -e "   ${GREEN}✅ CRM API OK (HTTP $CRM_CODE)${NC}"
  echo "   Response preview: $(echo $CRM_BODY | head -c 200)"
else
  echo -e "   ${RED}❌ CRM API ERRO (HTTP $CRM_CODE)${NC}"
  echo "   $CRM_BODY"
  exit 1
fi

echo ""
echo "2️⃣  Testando Resend API..."
RESEND_RESULT=$(curl -s -w "\n%{http_code}" -X GET "https://api.resend.com/domains" \
  -H "Authorization: Bearer ${RESEND_API_KEY}")
RESEND_CODE=$(echo "$RESEND_RESULT" | tail -1)
RESEND_BODY=$(echo "$RESEND_RESULT" | head -n -1)

if [ "$RESEND_CODE" -ge 200 ] && [ "$RESEND_CODE" -lt 300 ]; then
  echo -e "   ${GREEN}✅ Resend API OK (HTTP $RESEND_CODE)${NC}"
  echo "   Domains: $(echo $RESEND_BODY | head -c 200)"
else
  echo -e "   ${RED}❌ Resend API ERRO (HTTP $RESEND_CODE)${NC}"
  echo "   $RESEND_BODY"
fi

echo ""
echo "3️⃣  Testando Google Sheets API..."
SHEETS_RESULT=$(curl -s -w "\n%{http_code}" \
  "https://sheets.googleapis.com/v4/spreadsheets/${GOOGLE_SHEETS_ID}?key=${GOOGLE_SHEETS_API_KEY}&fields=sheets.properties.title")
SHEETS_CODE=$(echo "$SHEETS_RESULT" | tail -1)
SHEETS_BODY=$(echo "$SHEETS_RESULT" | head -n -1)

if [ "$SHEETS_CODE" -ge 200 ] && [ "$SHEETS_CODE" -lt 300 ]; then
  echo -e "   ${GREEN}✅ Google Sheets API OK (HTTP $SHEETS_CODE)${NC}"
  echo "   Abas: $(echo $SHEETS_BODY | head -c 300)"
else
  echo -e "   ${YELLOW}⚠️  Google Sheets (HTTP $SHEETS_CODE) — pode precisar criar as abas${NC}"
  echo "   $SHEETS_BODY"
fi

echo ""
echo "4️⃣  Testando Apollo API..."
APOLLO_RESULT=$(curl -s -w "\n%{http_code}" -X POST "https://api.apollo.io/api/v1/people/match" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: ${APOLLO_API_KEY}" \
  -d '{"first_name": "Test", "last_name": "User"}')
APOLLO_CODE=$(echo "$APOLLO_RESULT" | tail -1)

if [ "$APOLLO_CODE" -ge 200 ] && [ "$APOLLO_CODE" -lt 300 ]; then
  echo -e "   ${GREEN}✅ Apollo API OK (HTTP $APOLLO_CODE)${NC}"
else
  echo -e "   ${YELLOW}⚠️  Apollo API (HTTP $APOLLO_CODE)${NC}"
fi

echo ""
echo "=========================================="
echo "5️⃣  Criando LEADS DE TESTE no CRM..."
echo "=========================================="

# Lead de teste 1 — KOSMOS (criador de conteúdo fake mas com seu email)
echo ""
echo "   Criando lead teste KOSMOS..."
LEAD1=$(curl -s -w "\n%{http_code}" -X POST "${CRM_BASE_URL}/v1/contacts" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "viniciusoliveirap98@gmail.com",
    "full_name": "Teste Motor KOSMOS",
    "phone": "+5511999999999",
    "instagram": "teste_motor_kosmos",
    "tenant": "kosmos",
    "channel_in": "scraper",
    "source": "outbound",
    "source_detail": {
      "followers_count": 15000,
      "is_business": true,
      "bio": "🚀 Mentor de negócios digitais | Criador do Método X | +500 alunos | Curso de marketing digital | Link na bio 👇",
      "external_url": "https://linktr.ee/testemotor"
    }
  }')
LEAD1_CODE=$(echo "$LEAD1" | tail -1)
LEAD1_BODY=$(echo "$LEAD1" | head -n -1)

if [ "$LEAD1_CODE" -ge 200 ] && [ "$LEAD1_CODE" -lt 300 ]; then
  LEAD1_ID=$(echo "$LEAD1_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('contact_org_id', d.get('data',{}).get('id','???'))))" 2>/dev/null || echo "check_response")
  echo -e "   ${GREEN}✅ Lead KOSMOS criado (HTTP $LEAD1_CODE)${NC}"
  echo "   ID: $LEAD1_ID"
  echo "   Response: $(echo $LEAD1_BODY | head -c 300)"
else
  echo -e "   ${RED}❌ Erro ao criar lead KOSMOS (HTTP $LEAD1_CODE)${NC}"
  echo "   $LEAD1_BODY"
fi

# Lead de teste 2 — Oliveira Dev (B2B)
echo ""
echo "   Criando lead teste OLIVEIRA-DEV..."
LEAD2=$(curl -s -w "\n%{http_code}" -X POST "${CRM_BASE_URL}/v1/contacts" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "viniciusoliveirap98@gmail.com",
    "full_name": "Teste Motor OliveiraDev",
    "phone": "+5511988888888",
    "instagram": "teste_motor_oliveira",
    "tenant": "oliveira-dev",
    "channel_in": "scraper",
    "source": "outbound",
    "source_detail": {
      "followers_count": 3000,
      "is_business": true,
      "bio": "Construtora Silva & Associados | Engenharia civil | Gestão de obras | 20 anos no mercado | CNPJ ativo",
      "external_url": "https://construtorasilva.com.br"
    }
  }')
LEAD2_CODE=$(echo "$LEAD2" | tail -1)
LEAD2_BODY=$(echo "$LEAD2" | head -n -1)

if [ "$LEAD2_CODE" -ge 200 ] && [ "$LEAD2_CODE" -lt 300 ]; then
  LEAD2_ID=$(echo "$LEAD2_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('contact_org_id', d.get('data',{}).get('id','???'))))" 2>/dev/null || echo "check_response")
  echo -e "   ${GREEN}✅ Lead Oliveira-Dev criado (HTTP $LEAD2_CODE)${NC}"
  echo "   ID: $LEAD2_ID"
  echo "   Response: $(echo $LEAD2_BODY | head -c 300)"
else
  echo -e "   ${RED}❌ Erro ao criar lead Oliveira-Dev (HTTP $LEAD2_CODE)${NC}"
  echo "   $LEAD2_BODY"
fi

# Lead de teste 3 — Lead fraco (deve ser C)
echo ""
echo "   Criando lead teste FRACO (deve ser C)..."
LEAD3=$(curl -s -w "\n%{http_code}" -X POST "${CRM_BASE_URL}/v1/contacts" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "viniciusoliveirap98@gmail.com",
    "full_name": "Teste Motor Fraco",
    "instagram": "teste_motor_fraco",
    "tenant": "kosmos",
    "channel_in": "scraper",
    "source": "outbound",
    "source_detail": {
      "followers_count": 200,
      "is_business": false,
      "bio": "Amante de gatos 🐱 | Viagens ✈️",
      "external_url": null
    }
  }')
LEAD3_CODE=$(echo "$LEAD3" | tail -1)

if [ "$LEAD3_CODE" -ge 200 ] && [ "$LEAD3_CODE" -lt 300 ]; then
  echo -e "   ${GREEN}✅ Lead fraco criado (HTTP $LEAD3_CODE) — deve virar C no scoring${NC}"
else
  echo -e "   ${RED}❌ Erro (HTTP $LEAD3_CODE)${NC}"
fi

echo ""
echo "=========================================="
echo "✅ SETUP COMPLETO!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo "  1. Verifique os IDs dos leads criados acima"
echo "  2. No CRM, confirme que cadence_status = 'new'"
echo "  3. Rode: claude -p \"\$(cat m2-icp-scoring.md)\" pra testar scoring"
echo ""
echo "Leads de teste:"
echo "  KOSMOS:      viniciusoliveirap98@gmail.com / @teste_motor_kosmos"
echo "  OLIVEIRA:    viniciusoliveirap98@gmail.com / @teste_motor_oliveira"
echo "  FRACO:       viniciusoliveirap98@gmail.com / @teste_motor_fraco"
echo ""

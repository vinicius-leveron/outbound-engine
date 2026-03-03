#!/bin/bash
# ==============================================
# TEST SCRAPING E2E — Fluxo completo C1 ate M4
#
# Testa o pipeline de scraping com 1 lead por tenant,
# sem enviar email e sem Snov.io.
#
# Pipeline:
#   KOSMOS:         C1-lead-scraper -> M2 -> [advance] -> M4 -> STOP
#   ADVOCACIA-TECH: C1-discovery -> C1-web-enrich -> C1-decision-maker -> M2 -> [advance] -> M4 -> STOP
#
# Uso: bash tests/test-scraping-e2e.sh
# ==============================================

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULES_DIR="$BASE_DIR/modules"
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/e2e_c1_test_$(date +%Y-%m-%d_%H%M%S).log"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Contadores
STEPS_TOTAL=0
STEPS_OK=0
STEPS_FAIL=0

log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

header() {
  log ""
  log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  log "${BOLD}  $1${NC}"
  log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  log ""
}

step_ok() {
  STEPS_TOTAL=$((STEPS_TOTAL + 1))
  STEPS_OK=$((STEPS_OK + 1))
  log "${GREEN}  OK: $1${NC}"
}

step_fail() {
  STEPS_TOTAL=$((STEPS_TOTAL + 1))
  STEPS_FAIL=$((STEPS_FAIL + 1))
  log "${RED}  FAIL: $1${NC}"
}

checkpoint() {
  log ""
  log "${YELLOW}  Verifique: $1${NC}"
  log ""
  read -p "  Resultado OK? Prosseguir? (s/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log "${RED}Abortado pelo usuario.${NC}"
    exit 0
  fi
}

# Funcao para rodar modulo com override de teste
run_module() {
  local name=$1
  local prompt_file=$2
  local override_text=$3

  log "  Rodando: ${BOLD}$name${NC}"
  log "  Prompt: $prompt_file"
  log "  Inicio: $(date '+%Y-%m-%d %H:%M:%S')"
  log ""

  if [ ! -f "$prompt_file" ]; then
    step_fail "$name — prompt nao encontrado: $prompt_file"
    return 1
  fi

  local prompt_content
  prompt_content="$(cat "$prompt_file")"

  # Append test override
  local full_prompt="${prompt_content}

---
## OVERRIDE DE TESTE E2E (OBRIGATORIO)
${override_text}
---
Execute agora."

  claude -p "$full_prompt" \
    --allowedTools 'Bash(curl*)' 'Bash(jq*)' 'Bash(sleep*)' 'Bash(date*)' 'Bash(echo*)' 'Bash(cat*)' 'Bash(mkdir*)' \
    --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

  local exit_code=${PIPESTATUS[0]}
  log ""
  log "  Fim: $(date '+%Y-%m-%d %H:%M:%S')"

  if [ $exit_code -eq 0 ]; then
    step_ok "$name concluido"
  else
    step_fail "$name falhou (exit code: $exit_code)"
  fi

  return $exit_code
}

# Funcao para verificar leads no CRM
verify_crm() {
  local description=$1
  local query_params=$2

  local response
  response=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts?${query_params}" \
    -H "Authorization: Bearer ${CRM_API_KEY}" \
    -H "Content-Type: application/json" 2>/dev/null)

  local total
  total=$(echo "$response" | jq -r '.meta.total // 0' 2>/dev/null)

  if [ "$total" -gt 0 ] 2>/dev/null; then
    step_ok "$description — $total lead(s) encontrado(s)"
    echo "$response" | jq -r '.data[]? | "    - \(.organization_name // .full_name // .instagram // "N/A") | status: \(.cadence_status) | tenant: \(.tenant)"' 2>/dev/null | head -5 | tee -a "$LOG_FILE"
  else
    step_fail "$description — 0 leads"
    log "  Response: $(echo "$response" | head -c 300)"
  fi

  echo "$response"
}

# ==========================================
# ETAPA 0: PRE-FLIGHT
# ==========================================
header "ETAPA 0: PRE-FLIGHT"

log "Log file: $LOG_FILE"
log ""

# Carregar .env
ENV_LOADED=false
for env_path in "$BASE_DIR/.env" "/root/outbound-engine/.env" "/home/outbound/outbound-engine/.env"; do
  if [ -f "$env_path" ]; then
    set -a
    source "$env_path"
    set +a
    log "${GREEN}  .env carregado de: $env_path${NC}"
    ENV_LOADED=true
    break
  fi
done

if [ "$ENV_LOADED" = false ]; then
  log "${YELLOW}  .env nao encontrado. Usando credenciais do test-setup...${NC}"
  # Fallback: credenciais de teste do 00-test-setup.sh
  export CRM_BASE_URL="https://peegicizxybjgvuutegc.supabase.co/functions/v1/crm-api"
  export CRM_API_KEY="ks_live_3f0bc6b76a5c2a7f6a15253c48964d8cc57d38e27e7946ff"
fi

# Validar CRM
log ""
log "  Validando CRM API..."
CRM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${CRM_BASE_URL}/v1/contacts?per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" 2>/dev/null)

if [ "$CRM_STATUS" -ge 200 ] && [ "$CRM_STATUS" -lt 300 ] 2>/dev/null; then
  step_ok "CRM API (HTTP $CRM_STATUS)"
else
  step_fail "CRM API (HTTP $CRM_STATUS)"
  log "${RED}  CRM inacessivel. Abortando.${NC}"
  exit 1
fi

# Validar Apify
log "  Validando Apify API..."
if [ -n "$APIFY_TOKEN" ] && [ "$APIFY_TOKEN" != "<SUBSTITUIR>" ]; then
  APIFY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://api.apify.com/v2/user/me?token=${APIFY_TOKEN}" 2>/dev/null)
  if [ "$APIFY_STATUS" = "200" ]; then
    step_ok "Apify API (HTTP $APIFY_STATUS)"
  else
    step_fail "Apify API (HTTP $APIFY_STATUS)"
    log "${RED}  Apify inacessivel. C1 modules precisam do Apify.${NC}"
    exit 1
  fi
else
  step_fail "APIFY_TOKEN nao configurado"
  log "${RED}  Configure APIFY_TOKEN no .env antes de rodar este teste.${NC}"
  exit 1
fi

# Resumo do teste
log ""
log "${BOLD}  Este teste vai:${NC}"
log "    1. C1-lead-scraper: scrape 1 lead KOSMOS via Ad Library (Apify)"
log "    2. C1-discovery: scrape 1 escritorio ADVOCACIA-TECH via Google Maps (Apify)"
log "    3. C1-web-enrich: enriquecer website do escritorio (Apify)"
log "    4. C1-decision-maker: identificar decisor (SEM Snov.io)"
log "    5. M2: classificar ambos os leads (scoring)"
log "    6. Avancar manual: enriching -> ready (pula M3/T15)"
log "    7. M4: gerar copy de cadencia (SEM escrever no Sheets)"
log ""
log "${YELLOW}  Custo estimado: ~\$1-3 (Apify actors com 1 resultado cada)${NC}"
log "${GREEN}  Nenhum email sera enviado. Nenhuma DM sera enfileirada.${NC}"
log ""

read -p "  Iniciar teste E2E? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  log "Cancelado."
  exit 0
fi


# ==========================================
# ETAPA 1: C1-LEAD-SCRAPER (KOSMOS) — 1 lead
# ==========================================
header "ETAPA 1: C1-LEAD-SCRAPER (kosmos) — 1 lead"

run_module "C1-Lead-Scraper" "$MODULES_DIR/c1-lead-scraper/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Usar APENAS fonte ad_library (desabilitar following e speakers)
- Na Ad Library, usar max_results=1 (MAXIMO 1 resultado do Apify actor)
- Processar MAXIMO 1 handle no total
- Se nenhum handle qualificado, relaxar filtros de bio e followers para aceitar o primeiro resultado
- Executar fluxo completo: coletar -> enriquecer perfil -> filtrar -> salvar no CRM
- No relatorio, incluir '[E2E-TEST]' no titulo
- tenant = kosmos, cadence_status = new"

checkpoint "CRM: 1 lead kosmos com cadence_status=new"

log "  Verificando CRM..."
verify_crm "Leads kosmos novos" "cadence_status=new&tenant=kosmos&per_page=5" > /dev/null


# ==========================================
# ETAPA 2: C1-DISCOVERY (ADVOCACIA-TECH) — 1 lead
# ==========================================
header "ETAPA 2: C1-DISCOVERY (advocacia-tech) — 1 escritorio"

run_module "C1-Discovery" "$MODULES_DIR/c1-discovery/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Usar maxCrawledPlacesPerSearch=1 no Apify actor (MAXIMO 1 resultado)
- Processar MAXIMO 1 escritorio
- Se resultado nao passar nos filtros, relaxar para aceitar o primeiro resultado com website
- Executar fluxo completo: buscar -> filtrar -> deduplicar -> salvar no CRM
- No relatorio, incluir '[E2E-TEST]' no titulo
- tenant = advocacia-tech, cadence_status = discovered"

checkpoint "CRM: 1 lead advocacia-tech com cadence_status=discovered"

log "  Verificando CRM..."
verify_crm "Leads advocacia-tech discovered" "cadence_status=discovered&tenant=advocacia-tech&per_page=5" > /dev/null


# ==========================================
# ETAPA 3: C1-WEB-ENRICH (ADVOCACIA-TECH) — 1 lead
# ==========================================
header "ETAPA 3: C1-WEB-ENRICH (advocacia-tech) — enriquecer 1 escritorio"

run_module "C1-Web-Enrich" "$MODULES_DIR/c1-web-enrich/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Usar per_page=1 na busca do CRM (MAXIMO 1 escritorio)
- Processar MAXIMO 1 escritorio
- Manter maxCrawlPages=10 no Website Content Crawler
- Executar fluxo completo: buscar -> crawl website -> analisar -> salvar no CRM
- No relatorio, incluir '[E2E-TEST]' no titulo
- Avancar cadence_status para web_enriched"

checkpoint "CRM: lead advocacia-tech com cadence_status=web_enriched"

log "  Verificando CRM..."
verify_crm "Leads advocacia-tech web_enriched" "cadence_status=web_enriched&tenant=advocacia-tech&per_page=5" > /dev/null


# ==========================================
# ETAPA 4: C1-DECISION-MAKER (ADVOCACIA-TECH, SEM SNOV.IO) — 1 lead
# ==========================================
header "ETAPA 4: C1-DECISION-MAKER (advocacia-tech, sem Snov.io) — 1 escritorio"

run_module "C1-Decision-Maker" "$MODULES_DIR/c1-decision-maker/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Usar per_page=1 na busca do CRM (MAXIMO 1 escritorio)
- Processar MAXIMO 1 escritorio
- NAO USAR Snov.io (pular STEPs 3 e 4 do prompt original)
- Para email do decisor, usar FALLBACK:
  1. Se tem email no site (team_members[].email) -> usar esse
  2. Se nao, gerar pattern: nome.sobrenome@dominio.com.br
  3. Ultimo recurso: contato@dominio.com.br
- Marcar email_source como 'website' ou 'pattern_fallback'
- Executar restante do fluxo normalmente
- No relatorio, incluir '[E2E-TEST]' no titulo
- Avancar cadence_status para dm_identified"

checkpoint "CRM: lead advocacia-tech com cadence_status=dm_identified e decision_maker preenchido"

log "  Verificando CRM..."
verify_crm "Leads advocacia-tech dm_identified" "cadence_status=dm_identified&tenant=advocacia-tech&per_page=5" > /dev/null


# ==========================================
# ETAPA 5: M2 ICP SCORING — ambos tenants
# ==========================================
header "ETAPA 5: M2 ICP SCORING — ambos tenants"

run_module "M2-ICP-Scoring" "$MODULES_DIR/m2-icp-scoring/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Processar MAXIMO 5 leads no total (per_page=5)
- Buscar leads de TODOS os tenants:
  * cadence_status=new (kosmos, oliveira-dev)
  * cadence_status=dm_identified&tenant=advocacia-tech
- Executar scoring normalmente para cada tenant
- Para fins de teste, se lead tiver dados insuficientes, ainda assim classificar (nao pular)
- No relatorio, incluir '[E2E-TEST]' no titulo"

checkpoint "CRM: leads com cadence_status=enriching (A/B) ou archived (C)"

log "  Verificando CRM..."
verify_crm "Leads enriching" "cadence_status=enriching&per_page=10" > /dev/null


# ==========================================
# ETAPA 6: ADVANCE MANUAL (pular M3/T15)
# ==========================================
header "ETAPA 6: ADVANCE MANUAL — enriching -> ready (pula M3/T15)"

log "  Buscando leads em 'enriching' para avancar manualmente..."
ENRICHING_RESPONSE=$(curl -s -X GET "${CRM_BASE_URL}/v1/contacts?cadence_status=enriching&per_page=10" \
  -H "Authorization: Bearer ${CRM_API_KEY}" \
  -H "Content-Type: application/json")

ENRICHING_IDS=$(echo "$ENRICHING_RESPONSE" | jq -r '.data[]?.contact_org_id // empty' 2>/dev/null)

if [ -z "$ENRICHING_IDS" ]; then
  step_fail "Nenhum lead em 'enriching' encontrado"
  log "${YELLOW}  Se os leads foram classificados como C (archived), o teste de M4 sera pulado.${NC}"
  log "${YELLOW}  Verifique o relatorio do M2 acima.${NC}"
  checkpoint "Deseja continuar mesmo assim?"
else
  ADVANCED_COUNT=0
  for LEAD_ID in $ENRICHING_IDS; do
    log "  Avancando lead $LEAD_ID: enriching -> ready"
    PATCH_RESULT=$(curl -s -w "\n%{http_code}" -X PATCH "${CRM_BASE_URL}/v1/contacts/${LEAD_ID}/cadence" \
      -H "Authorization: Bearer ${CRM_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"cadence_status": "ready"}')
    PATCH_CODE=$(echo "$PATCH_RESULT" | tail -1)

    if [ "$PATCH_CODE" -ge 200 ] && [ "$PATCH_CODE" -lt 300 ] 2>/dev/null; then
      step_ok "Lead $LEAD_ID avancado para 'ready'"
      ADVANCED_COUNT=$((ADVANCED_COUNT + 1))
    else
      step_fail "Falha ao avancar lead $LEAD_ID (HTTP $PATCH_CODE)"
    fi
  done

  log ""
  log "  ${GREEN}$ADVANCED_COUNT lead(s) avancado(s) para 'ready'${NC}"
fi

log "  Verificando CRM..."
verify_crm "Leads ready" "cadence_status=ready&per_page=10" > /dev/null

checkpoint "Leads avancados para 'ready'. Prosseguir para M4?"


# ==========================================
# ETAPA 7: M4 CADENCE ORCHESTRATOR — gera copy (SEM Sheets)
# ==========================================
header "ETAPA 7: M4 CADENCE ORCHESTRATOR — gerar copy (SEM escrever no Sheets)"

run_module "M4-Cadence" "$MODULES_DIR/m4-cadence-orchestrator/prompt.md" \
"MODO DE TESTE E2E — LIMITES OBRIGATORIOS:
- Processar MAXIMO 5 leads (per_page=5)
- Buscar leads com cadence_status=ready
- Gerar copy personalizada normalmente (email cold, DM opener conforme o step)
- *** NAO ESCREVER NO GOOGLE SHEETS ***
  - PULAR completamente o STEP 4.2 (append no Sheets)
  - PULAR a verificacao de duplicata no Sheets (STEP 4.1)
- APENAS:
  1. Decidir o step e canal para cada lead
  2. Gerar a copy personalizada
  3. Atualizar cadence_status no CRM para 'queued'
  4. Atualizar cadence_step no CRM
  5. Logar atividade no CRM
- MOSTRAR a copy gerada no relatorio (para revisao manual)
- No relatorio, incluir '[E2E-TEST]' no titulo
- IMPORTANTE: Isto e um teste. Nenhum email ou DM sera enviado."

checkpoint "CRM: leads com cadence_status=queued. Copy gerada no relatorio acima."

log "  Verificando CRM..."
verify_crm "Leads queued" "cadence_status=queued&per_page=10" > /dev/null


# ==========================================
# ETAPA 8: RELATORIO FINAL
# ==========================================
header "RELATORIO FINAL"

log "${BOLD}  =====================================${NC}"
log "${BOLD}  E2E SCRAPING TEST — RESULTADO${NC}"
log "${BOLD}  =====================================${NC}"
log "  Data: $(date '+%Y-%m-%d %H:%M:%S')"
log "  Log: $LOG_FILE"
log ""
log "  Steps executados: $STEPS_TOTAL"
log "  ${GREEN}OK: $STEPS_OK${NC}"
log "  ${RED}Fail: $STEPS_FAIL${NC}"
log ""

# Resumo por tenant
log "${BOLD}  KOSMOS:${NC}"
KOSMOS_NEW=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=new&tenant=kosmos&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
KOSMOS_ENRICHING=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=enriching&tenant=kosmos&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
KOSMOS_READY=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=ready&tenant=kosmos&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
KOSMOS_QUEUED=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=queued&tenant=kosmos&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
log "    new: $KOSMOS_NEW | enriching: $KOSMOS_ENRICHING | ready: $KOSMOS_READY | queued: $KOSMOS_QUEUED"

log ""
log "${BOLD}  ADVOCACIA-TECH:${NC}"
ADV_DISC=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=discovered&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
ADV_WEB=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=web_enriched&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
ADV_DM=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=dm_identified&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
ADV_ENRICHING=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=enriching&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
ADV_READY=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=ready&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
ADV_QUEUED=$(curl -s "${CRM_BASE_URL}/v1/contacts?cadence_status=queued&tenant=advocacia-tech&per_page=1" \
  -H "Authorization: Bearer ${CRM_API_KEY}" | jq -r '.meta.total // 0' 2>/dev/null)
log "    discovered: $ADV_DISC | web_enriched: $ADV_WEB | dm_identified: $ADV_DM"
log "    enriching: $ADV_ENRICHING | ready: $ADV_READY | queued: $ADV_QUEUED"

log ""
log "${GREEN}  Nenhum email foi enviado.${NC}"
log "${GREEN}  Nenhuma DM foi enfileirada.${NC}"
log "${GREEN}  Google Sheets NAO foi modificado.${NC}"
log ""
log "${BOLD}  =====================================${NC}"

if [ $STEPS_FAIL -eq 0 ]; then
  log "${GREEN}  TESTE E2E COMPLETO — TODOS OS STEPS OK${NC}"
else
  log "${YELLOW}  TESTE E2E COMPLETO — $STEPS_FAIL STEP(S) COM FALHA${NC}"
fi

log "${BOLD}  =====================================${NC}"
log ""
log "  Cleanup (opcional):"
log "    Para arquivar leads de teste:"
log "    curl -X PATCH \"\${CRM_BASE_URL}/v1/contacts/LEAD_ID/cadence\" -d '{\"cadence_status\": \"archived\"}'"
log ""

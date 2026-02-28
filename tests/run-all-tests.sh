#!/bin/bash
# ==============================================
# RUN ALL TESTS — Roda o motor completo em modo teste
#
# Uso: bash run-all-tests.sh
#
# Sequência:
#   1. Setup (validar APIs + criar leads teste)
#   2. M2 — ICP Scoring (classifica os leads)
#   3. M3 — Enrichment (busca email/phone)
#   4. M8 — Axiom (inicia social selling no Sheets)
#   5. M4 — Cadence (decide próximo step)
#   6. M5a — Email (envia email de teste pra você)
#   7. M5b — DM Dispatcher (enfileira DM no Sheets)
#   8. M6 — Event Tracker (checa eventos)
#   9. M9 — Domain Guard (checa reputação)
#   10. C3 — Daily Briefing
# ==============================================

set -e

MODULES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔══════════════════════════════════════════╗"
echo "║  🧪 OUTBOUND ENGINE — FULL TEST RUN     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Função pra rodar módulo via claude -p
run_module() {
  local module_name=$1
  local module_file=$2
  local description=$3

  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  🔄 $module_name — $description${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if [ ! -f "$MODULES_DIR/$module_file" ]; then
    echo -e "${RED}❌ Arquivo não encontrado: $MODULES_DIR/$module_file${NC}"
    return 1
  fi

  echo "Rodando: claude -p \"\$(cat $module_file)\""
  echo "Início: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # Roda o módulo via claude -p
  claude -p "$(cat "$MODULES_DIR/$module_file")" 2>&1

  local exit_code=$?
  echo ""
  echo "Fim: $(date '+%Y-%m-%d %H:%M:%S')"

  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ $module_name concluído${NC}"
  else
    echo -e "${RED}❌ $module_name falhou (exit code: $exit_code)${NC}"
  fi

  return $exit_code
}

# Pedir confirmação
echo "Este script vai:"
echo "  1. Criar 3 leads de teste no CRM (com seu email)"
echo "  2. Rodar M2 pra classificar (A, B, C)"
echo "  3. Rodar M3 pra enriquecer via Apollo"
echo "  4. Rodar M8 pra iniciar social selling no Sheets"
echo "  5. Rodar M4 pra decidir cadência"
echo "  6. Rodar M5a pra enviar email DE TESTE pro seu email"
echo "  7. Rodar M5b pra enfileirar DM no Sheets"
echo "  8. Rodar M6, M9, C3 (monitoring)"
echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO: Vai enviar 1 email real pra viniciusoliveirap98@gmail.com${NC}"
echo ""
read -p "Continuar? (s/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  echo "Cancelado."
  exit 0
fi

# ==========================================
# STEP 0: Setup
# ==========================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📦 STEP 0: Setup — Validar APIs + Criar leads${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
bash "$TESTS_DIR/00-test-setup.sh"

echo ""
read -p "APIs OK e leads criados? Prosseguir? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 1: M2 — ICP Scoring
# ==========================================
run_module "M2" "m2-icp-scoring.md" "ICP Scoring dos leads de teste"

echo ""
echo "Verifique no CRM:"
echo "  - Lead KOSMOS deve ser A (score ~90+)"
echo "  - Lead Oliveira deve ser A (score ~80+)"
echo "  - Lead Fraco deve ser C (score <30)"
echo "  - cadence_status deve ter mudado pra 'enriching' (A/B) e 'archived' (C)"
echo ""
read -p "Resultados OK? Prosseguir? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 2: M3 — Enrichment
# ==========================================
run_module "M3" "m3-enrichment.md" "Enrichment via Apollo"

echo ""
echo "Verifique no CRM:"
echo "  - Leads A/B devem estar com cadence_status = 'ready'"
echo "  - Apollo pode ter encontrado dados (ou não, são leads fake)"
echo ""
read -p "Prosseguir pra M8 (social selling)? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 3: M8 — Axiom Social Selling
# ==========================================
run_module "M8" "m8-axiom-orchestrator.md" "Social Selling — iniciar cadência no Sheets"

echo ""
echo "Verifique:"
echo "  - Google Sheets: abas Follow, Like_Post, Controle com dados"
echo "  - CRM: axiom_status = 'warm_up' nos leads KOSMOS"
echo ""
read -p "Prosseguir pra M4 (cadência outbound)? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 4: M4 — Cadence Orchestrator
# ==========================================
run_module "M4" "m4-cadence-orchestrator.md" "Decidir cadência e gerar mensagens"

echo ""
echo "Verifique no CRM:"
echo "  - cadence_status = 'queued'"
echo "  - custom_fields tem next_channel, next_message, next_subject"
echo ""
read -p "Prosseguir pra M5a (enviar email)? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 5: M5a — Email Sender
# ==========================================
echo -e "${YELLOW}⚠️  Vai enviar email real pra viniciusoliveirap98@gmail.com${NC}"
run_module "M5a" "m5a-email-sender.md" "Enviar email de teste"

echo ""
echo "Verifique:"
echo "  - Email chegou na sua inbox (viniciusoliveirap98@gmail.com)"
echo "  - cadence_status = 'in_sequence'"
echo ""
read -p "Prosseguir pra M5b (DM no Sheets)? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 6: M5b — DM Dispatcher
# ==========================================
run_module "M5b" "m5b-dm-dispatcher.md" "Enfileirar DM no Sheets"

echo ""
echo "Verifique Google Sheets aba DM_Queue"
echo ""
read -p "Prosseguir pra módulos de monitoring? (s/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 0; fi

# ==========================================
# STEP 7: M6 — Event Tracker
# ==========================================
run_module "M6" "m6-event-tracker.md" "Checar eventos de email e DMs"

# ==========================================
# STEP 8: M9 — Domain Guard
# ==========================================
run_module "M9" "m9-domain-guard.md" "Checar reputação do domínio"

# ==========================================
# STEP 9: C3 — Daily Briefing
# ==========================================
run_module "C3" "c3-daily-briefing.md" "Gerar briefing diário"

# ==========================================
# FIM
# ==========================================
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ FULL TEST RUN COMPLETO!             ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Logs salvos em /tmp/m*_report_*.log e /tmp/c3_briefing_*.log"
echo ""
echo "Se tudo funcionou, próximo passo é configurar o cron."
echo "Rode: bash engine.sh cron-install"
echo ""

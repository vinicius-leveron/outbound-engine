#!/bin/bash
# ===========================================
# C1 LEAD SCRAPER — Runner Script
# ===========================================
# Uso:
#   ./run.sh --mode full        # Todas as fontes
#   ./run.sh --mode incremental # So Ad Library
#   ./run.sh --mode dry-run     # Teste sem APIs
# ===========================================

set -e

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${MODULE_DIR}/logs/c1_$(date +%Y-%m-%d_%H%M%S).log"

# Parse args
MODE="full"
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

echo "======================================"
echo "C1 LEAD SCRAPER"
echo "======================================"
echo "Data: $(date)"
echo "Modo: ${MODE}"
echo "Log: ${LOG_FILE}"
echo "======================================"

# Carregar .env
if [ -f /home/outbound/outbound-engine/.env ]; then
  source /home/outbound/outbound-engine/.env
elif [ -f /root/outbound-engine/.env ]; then
  source /root/outbound-engine/.env
else
  echo "ERRO: .env nao encontrado"
  exit 1
fi

# Verificar dependencias
if [ -z "$APIFY_TOKEN" ]; then
  echo "ERRO: APIFY_TOKEN nao configurado"
  exit 1
fi

if [ -z "$CRM_API_KEY" ]; then
  echo "ERRO: CRM_API_KEY nao configurado"
  exit 1
fi

# Criar diretorios se nao existem
mkdir -p "${MODULE_DIR}/data/raw"
mkdir -p "${MODULE_DIR}/data/merged"
mkdir -p "${MODULE_DIR}/data/enriched"
mkdir -p "${MODULE_DIR}/logs"

# Executar com Claude
claude -p "$(cat $MODULE_DIR/prompt.md)

MODO DE EXECUCAO: ${MODE}

Se modo = dry-run:
- NAO chamar Apify
- NAO escrever no CRM
- Apenas simular fluxo e reportar

Se modo = incremental:
- Apenas fonte ad_library
- Ignorar following e speakers

Se modo = full:
- Todas as fontes habilitadas no config.yaml

Execute agora." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "======================================"
echo "C1 finalizado. Log: ${LOG_FILE}"
echo "======================================"

#!/bin/bash
# ===========================================
# C1 DECISION-MAKER — Runner Script
# ===========================================
# Identifica decisores e busca emails via Snov.io
# ===========================================

set -e

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${MODULE_DIR}/logs/c1-decision-maker_$(date +%Y-%m-%d_%H%M%S).log"

echo "======================================"
echo "C1 DECISION-MAKER (advocacia-tech)"
echo "======================================"
echo "Data: $(date)"
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
if [ -z "$CRM_API_KEY" ]; then
  echo "ERRO: CRM_API_KEY nao configurado"
  exit 1
fi

# Snov.io opcional (pode usar fallback)
if [ -z "$SNOV_CLIENT_ID" ] || [ -z "$SNOV_CLIENT_SECRET" ]; then
  echo "AVISO: Snov.io nao configurado - usando fallback de email"
fi

# Criar diretorios
mkdir -p "${MODULE_DIR}/data"
mkdir -p "${MODULE_DIR}/logs"

# Executar com Claude
claude -p "$(cat $MODULE_DIR/prompt.md)

Execute agora." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "======================================"
echo "C1-Decision-Maker finalizado. Log: ${LOG_FILE}"
echo "======================================"

#!/bin/bash
# ===========================================
# C1 WEB-ENRICH — Runner Script
# ===========================================
# Enriquece escritorios com dados do website
# ===========================================

set -e

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${MODULE_DIR}/logs/c1-web-enrich_$(date +%Y-%m-%d_%H%M%S).log"

echo "======================================"
echo "C1 WEB-ENRICH (advocacia-tech)"
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
if [ -z "$APIFY_TOKEN" ]; then
  echo "ERRO: APIFY_TOKEN nao configurado"
  exit 1
fi

if [ -z "$CRM_API_KEY" ]; then
  echo "ERRO: CRM_API_KEY nao configurado"
  exit 1
fi

# Criar diretorios
mkdir -p "${MODULE_DIR}/data"
mkdir -p "${MODULE_DIR}/logs"

# Executar com Claude
claude -p "$(cat $MODULE_DIR/prompt.md)

Execute agora." --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "======================================"
echo "C1-Web-Enrich finalizado. Log: ${LOG_FILE}"
echo "======================================"

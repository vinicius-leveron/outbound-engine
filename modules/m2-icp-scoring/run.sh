#!/bin/bash
# m2-icp-scoring — Execução via Claude Code
# Gerado automaticamente pelo master-setup.sh

MODULE_DIR="/root/outbound-engine/modules/m2-icp-scoring"
LOG_DIR="$MODULE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
LOG_FILE="$LOG_DIR/m2-icp-scoring_${TIMESTAMP}.log"

echo "[$(date)] m2-icp-scoring — Iniciando..." | tee "$LOG_FILE"

# Carregar variáveis de ambiente
source "/root/outbound-engine/.env"

# Executar via Claude Code
claude -p "$(cat $MODULE_DIR/prompt.md)" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] m2-icp-scoring concluído com sucesso." | tee -a "$LOG_FILE"
else
    echo "[$(date)] m2-icp-scoring ERRO — exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "$LOG_DIR" -name "m2-icp-scoring_*.log" -mtime +30 -delete 2>/dev/null

echo "[$(date)] m2-icp-scoring finalizado." | tee -a "$LOG_FILE"

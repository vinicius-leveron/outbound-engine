#!/bin/bash
# c4-ad-library-benchmark — Execução via Claude Code
# Gerado automaticamente pelo master-setup.sh

MODULE_DIR="/root/outbound-engine/modules/c4-ad-library-benchmark"
LOG_DIR="$MODULE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
LOG_FILE="$LOG_DIR/c4-ad-library-benchmark_${TIMESTAMP}.log"

echo "[$(date)] c4-ad-library-benchmark — Iniciando..." | tee "$LOG_FILE"

# Carregar variáveis de ambiente
source "/root/outbound-engine/.env"

# Executar via Claude Code
claude -p "$(cat $MODULE_DIR/prompt.md)" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] c4-ad-library-benchmark concluído com sucesso." | tee -a "$LOG_FILE"
else
    echo "[$(date)] c4-ad-library-benchmark ERRO — exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "$LOG_DIR" -name "c4-ad-library-benchmark_*.log" -mtime +30 -delete 2>/dev/null

echo "[$(date)] c4-ad-library-benchmark finalizado." | tee -a "$LOG_FILE"

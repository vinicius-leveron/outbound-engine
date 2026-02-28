#!/bin/bash
# m5c-whatsapp-sender — Execução via Claude Code
# Gerado automaticamente pelo master-setup.sh

MODULE_DIR="/root/outbound-engine/modules/m5c-whatsapp-sender"
LOG_DIR="$MODULE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
LOG_FILE="$LOG_DIR/m5c-whatsapp-sender_${TIMESTAMP}.log"

echo "[$(date)] m5c-whatsapp-sender — Iniciando..." | tee "$LOG_FILE"

# Carregar variáveis de ambiente
source "/root/outbound-engine/.env"

# Executar via Claude Code
claude -p "$(cat $MODULE_DIR/prompt.md)" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] m5c-whatsapp-sender concluído com sucesso." | tee -a "$LOG_FILE"
else
    echo "[$(date)] m5c-whatsapp-sender ERRO — exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "$LOG_DIR" -name "m5c-whatsapp-sender_*.log" -mtime +30 -delete 2>/dev/null

echo "[$(date)] m5c-whatsapp-sender finalizado." | tee -a "$LOG_FILE"

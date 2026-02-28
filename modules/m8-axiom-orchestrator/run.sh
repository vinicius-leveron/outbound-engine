#!/bin/bash
# m8-axiom-orchestrator — Execução via Claude Code
# Gerado automaticamente pelo master-setup.sh

MODULE_DIR="/root/outbound-engine/modules/m8-axiom-orchestrator"
LOG_DIR="$MODULE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
LOG_FILE="$LOG_DIR/m8-axiom-orchestrator_${TIMESTAMP}.log"

echo "[$(date)] m8-axiom-orchestrator — Iniciando..." | tee "$LOG_FILE"

# Carregar variáveis de ambiente
source "/root/outbound-engine/.env"

# Executar via Claude Code
claude -p "$(cat $MODULE_DIR/prompt.md)" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] m8-axiom-orchestrator concluído com sucesso." | tee -a "$LOG_FILE"
else
    echo "[$(date)] m8-axiom-orchestrator ERRO — exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "$LOG_DIR" -name "m8-axiom-orchestrator_*.log" -mtime +30 -delete 2>/dev/null

echo "[$(date)] m8-axiom-orchestrator finalizado." | tee -a "$LOG_FILE"

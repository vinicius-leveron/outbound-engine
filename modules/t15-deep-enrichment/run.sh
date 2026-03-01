#!/bin/bash
# t15-deep-enrichment — Execução via Claude Code
# Deep Enrichment + Análise Multimodal

MODULE_DIR="/root/outbound-engine/modules/t15-deep-enrichment"
LOG_DIR="$MODULE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M)
LOG_FILE="$LOG_DIR/t15-deep-enrichment_${TIMESTAMP}.log"

# Criar diretório de logs se não existir
mkdir -p "$LOG_DIR"

echo "[$(date)] t15-deep-enrichment — Iniciando..." | tee "$LOG_FILE"

# Carregar variáveis de ambiente
source "/root/outbound-engine/.env"

# Executar via Claude Code
claude -p "$(cat $MODULE_DIR/prompt.md)" 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] t15-deep-enrichment concluído com sucesso." | tee -a "$LOG_FILE"
else
    echo "[$(date)] t15-deep-enrichment ERRO — exit code: $EXIT_CODE" | tee -a "$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "$LOG_DIR" -name "t15-deep-enrichment_*.log" -mtime +30 -delete 2>/dev/null

# Limpar imagens temporárias
rm -f /tmp/post_*.jpg 2>/dev/null

echo "[$(date)] t15-deep-enrichment finalizado." | tee -a "$LOG_FILE"

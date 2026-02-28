#!/bin/bash
# ============================================================
# MOTOR DE OUTBOUND — MASTER SETUP
# ============================================================
# Configura TODOS os 16 módulos na VPS
# Cria estrutura de diretórios, scripts de execução e cron
# ============================================================
# Autor: Vinícius Oliveira
# Versão: 3.0 (Tudo Claude)
# ============================================================

set -e

BASE_DIR="$HOME/outbound-engine"
MODULES_DIR="$BASE_DIR/modules"
LOGS_DIR="$BASE_DIR/logs"
ENV_FILE="$BASE_DIR/.env"

echo "============================================================"
echo "  MOTOR DE OUTBOUND — Setup Completo"
echo "============================================================"
echo ""

# --- Criar estrutura ---
echo "📁 Criando estrutura de diretórios..."

MODULES=(
  "c1-lead-scraper"
  "m2-icp-scoring"
  "m3-enrichment"
  "t15-deep-enrichment"
  "m4-cadence-orchestrator"
  "m5a-email-sender"
  "m5b-dm-dispatcher"
  "m5c-whatsapp-sender"
  "m6-event-tracker"
  "m7-manychat-bridge"
  "m8-axiom-orchestrator"
  "m9-domain-guard"
  "m10-weekly-reporter"
  "c3-daily-briefing"
  "c4-ad-library-benchmark"
  "c5-reels-trends-scanner"
)

for module in "${MODULES[@]}"; do
  mkdir -p "$MODULES_DIR/$module/logs"
  echo "  ✅ $module"
done

mkdir -p "$LOGS_DIR"

# --- Criar .env ---
echo ""
echo "📋 Criando arquivo .env..."
cat > "$ENV_FILE" << 'ENVEOF'
# ============================================================
# MOTOR DE OUTBOUND — Credenciais
# ============================================================
# PREENCHA TODAS AS CHAVES ANTES DE RODAR OS MÓDULOS
# ============================================================

# --- CRM (Supabase) ---
CRM_BASE_URL=https://peegicizxybjgvuutegc.supabase.co/functions/v1/crm-api
CRM_API_KEY=${CRM_API_KEY}

# --- Apify ---
APIFY_TOKEN=${APIFY_API_TOKEN}

# --- Email (Resend) ---
RESEND_API_KEY=${RESEND_API_KEY}

# --- Enrichment ---
APOLLO_API_KEY=I2SbTXya07FoSSg5enheoA

# --- ManyChat ---
# NOTA: ManyChat faz POST direto pro CRM via External Request nos flows.
# Se precisar da API do ManyChat pra sync reverso (CRM→ManyChat tags):
MANYCHAT_API_TOKEN=

# --- WhatsApp (Z-API) — DESABILITADO POR AGORA ---
# Descomentar e preencher quando for ativar o M5c
# ZAPI_INSTANCE_ID=
# ZAPI_TOKEN=
# ZAPI_SECURITY_TOKEN=

# --- Google Sheets (Bridge Axiom + DMs) ---
GOOGLE_SHEETS_ID=1cE5LT-gW5F6b-TvDrA5MtIafO7uY1co-zSYMTuUzawk
GOOGLE_SHEETS_API_KEY=AIzaSyDDTGKRUuibxHFXPHl1ja7eRdPaUI6qGhc
GOOGLE_SHEETS_TOKEN=AIzaSyDDTGKRUuibxHFXPHl1ja7eRdPaUI6qGhc

# --- Remetentes de Email (ambos tenants usam leveron.online) ---
KOSMOS_EMAIL_FROM="Vinícius <vinicius@leveron.online>"
KOSMOS_EMAIL_REPLY_TO="vinicius@leveron.online"
OLIVEIRA_EMAIL_FROM="Vinícius <vinicius@leveron.online>"
OLIVEIRA_EMAIL_REPLY_TO="vinicius@leveron.online"
ENVEOF

echo "  ✅ .env criado em $ENV_FILE"
echo "  ⚠️  PREENCHA as chaves marcadas com <SUBSTITUIR>!"

# --- Criar script genérico de execução ---
echo ""
echo "🔧 Criando scripts de execução para cada módulo..."

for module in "${MODULES[@]}"; do
  RUN_SCRIPT="$MODULES_DIR/$module/run.sh"
  cat > "$RUN_SCRIPT" << RUNEOF
#!/bin/bash
# ${module} — Execução via Claude Code
# Gerado automaticamente pelo master-setup.sh

MODULE_DIR="$MODULES_DIR/${module}"
LOG_DIR="\$MODULE_DIR/logs"
TIMESTAMP=\$(date +%Y-%m-%d_%H%M)
LOG_FILE="\$LOG_DIR/${module}_\${TIMESTAMP}.log"

echo "[\$(date)] ${module} — Iniciando..." | tee "\$LOG_FILE"

# Carregar variáveis de ambiente
source "$ENV_FILE"

# Executar via Claude Code
claude -p "\$(cat \$MODULE_DIR/prompt.md)" 2>&1 | tee -a "\$LOG_FILE"

EXIT_CODE=\${PIPESTATUS[0]}

if [ \$EXIT_CODE -eq 0 ]; then
    echo "[\$(date)] ${module} concluído com sucesso." | tee -a "\$LOG_FILE"
else
    echo "[\$(date)] ${module} ERRO — exit code: \$EXIT_CODE" | tee -a "\$LOG_FILE"
fi

# Limpar logs com mais de 30 dias
find "\$LOG_DIR" -name "${module}_*.log" -mtime +30 -delete 2>/dev/null

echo "[\$(date)] ${module} finalizado." | tee -a "\$LOG_FILE"
RUNEOF

  chmod +x "$RUN_SCRIPT"
  echo "  ✅ $module/run.sh"
done

# --- Instruções de cópia dos prompts ---
echo ""
echo "============================================================"
echo "  📋 COPIAR PROMPTS"
echo "============================================================"
echo ""
echo "Copie cada arquivo .md para o diretório do módulo:"
echo ""
echo "  cp m2-icp-scoring.md         $MODULES_DIR/m2-icp-scoring/prompt.md"
echo "  cp m3-enrichment.md          $MODULES_DIR/m3-enrichment/prompt.md"
echo "  cp m4-cadence-orchestrator.md $MODULES_DIR/m4-cadence-orchestrator/prompt.md"
echo "  cp m5a-email-sender.md       $MODULES_DIR/m5a-email-sender/prompt.md"
echo "  cp m5b-dm-dispatcher.md      $MODULES_DIR/m5b-dm-dispatcher/prompt.md"
echo "  cp m5c-whatsapp-sender.md    $MODULES_DIR/m5c-whatsapp-sender/prompt.md"
echo "  cp m6-event-tracker.md       $MODULES_DIR/m6-event-tracker/prompt.md"
echo "  cp m7-manychat-bridge.md     $MODULES_DIR/m7-manychat-bridge/prompt.md"
echo "  cp m8-axiom-orchestrator.md  $MODULES_DIR/m8-axiom-orchestrator/prompt.md"
echo "  cp m9-domain-guard.md        $MODULES_DIR/m9-domain-guard/prompt.md"
echo "  cp m10-weekly-reporter.md    $MODULES_DIR/m10-weekly-reporter/prompt.md"
echo "  cp c3-daily-briefing.md      $MODULES_DIR/c3-daily-briefing/prompt.md"
echo "  cp c4-ad-library-benchmark.md $MODULES_DIR/c4-ad-library-benchmark/prompt.md"
echo "  cp c5-reels-trends-scanner.md $MODULES_DIR/c5-reels-trends-scanner/prompt.md"
echo ""

# --- Crontab ---
echo "============================================================"
echo "  ⏰ CRONTAB COMPLETO"
echo "============================================================"
echo ""
echo "Execute: crontab -e"
echo "Cole as linhas abaixo:"
echo ""

cat << 'CRONEOF'
# ============================================================
# MOTOR DE OUTBOUND — Crontab Completo
# ============================================================
# Timezone: America/Sao_Paulo (configurar no servidor)
# ============================================================

# --- DIÁRIO ---

# M2 ICP Scoring — Todo dia às 06:00
0 6 * * * ~/outbound-engine/modules/m2-icp-scoring/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M3 Enrichment — Todo dia às 07:00
0 7 * * * ~/outbound-engine/modules/m3-enrichment/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# C3 Daily Briefing — Todo dia às 08:00
0 8 * * * ~/outbound-engine/modules/c3-daily-briefing/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M9 Domain Guard — Todo dia às 08:00
0 8 * * * ~/outbound-engine/modules/m9-domain-guard/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M4 Cadence Orchestrator — 4x/dia (09, 12, 15, 18)
0 9,12,15,18 * * * ~/outbound-engine/modules/m4-cadence-orchestrator/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M5a Email Sender — 4x/dia (09:15, 12:15, 15:15, 18:15) — 15min após M4
15 9,12,15,18 * * * ~/outbound-engine/modules/m5a-email-sender/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M6 Event Tracker — A cada 30 minutos
*/30 * * * * ~/outbound-engine/modules/m6-event-tracker/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M7 ManyChat Bridge — SEM CRON (event-driven via External Request no ManyChat)
# Leads inbound entram direto no CRM. Ver m7-manychat-bridge.md para configuração.

# M8 Axiom Orchestrator — Todo dia às 20:00
0 20 * * * ~/outbound-engine/modules/m8-axiom-orchestrator/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M5b DM Dispatcher — Todo dia às 21:00
0 21 * * * ~/outbound-engine/modules/m5b-dm-dispatcher/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M5c WhatsApp Sender — DESABILITADO (ativar quando Z-API estiver pronta)
# 30 9,12,15,18 * * * ~/outbound-engine/modules/m5c-whatsapp-sender/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# --- SEMANAL ---

# C1 Lead Scraper — Segunda às 22:00
0 22 * * 1 ~/outbound-engine/modules/c1-lead-scraper/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# C4 Ad Library Benchmark — Segunda às 10:00
0 10 * * 1 ~/outbound-engine/modules/c4-ad-library-benchmark/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# C5 Reels Trends Scanner — Segunda às 11:00
0 11 * * 1 ~/outbound-engine/modules/c5-reels-trends-scanner/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# M10 Weekly Reporter — Sexta às 18:00
0 18 * * 5 ~/outbound-engine/modules/m10-weekly-reporter/run.sh >> ~/outbound-engine/logs/cron.log 2>&1

# --- MANUTENÇÃO ---

# Limpar logs gerais com mais de 60 dias
0 3 * * 0 find ~/outbound-engine/logs -name "*.log" -mtime +60 -delete 2>/dev/null
CRONEOF

# --- Instalar engine.sh (orquestrador + CLI) ---
echo ""
echo "🔧 Instalando orquestrador (engine.sh)..."
if [ -f "engine.sh" ]; then
    cp engine.sh "$BASE_DIR/engine.sh"
    chmod +x "$BASE_DIR/engine.sh"
    echo "  ✅ engine.sh instalado em $BASE_DIR/engine.sh"
else
    echo "  ⚠️  engine.sh não encontrado no diretório atual. Copie manualmente para $BASE_DIR/"
fi

# --- Criar alias 'engine' ---
echo ""
echo "🔗 Configurando alias 'engine'..."
ALIAS_LINE="alias engine='$BASE_DIR/engine.sh'"
if ! grep -q "alias engine=" ~/.bashrc 2>/dev/null; then
    echo "$ALIAS_LINE" >> ~/.bashrc
    echo "  ✅ Alias adicionado ao .bashrc"
else
    echo "  ℹ️  Alias 'engine' já existe no .bashrc"
fi
# Carregar agora
eval "$ALIAS_LINE"

echo ""
echo "============================================================"
echo "  📋 CHECKLIST PÓS-SETUP"
echo "============================================================"
echo ""
echo "  1. Preencher credenciais no .env:"
echo "     engine edit .env   (ou nano $ENV_FILE)"
echo ""
echo "  2. Copiar prompts .md para os diretórios dos módulos:"
echo "     cp m2-icp-scoring.md $MODULES_DIR/m2-icp-scoring/prompt.md"
echo "     cp m3-enrichment.md $MODULES_DIR/m3-enrichment/prompt.md"
echo "     (... repetir para cada módulo)"
echo ""
echo "  3. Configurar timezone:"
echo "     sudo timedatectl set-timezone America/Sao_Paulo"
echo ""
echo "  4. Verificar que tudo está ok:"
echo "     engine health     (checa APIs)"
echo "     engine status     (dashboard)"
echo ""
echo "  5. Testar módulo por módulo:"
echo "     engine run m2-icp-scoring"
echo "     engine run m3-enrichment"
echo ""
echo "  6. Instalar cron quando estiver pronto:"
echo "     engine cron-install"
echo ""
echo "  7. Monitorar:"
echo "     engine status      (dashboard)"
echo "     engine logs         (resumo dos logs)"
echo "     engine logs-live    (tempo real)"
echo ""
echo "============================================================"
echo "  COMANDOS RÁPIDOS (funciona do celular via SSH):"
echo "============================================================"
echo ""
echo "  engine run <modulo>       Roda um módulo"
echo "  engine run-chain <fase>   Roda fase inteira (1-5, ind, all)"
echo "  engine status             Dashboard"
echo "  engine logs [modulo]      Ver logs"
echo "  engine edit <modulo>      Editar prompt (nano)"
echo "  engine health             Health check APIs"
echo "  engine list               Listar módulos"
echo "  engine cron-pause         Pausar tudo"
echo "  engine cron-resume        Retomar tudo"
echo ""
echo "============================================================"
echo "  ✅ SETUP COMPLETO!"
echo "============================================================"

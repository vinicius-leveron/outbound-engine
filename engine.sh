#!/bin/bash
# ============================================================
# MOTOR DE OUTBOUND — Orquestrador + CLI
# ============================================================
# Uso:
#   engine run <modulo>       → roda um módulo manualmente
#   engine run-chain <fase>   → roda uma fase inteira em ordem
#   engine status             → dashboard de todos os módulos
#   engine logs <modulo>      → últimos logs de um módulo
#   engine logs-live          → tail -f do log geral
#   engine edit <modulo>      → abre o prompt pra edição (nano)
#   engine list               → lista todos os módulos
#   engine health             → health check de APIs
#   engine cron-install       → instala o crontab completo
#   engine cron-pause         → comenta todas as linhas do cron
#   engine cron-resume        → descomenta todas as linhas do cron
# ============================================================

set -e

BASE_DIR="$HOME/outbound-engine"
MODULES_DIR="$BASE_DIR/modules"
LOGS_DIR="$BASE_DIR/logs"
ENV_FILE="$BASE_DIR/.env"
STATUS_FILE="$BASE_DIR/.status.json"
CRON_FILE="$BASE_DIR/crontab.txt"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================
# MAPA DE DEPENDÊNCIAS
# ============================================================
# Cada módulo sabe de quem depende e o que produz.
# O orquestrador usa isso pra validar antes de rodar.

declare -A DEPS
DEPS[c1-lead-scraper]=""
DEPS[m2-icp-scoring]="c1-lead-scraper"
DEPS[m3-enrichment]="m2-icp-scoring"
DEPS[m4-cadence-orchestrator]="m3-enrichment"
DEPS[m5a-email-sender]="m4-cadence-orchestrator"
DEPS[m5b-dm-dispatcher]="m4-cadence-orchestrator"
# DEPS[m5c-whatsapp-sender]="m4-cadence-orchestrator"  # DESABILITADO — WhatsApp por último
DEPS[m6-event-tracker]="m5a-email-sender"
DEPS[m8-axiom-orchestrator]="m2-icp-scoring"
DEPS[m9-domain-guard]="m5a-email-sender"
DEPS[m10-weekly-reporter]=""
DEPS[c3-daily-briefing]=""
DEPS[c4-ad-library-benchmark]=""
DEPS[c5-reels-trends-scanner]=""

# Fases de execução
declare -A PHASES
PHASES[1]="c1-lead-scraper m2-icp-scoring"
PHASES[2]="m3-enrichment"
PHASES[3]="m4-cadence-orchestrator m5a-email-sender m5b-dm-dispatcher m6-event-tracker"
PHASES[4]="m8-axiom-orchestrator m9-domain-guard"  # m5c-whatsapp desabilitado
PHASES[5]="m10-weekly-reporter c3-daily-briefing"
PHASES[ind]="c4-ad-library-benchmark c5-reels-trends-scanner"

# Lista completa de módulos
ALL_MODULES="c1-lead-scraper m2-icp-scoring m3-enrichment m4-cadence-orchestrator m5a-email-sender m5b-dm-dispatcher m6-event-tracker m8-axiom-orchestrator m9-domain-guard m10-weekly-reporter c3-daily-briefing c4-ad-library-benchmark c5-reels-trends-scanner"

# ============================================================
# FUNÇÕES CORE
# ============================================================

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo -e "${RED}ERRO: .env não encontrado em $ENV_FILE${NC}"
        exit 1
    fi
}

update_status() {
    local module=$1
    local status=$2  # running, success, error, skipped
    local timestamp=$(date -Iseconds)
    local exit_code=${3:-0}

    # Criar/atualizar status JSON
    if [ ! -f "$STATUS_FILE" ]; then
        echo "{}" > "$STATUS_FILE"
    fi

    python3 -c "
import json, sys
with open('$STATUS_FILE', 'r') as f:
    data = json.load(f)
data['$module'] = {
    'status': '$status',
    'timestamp': '$timestamp',
    'exit_code': $exit_code
}
with open('$STATUS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
}

get_last_status() {
    local module=$1
    if [ -f "$STATUS_FILE" ]; then
        python3 -c "
import json
with open('$STATUS_FILE', 'r') as f:
    data = json.load(f)
m = data.get('$module', {})
print(m.get('status', 'never_run'))
" 2>/dev/null || echo "unknown"
    else
        echo "never_run"
    fi
}

check_dependency() {
    local module=$1
    local dep="${DEPS[$module]}"

    if [ -z "$dep" ]; then
        return 0  # Sem dependências
    fi

    local dep_status=$(get_last_status "$dep")
    if [ "$dep_status" = "success" ] || [ "$dep_status" = "never_run" ]; then
        return 0
    else
        echo -e "${YELLOW}⚠️  Dependência '$dep' tem status: $dep_status${NC}"
        return 1
    fi
}

# ============================================================
# COMANDO: run <modulo>
# ============================================================
cmd_run() {
    local module=$1

    if [ -z "$module" ]; then
        echo -e "${RED}Uso: engine run <nome-do-modulo>${NC}"
        echo "Módulos disponíveis:"
        cmd_list
        return 1
    fi

    local prompt_file="$MODULES_DIR/$module/prompt.md"
    local log_dir="$MODULES_DIR/$module/logs"
    local timestamp=$(date +%Y-%m-%d_%H%M)
    local log_file="$log_dir/${module}_${timestamp}.log"

    # Verificar se módulo existe
    if [ ! -d "$MODULES_DIR/$module" ]; then
        echo -e "${RED}ERRO: Módulo '$module' não encontrado${NC}"
        return 1
    fi

    # Verificar se prompt existe
    if [ ! -f "$prompt_file" ]; then
        echo -e "${RED}ERRO: Prompt não encontrado: $prompt_file${NC}"
        echo "Copie o arquivo .md para: $prompt_file"
        return 1
    fi

    # Verificar dependências
    if ! check_dependency "$module"; then
        echo -e "${YELLOW}Dependência não satisfeita. Continuar mesmo assim? (s/N)${NC}"
        read -r answer
        if [ "$answer" != "s" ] && [ "$answer" != "S" ]; then
            echo "Cancelado."
            return 1
        fi
    fi

    # Carregar env
    load_env

    # Executar
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ Executando: $module${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "[$(date)] $module — Iniciando..." | tee "$log_file"

    update_status "$module" "running"

    claude -p "$(cat $prompt_file)" --allowedTools 'Bash(curl*)' 'Bash(jq*)' 'Bash(sleep*)' 'Bash(date*)' 'Bash(echo*)' 'Bash(cat*)' 2>&1 | tee -a "$log_file"
    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ $module concluído com sucesso.${NC}" | tee -a "$log_file"
        update_status "$module" "success" 0
    else
        echo -e "${RED}❌ $module ERRO — exit code: $exit_code${NC}" | tee -a "$log_file"
        update_status "$module" "error" $exit_code
    fi

    # Limpar logs antigos
    find "$log_dir" -name "${module}_*.log" -mtime +30 -delete 2>/dev/null

    return $exit_code
}

# ============================================================
# COMANDO: run-chain <fase>
# ============================================================
cmd_run_chain() {
    local phase=$1

    if [ -z "$phase" ]; then
        echo -e "${RED}Uso: engine run-chain <fase>${NC}"
        echo ""
        echo "Fases disponíveis:"
        echo "  1  → Fundação: C1 (Lead Scraper) + M2 (ICP Scoring)"
        echo "  2  → Enrichment: M3"
        echo "  3  → Core Outbound: M4 + M5a + M5b + M6"
        echo "  4  → Complementar: M5c + M8 + M9"
        echo "  5  → Relatórios: M10 + C3"
        echo "  ind → Independentes: C4 + C5"
        echo "  all → Todas as fases em ordem"
        return 1
    fi

    if [ "$phase" = "all" ]; then
        for p in 1 2 3 4 5 ind; do
            echo -e "${BOLD}═══ FASE $p ═══${NC}"
            cmd_run_chain "$p"
            echo ""
        done
        return 0
    fi

    local modules="${PHASES[$phase]}"
    if [ -z "$modules" ]; then
        echo -e "${RED}Fase '$phase' não encontrada${NC}"
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ Executando Fase $phase${NC}"
    echo -e "  Módulos: $modules"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for module in $modules; do
        cmd_run "$module"
        local rc=$?
        if [ $rc -ne 0 ]; then
            echo -e "${RED}❌ Fase $phase parou no módulo $module (exit: $rc)${NC}"
            echo -e "${YELLOW}Corrigir e rodar: engine run $module${NC}"
            return $rc
        fi
        echo ""
    done

    echo -e "${GREEN}✅ Fase $phase completa!${NC}"
}

# ============================================================
# COMANDO: status
# ============================================================
cmd_status() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  MOTOR DE OUTBOUND — Status dos Módulos${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ ! -f "$STATUS_FILE" ]; then
        echo "{}" > "$STATUS_FILE"
    fi

    python3 << 'PYEOF'
import json, os
from datetime import datetime

status_file = os.path.expanduser("~/outbound-engine/.status.json")
modules_dir = os.path.expanduser("~/outbound-engine/modules")

with open(status_file) as f:
    data = json.load(f)

modules_order = [
    ("FASE 1 — Fundação", ["c1-lead-scraper", "m2-icp-scoring"]),
    ("FASE 2 — Enrichment", ["m3-enrichment"]),
    ("FASE 3 — Core Outbound", ["m4-cadence-orchestrator", "m5a-email-sender", "m5b-dm-dispatcher", "m6-event-tracker"]),
    ("FASE 4 — Complementar", ["m8-axiom-orchestrator", "m9-domain-guard"]),
    ("FASE 5 — Relatórios", ["m10-weekly-reporter", "c3-daily-briefing"]),
    ("INDEPENDENTES", ["c4-ad-library-benchmark", "c5-reels-trends-scanner"]),
]

icons = {
    "success": "✅",
    "error": "❌",
    "running": "🔄",
    "skipped": "⏭️",
    "never_run": "⬜",
    "unknown": "❓"
}

for phase_name, modules in modules_order:
    print(f"  \033[1m{phase_name}\033[0m")
    for m in modules:
        info = data.get(m, {})
        status = info.get("status", "never_run")
        icon = icons.get(status, "❓")
        ts = info.get("timestamp", "")
        has_prompt = os.path.exists(f"{modules_dir}/{m}/prompt.md")
        prompt_icon = "📄" if has_prompt else "⚠️"

        if ts:
            try:
                dt = datetime.fromisoformat(ts)
                ts_str = dt.strftime("%d/%m %H:%M")
            except:
                ts_str = ts[:16]
        else:
            ts_str = "—"

        print(f"    {icon} {prompt_icon} {m:<30} {status:<12} {ts_str}")
    print()

print("  Legenda: ✅=ok  ❌=erro  🔄=rodando  ⬜=nunca rodou  📄=prompt ok  ⚠️=prompt faltando")
PYEOF

    echo ""
}

# ============================================================
# COMANDO: logs <modulo>
# ============================================================
cmd_logs() {
    local module=$1

    if [ -z "$module" ]; then
        echo -e "${YELLOW}Últimos logs de cada módulo:${NC}"
        echo ""
        for m in $ALL_MODULES; do
            local last_log=$(ls -t "$MODULES_DIR/$m/logs/"*.log 2>/dev/null | head -1)
            if [ -n "$last_log" ]; then
                local size=$(wc -l < "$last_log")
                local date=$(stat -c %y "$last_log" 2>/dev/null | cut -d. -f1 || stat -f %Sm "$last_log" 2>/dev/null)
                echo -e "  ${BOLD}$m${NC} → $date ($size linhas)"
            else
                echo -e "  ${BOLD}$m${NC} → sem logs"
            fi
        done
        echo ""
        echo "Use: engine logs <modulo> para ver o log completo"
        return 0
    fi

    local last_log=$(ls -t "$MODULES_DIR/$module/logs/"*.log 2>/dev/null | head -1)
    if [ -n "$last_log" ]; then
        echo -e "${CYAN}━━━ $module — Último log ━━━${NC}"
        cat "$last_log"
    else
        echo "Sem logs para $module"
    fi
}

# ============================================================
# COMANDO: logs-live
# ============================================================
cmd_logs_live() {
    echo -e "${CYAN}Monitorando logs em tempo real (Ctrl+C pra sair)...${NC}"
    tail -f "$LOGS_DIR/cron.log" 2>/dev/null || echo "Arquivo de log cron não encontrado. Rode algum módulo primeiro."
}

# ============================================================
# COMANDO: edit <modulo>
# ============================================================
cmd_edit() {
    local module=$1

    if [ -z "$module" ]; then
        echo -e "${RED}Uso: engine edit <nome-do-modulo>${NC}"
        cmd_list
        return 1
    fi

    local prompt_file="$MODULES_DIR/$module/prompt.md"

    if [ ! -f "$prompt_file" ]; then
        echo -e "${RED}Prompt não encontrado: $prompt_file${NC}"
        return 1
    fi

    # Usar nano (funciona bem em mobile SSH)
    ${EDITOR:-nano} "$prompt_file"
}

# ============================================================
# COMANDO: list
# ============================================================
cmd_list() {
    echo ""
    echo -e "${BOLD}Módulos disponíveis:${NC}"
    echo ""
    echo "  FASE 1 (Fundação):"
    echo "    c1-lead-scraper          Scrape seguidores via Apify"
    echo "    m2-icp-scoring           Score e classifica leads A/B/C"
    echo ""
    echo "  FASE 2 (Enrichment):"
    echo "    m3-enrichment            Busca email/tel via Hunter/Apollo"
    echo ""
    echo "  FASE 3 (Core Outbound):"
    echo "    m4-cadence-orchestrator   Decide próximo step da cadência"
    echo "    m5a-email-sender          Envia emails via Resend"
    echo "    m5b-dm-dispatcher         Prepara DMs pro Axiom"
    echo "    m6-event-tracker          Polling de eventos + AI classify"
    echo ""
    echo "  FASE 4 (Complementar):"
    echo "    m5c-whatsapp-sender       Envia WhatsApp via Z-API (DESABILITADO)"
    echo "    m8-axiom-orchestrator     Orquestra ações IG"
    echo "    m9-domain-guard           Monitora reputação email"
    echo ""
    echo "  FASE 5 (Relatórios):"
    echo "    m10-weekly-reporter       Relatório semanal"
    echo "    c3-daily-briefing         Briefing diário"
    echo ""
    echo "  INDEPENDENTES:"
    echo "    c4-ad-library-benchmark   Benchmark de ads Meta"
    echo "    c5-reels-trends-scanner   Trends de Reels"
    echo ""
    echo "  CONFIGURAÇÃO (sem cron):"
    echo "    m7-manychat-bridge        Guia de config ManyChat→CRM"
    echo ""
}

# ============================================================
# COMANDO: health
# ============================================================
cmd_health() {
    load_env

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Health Check — APIs${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # CRM
    echo -n "  CRM Supabase:    "
    local crm_status=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${CRM_BASE_URL}/contacts?limit=1" -H "Authorization: Bearer ${CRM_API_KEY}" 2>/dev/null)
    if [ "$crm_status" = "200" ]; then
        echo -e "${GREEN}✅ OK (HTTP $crm_status)${NC}"
    else
        echo -e "${RED}❌ ERRO (HTTP $crm_status)${NC}"
    fi

    # Apify
    echo -n "  Apify:           "
    if [ -n "$APIFY_TOKEN" ] && [ "$APIFY_TOKEN" != "<SUBSTITUIR>" ]; then
        local apify_status=$(curl -s -o /dev/null -w "%{http_code}" "https://api.apify.com/v2/user/me?token=${APIFY_TOKEN}" 2>/dev/null)
        if [ "$apify_status" = "200" ]; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ ERRO (HTTP $apify_status)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Não configurado${NC}"
    fi

    # Resend
    echo -n "  Resend:          "
    if [ -n "$RESEND_API_KEY" ] && [ "$RESEND_API_KEY" != "<SUBSTITUIR>" ]; then
        local resend_status=$(curl -s -o /dev/null -w "%{http_code}" "https://api.resend.com/domains" -H "Authorization: Bearer ${RESEND_API_KEY}" 2>/dev/null)
        if [ "$resend_status" = "200" ]; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ ERRO (HTTP $resend_status)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Não configurado${NC}"
    fi

    # Z-API
    echo -n "  Z-API:           "
    if [ -n "$ZAPI_INSTANCE_ID" ] && [ "$ZAPI_INSTANCE_ID" != "<SUBSTITUIR>" ]; then
        local zapi_status=$(curl -s -o /dev/null -w "%{http_code}" "https://api.z-api.io/instances/${ZAPI_INSTANCE_ID}/token/${ZAPI_TOKEN}/status" -H "Client-Token: ${ZAPI_SECURITY_TOKEN}" 2>/dev/null)
        if [ "$zapi_status" = "200" ]; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ ERRO (HTTP $zapi_status)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Não configurado${NC}"
    fi

    # Hunter
    echo -n "  Hunter.io:       "
    if [ -n "$HUNTER_API_KEY" ] && [ "$HUNTER_API_KEY" != "<SUBSTITUIR>" ]; then
        local hunter_status=$(curl -s -o /dev/null -w "%{http_code}" "https://api.hunter.io/v2/account?api_key=${HUNTER_API_KEY}" 2>/dev/null)
        if [ "$hunter_status" = "200" ]; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ ERRO (HTTP $hunter_status)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Não configurado${NC}"
    fi

    # Google Sheets
    echo -n "  Google Sheets:   "
    if [ -n "$GOOGLE_SHEETS_ID" ] && [ "$GOOGLE_SHEETS_ID" != "<SUBSTITUIR>" ]; then
        echo -e "${GREEN}📋 Configurado (ID: ${GOOGLE_SHEETS_ID:0:10}...)${NC}"
    else
        echo -e "${YELLOW}⚠️  Não configurado${NC}"
    fi

    echo ""
}

# ============================================================
# COMANDO: cron-install
# ============================================================
cmd_cron_install() {
    cat > "$CRON_FILE" << 'CRONEOF'
# ============================================================
# MOTOR DE OUTBOUND — Crontab
# Timezone: America/Sao_Paulo
# Gerenciado por: engine cron-install
# ============================================================

# FASE 1
0 6 * * * ~/outbound-engine/engine.sh run m2-icp-scoring >> ~/outbound-engine/logs/cron.log 2>&1

# FASE 2
0 7 * * * ~/outbound-engine/engine.sh run m3-enrichment >> ~/outbound-engine/logs/cron.log 2>&1

# FASE 3
0 9,12,15,18 * * * ~/outbound-engine/engine.sh run m4-cadence-orchestrator >> ~/outbound-engine/logs/cron.log 2>&1
15 9,12,15,18 * * * ~/outbound-engine/engine.sh run m5a-email-sender >> ~/outbound-engine/logs/cron.log 2>&1
0 21 * * * ~/outbound-engine/engine.sh run m5b-dm-dispatcher >> ~/outbound-engine/logs/cron.log 2>&1
*/30 * * * * ~/outbound-engine/engine.sh run m6-event-tracker >> ~/outbound-engine/logs/cron.log 2>&1

# FASE 4
# M5c WhatsApp — DESABILITADO (ativar quando Z-API estiver configurada)
# 30 9,12,15,18 * * * ~/outbound-engine/engine.sh run m5c-whatsapp-sender >> ~/outbound-engine/logs/cron.log 2>&1
0 20 * * * ~/outbound-engine/engine.sh run m8-axiom-orchestrator >> ~/outbound-engine/logs/cron.log 2>&1
0 8 * * * ~/outbound-engine/engine.sh run m9-domain-guard >> ~/outbound-engine/logs/cron.log 2>&1

# FASE 5
0 8 * * * ~/outbound-engine/engine.sh run c3-daily-briefing >> ~/outbound-engine/logs/cron.log 2>&1
0 18 * * 5 ~/outbound-engine/engine.sh run m10-weekly-reporter >> ~/outbound-engine/logs/cron.log 2>&1

# INDEPENDENTES
0 22 * * 1 ~/outbound-engine/engine.sh run c1-lead-scraper >> ~/outbound-engine/logs/cron.log 2>&1
0 10 * * 1 ~/outbound-engine/engine.sh run c4-ad-library-benchmark >> ~/outbound-engine/logs/cron.log 2>&1
0 11 * * 1 ~/outbound-engine/engine.sh run c5-reels-trends-scanner >> ~/outbound-engine/logs/cron.log 2>&1

# MANUTENÇÃO
0 3 * * 0 find ~/outbound-engine -name "*.log" -mtime +60 -delete 2>/dev/null
CRONEOF

    crontab "$CRON_FILE"
    echo -e "${GREEN}✅ Crontab instalado com sucesso!${NC}"
    echo "Verificar com: crontab -l"
}

# ============================================================
# COMANDO: cron-pause / cron-resume
# ============================================================
cmd_cron_pause() {
    crontab -l 2>/dev/null | sed 's/^\([^#]\)/# \1/' | crontab -
    echo -e "${YELLOW}⏸️  Todos os crons pausados.${NC}"
    echo "Para retomar: engine cron-resume"
}

cmd_cron_resume() {
    crontab -l 2>/dev/null | sed 's/^# \(.*engine\)/\1/' | crontab -
    echo -e "${GREEN}▶ Crons retomados.${NC}"
}

# ============================================================
# ROTEADOR DE COMANDOS
# ============================================================
case "${1:-}" in
    run)        cmd_run "$2" ;;
    run-chain)  cmd_run_chain "$2" ;;
    status)     cmd_status ;;
    logs)       cmd_logs "$2" ;;
    logs-live)  cmd_logs_live ;;
    edit)       cmd_edit "$2" ;;
    list)       cmd_list ;;
    health)     cmd_health ;;
    cron-install) cmd_cron_install ;;
    cron-pause) cmd_cron_pause ;;
    cron-resume) cmd_cron_resume ;;
    *)
        echo -e "${BOLD}Motor de Outbound — CLI${NC}"
        echo ""
        echo "Comandos:"
        echo "  engine run <modulo>       Roda um módulo"
        echo "  engine run-chain <fase>   Roda uma fase inteira (1-5, ind, all)"
        echo "  engine status             Dashboard de status"
        echo "  engine logs [modulo]      Ver logs (sem módulo = resumo)"
        echo "  engine logs-live          Logs em tempo real"
        echo "  engine edit <modulo>      Editar prompt do módulo"
        echo "  engine list               Listar módulos"
        echo "  engine health             Health check das APIs"
        echo "  engine cron-install       Instalar crontab"
        echo "  engine cron-pause         Pausar todos os crons"
        echo "  engine cron-resume        Retomar crons"
        echo ""
        echo "Exemplos:"
        echo "  engine run m2-icp-scoring"
        echo "  engine run-chain 1"
        echo "  engine edit m4-cadence-orchestrator"
        echo "  engine status"
        ;;
esac

#!/bin/bash
SESSION="outbound-test"
DIR="/root/outbound-engine"
CMD="claude --dangerously-skip-permissions -p"

tmux kill-session -t $SESSION 2>/dev/null

tmux new-session -d -s $SESSION -n "M3" -c "$DIR"
tmux send-keys -t $SESSION:M3 "$CMD \"\$(cat m3-enrichment.md)\"" Enter

tmux new-window -t $SESSION -n "M4" -c "$DIR"
tmux send-keys -t $SESSION:M4 "$CMD \"\$(cat m4-cadence-orchestrator.md)\"" Enter

tmux new-window -t $SESSION -n "M5a" -c "$DIR"
tmux send-keys -t $SESSION:M5a "$CMD \"\$(cat m5a-email-sender.md)\"" Enter

tmux new-window -t $SESSION -n "M8" -c "$DIR"
tmux send-keys -t $SESSION:M8 "$CMD \"\$(cat m8-axiom-orchestrator.md)\"" Enter

tmux new-window -t $SESSION -n "M9" -c "$DIR"
tmux send-keys -t $SESSION:M9 "$CMD \"\$(cat m9-domain-guard.md)\"" Enter

tmux new-window -t $SESSION -n "M10" -c "$DIR"
tmux send-keys -t $SESSION:M10 "$CMD \"\$(cat m10-weekly-reporter.md)\"" Enter

tmux new-window -t $SESSION -n "C3" -c "$DIR"
tmux send-keys -t $SESSION:C3 "$CMD \"\$(cat c3-daily-briefing.md)\"" Enter

tmux new-window -t $SESSION -n "M6" -c "$DIR"
tmux send-keys -t $SESSION:M6 "$CMD \"\$(cat m6-event-tracker.md)\"" Enter

echo "✅ 8 módulos rodando! Conectando..."
echo "Ctrl+B → n (próxima) | p (anterior) | w (lista)"
tmux attach -t $SESSION

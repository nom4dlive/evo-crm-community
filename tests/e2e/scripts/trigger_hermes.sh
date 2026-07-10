#!/bin/bash

# Configuration
VPS_USER="root"
VPS_HOST="2.25.156.25"
VPS_PATH="/opt/data/evo-crm/tests"

echo "=========================================="
echo "🚀 Sincronizando testes E2E com a VPS..."
echo "=========================================="

# 1. Sync files to VPS
rsync -avz --exclude 'node_modules' --exclude 'test-results' --exclude 'playwright-report' ../ $VPS_USER@$VPS_HOST:$VPS_PATH

echo "=========================================="
echo "🤖 Acionando Hermes Agent na VPS..."
echo "=========================================="

# 2. Trigger Hermes Profile to run the suite and report back
ssh $VPS_USER@$VPS_HOST "docker exec -i hermes-agent-6bxv-hermes-agent-1 hermes --profile evo-tester -z \"Por favor, navegue até $VPS_PATH, instale as dependências se necessário com npm install, execute a suíte Playwright. Ao finalizar, gere um arquivo TEST_REPORT.md com os resultados e envie um resumo via Telegram para o ID 5500841656.\" chat"

echo "=========================================="
echo "✅ Gatilho concluído."
echo "=========================================="

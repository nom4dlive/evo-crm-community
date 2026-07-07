cd /opt/crm && docker compose down -v 2>/dev/null || true
cd /opt/crm/bh-tech-core && docker compose down -v 2>/dev/null || true
cd /var/www/n4-crm/client-a && docker compose down -v 2>/dev/null || true

# Remover os contêineres órfãos do CRM que estão rodando
docker ps -a -q -f name=crm- | xargs -r docker rm -f 2>/dev/null
docker ps -a -q -f name=bodyharmony- | xargs -r docker rm -f 2>/dev/null
docker ps -a -q -f name=evo-crm- | xargs -r docker rm -f 2>/dev/null

echo "Portas ainda abertas:"
ss -tulpn | grep -E ':(80|443|3000|3001|5432|6379|5173)' || echo "Nenhuma das portas principais está em uso."

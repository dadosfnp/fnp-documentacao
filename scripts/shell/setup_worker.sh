#!/bin/bash
# FNP — Configuração do servidor de ingestão (Ubuntu 22.04)
# Executar como root após criar o Droplet no DigitalOcean
# O servidor deve estar na mesma VPC do banco, SEM endereço IP público

set -e

echo "=== FNP — Configuração do servidor de ingestão ==="

# Atualizar o sistema operacional
apt update && apt upgrade -y

# Instalar Python e dependências do sistema
apt install -y python3-pip python3-venv git cron

# Criar usuário dedicado (nunca rodar como root)
useradd -m -s /bin/bash fnp || true
mkdir -p /home/fnp/app
chown fnp:fnp /home/fnp/app

# Criar e ativar ambiente virtual Python
sudo -u fnp python3 -m venv /home/fnp/venv

# Instalar dependências Python
sudo -u fnp /home/fnp/venv/bin/pip install \
    openai \
    anthropic \
    psycopg2-binary \
    pgvector \
    sqlalchemy \
    boto3 \
    pypdf \
    python-docx \
    python-pptx \
    pandas \
    pyarrow \
    openpyxl \
    tiktoken \
    python-dotenv \
    google-api-python-client \
    google-auth

echo "=== Dependências instaladas ==="

# Configurar agendamento automático de ingestão diária às 2h da manhã
(crontab -u fnp -l 2>/dev/null; echo "0 2 * * * /home/fnp/venv/bin/python /home/fnp/app/ingestor.py >> /var/log/fnp-ingestor.log 2>&1") | crontab -u fnp -

# Criar arquivo de registro de execução
touch /var/log/fnp-ingestor.log
chown fnp:fnp /var/log/fnp-ingestor.log

echo "=== Agendamento configurado: ingestão automática diária às 2h ==="
echo ""
echo "Próximos passos:"
echo "  1. Copiar ingestor.py para /home/fnp/app/"
echo "  2. Copiar .env para /home/fnp/app/.env"
echo "  3. Testar manualmente: sudo -u fnp /home/fnp/venv/bin/python /home/fnp/app/ingestor.py"
echo "  4. Acompanhar execução: tail -f /var/log/fnp-ingestor.log"

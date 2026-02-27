#!/bin/bash

# ==========================================================================
# Astral Cloud - Instalador Automático de Banco de Dados & phpMyAdmin
# Desenvolvido para: Ubuntu 20.04/22.04/24.04 e Debian 11/12/13
# ==========================================================================

# Cores e Formatação
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}     🚀 ASTRAL CLOUD - SETUP DE BANCO DE DADOS        ${NC}"
echo -e "${CYAN}======================================================${NC}\n"

# 1. Verificação de Root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}[ERRO] Por favor, execute este script como root (sudo su).${NC}"
  exit 1
fi

# Pega o IP da máquina para usar nas validações
IP_ADDR=$(curl -s -4 ifconfig.me)

# 2. Coleta de Dados com Validação (Impede que o cliente deixe em branco)
echo -e "${YELLOW}➤ Passo 1: Configuração de Acesso${NC}"
while [[ -z "$DB_NAME" ]]; do read -p "Nome do Banco de Dados: " DB_NAME; done
while [[ -z "$DB_USER" ]]; do read -p "Usuário do Banco: " DB_USER; done
while [[ -z "$DB_PASS" ]]; do read -p "Senha do Banco: " DB_PASS; done

echo -e "\n${YELLOW}➤ Passo 2: Configuração de Domínio e SSL${NC}"
echo -e "Você deseja usar um domínio personalizado com SSL/HTTPS? (s/n)"
read -r USE_SSL

if [[ "$USE_SSL" =~ ^[Ss]$ ]]; then
    read -p "Digite o domínio (ex: db.astralcloud.com): " DOMAIN
    echo -e "\n${RED}⚠️ ATENÇÃO IMPORTANTÍSSIMA ⚠️${NC}"
    echo -e "Para o SSL funcionar, o domínio ${CYAN}$DOMAIN${NC} DEVE estar apontado"
    echo -e "para o IP desta VPS: ${GREEN}$IP_ADDR${NC} (via Cloudflare ou Registro.br)."
    read -p "Você já fez esse apontamento e esperou propagar? (s/n): " DNS_OK
    
    if [[ ! "$DNS_OK" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Instalação de SSL cancelada. O painel será acessado via IP.${NC}"
        USE_SSL="n"
    fi
fi

echo -e "\n${GREEN}Iniciando a instalação mágica... Sente-se e relaxe! ☕${NC}\n"

# 3. Preparação do Sistema (Modo 100% Silencioso)
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# 4. Detecção de Porta Livre (Usando 'ss' que é nativo do Linux, mais seguro que lsof)
check_port() {
  local port=$1
  while ss -tuln | grep -q ":$port " ; do
    port=$((port+1))
  done
  echo $port
}
FINAL_PORT=$(check_port 80)
echo -e "[+] Porta selecionada para o Web Server: $FINAL_PORT"

# 5. Instalação de Pacotes Essenciais
echo -e "[+] Instalando Nginx, MariaDB, PHP e Certbot..."
apt-get install -y -qq mariadb-server nginx php-fpm php-mysql php-mbstring curl certbot python3-certbot-nginx > /dev/null

# Garante que os serviços iniciem com o boot da máquina
systemctl enable mariadb nginx > /dev/null 2>&1

# 6. Configuração do MariaDB (Acesso Externo)
echo -e "[+] Configurando MariaDB para acesso remoto..."
# Busca o arquivo de configuração correto dependendo da versão do SO
if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
elif [ -f /etc/mysql/my.cnf ]; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
fi
systemctl restart mariadb

# Aguarda o MariaDB subir completamente antes de injetar comandos
sleep 2

# Criação Segura do Banco e Usuários
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# 7. Instalação do phpMyAdmin (Sem interrupções na tela)
echo -e "[+] Instalando phpMyAdmin..."
echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get install -y -qq phpmyadmin > /dev/null

# 8. Detecção robusta do Socket do PHP-FPM
PHP_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)
if [ -z "$PHP_SOCK" ]; then
    # Fallback caso a busca falhe
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_SOCK="/var/run/php/php${PHP_VER}-fpm.sock"
fi

# 9. Configuração do Nginx
echo -e "[+] Configurando Web Server (Nginx)..."
SERVER_NAME_CONF="_"
if [[ "$USE_SSL" =~ ^[Ss]$ ]]; then
    SERVER_NAME_CONF="$DOMAIN"
fi

cat <<EOF > /etc/nginx/sites-available/astral-db
server {
    listen $FINAL_PORT;
    server_name $SERVER_NAME_CONF;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    # Aumenta limite de upload para importar bancos grandes
    client_max_body_size 512M;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Ativa o site e remove conflitos
ln -sf /etc/nginx/sites-available/astral-db /etc/nginx/sites-enabled/
if [ "$FINAL_PORT" == "80" ]; then
    rm -f /etc/nginx/sites-enabled/default
fi
systemctl restart nginx

# 10. Geração do SSL (Se solicitado e confirmado)
FINAL_URL="http://$IP_ADDR:$FINAL_PORT"

if [[ "$USE_SSL" =~ ^[Ss]$ ]]; then
    echo -e "[+] Gerando certificado SSL para $DOMAIN..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email > /dev/null 2>&1; then
        FINAL_URL="https://$DOMAIN"
        echo -e "${GREEN}[+] SSL gerado com sucesso!${NC}"
    else
        echo -e "${RED}[!] Falha ao gerar o SSL. Verifique se o DNS ($DOMAIN) aponta para $IP_ADDR.${NC}"
        echo -e "${YELLOW}[!] O painel continuará acessível via HTTP.${NC}"
        FINAL_URL="http://$DOMAIN:$FINAL_PORT"
    fi
fi

# 11. Otimização do PHP para Bancos Maiores
# Encontra o php.ini do fpm e aumenta os limites de upload para 512M
PHP_INI=$(find /etc/php/ -name "php.ini" | grep fpm | head -n 1)
if [ -n "$PHP_INI" ]; then
    sed -i 's/upload_max_filesize.*/upload_max_filesize = 512M/' "$PHP_INI"
    sed -i 's/post_max_size.*/post_max_size = 512M/' "$PHP_INI"
    systemctl restart php*-fpm > /dev/null 2>&1
fi

# 12. Tela de Sucesso Final
echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}   ✅ ASTRAL CLOUD - SERVIDOR PRONTO PARA USO!        ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "🌐 ${YELLOW}Acesse seu Painel:${NC} $FINAL_URL"
echo -e "🗄️  ${YELLOW}Nome do Banco:${NC}   $DB_NAME"
echo -e "👤 ${YELLOW}Usuário:${NC}         $DB_USER"
echo -e "🔑 ${YELLOW}Senha:${NC}           $DB_PASS"
echo -e "📡 ${YELLOW}Acesso Remoto:${NC}   Liberado (0.0.0.0 / %)"
echo -e "${CYAN}======================================================${NC}"
echo -e "💡 Dica: Use os dados acima para conectar seu servidor Minecraft,"
echo -e "   site ou bots do Discord hospedados em outros Nodes.\n"

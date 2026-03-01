#!/bin/bash

# ==========================================================================
# Instalador Automático de Banco de Dados & phpMyAdmin
# Compatibilidade: Ubuntu 20.04/22.04/24.04 e Debian 11/12/13
# ==========================================================================

# Cores e Formatação
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'

# Limpa a tela e mostra o Header
clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}     🚀 SETUP AUTOMÁTICO DE BANCO DE DADOS & PMA      ${NC}"
echo -e "${CYAN}======================================================${NC}\n"

# 1. Verificação de Root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}[ERRO] Por favor, execute este script como root (sudo su).${NC}"
  exit 1
fi

# Pega o IP da máquina
IP_ADDR=$(curl -s -4 ifconfig.me)

# 2. Menu Interativo Aprimorado
echo -e "${YELLOW}➤ O que você deseja fazer no servidor?${NC}\n"
echo -e "  ${GREEN}[1]${NC} Instalar Banco de Dados (MariaDB) + phpMyAdmin"
echo -e "  ${GREEN}[2]${NC} Instalar APENAS phpMyAdmin (Conectar em banco externo)"
echo -e "  ${MAGENTA}[3]${NC} 🗑️  Remover phpMyAdmin do servidor (Limpeza segura)"
echo -e "  ${RED}[0]${NC} Sair do Script\n"

while true; do
    read -p "Digite a opção desejada: " INSTALL_TYPE
    case $INSTALL_TYPE in
        [0-3]) break ;;
        *) echo -e "${RED}[!] Opção inválida. Digite 0, 1, 2 ou 3.${NC}" ;;
    esac
done

if [[ "$INSTALL_TYPE" == "0" ]]; then
    echo -e "\n${YELLOW}Saindo... Nenhuma alteração foi feita.${NC}"
    exit 0
fi

# ==========================================================================
# LÓGICA DE REMOÇÃO (OPÇÃO 3)
# ==========================================================================
if [[ "$INSTALL_TYPE" == "3" ]]; then
    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${MAGENTA}       🗑️ INICIANDO REMOÇÃO DO PHPMYADMIN...          ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    read -p "Qual foi o 'Nome do projeto' usado na instalação? (Deixe em branco se foi 'meupainel'): " CONFIG_NAME
    CONFIG_NAME=${CONFIG_NAME:-meupainel}
    CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd 'a-zA-Z0-9_-')

    echo -e "[+] Purgando pacote phpmyadmin e dependências não utilizadas..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y phpmyadmin > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1

    echo -e "[+] Removendo bloco de servidor do Nginx ($CONFIG_NAME)..."
    rm -f /etc/nginx/sites-available/$CONFIG_NAME
    rm -f /etc/nginx/sites-enabled/$CONFIG_NAME
    
    echo -e "[+] Reiniciando Nginx para aplicar as mudanças..."
    systemctl restart nginx > /dev/null 2>&1

    echo -e "\n${GREEN}✅ phpMyAdmin e suas configurações Nginx foram removidos!${NC}"
    echo -e "${YELLOW}Nota:${NC} Seus bancos de dados no MariaDB permanecem intactos e seguros."
    exit 0
fi

# ==========================================================================
# LÓGICA DE INSTALAÇÃO (OPÇÕES 1 e 2)
# ==========================================================================
echo -e "\n${YELLOW}➤ Passo 1: Configuração de Acesso${NC}"

read -p "Nome do projeto para configuração do Nginx (Ex: painel_db): " CONFIG_NAME
CONFIG_NAME=${CONFIG_NAME:-meupainel}
CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -cd 'a-zA-Z0-9_-')

# Coleta dados do banco apenas se for a Opção 1
if [[ "$INSTALL_TYPE" == "1" ]]; then
    while [[ -z "$DB_NAME" ]]; do read -p "Nome do Banco de Dados: " DB_NAME; done
    while [[ -z "$DB_USER" ]]; do read -p "Usuário do Banco: " DB_USER; done

    read -p "Senha do Banco (Deixe em branco para gerar automaticamente): " DB_PASS
    if [[ -z "$DB_PASS" ]]; then
        DB_PASS=$(openssl rand -base64 12)
        echo -e "${GREEN}[+] Senha forte gerada automaticamente!${NC}"
    fi
fi

echo -e "\n${YELLOW}➤ Passo 2: Configuração de Domínio e SSL${NC}"
echo -e "Você deseja usar um domínio personalizado com SSL/HTTPS? (s/n)"
read -r USE_SSL

if [[ "$USE_SSL" =~ ^[Ss]$ ]]; then
    read -p "Digite o domínio (ex: db.seudominio.com): " DOMAIN
    echo -e "\n${RED}⚠️ ATENÇÃO IMPORTANTÍSSIMA ⚠️${NC}"
    echo -e "Para o SSL funcionar, o domínio ${CYAN}$DOMAIN${NC} DEVE estar apontado"
    echo -e "para o IP desta VPS: ${GREEN}$IP_ADDR${NC} (via Cloudflare ou Registro.br)."
    read -p "Você já fez esse apontamento e esperou propagar? (s/n): " DNS_OK
    
    if [[ ! "$DNS_OK" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Instalação de SSL cancelada. O painel será acessado via IP.${NC}"
        USE_SSL="n"
    fi
fi

echo -e "\n${GREEN}Iniciando a instalação... Sente-se e relaxe! ☕${NC}\n"

# 4. Otimização de Mirrors (Brasil)
echo -e "[+] Otimizando repositórios do APT (Mirrors BR)..."
source /etc/os-release

if [ "$ID" == "ubuntu" ]; then
    if [ -f /etc/apt/sources.list ]; then
        sed -i -E 's|http://([a-z]{2}\.)?archive\.ubuntu\.com/ubuntu/?|http://br.archive.ubuntu.com/ubuntu/|g' /etc/apt/sources.list
    fi
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        sed -i -E 's|URIs: http://([a-z]{2}\.)?archive\.ubuntu\.com/ubuntu/?|URIs: http://br.archive.ubuntu.com/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources
    fi
elif [ "$ID" == "debian" ]; then
    if [ -f /etc/apt/sources.list ]; then
        sed -i -E 's|http://([a-z]{2}\.)?deb\.debian\.org/debian/?|http://ftp.br.debian.org/debian/|g' /etc/apt/sources.list
    fi
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        sed -i -E 's|URIs: http://([a-z]{2}\.)?deb\.debian\.org/debian/?|URIs: http://ftp.br.debian.org/debian/|g' /etc/apt/sources.list.d/debian.sources
    fi
fi

# 5. Preparação do Sistema
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# 6. Detecção de Porta Livre
check_port() {
  local port=$1
  while ss -tuln | grep -q ":$port " ; do
    port=$((port+1))
  done
  echo $port
}
FINAL_PORT=$(check_port 80)
echo -e "[+] Porta selecionada para o Web Server: $FINAL_PORT"

# 7. Liberação Automática de Firewall
if command -v ufw > /dev/null; then
    if ufw status | grep -q "Status: active"; then
        echo -e "[+] Firewall UFW detectado. Liberando portas..."
        ufw allow $FINAL_PORT/tcp > /dev/null 2>&1
        if [[ "$INSTALL_TYPE" == "1" ]]; then
            ufw allow 3306/tcp > /dev/null 2>&1
        fi
    fi
fi

# 8. Instalação de Pacotes Essenciais
echo -e "[+] Instalando pacotes necessários..."
PKGS="nginx php-fpm php-mysql php-mbstring curl certbot python3-certbot-nginx"
if [[ "$INSTALL_TYPE" == "1" ]]; then
    PKGS="$PKGS mariadb-server"
fi
apt-get install -y -qq $PKGS > /dev/null

systemctl enable nginx > /dev/null 2>&1
if [[ "$INSTALL_TYPE" == "1" ]]; then
    systemctl enable mariadb > /dev/null 2>&1
fi

# 9. Configuração do MariaDB (Apenas Opção 1)
if [[ "$INSTALL_TYPE" == "1" ]]; then
    echo -e "[+] Configurando MariaDB para acesso remoto..."
    if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
        sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
    elif [ -f /etc/mysql/my.cnf ]; then
        sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
    fi
    systemctl restart mariadb
    sleep 2

    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
fi

# 10. Instalação do phpMyAdmin
echo -e "[+] Instalando phpMyAdmin..."
echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get install -y -qq phpmyadmin > /dev/null

# Permite conectar em bancos externos se for apenas PMA
if [[ "$INSTALL_TYPE" == "2" ]]; then
    echo -e "[+] Ativando login em servidores externos no phpMyAdmin..."
    if [ -f /etc/phpmyadmin/config.inc.php ]; then
        if ! grep -q "AllowArbitraryServer" /etc/phpmyadmin/config.inc.php; then
            echo "\$cfg['AllowArbitraryServer'] = true;" >> /etc/phpmyadmin/config.inc.php
        fi
    fi
fi

# 11. Detecção robusta do Socket do PHP-FPM
PHP_SOCK=$(find /var/run/php/ -name "php*-fpm.sock" | head -n 1)
if [ -z "$PHP_SOCK" ]; then
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_SOCK="/var/run/php/php${PHP_VER}-fpm.sock"
fi

# 12. Configuração do Nginx Customizada
echo -e "[+] Configurando Web Server (Nginx)..."
SERVER_NAME_CONF="_"
if [[ "$USE_SSL" =~ ^[Ss]$ ]]; then
    SERVER_NAME_CONF="$DOMAIN"
fi

cat <<EOF > /etc/nginx/sites-available/$CONFIG_NAME
server {
    listen $FINAL_PORT;
    server_name $SERVER_NAME_CONF;

    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

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

ln -sf /etc/nginx/sites-available/$CONFIG_NAME /etc/nginx/sites-enabled/
if [ "$FINAL_PORT" == "80" ]; then
    rm -f /etc/nginx/sites-enabled/default
fi
systemctl restart nginx

# 13. Geração do SSL
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

# 14. Otimização do PHP para Bancos Maiores
PHP_INI=$(find /etc/php/ -name "php.ini" | grep fpm | head -n 1)
if [ -n "$PHP_INI" ]; then
    sed -i 's/upload_max_filesize.*/upload_max_filesize = 512M/' "$PHP_INI"
    sed -i 's/post_max_size.*/post_max_size = 512M/' "$PHP_INI"
    systemctl restart php*-fpm > /dev/null 2>&1
fi

# 15. Tela de Sucesso Final
echo -e "\n${CYAN}======================================================${NC}"
echo -e "${GREEN}   ✅ SERVIDOR PRONTO PARA USO!                       ${NC}"
echo -e "${CYAN}======================================================${NC}"
echo -e "🌐 ${YELLOW}Acesse seu Painel:${NC} $FINAL_URL"

if [[ "$INSTALL_TYPE" == "1" ]]; then
    echo -e "🗄️  ${YELLOW}Nome do Banco:${NC}   $DB_NAME"
    echo -e "👤 ${YELLOW}Usuário:${NC}         $DB_USER"
    echo -e "🔑 ${YELLOW}Senha:${NC}           $DB_PASS"
    echo -e "📡 ${YELLOW}Acesso Remoto:${NC}   Liberado (Porta 3306 / %)"
else
    echo -e "💡 ${YELLOW}Nota:${NC} O phpMyAdmin foi configurado para aceitar"
    echo -e "         conexões de servidores externos. Na tela de"
    echo -e "         login, digite o IP do banco no campo 'Servidor'."
fi

echo -e "${CYAN}======================================================${NC}"
echo -e "💡 Guarde estes dados em um local seguro.\n"

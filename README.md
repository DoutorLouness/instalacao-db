# 🚀 Astral Cloud - Scripts de Automação para VPS

Bem-vindo ao repositório oficial de scripts da **Astral Cloud**. Aqui você encontra ferramentas desenvolvidas para facilitar a gestão da sua VPS, focando em automação, performance e facilidade de uso para todos os níveis de conhecimento.

---

## 🛠️ Instalador de Banco de Dados & phpMyAdmin

Este script automatiza 100% da configuração de um ambiente de banco de dados profissional na sua VPS. Ideal para quem precisa de um painel visual para gerenciar dados de servidores de jogos (Minecraft, FiveM), sites ou bots.

### ✨ O que o script faz:
* **Detecção Inteligente de Portas:** Identifica automaticamente portas livres (80, 81, 82...) para evitar conflitos.
* **Stack Completa:** Instala Nginx, MariaDB e PHP-FPM de forma silenciosa.
* **Acesso Externo Habilitado:** Configura o banco de dados para aceitar conexões remotas (`%`), permitindo conexão entre diferentes Nodes.
* **SSL Automático:** Gera certificado HTTPS via Certbot (Let's Encrypt) com um clique.
* **Otimização de Upload:** Configura o PHP para suportar uploads de bancos de dados de até **512MB**.
* **Compatibilidade:** Suporte total para Ubuntu 20.04+ e Debian 11+.

---

## 🚀 Como usar

Para rodar o instalador na sua VPS, basta copiar e colar o comando abaixo no seu terminal:

```bash
bash <(curl -s [https://raw.githubusercontent.com/SEU_USUARIO/NOME_DO_REPO/main/db.sh](https://raw.githubusercontent.com/SEU_USUARIO/NOME_DO_REPO/main/db.sh))

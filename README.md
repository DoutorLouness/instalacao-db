# 🚀 Astral Cloud - Instalador de Banco de Dados

Bem-vindo ao repositório oficial de automação da **Astral Cloud**. Desenvolvemos estas ferramentas para transformar sua VPS em um ambiente profissional com apenas um comando. 

> **Foco:** Performance, Segurança e simplicidade para usuários de todos os níveis.

---

## 🗄️ Instalador de Banco de Dados & phpMyAdmin

Cansado de gerenciar MySQL pelo terminal? Este script configura uma stack completa de banco de dados com painel visual, otimizada para servidores de jogos (Minecraft, FiveM), sites e aplicações.

### ✨ Diferenciais do Script
* **🚀 Instalação Instantânea:** Nginx + MariaDB + PHP-FPM configurados em menos de 2 minutos.
* **🔌 Porta Inteligente:** O script detecta se a porta 80 está em uso e aloca automaticamente a próxima disponível (81, 82...).
* **🌍 Conexão Remota (%):** Bancos de dados configurados para aceitar conexões de qualquer Node ou servidor externo.
* **🔐 SSL One-Click:** Integração nativa com Certbot para gerar HTTPS no seu domínio.
* **🐘 PHP Otimizado:** Limite de upload aumentado para **512MB** (importação de bancos grandes sem erro).
* **🐧 Ampla Compatibilidade:** Testado e aprovado em Ubuntu 20.04 até 24.04 e Debian 11 até 13.

---

## ⚡ Como Instalar

Não precisa baixar nada manualmente. Basta copiar o comando abaixo, colar no terminal da sua VPS e seguir as instruções na tela:

```bash
bash <(curl -s https://raw.githubusercontent.com/DoutorLouness/instalacao-db/refs/heads/main/install.sh)

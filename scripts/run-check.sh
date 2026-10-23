#!/bin/bash

################################################################################
#                                                                              #
#  ONE-LINER EXECUTOR - SCRIPTS DE VALIDAÇÃO DO GITHUB PRIVADO                #
#                                                                              #
#  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16                        #
#  Data: 23/10/2024                                                           #
#  Versão: 1.0                                                                #
#                                                                              #
#  USO (one-liner):                                                            #
#                                                                              #
#  GITHUB_TOKEN="seu_token" bash <(curl -fsSL \                               #
#    "https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/\     #
#    run-check.sh") pg01                                                      #
#                                                                              #
#  Ou com autenticação SSH (mais simples):                                    #
#  bash <(curl -fsSL https://..../run-check-ssh.sh) pg01                      #
#                                                                              #
################################################################################

set +e  # Continua mesmo com erros

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Parâmetro: tipo de servidor
SERVER_TYPE="${1:-interactive}"

echo -e "${BOLD}${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║  EXECUTAR VALIDAÇÃO DO GITHUB PRIVADO (ONE-LINER)              ║"
echo "║  Projeto: Aeroporto - Zabbix 7.0 LTS + PostgreSQL 16           ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

################################################################################
# FUNÇÃO: Baixar script com token
################################################################################

download_script() {
    local script_name="$1"
    local token="$2"
    
    if [ -z "$token" ]; then
        # Tentar sem token (público)
        curl -fsSL "https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/$script_name" 2>/dev/null
    else
        # Com token (privado)
        curl -fsSL -H "Authorization: token $token" \
            "https://raw.githubusercontent.com/Reisvmr/aeroporto/main/scripts/$script_name" 2>/dev/null
    fi
}

################################################################################
# FUNÇÃO: Validar resultado
################################################################################

validate_download() {
    local content="$1"
    
    if [ -z "$content" ]; then
        return 1
    fi
    
    if [[ "$content" == *"404"* ]] || [[ "$content" == *"Not Found"* ]]; then
        return 1
    fi
    
    if [[ "$content" == *"Bad credentials"* ]]; then
        return 2  # Token inválido
    fi
    
    return 0
}

################################################################################
# MENU OU PARÂMETRO
################################################################################

if [ "$SERVER_TYPE" = "interactive" ]; then
    echo -e "${BOLD}Qual servidor deseja validar?${NC}\n"
    echo "1) pg01         - PostgreSQL Primary (10.31.38.64)"
    echo "2) zbx-server   - Zabbix Server"
    echo "3) zbx-fe       - Zabbix Frontend"
    echo ""
    read -p "Escolha [1-3]: " choice
    
    case $choice in
        1) SERVER_TYPE="pg01" ;;
        2) SERVER_TYPE="zbx-server" ;;
        3) SERVER_TYPE="zbx-fe" ;;
        *) 
            echo -e "${RED}❌ Opção inválida!${NC}"
            exit 1
            ;;
    esac
fi

################################################################################
# MAPEAR TIPO PARA ARQUIVO
################################################################################

case $SERVER_TYPE in
    pg01)
        SCRIPT_FILE="check-server-pg-01-IMPROVED.sh"
        DESCRIPTION="PostgreSQL Primary (10.31.38.64)"
        ;;
    pg01-orig)
        SCRIPT_FILE="check-server-pg-01.sh"
        DESCRIPTION="PostgreSQL Primary v1.0 (original)"
        ;;
    zbx-server)
        SCRIPT_FILE="check-server-zbx-server-01-IMPROVED.sh"
        DESCRIPTION="Zabbix Server"
        ;;
    zbx-server-orig)
        SCRIPT_FILE="check-server-zbx-server-01.sh"
        DESCRIPTION="Zabbix Server v1.0 (original)"
        ;;
    zbx-fe)
        SCRIPT_FILE="check-server-zbx-fe-01-IMPROVED.sh"
        DESCRIPTION="Zabbix Frontend"
        ;;
    zbx-fe-orig)
        SCRIPT_FILE="check-server-zbx-fe-01.sh"
        DESCRIPTION="Zabbix Frontend v1.0 (original)"
        ;;
    *)
        echo -e "${RED}❌ Servidor desconhecido: $SERVER_TYPE${NC}\n"
        echo "Opções válidas:"
        echo "  pg01, pg01-orig"
        echo "  zbx-server, zbx-server-orig"
        echo "  zbx-fe, zbx-fe-orig"
        exit 1
        ;;
esac

echo -e "${BOLD}Servidor: $DESCRIPTION${NC}"
echo -e "${BOLD}Script: $SCRIPT_FILE${NC}\n"

################################################################################
# OBTER TOKEN (se existir)
################################################################################

if [ -z "$GITHUB_TOKEN" ] && [ -f ~/.github_token ]; then
    GITHUB_TOKEN=$(cat ~/.github_token 2>/dev/null)
fi

if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${GREEN}✅ Token GitHub detectado${NC}\n"
else
    echo -e "${YELLOW}⚠️  Sem token (tentando acesso público)${NC}\n"
fi

################################################################################
# BAIXAR SCRIPT
################################################################################

echo -e "${BOLD}Baixando script...${NC}"

SCRIPT_CONTENT=$(download_script "$SCRIPT_FILE" "$GITHUB_TOKEN")

validate_download "$SCRIPT_CONTENT"
result=$?

if [ $result -eq 1 ]; then
    echo -e "${RED}❌ ERRO: Script não encontrado ou acesso negado!${NC}\n"
    echo "Causas possíveis:"
    echo "  • Arquivo não existe no repositório"
    echo "  • Repositório não é acessível (privado)"
    echo "  • Token não foi fornecido"
    echo ""
    echo "Soluções:"
    echo "  1. Usar token (repositório privado):"
    echo "     export GITHUB_TOKEN='seu_token_github'"
    echo "     bash <(curl -fsSL https://...) pg01"
    echo ""
    echo "  2. Ou usar SSH (se configurado):"
    echo "     ssh -T git@github.com  # testar acesso"
    echo ""
    echo "  3. Ou criar arquivo ~/.github_token:"
    echo "     echo 'seu_token' > ~/.github_token"
    echo "     chmod 600 ~/.github_token"
    exit 1
elif [ $result -eq 2 ]; then
    echo -e "${RED}❌ ERRO: Token GitHub inválido!${NC}\n"
    echo "Verifique:"
    echo "  • Token expirado"
    echo "  • Token não tem permissão 'repo'"
    echo "  • Token digitado incorretamente"
    exit 1
fi

echo -e "${GREEN}✅ Script baixado com sucesso!${NC}\n"

################################################################################
# EXECUTAR SCRIPT
################################################################################

echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Executando: $DESCRIPTION${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}\n"

# Executar script em subshell (importante para one-liner)
eval "$SCRIPT_CONTENT"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✅ Validação concluída com sucesso!${NC}\n"
else
    echo -e "\n${YELLOW}${BOLD}⚠️  Validação concluída (verifique relatório)${NC}\n"
fi

exit $exit_code

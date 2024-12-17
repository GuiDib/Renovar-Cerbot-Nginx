#!/bin/bash

# Verifica se o comando certbot está instalado
if ! command -v certbot &> /dev/null; then
    echo "Certbot não está instalado. Instale o certbot e tente novamente."
    exit 1
fi

# Diretório onde estão os certificados configurados
CERT_DIR="/etc/letsencrypt/live"

# Data atual em segundos desde 1970-01-01
CURRENT_DATE=$(date +%s)

# Flag para indicar se houve renovação
RENEWED=false

echo "Verificando certificados que expiram em 7 dias ou menos..."

# Loop pelos diretórios dos certificados
for DOMAIN_DIR in "$CERT_DIR"/*; do
    if [ -d "$DOMAIN_DIR" ]; then
        DOMAIN=$(basename "$DOMAIN_DIR")
        CERT_FILE="$DOMAIN_DIR/cert.pem"

        # Verifica se o arquivo de certificado existe
        if [ -f "$CERT_FILE" ]; then
            # Obtém a data de expiração do certificado
            EXPIRATION_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
            EXPIRATION_DATE_SECONDS=$(date -d "$EXPIRATION_DATE" +%s)

            # Calcula os dias restantes
            DAYS_LEFT=$(( (EXPIRATION_DATE_SECONDS - CURRENT_DATE) / 86400 ))

            echo "Certificado do domínio $DOMAIN expira em $DAYS_LEFT dias."

            # Verifica se faltam 7 dias ou menos
            if [ "$DAYS_LEFT" -le 7 ] && [ "$DAYS_LEFT" -ge 0 ]; then
                echo "Renovando certificado do domínio $DOMAIN..."
                certbot certonly --nginx --non-interactive --quiet --agree-tos -d "$DOMAIN"
                if [ $? -eq 0 ]; then
                    echo "Certificado do domínio $DOMAIN renovado com sucesso!"
                    RENEWED=true
                else
                    echo "Erro ao renovar o certificado do domínio $DOMAIN."
                fi
            fi
        else
            echo "Arquivo de certificado não encontrado para o domínio $DOMAIN."
        fi
    fi
done

# Se algum certificado foi renovado, recarrega o Nginx
if [ "$RENEWED" = true ]; then
    echo "Certificados renovados. Recarregando configurações do Nginx..."
    nginx -s reload
    echo "Configurações do Nginx recarregadas com sucesso!"
else
    echo "Nenhum certificado precisava de renovação."
fi

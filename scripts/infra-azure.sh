#!/bin/bash
# =====================================================================
#  PrimeiroPasso (Ventrya API) - Provisionamento de infraestrutura Azure
#  Executar no Azure Cloud Shell (Bash):   bash infra-azure.sh
#
#  Cria:
#    - Resource Group
#    - Azure Container Registry (ACR)  -> guarda a imagem da API (push pela Release)
#    - ACI Oracle Database 23ai Free   -> banco de dados em nuvem
#    - ACI RabbitMQ                     -> mensageria usada pela API
#  O container da API (ACI) é criado/atualizado pela pipeline de Release.
# =====================================================================
set -e

# ---------- PARÂMETROS (altere o RM se precisar) ----------
RM="563512"
LOCATION="eastus"
RG="rg-ventrya-gs-${RM}"
ACR_NAME="acrventrya${RM}"
ACI_DB="aci-ventrya-oracle-${RM}"
ACI_MQ="aci-ventrya-rabbitmq-${RM}"
ACI_APP="aci-ventrya-api-${RM}"
DNS_DB="ventrya-db-${RM}"
DNS_MQ="ventrya-mq-${RM}"
DNS_APP="ventrya-api-${RM}"
DB_USERNAME="ventrya"
MQ_USER="ventrya"
SECRETS_FILE="$HOME/ventrya-secrets.txt"   # fica no Cloud Shell, NUNCA no repositório

# ---------- SENHAS (geradas na hora, sem senha no código) ----------
gen_pwd() { echo "Vt$(openssl rand -hex 10)X9"; }
ORACLE_SYS_PASSWORD="${ORACLE_SYS_PASSWORD:-$(gen_pwd)}"
DB_PASSWORD="${DB_PASSWORD:-$(gen_pwd)}"
MQ_PASSWORD="${MQ_PASSWORD:-$(gen_pwd)}"
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 48 | tr -d '\n')}"

echo ">> Registrando providers..."
az provider register --namespace Microsoft.ContainerInstance --wait
az provider register --namespace Microsoft.ContainerRegistry --wait

echo ">> Resource Group: $RG"
az group create --name "$RG" --location "$LOCATION" -o none

echo ">> ACR: $ACR_NAME (Standard + admin + pull anônimo)"
az acr show --name "$ACR_NAME" -o none 2>/dev/null || \
  az acr create --resource-group "$RG" --name "$ACR_NAME" --sku Standard --admin-enabled true -o none
az acr update --name "$ACR_NAME" --admin-enabled true --anonymous-pull-enabled true -o none
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)
ACR_SERVER="${ACR_NAME}.azurecr.io"

# Importa as imagens para o ACR (evita o rate limit do Docker Hub no ACI)
import_img() {   # $1 = nome no ACR, demais = fontes em ordem de tentativa
  local target="$1"; shift
  if az acr repository show --name "$ACR_NAME" --image "$target" -o none 2>/dev/null; then
    echo "   $target já está no ACR"; return 0
  fi
  for src in "$@"; do
    echo "   importando $src ..."
    if az acr import --name "$ACR_NAME" --source "$src" --image "$target" --force -o none; then
      echo "   OK: $target"; return 0
    fi
  done
  echo "ERRO: não foi possível importar $target"; exit 1
}
echo ">> Importando imagens para o ACR"
import_img "oracle-free:23-slim" ghcr.io/gvenzl/oracle-free:23-slim docker.io/gvenzl/oracle-free:23-slim
import_img "rabbitmq:3-management" public.ecr.aws/docker/library/rabbitmq:3-management docker.io/library/rabbitmq:3-management

# Cria ACI via YAML (sem credencial de registry: o ACR tem pull anônimo)
create_aci() {   # $1 = arquivo yaml
  az container create --resource-group "$RG" --file "$1" -o none
  rm -f "$1"
}

echo ">> ACI Oracle: $ACI_DB (pode levar alguns minutos)"
az container delete -g "$RG" -n "$ACI_DB" --yes -o none 2>/dev/null || true
cat > aci-db.yaml <<EOF
apiVersion: '2019-12-01'
location: $LOCATION
name: $ACI_DB
type: Microsoft.ContainerInstance/containerGroups
properties:
  osType: Linux
  restartPolicy: Always
  ipAddress:
    type: Public
    dnsNameLabel: $DNS_DB
    ports:
      - protocol: tcp
        port: 1521
  containers:
    - name: oracle
      properties:
        image: $ACR_SERVER/oracle-free:23-slim
        ports:
          - port: 1521
        resources:
          requests:
            cpu: 2
            memoryInGb: 4
        environmentVariables:
          - name: APP_USER
            value: "$DB_USERNAME"
          - name: ORACLE_PASSWORD
            secureValue: "$ORACLE_SYS_PASSWORD"
          - name: APP_USER_PASSWORD
            secureValue: "$DB_PASSWORD"
EOF
create_aci aci-db.yaml

echo ">> ACI RabbitMQ: $ACI_MQ"
az container delete -g "$RG" -n "$ACI_MQ" --yes -o none 2>/dev/null || true
cat > aci-mq.yaml <<EOF
apiVersion: '2019-12-01'
location: $LOCATION
name: $ACI_MQ
type: Microsoft.ContainerInstance/containerGroups
properties:
  osType: Linux
  restartPolicy: Always
  ipAddress:
    type: Public
    dnsNameLabel: $DNS_MQ
    ports:
      - protocol: tcp
        port: 5672
      - protocol: tcp
        port: 15672
  containers:
    - name: rabbitmq
      properties:
        image: $ACR_SERVER/rabbitmq:3-management
        ports:
          - port: 5672
          - port: 15672
        resources:
          requests:
            cpu: 1
            memoryInGb: 1.5
        environmentVariables:
          - name: RABBITMQ_DEFAULT_USER
            value: "$MQ_USER"
          - name: RABBITMQ_DEFAULT_PASS
            secureValue: "$MQ_PASSWORD"
EOF
create_aci aci-mq.yaml

DB_FQDN=$(az container show -g "$RG" -n "$ACI_DB" --query ipAddress.fqdn -o tsv)
MQ_FQDN=$(az container show -g "$RG" -n "$ACI_MQ" --query ipAddress.fqdn -o tsv)
DB_URL="jdbc:oracle:thin:@//${DB_FQDN}:1521/FREEPDB1"

echo ">> Aguardando o Oracle ficar pronto..."
for i in $(seq 1 40); do
  if az container logs -g "$RG" -n "$ACI_DB" 2>/dev/null | grep -q "DATABASE IS READY TO USE"; then
    echo "   Oracle pronto!"; break
  fi
  echo "   ...ainda iniciando ($i/40)"; sleep 15
done

cat > "$SECRETS_FILE" <<EOF
# ==== Copie para Azure DevOps > Pipelines > Library > Variable group "ventrya-vars" ====
# (marque como SECRET as que têm [SECRET])
RG=$RG
LOCATION=$LOCATION
ACR_NAME=$ACR_NAME
ACR_USERNAME=$ACR_USERNAME
ACR_PASSWORD=$ACR_PASSWORD            [SECRET]
ACI_APP_NAME=$ACI_APP
DNS_APP=$DNS_APP
DB_URL=$DB_URL
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD              [SECRET]
JWT_SECRET=$JWT_SECRET                [SECRET]
RABBITMQ_HOST=$MQ_FQDN
RABBITMQ_USER=$MQ_USER
RABBITMQ_PASSWORD=$MQ_PASSWORD        [SECRET]

# ==== Conexão no SQL Developer (para mostrar os SELECTs no vídeo) ====
# Host: $DB_FQDN   Porta: 1521   Service name: FREEPDB1
# Usuário: $DB_USERNAME   Senha: $DB_PASSWORD
# (usuário SYSTEM, se precisar: senha $ORACLE_SYS_PASSWORD)

# ==== RabbitMQ painel ====
# http://$MQ_FQDN:15672  ($MQ_USER / $MQ_PASSWORD)

# ==== API (depois da 1a Release) ====
# http://$DNS_APP.$LOCATION.azurecontainer.io:8080
EOF

echo ""
echo "=================================================================="
echo " Infra criada! Variáveis salvas em: $SECRETS_FILE"
echo "=================================================================="
cat "$SECRETS_FILE"
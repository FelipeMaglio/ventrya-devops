#!/bin/bash
# Religa o ambiente na ordem: Oracle -> RabbitMQ -> API.
# Obs.: o Oracle volta vazio; a API recria as tabelas via Flyway ao subir.
RG="rg-ventrya-gs-563512"
az container start -g "$RG" -n aci-ventrya-oracle-563512
echo "Aguardando o Oracle..."
for i in $(seq 1 40); do
  if az container logs -g "$RG" -n aci-ventrya-oracle-563512 2>/dev/null | grep -q "DATABASE IS READY TO USE"; then
    echo "Oracle pronto!"; break
  fi
  sleep 15
done
az container start -g "$RG" -n aci-ventrya-rabbitmq-563512
az container start -g "$RG" -n aci-ventrya-api-563512
az container list -g "$RG" --query "[].{nome:name, estado:instanceView.state}" -o table
echo "Swagger: http://ventrya-api-563512.eastus.azurecontainer.io:8080/swagger-ui.html"

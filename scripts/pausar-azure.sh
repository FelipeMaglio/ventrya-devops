#!/bin/bash
# Para os containers (sem cobrança de processamento). Nomes e endereços são mantidos.
RG="rg-ventrya-gs-563512"
az container stop -g "$RG" -n aci-ventrya-api-563512
az container stop -g "$RG" -n aci-ventrya-rabbitmq-563512
az container stop -g "$RG" -n aci-ventrya-oracle-563512
az container list -g "$RG" --query "[].{nome:name, estado:instanceView.state}" -o table

#!/bin/bash
# Remove TODOS os recursos da GS (use só depois da apresentação)
RM="563512"
az group delete --name "rg-ventrya-gs-${RM}" --yes --no-wait
echo "Exclusão do resource group rg-ventrya-gs-${RM} iniciada."

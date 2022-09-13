RESOURCE_GROUP=daprchaosloadwe5
CLUSTERNAME=daprchaosloadcluster5
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
az group create --name $RESOURCE_GROUP --location westeurope
az aks create -g $RESOURCE_GROUP -n $CLUSTERNAME  --node-count 1
az aks get-credentials -n $CLUSTERNAME -g $RESOURCE_GROUP
RESOURCE_ID=$(az aks show -n $CLUSTERNAME -g $RESOURCE_GROUP --query "id")

#dapr (make sure provider is registered) 
#az provider register --namespace Microsoft.KubernetesConfiguration
#az provider list --query "[?contains(namespace,'Microsoft.KubernetesConfiguration')]" -o table

az k8s-extension create --cluster-type managedClusters --cluster-name $CLUSTERNAME --resource-group $RESOURCE_GROUP --name myDaprExtension --extension-type Microsoft.Dapr

#chaos
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update
kubectl create ns chaos-testing
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing --set chaosDaemon.runtime=containerd --set chaosDaemon.socketPath=/run/containerd/containerd.sock

kubectl get po -n chaos-testing

#enable chaos for aks
#create target
TARGET_ID=$(az rest --method put --url "https://management.azure.com/$RESOURCE_ID/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh?api-version=2021-09-15-preview" --body "{\"properties\":{}}" --query id)
echo $TARGET_ID

cp networkingchaos.template networkingchaos_working.json
sed -i "s|MYCHAOSTARGET|$TARGET_ID|" networkingchaos_working.json

az rest --method put --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTERNAME/providers/Microsoft.Chaos/targets/Microsoft-AzureKubernetesServiceChaosMesh/capabilities/NetworkChaos-2.1?api-version=2021-09-15-preview"  --body "{\"properties\":{}}"

# create experiment
EXPERIMENT_NAME=NetworkingChaosExperiment$(date +%s)
EXPERIMENT_PRINCIPAL_ID=$(az rest --method put --uri https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXPERIMENT_NAME?api-version=2021-09-15-preview --body @networkingchaos_working.json --query identity.principalId -o tsv)

az role assignment create --role "Azure Kubernetes Service Cluster Admin Role" --assignee-object-id $EXPERIMENT_PRINCIPAL_ID --scope $RESOURCE_ID	

# deploy app
kubectl apply -f .

#run experiment
az rest --method post --uri https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Chaos/experiments/$EXPERIMENT_NAME/start?api-version=2021-09-15-preview


# 
cp test.template test.http

FE_NO_DAPR=$(kubectl get svc  fe-no-dapr -o json | jq -r .status.loadBalancer.ingress[0].ip)
echo "FRONTEND without DAPR:" $FE_NO_DAPR
sed -i "s|FE_NO_DAPR|$FE_NO_DAPR|" test.http


FE_DAPR=$(kubectl get svc  frontendapp-a -o json | jq  -r .status.loadBalancer.ingress[0].ip)
echo "FRONTEND with DAPR:" $FE_DAPR
sed -i "s|FE_DAPR|$FE_DAPR|" test.http

BACKEND=$(kubectl get svc  backendapp-c -o json | jq -r .status.loadBalancer.ingress[0].ip )
echo "BACKEND:" $BACKEND
sed -i "s|BACKEND|$BACKEND|" test.http

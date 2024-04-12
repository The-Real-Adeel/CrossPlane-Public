# Crossplane

Crossplane lets you build control planes for applications and infrastructure without writing scripts or managing through the portol, instead you write yaml manifests to declare the resources.

It essentially turns the k8s cluster in to the 'engine' that manages your resources and infrasturue on Azure. 

It holds the manifests inside the k8s cluster as the current state. it updates periodcally to match state if it ever drifts from it (default is hourly)

You write and update these yaml files (desired state) and push them into k8s cluster engine (current state). The cluster has the necessary perms to ensure what you declared, it can push to deploy into Azure.

This tutorial focuses on Crossplane using AKS, you could alternatively use the offical one by following this (but it requires a local k8s cluster and does not use managed identities): https://docs.crossplane.io/latest/getting-started/provider-azure/

Since we want to leverage the cloud so we will use AKS with little setup locally. You can follow this guide instead

# Pre-reqs:

I have divided the repo in two seperate folders. one for deployment of Terraform and another for deployment of Crossplane with a few examples of resources you can deploy.

**Ensure you have the ability to run terraform, kubectl, helm and az cmds in your computer's terminal by installing all the tools:**
1. Install Terraform: https://developer.hashicorp.com/terraform/install
2. Install Helm: https://helm.sh/docs/intro/install/
3. Install Kubernetes: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/ 
4. Install Azure CLI: https://learn.microsoft.com/en-us/dotnet/azure/install-azure-cli 

**Ensure you setup AKS before running the commands below by running terraform files in this collection.**

Notes for the terraform deployment, it can be found in the main.tf
Ensure you update your tenant ID and Sub in the config file: provider.tf and have the data source for resource group created (where we will depoy crossplane resources to)

# Getting Started

**If you haven't already login to azure using Azure CLI on the terminal**

```
az login
```

Change directroy if you need to the one with AKS: az account set --subscription "subID"

**Get the data of existing services needed to connect to AKS & alter providerconfig later**

```
$AKSRG = 'RG_AKS'
$AKSNAME = 'corpo-aks-crossplane'
$identityName = 'aks-mi'
$identity = az identity show --name $identityName --resource-group $AKSRG --query id -o tsv
$clientId = az identity show --name $identityName --resource-group $AKSRG --query clientId -o tsv
$identity
```

NOTE: change directory to parent folder if you are inside terraform subdirectory in the terminal

```
cd ..

```

**Add the clientID value to the providerconfig file so it can be used to authN for crossplane deployments**

Since each deployment of terrafrom rebuilds the identities as well. I have the following powershell cmds to take the clientID from above & inject it in the authN yaml file.

Note: I have removed tenant ID and subscription ID from the file az-provider-config.yaml. Please enter those values for your own tenant/sub.

```
$filePath = (location).path + "\crossplane\providers\az-provider-config.yaml"
$content = Get-Content -Path $filePath
$newClientID = '"$clientId"'
$pattern = '(clientID: ).*'
$updatedContent = $content -replace $pattern, "`$1`"$clientid`""
$updatedContent | Set-Content -Path $filePath
```
Ensure the value has been updated (using the ID of your user-assigned managed identity) before proceeding

**With that information we can connect to the AKS**

```
az aks get-credentials --resource-group $AKSRG --name $AKSNAME  --overwrite-existing
```

**Update connection to use Managed Identity**
```
az aks update --resource-group $AKSRG --name $AKSNAME --enable-managed-identity --assign-identity $identity
```
Now you are ready to punch in kubectl cmds to AKS

# Configure the AKS Cluster with Crossplane
**Create the namespace for crossplane, upbound is parent company's name**
```
kubectl create namespace upbound-system
```

**Add helm repo / Update Repo, if not already done. Otherwise skip**

This just downloads files and updates the repo you downloaded to ensure its the latest. 
You will have a copy on your computer once you run this

```
helm repo add upbound-system https://charts.crossplane.io/stable
helm repo update
```

**Install crossplane on the namespace using Helm**
```
helm install crossplane --namespace upbound-system crossplane-stable/crossplane
kubectl get pods -n upbound-system
```

Wait for the pods to fire up, you can check status: **kubectl get pods -n upbound-system**

# Configure the providers
**Management Providers**

1. az-management-provider.yaml has the provider needed to Azure Management
2. az-provider-config.yaml has the managed identity we will use for this deployment which is the user-assigned managed identities of the kubelets

```
kubectl apply -f ".\crossplane\Providers\az-management-provider.yaml"
```
wait a bit before applying the next config as it needs dependancies from the last. If it fails just try again later.
```
kubectl apply -f ".\crossplane\Providers\az-provider-config.yaml"
```

**Resource Providers**

Depending on resource type (Network, Storage, etc), you will need providers for them as well.

The list of providers is found here https://marketplace.upbound.io/providers/upbound/provider-family-azure/v0.41.0/providers.

1. azprovidernetwork has the provider needed for Network Resources (that you can deploy)
2. az-storage-provider.yaml has the provider needed for Storage Resources (that you can deploy)

```
kubectl apply -f ".\crossplane\Providers\az-network-provider.yaml"
kubectl apply -f ".\crossplane\Providers\az-storage-provider.yaml"
```

**Verify cmds**
kubectl get providers
kubectl get pods -n upbound-system

# Deploy and manage through crossplane

**To create**
Now lets create & manage resources using crossplane by pushing the manifest files
```
kubectl create -f ".\crossplane\Resources\VirtualNetworkV2.yaml"
kubectl create -f ".\crossplane\Resources\StorageAccount.yaml"
```


**To Modify**
After you have made changes run the following
```
kubectl apply -f ".\crossplane\Resources\VirtualNetworkV2.yaml"
```

**To Log**

Set of cmds to get different kinds of data
```

kubectl describe -f ".\crossplane\Resources\VirtualNetworkV2.yaml"

kubectl get pods -n upbound-system

kubectl get -n upbound-system virtualnetwork

kubectl get pods -A

kubectl get crds accounts.storage.azure.upbound.io

kubectl get crds accounts.storage.azure.upbound.io yaml

```

**To delete**

To delete them run the following, it has a few parts that you need to take from elsewhere.
1. "virtualnetwork" = kind found in manifest
2. "network" = from api in az-network-provider, the first part 
3. "corpo-vnet-001" = name found in metadata in the resource VirtualNetwork.yaml

```
kubectl delete virtualnetwork.network corpo-vnet-001
kubectl delete account.storage corpostracct001
```

To test: what happens if I instead run: **kubectl delete -f ".\crossplane\Resources\VirtualNetworkV2.yaml"**

# Resources used
Find the authN information here
https://docs.upbound.io/providers/provider-azure/authentication/

Find the getting started example here
https://docs.crossplane.io/latest/getting-started/provider-azure/ 

Find more information on the providers here
https://github.com/upbound/provider-azure?tab=readme-ov-file

latest provider info found here, select install manifest:
https://marketplace.upbound.io/providers/upbound/provider-azure/v0.41.0/docs/quickstart 
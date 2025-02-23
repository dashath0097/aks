provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "AKS"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "myAKSCluster"
  location           = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix         = "myaks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      if ! command -v az &> /dev/null; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash || curl -sL https://aka.ms/InstallAzureCLI | bash
        export PATH=$HOME/.local/bin:$PATH
      fi
      az aks get-credentials --resource-group AKS --name myAKSCluster --overwrite-existing
    EOT
  }
}






# Deploy Kubernetes resources
resource "null_resource" "deploy_app" {
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF
    EOT
  }
  depends_on = [null_resource.kubeconfig]
}

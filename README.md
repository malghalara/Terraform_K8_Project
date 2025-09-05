# Kubernetes Core Concepts Visualization & Networking Demo

This project provisions a **Kubernetes cluster on DigitalOcean using Terraform** and demonstrates **core Kubernetes concepts** by deploying an nginx application and testing networking (kube-proxy, DNS inside pods, NodePort access).

---

## Objectives

* Provision infrastructure (1 master, 2 worker nodes) with Terraform.
* Install and configure Kubernetes from scratch using **kubeadm**.
* Deploy a sample **nginx application**.
* Test Kubernetes networking concepts:

  * Pod-to-Pod communication.
  * Service abstraction with **kube-proxy**.
  * DNS resolution inside pods with **CoreDNS**.
  * External access using **NodePort**.

---

## 🛠Prerequisites

* DigitalOcean account + API Token.
* SSH key added to DigitalOcean.
* Terraform binary (`terraform.exe`) in project folder.
* SSH client.
* Ubuntu 22.04 for droplets.

---


## Step 1: Provision Infrastructure with Terraform

### 1. Configure variables

Create `terraform.tfvars` (not pushed to GitHub) with your token + SSH key ID:

```hcl
do_token   = "your_digitalocean_api_token"
ssh_key_id = "your_ssh_key_id"
```

### 2. Initialize Terraform

```powershell
.\terraform.exe init
```

### 3. Plan resources

```powershell
.\terraform.exe plan -var-file="terraform.tfvars"
```

### 4. Apply resources

```powershell
.\terraform.exe apply -var-file="terraform.tfvars"
```

This provisions:

* `k8s-master` (4GB droplet).
* `k8s-worker-1` & `k8s-worker-2` (2GB each).

Terraform outputs their IPs.

---

## Step 2: Prepare All Nodes

SSH into **each node (master + workers)**:

```bash
ssh -i C:\path\to\privatekey root@<droplet_ip>
```

Update + install dependencies:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gpg
```

Disable swap:

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Install container runtime (containerd):

```bash
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Install Kubernetes components:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Enable IP forwarding (fix for Calico + kubeadm):

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

---

## Step 3: Initialize Master Node

On **master only**:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```
📌 Note: The --pod-network-cidr=192.168.0.0/16 flag defines the pod IP range. This value should match the CNI plugin you plan to use (e.g., 10.244.0.0/16 for Flannel). In this project, 192.168.0.0/16 was used with Calico.

Configure kubectl:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Step 4: Install Calico CNI

On **master**:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

Wait until pods in `kube-system` are Running:

```bash
kubectl get pods -n kube-system
```

---

## Step 5: Join Worker Nodes

On **each worker**, run the `kubeadm join ...` command given by master.
Example:

```bash
sudo kubeadm join <master_ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Verify on **master**:

```bash
kubectl get nodes
```

---

## Step 6: Deploy nginx

Apply manifest:

```bash
kubectl apply -f k8s-manifests/nginx-deployment.yaml
kubectl apply -f k8s-manifests/nginx-service.yaml
```

Or run directly:

```bash
kubectl create deployment nginx --image=nginx --replicas=2
kubectl expose deployment nginx --port=80 --type=NodePort
```

Check resources:

```bash
kubectl get pods -o wide
kubectl get svc nginx
```

---

## Step 7: Test Networking

###  1. kube-proxy (service → pods mapping)

```bash
kubectl get endpoints nginx
```

Expected:

```
nginx   10.244.0.10:80,10.244.1.15:80
```

### 2. CoreDNS (DNS inside pod)

Run a test pod:

```bash
kubectl run busybox --image=busybox:1.28 --restart=Never --command -- sleep 3600
kubectl exec -it busybox -- sh
```

Inside busybox:

```sh
nslookup nginx
wget -qO- http://nginx
```

Expected: nginx welcome page.

### 3. Browser Access (NodePort)

From master, check NodePort:

```bash
kubectl get svc nginx
```

Example:

```
PORT(S)  80:32255/TCP
```

Open in browser:

```
http://<worker-node-ip>:<port-id>
```


## Final Outcome

* A **3-node Kubernetes cluster** (1 master, 2 workers) was provisioned with Terraform.
* nginx was deployed and exposed.
* Networking was tested end-to-end: kube-proxy, CoreDNS, NodePort access.
* Browser successfully displayed nginx default page.

---


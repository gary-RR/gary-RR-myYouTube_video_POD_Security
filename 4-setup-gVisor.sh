#Install the appropriate dependencies to allow apt to install packages via https:
sudo apt-get update && \
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg


#configure the key used to sign archives and the repository.
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null

#Now the runsc package can be installed:
sudo apt-get update && sudo apt-get install -y runsc

#Configure containerd
#Update /etc/containerd/config.toml. Make sure containerd-shim-runsc-v1 is in ${PATH} or in the same directory as containerd binary.
sudo -i    
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
exit 

sudo systemctl restart containerd

#Install the RuntimeClass for gVisor:
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
EOF

#Verify gvisor is listed as a runtimeclass:
kubectl get runtimeclass

#Create a POD and use gVisor runtime class
cat <<EOF | kubectl  apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: myapp
spec:
  containers:
  - image: nginx
    name: nginx-frontend
EOF

#Run "dmseg". This is Linux utility for displaying the messages that flow within the kernel ring buffer.
dmesg

kubectl exec -it myapp -- sh
#Run desg inside the POD
dmesg
exit

#Cleanup
kubectl delete pod myapp
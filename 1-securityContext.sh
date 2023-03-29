#Examine the security context of a POD when no policies are applied and/or no changes made 
#to its POD or container securityContext

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
EOF

#Make sure the POD is created and in "ready" state befor sh in to it
kubectl get pods test-pod 

kubectl exec -it test-pod -- sh
    ps -u
    id
    id -G
    echo Hello! > /data/demo/test.txt
    ls -l /data/demo/test.txt
    exit

kubectl delete pod test-pod
#*************************************************************Set the "runAsUser", "runAsGroup", and "fsGroup" for a POD********************************

#Set the "runAsUser", "runAsGroup", and "fsGroup" for a POD
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  securityContext:
     runAsUser: 1000
     runAsGroup: 3000
     fsGroup: 2000   
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      allowPrivilegeEscalation: false
EOF

kubectl get pods test-pod 

kubectl exec -it test-pod -- sh
    ps
    id
    id -G
    echo Hello! > /data/demo/test.txt
    ls -l /data/demo/test.txt    
    exit

kubectl delete pod test-pod
#***************************************************************#Set the security context for individual container*********************************************

#Set the security context for individual container
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  securityContext:
     runAsUser: 1000
     runAsGroup: 3000
     fsGroup: 2000   
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      runAsUser: 4000
      runAsGroup: 5000        
      allowPrivilegeEscalation: false
EOF

kubectl get pods test-pod 

kubectl exec -it test-pod -- sh
    ps aux
    id
    id -G
    echo Hello! > /data/demo/test.txt
    ls -l /data/demo/test.txt  
    exit

kubectl delete pod test-pod
#*****************************************************************Set capabilities for a Container****************************************************************
#Capabilities permit certain named root actions without giving full root access. They are a more fine-grained permissions model, 
#and all capabilities should be dropped from a pod, with only those required added back.

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}    
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo      
EOF

kubectl get pods test-pod 

kubectl exec -it test-pod -- sh
    ps aux
    cd /proc/1
    cat status | grep CapPrm
    exit

kubectl delete pod test-pod

CapPrm: 00000000a80425fb
CapPrm: 00000000aa0435fb
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}  
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:       
      allowPrivilegeEscalation: false
      capabilities:
        add: ["NET_ADMIN", "SYS_TIME"]
EOF

kubectl get pods test-pod 

kubectl exec -it test-pod -- sh
    ps aux    
    cd /proc/1
    cat status | grep CapPrm
    exit

kubectl delete pod test-pod

capsh --decode=00000000aa0435fb

#Very dangerous settings!!
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  #Sharing the host’s network namespace permits processes in the pod to communicate with processes bound to the host’s loopback adapter.
  hostNetwork: true
  #Sharing the host’s PID namespace allows visibility of processes on the host, potentially leaking information such as environment variables and configuration. 
  hostPID: true  
  #Sharing the host’s IPC namespace allows container processes to communicate with processes on the host. 
  hostIPC: true
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}   
  containers:
  - image: grostami/spring-boot-app:2.0.0
    name: demo-pod
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo    
EOF

kubectl get pods test-pod

kubectl exec -it test-pod -- sh
    ps aux  
    cd /proc/1
    cat status | grep CapPrm
    exit

kubectl delete pod test-pod
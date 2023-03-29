#Install OPA gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

#***************************************************************Require label*****************************************************************
cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels        
      validation:
        # Schema for the 'parameters' field
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg, "details": {"missing_labels": missing}}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("you must provide labels: %v", [missing])
        }       
EOF

cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-hr
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
    namespaces:
      - "hr"  
  parameters:
    labels: ["hr"]
EOF

kubectl create ns hr 


#***************************************************************************Require from a trusted registry***********************************************************************************

kubectl create ns marketing-prod

cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredregistry
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredRegistry
      validation:
        # Schema for the `parameters` field
        openAPIV3Schema:
          properties:
            image:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredregistry
        violation[{"msg": msg, "details": {"Registry should be": required}}] {
          input.review.object.kind == "Pod"
          some i
          image := input.review.object.spec.containers[i].image
          required := input.parameters.registry
          not startswith(image,required)
          msg := sprintf("Forbidden registry: %v", [image])
        }
EOF

cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredRegistry
metadata:
  name: images-must-come-from-gcr
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
       - "marketing-prod"
  parameters:
    registry: "gcr.io/"   
EOF

cat <<EOF | kubectl -n marketing-prod apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: myapp
spec:
  containers:
  - image: nginx
    name: nginx-frontend
EOF

#******************************************************************Service type NodePort not allowed******************************
cat <<EOF | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: nodeportnotallowed
spec:
  crd:
    spec:
      names:
        kind: NodePortNotAllowed        
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package kubernetes.admission
        violation[{"msg": msg}] {
                    input.review.kind.kind == "Service"
                    input.review.operation == "CREATE"
                    input.review.object.spec.type == "NodePort"
                    msg := "NodePort Services are not allowed!"
        }

EOF


kubectl get  ConstraintTemplate nodeportnotallowed  

cat <<EOF | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: NodePortNotAllowed
metadata:
  name: deny-svc-type-nodeport-marketing-prod
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Service"]
    namespaces:
      - "marketing-prod"
EOF


kubectl create -n marketing-prod deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
kubectl -n marketing-prod expose deployment hello-world --port=8080 --target-port=8080 --type=NodePort 


#*************************************************************************************************************************************************
kubectl get constraint
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
kubectl delete ConstraintTemplate nodeportnotallowed
kubectl delete ConstraintTemplate nodeportnotallowed
kubectl delete ConstraintTemplate k8srequiredlabels
kubectl delete ns marketing-prod
kubectl delete ns hr

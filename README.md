# kind-clusters
---
### Install
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/localbin/kind
```

### Management
```bash
kind create cluster --name noop --config kind-config.yaml
kubectl cluster-info --context kind-nook
kubectl create deployment nginx --image=nginx
kind delete cluster --name noop

docker ps
docker exec -it noop-control-plane bash
  hostname
  ls /etc/kubernetes/manifests/
  systemctl status kubelet.service

```
---
### Without CNI
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
networking:
  disableDefaultCNI: true
```

### NodePorts
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
...
- role: control-plane
  # this is to expose extra ports for NodePort
  # see #https://github.com/kubernetes-sigs/kind/pull/637, https://github.com/kubernetes-sigs/kind/issues/99
  extraPortMappings:
  - containerPort: 30100
    hostPort: 30100
  - containerPort: 30101
    hostPort: 30101
  - containerPort: 30102
    hostPort: 30102
 ```
### Ingress Support
```bash
$ kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-rbac.yaml

$ kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-ds.yaml

$ kubectl edit service/traefik-ingress-service -n kube-system
```
Make sure we update `traefik`'s service, like this:

```bash
$ kubectl apply -n kube-system -f - <<EOF
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  type: NodePort          # <-- 1. change the default ClusterIp to NodePort
  selector:
    k8s-app: traefik-ingress-lb
  ports:
  - protocol: TCP
    port: 80
    nodePort: 30100       # <-- 2. add this nodePort binding to one of the node ports exposed
    name: web
  - protocol: TCP
    port: 8080
    nodePort: 30101       # <-- 3. add this nodePort binding to another one of the node ports exposed
    name: admin
EOF
```

Test it out:

```bash
$ kubectl create deployment web --image=nginx
$ kubectl expose deployment web --port=80
$ kubectl apply -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-test
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: www.example.com
      http:
        paths:
          - path: /
            backend:
              serviceName: web
              servicePort: 80
EOF

$ curl -s -H "Host: www.example.com" http://localhost:30100 | grep title
<title>Welcome to nginx!</title>
```

### Local Registry
```
### Advanced Features
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
# patch the generated kubeadm config with some extra settings
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: ClusterConfiguration
  metadata:
    name: config
  apiServer:
    extraArgs:
      enable-admission-plugins: NodeRestriction
      "feature-gates": "DynamicAuditing=true"   # way to enable desired features
  scheduler:
    extraArgs:
      "feature-gates": "DynamicAuditing=true"   # way to enable desired features
  controllerManager:
    extraArgs:
      "feature-gates": "DynamicAuditing=true"   # way to enable desired features
- |
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: InitConfiguration
  metadata:
    name: config
  nodeRegistration:
    kubeletExtraArgs:
      "feature-gates": "DynamicAuditing=true"   # way to enable desired features
nodes:
# The control plane node config
- role: control-plane
  # this is to expose extra ports for NodePort
  # see #https://github.com/kubernetes-sigs/kind/pull/637, https://github.com/kubernetes-sigs/kind/issues/99
  extraPortMappings:
  - containerPort: 30100
    hostPort: 30100
  - containerPort: 30101
    hostPort: 30101
  - containerPort: 30102
    hostPort: 30102
# The three workers
- role: worker
- role: worker
- role: worker
# To disable CNI so we can add our choice of CNI, e.g. weave-net, later
networking:
  disableDefaultCNI: true       # disable kindnet
  #podSubnet: 192.168.0.0/16    # set to Calico's default subnet
  podSubnet: 10.32.0.0/12       # set to WeaveNet's default subnet
```

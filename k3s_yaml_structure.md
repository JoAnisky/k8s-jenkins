# Structure YAML K3s - Jenkins + Guide Complet

## Organisation des répertoires

```
~/k3s/
├── kustomization.yml         # Fichier maître pour appliquer tout
├── deploy.sh                 # Script de déploiement
├── reset.sh                  # Script de reset complet
├── README.md
└── jenkins/
    ├── namespace.yml
    ├── pvc.yml
    ├── deployment.yml
    ├── service.yml
    └── ingress.yml
```

---

# 1. Configuration Traefik (édition manuelle du déploiement)
Utilise la version de Traefik présent lors de l'install de k3s (plus simple et plus léger)

## Ajouter Let's Encrypt à Traefik

```bash
# Éditer le déploiement Traefik
kubectl edit deployment -n kube-system traefik
```

Chercher la section `args:` et ajouter ces trois lignes à la fin :

```yaml
        - --certificatesresolvers.letsencrypt.acme.email=aniskydev@protonmail.com
        - --certificatesresolvers.letsencrypt.acme.storage=/data/acme.json
        - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
```

**Attention** : utiliser **espaces** uniquement, pas de tabs.

Sauvegarder et sortir (`:wq` en vim). Traefik redémarrera automatiquement.

Vérifier :

```bash
sleep 30
kubectl get deployment -n kube-system traefik -o yaml | grep "certificatesresolvers"
```

Vous devez voir les trois lignes.

---

# 2. Jenkins - Fichiers YAML

- `~/k3s/jenkins/namespace.yml`
- `~/k3s/jenkins/pvc.yml`
- `~/k3s/jenkins/deployment.yml`
- `~/k3s/jenkins/service.yml`
- `~/k3s/jenkins/ingress.yml`

---

# 3. Kustomization - Appliquer tout en une seule commande

`~/k3s/kustomization.yml`

**Appliquer** :

```bash
kubectl apply -k ~/k3s/
```

---

# 4. Scripts de déploiement et reset

- `~/k3s/deploy.sh` - Déploiement complet

- `~/k3s/reset.sh` - Reset complet (si ça plante)

**Rendre exécutables** :

```bash
chmod +x ~/k3s/deploy.sh ~/k3s/reset.sh
```

---

# 5. Procédure complète de déploiement / redéploiement

## Premier déploiement

```bash
# 1. Créer les répertoires
mkdir -p ~/k3s/jenkins

# 2. Créer tous les fichiers YAML (voir section 2)

# 3. Créer kustomization.yml (voir section 3)

# 4. Créer les scripts (voir section 4)

# 5. Déployer
~/k3s/deploy.sh

# 6. Accéder
curl -k https://jenkins.jonathanlore.fr
# Ou dans le navigateur : https://jenkins.jonathanlore.fr
```

## Si ça plante / redéployer

```bash
# 1. Reset complet
~/k3s/reset.sh

# 2. Redéployer
~/k3s/deploy.sh
```

## Mettre à jour un fichier

```bash
# 1. Modifier un fichier (par exemple deployment.yml)
nano ~/k3s/jenkins/deployment.yml

# 2. Réappliquer
kubectl apply -k ~/k3s/

# 3. Attendre que le changement se propage
kubectl rollout status deployment/jenkins -n jenkins
```

---

# 6. Commandes utiles

```bash
# Voir l'état de Jenkins
kubectl get all -n jenkins

# Voir les logs en temps réel
kubectl logs -n jenkins -f deployment/jenkins

# Voir les certificats TLS
kubectl describe ingress jenkins -n jenkins

# Accès direct (bypass DNS)
kubectl port-forward -n jenkins svc/jenkins 8080:8080 &
# Puis : http://localhost:8080

# Voir les différences avant d'appliquer
kubectl diff -k ~/k3s/

# Voir l'historique des rollout
kubectl rollout history deployment/jenkins -n jenkins

# Revenir à la version précédente
kubectl rollout undo deployment/jenkins -n jenkins
```

---

# 7. Pour un projet externe - Fichiers Kubernetes à inclure

Dans le repo du projet, inclure cette structure :

```
portfolio/
├── k8s/                          # Fichiers Kubernetes
│   ├── kustomization.yml
│   ├── namespace.yml
│   ├── deployment.yml
│   ├── service.yml
│   ├── ingress.yml
│   └── README.md
├── src/
├── Dockerfile
└── package.json
```

## `portfolio/k8s/namespace.yml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
```

## `portfolio/k8s/deployment.yml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portfolio
  namespace: portfolio
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: portfolio
  template:
    metadata:
      labels:
        app: portfolio
    spec:
      containers:
      - name: portfolio
        image: REGISTRE_DOCKER/portfolio:latest  # À remplacer
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
```

## `portfolio/k8s/service.yml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: portfolio
  namespace: portfolio
  labels:
    app: portfolio
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
    name: http
  selector:
    app: portfolio
```

## `portfolio/k8s/ingress.yml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portfolio
  namespace: portfolio
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  tls:
  - hosts:
    - portfolio.jonathanlore.fr
    secretName: portfolio-tls
  rules:
  - host: portfolio.jonathanlore.fr
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: portfolio
            port:
              number: 3000
```

## `portfolio/k8s/kustomization.yml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: portfolio

resources:
  - namespace.yml
  - deployment.yml
  - service.yml
  - ingress.yml

commonLabels:
  app: portfolio
  version: "1.0"
```

## `portfolio/k8s/README.md`

```markdown
# Portfolio Kubernetes Deployment

## Deploy

```bash
kubectl apply -k ./k8s/
```

## Update image

```bash
kubectl set image deployment/portfolio portfolio=VOTRE_REGISTRY/portfolio:v1.2.3 -n portfolio
```

## View logs

```bash
kubectl logs -n portfolio -f deployment/portfolio
```

## Rollback

```bash
kubectl rollout undo deployment/portfolio -n portfolio
```
```

## CI/CD Integration (Jenkins)

Dans Jenkins, créer un pipeline qui :

1. Build l'image Docker
2. Push vers registry
3. Update Kubernetes :

```bash
kubectl set image deployment/portfolio portfolio=VOTRE_REGISTRY/portfolio:$BUILD_NUMBER -n portfolio
kubectl rollout status deployment/portfolio -n portfolio
```

---

# 8. Versionner avec Git

```bash
cd ~/k3s
git init
git add .
git commit -m "Initial K3s Jenkins configuration"

# Ou dans votre repo portfolio
cd portfolio
git add k8s/
git commit -m "Add Kubernetes deployment files"
```

**`.gitignore`** (à la racine) :

```
*.log
*.tmp
.DS_Store
acme.json
```

---

# 9. Troubleshooting

**Jenkins pod ne démarre pas :**

```bash
kubectl describe pod -n jenkins -l app=jenkins
kubectl logs -n jenkins -l app=jenkins
```

**TLS certificat ne se génère pas :**

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep -i "acme\|certificate"
```

**Ingress ne fonctionne pas :**

```bash
kubectl describe ingress jenkins -n jenkins
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep jenkins
```

**Réinitialiser complètement :**

```bash
~/k3s/reset.sh
~/k3s/deploy.sh
```
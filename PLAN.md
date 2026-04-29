# 🏛️ Manifeste du Fluide Souverain Fédération (FSF)

## 1. Vision Architecturale
Le **FSF** est une infrastructure Kubernetes (K3s) ultra-résiliente conçue pour un environnement hybride et décentralisé. Contrairement aux clusters classiques, le FSF est **agnostique à la machine** : il survit tant qu'un seul nœud est en vie (i > 0) et adapte sa charge de travail en fonction des ressources disponibles en temps réel.

## 2. Le Cœur : État et Réseau (Zero Single Point of Failure)

### 🧠 2.1 Le Cerveau Distribué (Kine + CockroachDB)
*   **Technologie :** Remplacement d'ETCD par **CockroachDB** via le shim **Kine**.
*   **Fonctionnement :** La base de données SQL est répliquée sur tous les nœuds stables. CockroachDB permet une survie native même avec un seul nœud actif.
*   **Résilience :** Si PVE tombe, Ubuntu possède déjà l'intégralité de l'état du cluster.

### 🌐 2.2 L'IP Virtuelle (Kube-VIP)
*   **Concept :** Une "IP Flottante" unique ($CLUSTER_VIP) pour l'accès à l'API.
*   **Failover :** Le protocole ARP déplace l'IP sur le nœud le plus sain en cas de panne du leader actuel.

---

## 3. Gouvernance des Services (Hiérarchie de Survie)

Nous utilisons des **PriorityClasses** pour orchestrer la survie des services :

### 🔴 Classe Alpha : Services Vitaux (Priorité 1000)
*   **Comportement :** Failover automatique immédiat. Priorité absolue sur les ressources.
*   **Exemples :** Kube-VIP, CockroachDB, CoreDNS, Vault.

### 🟡 Classe Bêta : Services de Ressources (Priorité 500)
*   **Comportement :** Mis en sommeil si les ressources globales sont insuffisantes.
*   **Exemples :** Monitoring, Media servers, Dev tools.

### 🔵 Classe Gamma : Services Spécifiques (Priorité 100)
*   **Comportement :** Liés à un OS spécifique (NodeAffinity). Data sauvegardée en continu.
*   **Exemples :** Logiciels propriétaires Windows, Outils Mac.

---

## 4. Stratégie de Stockage (Liquidité des Données)
*   **Longhorn :** Block storage répliqué (Chaud).
*   **NFS/S3 :** Stockage froid pour backups et snapshots de services endormis.

---

## 5. Roadmap Technique
1.  **Phase 0 :** Déploiement du cerveau (0.1) et de la passerelle (0.2).
2.  **Phase 1 :** Lancement de l'engine stateless (1.1).
3.  **Phase 2 :** Tests de résilience et failover.
4.  **Phase 3 :** Activation du stockage et des secrets.

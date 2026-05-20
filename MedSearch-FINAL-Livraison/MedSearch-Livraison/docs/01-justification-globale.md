# Justification globale — Infrastructure MedSearch

## 1. Contexte et problématique

MedSearch est une entreprise spécialisée dans la recherche médicale, présente sur deux sites :
- **Caen** : site principal, datacenter central
- **Saint-Cénéri-le-Gérei** : site distant, employés accédant aux services centralisés

### Situation initiale (problèmes identifiés)
- Aucun système d'information centralisé
- Partages de documents par clés USB uniquement
- **Un seul administrateur IT** — point critique de toute l'architecture
- Impossibilité de déployer WSUS, WDS, DFS, messagerie, solutions collaboratives

### Objectif
Fournir une infrastructure de base capable de supporter tous les services futurs, avec une haute disponibilité et une gestion simplifiée pour un seul administrateur.

---

## 2. Choix de la plateforme — Azure vs On-Premise

### Pourquoi Azure
L'environnement de démonstration a été déployé sur **Microsoft Azure** avec des crédits lors de la création d'un nouveau compte ($200) pour les raisons suivantes :

| Critère | Azure | On-Premise |
|---------|-------|-----------|
| Déploiement | Rapide (< 1h) | Long (hardware, câblage) |
| Coût initial | 0€ (crédits) | Élevé (serveurs physiques) |
| Flexibilité | Haute | Faible |
| Scripts identiques | Oui | Oui |
| Haute dispo native | Availability Zones | Cluster physique |



### Contraintes Azure rencontrées
- **Limitation 4 vCPU** → 2 VMs maximum (Standard_B2ms chacune)
- **VNets séparés** : SRV-CAEN créé sur `SRV-CAEN-vnet` (10.1.0.0/24), SRV-SAINTCENERI sur `MedSearch-VNet` (10.0.0.0/16)
- **Solution :** VNet Peering bidirectionnel pour simuler la communication inter-sites
- **Remoting PowerShell** : authentification Kerberos bloquée entre VNets différents → contournement avec API locale

---

## 3. Choix de l'OS — Windows Server 2022

Windows Server 2022 Datacenter Azure Edition a été choisi car :
- Support natif de tous les rôles requis (AD DS, IIS, RRAS, RDS, Failover Clustering)
- Intégration parfaite avec Azure (Hotpatch, Azure Arc)
- Cohérent avec l'expertise Microsoft de notre entreprise
- Support jusqu'en 2031

---

## 4. Architecture réseau

```
Internet
    |
    | (RDP:3389, HTTP:80, HTTPS:443, Dashboard:8080, API:8081)
    |
+---+-------------------+          +----------------------+
|   SRV-CAEN            |          |   SRV-SAINTCENERI    |
|   10.1.0.4            |<-------->|   10.0.0.4           |
|   SRV-CAEN-vnet       | VNet     |   MedSearch-VNet     |
|                       | Peering  |                      |
|   AD DS (DC principal)|  1ms     |   AD DS (replica)    |
|   DNS                 |          |   RDS Session Host   |
|   IIS + Deploy-Site   |          |   Failover Cluster   |
|   RRAS VPN SSTP       |          |   VPN Client SSTP    |
|   Failover Cluster    |          |                      |
|   WEF Collecteur      |          |                      |
|   Dashboard :8080     |          |                      |
|   API REST :8081      |          |                      |
+---+-------------------+          +----------------------+
```

---

## 5. Point critique — Un seul administrateur IT

Toutes les décisions techniques ont été prises en tenant compte de cette contrainte majeure. Chaque solution doit être :
- **Simple à utiliser** (peu de commandes, interfaces graphiques)
- **Automatisée** (tâches planifiées, scripts)
- **Monitored** (alertes automatiques)
- **Accessible à distance** (VPN + RDS)

### Solutions mises en place

| Besoin | Solution | Complexité admin |
|--------|----------|-----------------|
| Déployer un site | Deploy-Site.ps1 (3 paramètres) | Très faible |
| Surveiller les serveurs | Dashboard web temps réel | Aucune |
| Recevoir des alertes | Email automatique CPU/RAM | Aucune |
| Analyser les erreurs | WEF - logs centralisés | Faible |
| Administrer à distance | RRAS VPN + RDS | Faible |
| Gérer les serveurs | Windows Admin Center (installé) | Faible |

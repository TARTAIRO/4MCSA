# Communication inter-sites — Caen ↔ Saint-Cénéri

## 1. Contexte

MedSearch dispose de deux sites géographiques :
- **Caen** : datacenter principal, tous les services
- **Saint-Cénéri-le-Gérei** : site distant, pas de datacenter local

Les employés de Saint-Cénéri doivent accéder aux données et services de Caen de manière :
- **Sécurisée** (données médicales sensibles)
- **Sans configuration sur leurs postes** (contrainte explicite du projet)

---

## 2. Solution retenue — VPN SSTP + VNet Peering

### Architecture de communication

```
Site Caen                              Site Saint-Cénéri
+------------------+                   +------------------+
|   SRV-CAEN       |                   |   SRV-SAINTCENERI|
|   10.1.0.4       |<==VNet Peering==>|   10.0.0.4       |
|   SRV-CAEN-vnet  |   (1ms latence)  |   MedSearch-VNet |
|                  |                   |                  |
|   RRAS VPN SSTP  |<==VPN SSTP 443==>|   Postes clients |
|   Port 443       |   (chiffré SSL)  |   Windows natif  |
+------------------+                   +------------------+
```

---

## 3. VNet Peering Azure (simulation inter-sites)

### Pourquoi VNet Peering
En environnement Azure de démonstration, les 2 VMs sont sur des VNets différents :
- `SRV-CAEN-vnet` : 10.1.0.0/24
- `MedSearch-VNet` : 10.0.0.0/16

Le VNet Peering simule la connexion réseau inter-sites (WAN en production).

### Configuration du peering
```
SRV-CAEN-vnet  ←→  MedSearch-VNet
Peering : SaintCeneri-to-Caen / Caen-to-SaintCeneri
Status  : Fully Synchronized ✅
Latence : 1ms
```

### Paramètres activés
- Allow VNet to access remote VNet : ✅
- Allow forwarded traffic : ✅
- Allow gateway transit : ✅

### Validation de la connectivité
```powershell
# Depuis SRV-CAEN vers SRV-SAINTCENERI
Test-Connection -ComputerName 10.0.0.4 -Count 2
```
```
Source    Destination  Bytes  Time(ms)
------    -----------  -----  --------
SRV-CAEN  10.0.0.4     32     1
SRV-CAEN  10.0.0.4     32     1
```

---

## 4. VPN SSTP — Accès sécurisé sans configuration poste

### Pourquoi SSTP est la solution idéale
Le projet exige : **"sans configuration sur les postes employés"**

| VPN Type | Config poste | Port | Firewall friendly |
|----------|-------------|------|------------------|
| SSTP | Natif Windows | 443 | ✅ Oui |
| L2TP/IPsec | Clés PSK | 1701 | ❌ Parfois bloqué |
| OpenVPN | Client requis | 1194 | ❌ Parfois bloqué |
| PPTP | Natif Windows | 1723 | ❌ Déprécié |

**SSTP = port 443 HTTPS → passe tous les firewalls d'entreprise sans exception**

### Connexion SSTP depuis un poste Windows (zéro config admin)
1. Windows natif → Paramètres → Réseau → VPN → Ajouter une connexion
2. Serveur : `20.82.143.72`
3. Type : SSTP
4. Identifiants : `medsearch\vpnuser` / `MedSearch2024!`

### En PowerShell (pour déploiement automatisé)
```powershell
Add-VpnConnection -Name "MedSearch-VPN" `
    -ServerAddress "20.82.143.72" `
    -TunnelType Sstp `
    -EncryptionLevel Required `
    -AuthenticationMethod MSChapv2 `
    -RememberCredential
```

---

## 5. Active Directory répliqué

Pour assurer la continuité de service en cas de perte du lien réseau :
- SRV-SAINTCENERI est configuré comme **contrôleur de domaine secondaire**
- Réplication AD automatique du domaine `medsearch.local`
- En cas de coupure réseau : authentification locale toujours possible

### Validation
```powershell
# Sur SRV-SAINTCENERI
(Get-WmiObject Win32_ComputerSystem).Domain
# Résultat : medsearch.local
```

---

## 6. Problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| Ping inter-VNet bloqué | Firewall Windows ICMP désactivé | `New-NetFirewallRule -Protocol ICMPv4` sur SRV-SAINTCENERI |
| NSG Azure bloquait ICMP | Règle par défaut deny | Ajout règle Allow-ICMP sur NSG SRV-SAINTCENERI |
| VNet Peering "Disabled" | Option "Allow traffic" non cochée | Activation dans Azure portal → Peering settings |
| Jonction domaine échouée | DNS pointait sur Azure (168.63.x.x) | `Set-DnsClientServerAddress` vers 10.1.0.4 (SRV-CAEN) |

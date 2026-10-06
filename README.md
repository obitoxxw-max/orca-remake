<h1 align="center">⚡ Broly</h1>
<div align="center">Menu de qualité et de confort pour ton jeu Roblox — <b>par psych0pat3</b></div>
<br>

Un menu d'options moderne et animé, en Luau pur, **sans aucune dépendance externe**
(pas de Roact, pas de rojo, pas de npm). Tu le colles dans Studio et ça marche.

Chaque réglage pilote une **vraie propriété du moteur**. Rien n'est simulé, rien
n'est décoratif : si un interrupteur n'a pas d'effet, c'est que le réglage n'a
pas été écrit.

---

## 📦 Installation

Tout est dans `src/`. Il faut répartir 2 fichiers et regrouper les 7 modules.

**1. Crée un dossier `Broly` dans ReplicatedStorage** et mets-y les 5 modules
racine + le dossier `UI` :

```
ReplicatedStorage
└── Broly
    ├── Anim.lua       ModuleScript
    ├── Config.lua     ModuleScript
    ├── Store.lua      ModuleScript
    ├── Theme.lua      ModuleScript
    └── UI
        ├── init.lua   ModuleScript
        ├── Kit.lua    ModuleScript
        └── Pages.lua  ModuleScript
```

**2. Déplace les 2 scripts restants** vers leur service :

| Fichier | Destination |
| --- | --- |
| `Broly.server.lua` | `ServerScriptService` |
| `Broly.client.lua` | `StarterPlayerScripts` |

**3. Teste** avec <kbd>F5</kbd> (Play). Appuie sur <kbd>F6</kbd> pour ouvrir le menu.

> Les 7 modules doivent rester **ensemble** : ils se récupèrent par
> `script.Parent`. Ils vont dans `ReplicatedStorage` parce que c'est le seul
> service lisible à la fois par le client et par le serveur.
>
> Si tu préfères tout garder dans un seul coin, ça marche aussi : les 2 scripts
> acceptoront de trouver les modules à côté d'eux. Ils ne demandent que le
> premier emplacement trouvé.

### Pour activer la sauvegarde
Game Settings → **Enable Studio Access to API Services**. En jeu publié, le
DataStore fonctionne sans réglage.

Si `Broly.server.lua` est absent, le menu marche quand même — il te le dira dans
Options → Données, et Options → Apps te dira que vitesse, saut et gravité ne
seront pas appliqués.

### En cas d'erreur

Toutes les erreurs de ce projet sont préfixées `[Broly]`.

| Message | Cause |
| --- | --- |
| `[Broly] module introuvable : X.lua` | Un module n'est pas dans `Broly`, ou mal nommé |
| `expected instance to be a ModuleScript` | Un module est en Script/LocalScript au lieu de ModuleScript |
| Le menu ne s'ouvre pas | `Broly.client.lua` n'est pas dans `StarterPlayerScripts` |
| Réglages non conservés | API Services désactivée dans Studio |

---

## 🎮 Les onglets

### Accueil — qualité et graphismes

Quatre profils (Qualité, Équilibré, Performance, Cinématique) appliquent toute
une famille de réglages d'un coup, puis :

| Groupe | Options | Propriété pilotée |
| --- | --- | --- |
| Shadows | Ombres, résolution 512→4096, technologie | `Lighting.GlobalShadows`, `ShadowMapSize`, `Technology` |
| Lighting | Luminosité, exposition, ambiante, diffusion, spéculaire, heure, atmosphère | `Lighting.*` |
| Fog | Brouillard, début, fin, courbe | `Lighting.FogMode`, `FogStart`, `FogEnd` |
| Camera | Zoom caméra max | `Player.CameraMaxZoomDistance` |

### Apps — gameplay

| Groupe | Options | Propriété pilotée |
| --- | --- | --- |
| Camera | Sensibilité, FOV, mode, hauteur | `UserInputService.MouseDeltaSensitivity`, `Camera.FieldOfView`, `Player.CameraMode`, `Humanoid.CameraOffset` |
| Movement | Vitesse, saut, gravité, saut auto | `Humanoid.WalkSpeed`… **via le serveur** |
| Comfort | Noms au-dessus des joueurs | `BillboardGui` local |

### Presets

Sauvegarde une combinaison de réglages sous un nom, réapplique-la en un clic,
supprime-la, ou exporte toute la configuration en JSON à copier-coller entre
joueurs.

### Options

Thèmes (Midnight, Obsidian, Carbon, Contraste), accents (Lime, Golden, Crimson,
Vast, Legendary), **réduire les animations**, texte contrasté, échelle de
l'interface, compteur FPS, et le raccourci clavier du menu (reconfigurable en
cliquant sur le champ).

---

## 🔑 Les options « serveur »

`WalkSpeed`, `JumpPower` et `Gravity` sont marqués **appliqués par le serveur**
dans l'interface. Ce n'est pas une précaution de façade : ces propriétés sont
possédées par le serveur, et une écriture faite uniquement côté client est
réécrite à la réplication.

C'est pour ça que `Broly.server.lua` existe. Il :

- valide chaque valeur reçue contre le schéma (bornes, types, choix) — un
  client modifié ne peut pas écrire n'importe quoi dans le DataStore ;
- applique les valeurs sur le Humanoid ;
- les ré-applique à 1 Hz, parce que la plupart des jeux réinitialisent
  `WalkSpeed` dans leurs propres scripts ;
- limite l'écriture DataStore (1 write / 6 s, en plus d'un cache mémoire).

Le reste des options est appliqué directement par le client, ce qui est
parfaitement normal pour des préférences purement visuelles.

---

## 🎨 L'image principale

Tu as demandé une image principale. **Roblox ne peut pas charger une image
depuis une URL distante** (`https://files.catbox.moe/…`) : le moteur bloque le
HTTP externe pour les `ImageLabel`, et l'asset serait refusé à la publication.

La marche à suivre :

1. Télécharge ton image.
2. Dans Studio, fais un clic droit sur ton image dans l'explorateur →
   **Get Asset ID**.
3. Options → Apparence → **ID du logo (asset)** : colle le nombre.

Avec `0`, le menu affiche un monogramme « B » en dégradé d'accent, qui suit la
couleur choisie. C'est le comportement par défaut.

---

## 🧩 Architecture

| Fichier | Rôle |
| --- | --- |
| `Config.lua` | Source de vérité : schéma, défauts, validation, application moteur |
| `Store.lua` | État vivant, cache, synchronisation DataStore, import/export |
| `Theme.lua` | Palettes, accents, helpers d'instances |
| `Anim.lua` | Tween + ressort, entrances, stagger, échelle de mouvement |
| `UI/Kit.lua` | Toggle, slider, segmenté, swatches, bouton, champ, carte, scroll |
| `UI/Pages.lua` | Les 4 pages, générées depuis le schéma |
| `UI/UI.lua` | Fenêtre, navbar animée, routeur, drag, raccourci, toasts, FPS |

`Config.lua` est le seul endroit où tu ajoutes une option : le schéma génère la
page, le widget, la validation et la persistance.

### Ajouter une option

```lua
e({
    key = "myOption",
    label = "Mon option",
    kind = "number",        -- "bool" | "number" | "choice" | "key"
    default = 5,
    min = 0, max = 10, step = 0.5,
    format = "percent",     -- optionnel : "percent" | "decimal"
    server = true,          -- optionnel : appliqué par Broly.server.lua
    page = "apps",
    group = "Movement",
})
```

Puis dans `Config.applyClient` ajoute le `pcall` qui écrit la propriété. Si
l'option est `server = true`, ajoute-la aussi dans `applyGameplay` (dans
`Broly.server.lua`), sinon elle restera sans effet.

---

## ⚠️ Ce qui n'est pas réglable en jeu

Ces réglages n'existent tout simplement pas dans l'API Roblox, donc ils ne sont
**pas** dans le menu plutôt que d'être de faux interrupteurs :

- le niveau de qualité global (le curseur 1–21 des réglages Roblox) ;
- la qualité des textures ;
- le V-Sync.

Use le menu **Settings** de Roblox pour ceux-là.

---

## 🛠 Développement

Tout le projet est formaté avec StyLua :

```bash
stylua --check src
```

Accès depuis un autre script :

```lua
local broly = _G.Broly
broly.ui.notify("Coucou !", "ok")
broly.store.set("fov", 90)
broly.ui.open()
```
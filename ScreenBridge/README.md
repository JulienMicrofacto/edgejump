# ScreenBridge

App macOS de barre de menu qui teleporte le curseur entre les bords interieurs de deux ecrans exterieurs, en ne bridgeant que la moitie haute de l'ecran (la moitie basse laisse macOS gerer la transition vers un ecran central).

## Cas d'usage

Setup avec 3 ecrans : 2 grands moniteurs (gauche/droite) + MacBook au centre en dessous.

```
┌──────────┐┌──────────┐
│  Gauche  ││  Droite  │
│          ││          │
└────┬─────┘└─────┬────┘
     │ ┌────────┐ │
     └─│ MacBook│─┘
       └────────┘
```

Dans les Reglages macOS, les deux grands ecrans sont colles bord a bord. Le MacBook est place en dessous, entre les deux. Le probleme : la moitie haute des ecrans n'a physiquement rien entre eux, mais macOS ne permet pas de definir deux destinations differentes selon la hauteur du curseur.

ScreenBridge resout ca :
- **Moitie haute** : le curseur atteint le bord interieur → teleportation directe vers l'autre grand ecran
- **Moitie basse** : macOS gere normalement (transition vers le MacBook)

## Prerequis

- macOS 13+
- Autorisation Accessibilite (demandee au premier lancement)

## Build

```bash
cd ScreenBridge
make
```

Produit `build/ScreenBridge.app`.

## Lancement

```bash
make run
# ou
open build/ScreenBridge.app
```

Au premier lancement, accorder l'acces Accessibilite dans :
**Reglages Systeme → Confidentialite et securite → Accessibilite**

## Installation

```bash
cp -R build/ScreenBridge.app /Applications/
```

Pour le lancement automatique au demarrage :
**Reglages Systeme → General → Ouverture → ajouter ScreenBridge**

## Fonctionnement

- Icone barre de menu : ↔ (`arrow.left.arrow.right`)
- Menu : statut + Quit
- Detection automatique des ecrans via `NSScreen.screens`
- Surveillance du curseur via `CGEventTap`
- Teleportation via `CGWarpMouseCursorPosition`
- Cooldown de 0.3s pour eviter les boucles
- Zone de detection de 6px autour du bord
- Logs dans `/tmp/screenbridge.log`

## Structure

```
ScreenBridge/
├── Makefile
├── .gitignore
└── ScreenBridge/
    ├── main.swift          # Point d'entree
    ├── AppDelegate.swift   # Logique principale
    └── Info.plist          # LSUIElement=true (pas d'icone Dock)
```

## Limitations

- Fonctionne uniquement avec le setup 3 ecrans decrit ci-dessus
- Necessite que les deux grands ecrans soient les plus a gauche et plus a droite dans la disposition macOS
- Pas de preferences ni de configuration

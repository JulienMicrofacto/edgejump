# ScreenBridge

App menu bar macOS en Swift. Teleporte le curseur entre deux ecrans exterieurs quand il est dans la moitie haute du bord interieur.

## Build

```bash
cd ScreenBridge && make
```

Pas de Xcode project, pas de SPM — juste `swiftc` via le Makefile.

## Architecture

Un seul fichier de logique : `ScreenBridge/AppDelegate.swift`.

- `setupEventTap()` : cree un `CGEventTap` pour intercepter les mouvements souris
- `handleMouseEvent()` : detecte si le curseur est au bord interieur d'un des deux ecrans exterieurs, dans la moitie haute → teleporte vers l'autre ecran
- `cgRect(from:mainScreenHeight:)` : convertit les coordonnees NSScreen (origine bas-gauche) en coordonnees CG (origine haut-gauche)

## Coordonnees

Attention : NSScreen utilise un systeme avec Y=0 en bas, CG utilise Y=0 en haut. La conversion se fait via `mainScreenHeight - y - height`.

## Logs

Les logs vont dans `/tmp/screenbridge.log`. Position du curseur loggee toutes les 0.5s + events de teleportation.

## Tests

Pas de tests automatises. Pour tester manuellement : bouger la souris vers le bord interieur des deux grands ecrans et verifier la teleportation dans la moitie haute. Verifier que la moitie basse ne teleporte pas.

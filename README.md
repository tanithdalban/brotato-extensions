# Brotato Extensions

Mes mods pour **[Brotato](https://store.steampowered.com/app/1942280/Brotato/)** (Godot 3, ModLoader).
Ce dépôt est un *monorepo* : il héberge plusieurs mods qui partagent la même doc, les mêmes outils de build et le même environnement de développement.

*My Brotato mods. This repository is a monorepo hosting several mods that share tooling and docs. Code and documentation are written in French; in-game labels are bilingual FR/EN. See the English summary at the bottom.*

---

## Les mods

### 🧨 Bomberman — *Bomberto*

Un personnage qui **pose des bombes à mèche** au lieu de viser, et dont la boutique est recentrée sur les armes explosives et la mêlée à fort knockback.

- **Quatre bombes** : la normale (dégâts d'explosion), la **glace** (ralentit durablement, sans dégâts), le **poison** (dégâts sur la durée qui **ignorent l'armure**, feu vert), la **foudre** (salve d'éclairs en cercle, repousse les ennemis).
- **Buffs façon Artificier** : −75 % de dégâts, mais la taille et les dégâts d'explosion montent avec l'élémentaire et l'ingénierie.
- Une **icône de personnage animée** (mèche → explosion → boucle).
- Et une surprise qu'il vaut mieux découvrir en jeu.

📦 [Steam Workshop — item `3752197886`](https://steamcommunity.com/sharedfiles/filedetails/?id=3752197886)

### 🛒 ShopConfig

Un écran de **configuration du pool du magasin, par joueur**, inséré entre la sélection du personnage et celle de l'arme. On y exclut les objets et armes qu'on ne veut **jamais** voir apparaître dans sa boutique de la run.

- Grille filtrée par compatibilité avec le personnage, filtres par tier et par classe.
- Les exclusions sont **mémorisées d'une run à l'autre** pendant la session (aucun fichier écrit sur le disque).
- Fonctionne en **coop** : chaque joueur configure sa propre boutique, à la manette, sur son propre panneau.

📦 [Steam Workshop — item `3748276960`](https://steamcommunity.com/sharedfiles/filedetails/?id=3748276960)

---

## ⚠️ Le jeu n'est pas dans ce dépôt

Le développement s'appuie sur une copie **décompilée** de Brotato, indispensable pour lire le code que les mods étendent (Godot 3 n'a pas de système de hooks : l'intégration passe uniquement par des *script extensions* ModLoader, qui héritent de fichiers du jeu).

Cette copie est du **contenu propriétaire de Blobfish** : elle est exclue par le `.gitignore` et **ne figure nulle part dans ce dépôt ni dans son historique**. Seuls les dossiers `Brotato/mods-unpacked/Tanith-*` sont versionnés. Pour développer, il faut décompiler sa propre copie du jeu (achetée) dans `Brotato/`.

---

## Structure

```
Brotato/mods-unpacked/
  Tanith-Bomberman/     le personnage Bomberto et ses bombes
  Tanith-ShopConfig/    l'écran de configuration du magasin
docs/superpowers/
  specs/                les intentions de design, validées avant d'écrire du code
  plans/                les plans d'implémentation
  notes/                les points d'intégration repérés dans le jeu vanilla
tools/
  build-bomberman.ps1   fabrique le .zip prêt pour le Workshop
  build-shopconfig.ps1
```

Chaque mod isole sa **logique pure** (sans aucune dépendance au jeu) dans `content/logic/`, ce qui la rend testable sans lancer Brotato.

## Tests

Les suites ne couvrent que la logique pure : tout ce qui touche aux autoloads de ModLoader ne se charge pas en mode *headless* et se vérifie en jeu.

```bash
# ShopConfig
./run-tests.sh

# Bomberman (exécutable Godot direct, depuis la racine du dépôt)
"./Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64.exe" \
  --path Brotato --no-window \
  -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
```

Le résultat est la ligne `=== N tests, M échec(s) ===`. Les erreurs moteur affichées **après** cette ligne sont la fermeture des autoloads du jeu : elles sont normales.

## Build

```powershell
tools\build-bomberman.ps1     # -> dist\Tanith-Bomberman.zip
tools\build-shopconfig.ps1    # -> dist\Tanith-ShopConfig.zip
```

Un item Workshop est un **dossier contenant un `.zip`**, que ModLoader monte via `load_resource_pack`. Le `.zip` doit donc contenir `mods-unpacked/<Mod>/…` (et non les fichiers à sa racine), avec des séparateurs `/`.

---

## English summary

Two mods for **Brotato**, kept in one repository:

- **Bomberman** — *Bomberto*, a character who **drops fuse bombs** instead of aiming, with four bomb types (normal, ice, poison, storm), an Artificer-style trade-off (−75 % damage, but explosion size and damage scale with elemental and engineering), and an animated character icon.
- **ShopConfig** — a **per-player shop pool configuration screen**, inserted between character and weapon selection: exclude the items and weapons you never want to see in your shop. Co-op friendly.

In-game text is bilingual (FR/EN); the source, comments and documentation are in French.

**The decompiled game is not part of this repository.** It is Blobfish's proprietary content, excluded by `.gitignore` and absent from the history. Only the mod folders are versioned.

## Licence

[MIT](LICENSE) — © 2026 Tanith Dalban.

La licence couvre le **code des mods** de ce dépôt. Elle ne couvre ni Brotato, ni ses assets.

Les images des mods (sprites de bombes, personnage, icônes) ont été **générées par IA**, puis retouchées et assemblées par script. Elles n'empruntent à aucune œuvre tierce et ne demandent donc aucune attribution.

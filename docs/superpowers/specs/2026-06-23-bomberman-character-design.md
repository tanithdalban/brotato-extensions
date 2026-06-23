# Mod Bomberman — Design

Date : 2026-06-23
Branche cible : à créer (`feat/bomberman`)
Statut : design validé, prêt pour plan d'implémentation.

## 1. Vue d'ensemble

Nouveau mod **séparé** `Brotato/mods-unpacked/Tanith-Bomberman/` (indépendant de `Tanith-ShopConfig`) ajoutant au jeu :

- un **personnage** « Bomberman » dont la seule arme disponible est la Bombe ;
- une **arme** « Bombe » qui se **pose aux pieds du joueur** au rythme de la cadence (pas de visée),
  attend une **mèche** puis explose via le système d'explosion vanilla ;
- l'**art jouable en placeholder** (recompo/recolor d'assets existants) + un **brief de génération IA**
  (`docs/art-brief.md`) avec prompts et specs px exactes, pour les sprites finaux.

Fantasme de jeu : équiper plusieurs Bombes (jusqu'à 6, le max Brotato) ; chacune se posant à la
position courante du joueur, elles se **sèment le long du trajet récent** ⇒ effet **« train »/serpent**
de bombes derrière le joueur.

Toute la rédaction (code, commentaires, libellés de commits) est en **français** ; libellés UI bilingues
FR/EN si besoin, comme le mod ShopConfig.

## 2. Décisions de design (verrouillées)

| Sujet | Décision |
|---|---|
| Pose de la bombe | Aux **pieds du joueur** (position courante), sans ciblage. |
| Scaling des dégâts | **Explosion** (style Artificer) : dégâts = `explosion_damage`, zone = `explosion_size`, boostés par l'**Ingénierie** via le set « outil/ingé ». |
| Sensibilité dynamite / pot de miel | **Automatique** : l'explosion vanilla lit `explosion_damage`/`explosion_size`, que dynamite (+15 dmg) et pot de miel (+10 dmg, +5 size) augmentent déjà. Rien de spécial à coder. |
| Auto-dégâts du joueur | **Aucun** (les explosions vanilla n'affectent pas le joueur). |
| Slots d'arme | **Jusqu'à 6** (= max Brotato par défaut, donc rien à modifier) ; **uniquement des Bombes** (toutes les autres armes bannies). |
| Formation du train | **Traînée naturelle (serpent)** : chaque arme a son cooldown propre et pose à la position courante ; le train émerge du mouvement. Affiné par un **déphasage de cooldown par slot**. |
| Départ | **1 Bombe** ; progression = acheter d'autres Bombes (jusqu'à 6) et monter les tiers en boutique. |
| Tiers de la Bombe | **4 tiers (I–IV)** comme une arme normale, pour une vraie montée en puissance en boutique. |
| Mèche (fuse) | **~1.0 s** par défaut (ajustable). |
| Pipeline art | **Placeholders jouables** d'abord + **brief IA** ensuite ; l'utilisateur dépose les PNG finaux. |

## 3. Architecture

Godot 3 / ModLoader, comme ShopConfig. **Deux familles d'apport** :

1. **Contenu neuf** (perso + arme + bombe) : nos propres ressources `.tres`, scènes `.tscn` et scripts `.gd`,
   enregistrés auprès du jeu via les API ModLoader d'ajout de contenu (`ModLoaderMod.add_*` /
   enregistrement dans `ItemService`). Ce sont des **éléments neufs**, pas des patchs du vanilla.
2. **Aucun patch vanilla requis pour la mécanique** : l'arme est une scène neuve avec son propre script ;
   on n'utilise des `install_script_extension` que si l'intégration du contenu l'exige (à confirmer au plan).

### Arborescence prévue

```
Tanith-Bomberman/
  manifest.json
  mod_main.gd
  content/
    characters/
      bomberman/
        bomberman_data.tres
        bomberman_effect_*.tres          # bonus explosion, bans d'armes, profil de stats
        bomberman_eyes.png / _appearance.tres
        bomberman_mouth.png / _appearance.tres
        bomberman_helmet.png / _appearance.tres   # overlay casque
        bomberman_icon.png
    weapons/
      bomb/
        bomb_weapon.gd                    # BombWeapon extends Weapon/RangedWeapon
        bomb.tscn                         # scène d'arme (sprite tenu)
        bomb_data.tres + bomb_stats.tres  # par tier 1..4
        bomb_icon.png / bomb.png
        bomb_entity.gd / bomb_entity.tscn # la bombe posée (sprite + mèche)
    logic/
      bomb_timing.gd                      # helper PUR (cooldown/fuse/déphasage), testable
    sets/
      bomb_set_data.tres                  # le set « outil/ingé » de la Bombe
  test/
    run_tests.gd                          # runner headless (logique pure)
  docs/
    art-brief.md                          # prompts IA + specs px
```

## 4. Composants

### 4.1 Arme « Bombe » — `BombWeapon`

Script custom étendant la classe d'arme vanilla. Deux surcharges clés :

- **`should_shoot()`** → renvoie vrai dès que `_current_cooldown <= 0` (et que les conditions de
  mouvement vanilla sont respectées : immobile, ou effet « attaque en bougeant »). **Ne dépend
  d'aucune cible ni portée** — contrairement au vanilla (`weapon.gd:273` exige une cible à portée).
- **`shoot()`** → instancie une **entité Bombe** (`bomb_entity.tscn`) à `_parent.global_position`,
  puis relance le cooldown (`get_next_cooldown()`), sans projectile dirigé.

Appartenance au **set « outil/ingé »** ⇒ l'Ingénierie augmente ses dégâts (modèle Artificer).
4 tiers (I–IV) via `bomb_stats.tres` distincts (cooldown, dégâts d'explosion de base, taille).

**Déphasage par slot (train net)** : à l'équipement / au début de vague, chaque instance de Bombe
reçoit un petit décalage de cooldown initial dépendant de son index de slot, afin que les bombes
**s'égrènent en file** au lieu de tomber en paquet au même endroit. Le calcul du décalage est dans le
helper pur `bomb_timing.gd`.

### 4.2 Entité Bombe posée — `bomb_entity`

- À l'apparition : pose le sprite de bombe au sol + (optionnel) animation de mèche.
- **Timer de mèche (~1.0 s)** ; à échéance : instancie `res://projectiles/explosion.tscn`
  (la même explosion que landmines/roquettes), positionnée sur la bombe, puis se libère.
- L'explosion vanilla applique les dégâts de zone en lisant `explosion_damage` / `explosion_size`
  ⇒ **sensibilité dynamite + pot de miel automatique**, **sans toucher au joueur**.

### 4.3 Personnage « Bomberman »

`bomberman_data.tres` (calqué sur la structure de `artificer_data.tres`) :

- `starting_weapons = [ Bombe tier 1 ]`.
- **Bans** : `banned_item_groups` couvre **tous les sets d'armes sauf le set Bombe**
  (à recenser depuis `ItemService.item_groups` / les sets vanilla) ⇒ seule la Bombe peut apparaître
  en boutique. (Bans complétés par `banned_items` si un set ne suffit pas.)
- **Bonus explosion inné** : effet `explosion_damage` (+ un peu d'`explosion_size`), valeurs de
  départ à équilibrer en jeu.
- **Profil de stats** : proposition de départ inspirée Artificer (léger malus dégâts %/armure
  pour cadrer la puissance des explosions) — **à régler en jeu**.
- `wanted_tags = [ "explosive" ]` si pertinent (comme Artificer), à confirmer.
- Slots d'arme : on **ne touche pas** au max (6 par défaut).

### 4.4 Logique pure — `bomb_timing.gd`

Fonctions sans dépendance jeu, **testables en headless** :

- calcul du **déphasage initial** de cooldown selon l'index de slot et le nombre de slots ;
- éventuels helpers de durée de mèche / conversion cadence→intervalle.

Tout ce qui touche aux autoloads/ModLoader (apparition de bombe, explosion, bans) **ne se teste pas
en headless** et se vérifie **en jeu**, comme pour ShopConfig.

## 5. Art

Format : **PNG RGBA transparent, pixel-art** facon Brotato. Dimensions reprises du vanilla.

| Asset | Dimensions | Note |
|---|---|---|
| Perso — yeux (overlay) | 150×150 | posé sur la patate de base |
| Perso — bouche (overlay) | 150×150 | |
| Perso — casque Bomberman (overlay) | 150×150 | élément d'identité ; `display_priority`/`depth` comme les overlays robe vanilla |
| Perso — icône | 96×96 | écran de sélection |
| Arme Bombe — sprite tenu | 80×80 | ×4 tiers (variantes couleur) |
| Arme Bombe — icône | 96×96 | ×4 tiers |
| Bombe posée — sprite | ~32–48 px | bombe ronde noire à mèche ; explosion = vanilla |

**Pipeline en 2 temps** :

1. **Placeholders** générés par recompo/recolor d'assets existants du jeu ⇒ le mod est **100 % jouable**
   et testable immédiatement.
2. **`docs/art-brief.md`** : pour chaque asset, un prompt IA prêt à l'emploi + les contraintes
   (dimensions px exactes, fond transparent, palette, style pixel-art Brotato, cadrage). L'utilisateur
   génère et **dépose les PNG finaux** ; on remplace les placeholders et on rebranche les `.import`.

## 6. Intégration & tests

- **Enregistrement** du perso, de l'arme, du set et des ressources via les API ModLoader (méthode
  exacte à arrêter au plan : `add_content` vs enregistrement direct dans `ItemService`).
- **Déverrouillage** : décider si Bomberman est `unlocked_by_default = true` (pratique pour tester) ou
  verrouillé ; le mod `Tanith-DevUnlockAll` reste dispo pour les tests multi-persos.
- **Commande de test unitaire** (identique à ShopConfig) :
  ```
  "Godot_v3.6.2-stable_win64.exe/Godot_v3.6.2-stable_win64_console.cmd" --path Brotato --no-window -s res://mods-unpacked/Tanith-Bomberman/test/run_tests.gd
  ```
  Couvre **uniquement** `bomb_timing.gd` (logique pure).
- **Vérification en jeu** (copie/symlink du dossier mod à côté du `.pck`) : apparition de la bombe à la
  position du joueur, traînée/serpent avec plusieurs bombes, mèche puis explosion, dégâts aux ennemis
  uniquement, sensibilité dynamite/pot de miel, ban des autres armes, seule la Bombe en boutique,
  montée en tiers, jeu solo **et** coop.

## 7. Risques & points ouverts (à trancher au plan)

- **API d'ajout de contenu ModLoader** exacte pour perso/arme/set (à confirmer sur la version
  `compatible_mod_loader_version`).
- **Recensement des sets d'armes** à bannir pour ne laisser que la Bombe (couverture complète via
  `banned_item_groups` ; secours via `banned_items`).
- **Classe d'arme à étendre** (`Weapon` vs `RangedWeapon`) selon ce dont `shoot()`/`should_shoot()` ont
  besoin sans tirer de projectile dirigé.
- **Réglage du déphasage par slot** pour un train lisible sans trop espacer.
- **Équilibrage** (dégâts d'explosion de base par tier, cooldown, bonus inné, malus éventuels) — itératif
  en jeu.
- **Compat ShopConfig** : Bomberman doit rester cohérent avec l'écran de config du pool (la Bombe doit
  pouvoir y figurer ; les bans perso priment). À vérifier en jeu si les deux mods sont actifs.

## 8. Hors périmètre (YAGNI)

- Pas d'auto-dégâts du joueur.
- Pas de déclenchement manuel / télécommande de la bombe (la mèche est automatique).
- Pas de variantes de bombes (à mèche courte, à fragmentation…) en v1.
- Pas de bombes téléguidées vers les ennemis (décision : pose aux pieds uniquement).
- Pas de tuning d'animation avancé pour les placeholders (l'art final viendra via le brief IA).

# Spec — Troll bombe (mod Tanith-Bomberman)

Date : 2026-06-27
Mod : `Brotato/mods-unpacked/Tanith-Bomberman/`
Statut : design validé, prêt pour le plan d'implémentation.

## Résumé

Nouvel élément du perso **Bombertoe** : la **troll bombe**. Aléatoirement, une bombe
posée par le personnage « se réveille » pendant sa mèche et devient un **danger mobile**
qui poursuit le joueur pour **lui exploser au visage**. Elle est **inarrêtable** par les
armes (elle ne meurt qu'en explosant) et son explosion blesse **les joueurs et leurs
alliés**, jamais les ennemis.

## Décisions de design (validées avec l'utilisateur)

| Aspect | Décision |
|---|---|
| Déclenchement | **Pendant la mèche** : la bombe est posée normalement, puis peut se réveiller. |
| Tuable par les armes | **Non.** Inarrêtable ; ne disparaît qu'en explosant. |
| Fin de vie si elle n'attrape personne | **Minuteur de poursuite** (~4–6 s) → explose sur place. |
| Cible de l'explosion | **Joueur + alliés** (coéquipiers coop). **Pas** les ennemis. |
| Risque de réveil | **~10 %** par bombe posée. |
| Vitesse | **≈ vitesse de base d'un joueur, fixe** : ignore la stat vitesse (un joueur rapide la sème, un joueur ralenti non). La troll bombe ne change jamais de vitesse. |
| Dégâts | **= ceux de la bombe d'origine** (`stats.damage`, donc montée en puissance par tier). |
| Emplacement d'apparition | **Là où la bombe a été posée** (conséquence du réveil pendant la mèche ; souvent derrière le joueur, à distance variable selon son déplacement). |
| Apparence | Bombe cartoon **colorée par le tier de sa bombe d'origine** (T1 gris / T2 bleu / T3 violet / T4 rouge, comme les bombes normales) + **visage fâché** en surcouche (réf. `screens/trollbomb.jpg`). |
| Couleur | **Modulée par le tier d'origine** : corps = sprite de bombe déjà coloré (réutilisé tel quel), visage = overlay unique indépendant du tier. |
| Son de réveil | SFX court joué au réveil ; **son vanilla réutilisé** d'abord (placeholder), à affiner en jeu. |
| Explosion (visuel + dégâts de zone) | **Réutilise `explosion.tscn` vanilla** (cohérent avec la bombe normale). |

## Approche technique retenue

**Approche A — entité « danger » maison dédiée.** Une scène `troll_bomb` autonome,
distincte de la bombe normale, construite hors du tableau des ennemis vanilla. Justification :
les 3 specs « anormales » (inarrêtable, dégâts aux joueurs seulement, minuteur propre) se
contrôlent entièrement, sans se battre contre le framework d'ennemis vanilla (qui sont
tuables, comptés dans le cap, visés par l'auto-aim et par les propres bombes du joueur, et
dont les dégâts viennent des stats d'ennemi). Cohérent avec le style du mod : entités fines
+ logique pure testable.

### Comment infliger des dégâts au joueur (et pas aux ennemis)

Les ennemis vanilla blessent le joueur via un nœud `Hitbox` (`res://overlap/hitbox.tscn`,
classe `Hitbox` extends `Area2D`) placé sur la **couche de collision 4** (« hitbox ennemie »).
Le joueur (`Unit`) a une `Hurtbox` qui réagit à cette couche : `unit.gd:610
_on_Hurtbox_area_entered` → `hurt_area_entered_deferred` → `take_damage`.

La troll bombe porte donc une `Hitbox` sur la **couche 4**, `from = null`, `damage =
stats.damage`. Résultat : les `Hurtbox` des joueurs/alliés encaissent comme face à tout
ennemi ; les ennemis (pas de hurtbox sur cette couche) sont épargnés. Exactement l'inverse
de l'explosion de la bombe normale (`WeaponService.explode` avec `from_player_index`, qui
ne tape que les ennemis).

## Composants

### Nouveaux fichiers

| Fichier | Rôle |
|---|---|
| `content/entities/troll_bomb.tscn` | Scène : `KinematicBody2D` + `Sprite` (corps, texture par tier) + `Sprite` enfant (visage fâché, overlay) + `Hitbox` (couche 4) + `PursuitTimer` (one-shot). |
| `content/entities/troll_bomb.gd` | Comportement : poursuite, contact, explosion, dégâts joueurs/alliés, son de réveil, application couleur par tier. |
| `content/logic/troll_bomb_logic.gd` | **Logique pure** testable (aucune dépendance jeu). |
| `content/weapons/bomb/skins/troll_bomb_face.png` | **Seul nouvel asset** : overlay « visage fâché » (yeux + bouche), indépendant du tier, posé sur le corps coloré (placeholder → art final). |

### Fichiers modifiés

- `content/entities/bomb_entity.gd` : pendant la mèche, tire le dé ~10 %. Sur succès,
  programme le réveil (~50 % de la mèche) ; au réveil, joue le SFX, instancie `troll_bomb`
  à sa `global_position` (en lui transmettant `player_index`, `stats`, `tier`,
  `damage_tracking_key_hash`), puis se `queue_free()` **sans** déclencher l'explosion normale.
- `test/run_tests.gd` : enregistre les tests de `troll_bomb_logic`.
- `content/weapons/bomb/skins/CREDITS.md` : crédit de l'art/son si source CC0 (le moment venu).

## Comportement détaillé (flux de vie)

1. **Pose** — inchangée : `bomb_entity.arm()` pose la bombe, démarre `FuseTimer`.
2. **Tirage du dé** — à l'armement, `troll_bomb_logic.should_wake(roll, chance)` une seule fois
   (`roll` = `randf()` injecté côté entité ; `chance` défaut 0.10).
   - Échec → comportement actuel inchangé (mèche → `WeaponService.explode`, dégâts ennemis).
   - Succès → réveil programmé à `troll_bomb_logic.wake_delay(fuse_seconds, ~0.5)`.
3. **Réveil** — `bomb_entity` joue le SFX de réveil, instancie `troll_bomb` à sa position,
   se libère sans exploser.
4. **Poursuite** (`troll_bomb._physics_process`) — récupère les joueurs vivants, choisit le
   plus proche (`nearest_target`), avance à vitesse fixe (`step_velocity` + `move_and_slide`).
   Apparence : corps = sprite de bombe coloré par le **tier d'origine** (réutilise
   `bomb_skin.load_world_texture(tier)`, comme la bombe normale), + overlay « visage fâché »
   posé en sprite enfant. `PursuitTimer` (4–6 s) démarré au spawn.
5. **Explosion — deux issues** :
   - **Contact joueur** : la `Hitbox` chevauche la `Hurtbox` d'un joueur → dégâts via le
     chemin vanilla ; on déclenche le visuel `explosion.tscn` et `queue_free()`.
   - **Fin du minuteur** : explosion sur place ; `Hitbox` activée brièvement sur le rayon
     d'explosion pour toucher joueurs/alliés à portée, puis `queue_free()`.

**Coop** : chaque troll bombe vise le joueur **vivant le plus proche** ; son explosion finale
peut toucher plusieurs joueurs/alliés dans le rayon.

## Logique pure (`troll_bomb_logic.gd`)

Testable headless, comme `bomb_skin.gd` / `bomb_timing.gd`.

- `should_wake(roll: float, chance: float) -> bool` — `roll < chance`. Bornes : `chance` 0 → toujours faux ; 1 → toujours vrai.
- `nearest_target(from_pos: Vector2, players: Array) -> Dictionary` — joueur vivant le plus
  proche. Entrée : liste de `{index, position, dead}` (ou structure équivalente). Retourne
  `{index, position}` ou un marqueur « aucune cible » si liste vide / tous morts.
- `step_velocity(from_pos: Vector2, target_pos: Vector2, speed: float) -> Vector2` — direction
  normalisée × `speed` ; `Vector2.ZERO` si pas de cible / positions confondues.
- `wake_delay(fuse_seconds: float, fraction: float) -> float` — instant de réveil dans la mèche.

## Tests (ajoutés à `test/run_tests.gd`)

- **Réveil** : `should_wake` vrai/faux autour du seuil ; bornes 0 % et 100 %.
- **Cible** : plus proche correct ; ignore les joueurs morts ; liste vide → aucune cible.
- **Déplacement** : direction correcte ; norme = `speed` ; `Vector2.ZERO` sans cible.
- **`wake_delay`** : valeur cohérente selon mèche/fraction.

Le comportement « scène » (poursuite réelle, `Hitbox`, explosion, son) reste **vérifié en jeu
par l'humain** — non testable headless (autoloads + physique), comme le reste du mod.

## Art & packaging

- **Corps** : aucun nouvel asset — on réutilise tel quel les sprites de bombe déjà colorés
  par tier (`bomb_gray/blue/purple/red_48.png`) via `bomb_skin.load_world_texture(tier)`.
  La couleur de la troll bombe est donc exactement celle de sa bombe d'origine.
- **Visage** : un seul nouvel asset `troll_bomb_face.png` (overlay yeux + bouche fâchés,
  indépendant du tier), pixel-art façon `screens/trollbomb.jpg`. Placeholder d'abord, art
  final ensuite. Même technique que les overlays yeux/bouche du perso Bombertoe.
- Chargés au **runtime** (`Image.load` → `ImageTexture`, filtre net), comme les skins de
  bombe → indépendants du cache `.import`/`.stex`. Le `.png` est embarqué dans le `.zip`
  Workshop par `tools/build-bomberman.ps1` (mécanisme déjà en place).
- Son : SFX vanilla réutilisé d'abord (via `SoundManager`) ; remplaçable plus tard par un
  son dédié CC0 chargé au runtime.

## Paramètres réglables (constantes en tête de `troll_bomb.gd` / `bomb_entity.gd`)

| Param | Valeur de départ |
|---|---|
| Risque de réveil | 10 % (0.10) |
| Instant de réveil | ~50 % de la mèche |
| Vitesse | ≈ vitesse de base joueur (constante) |
| Minuteur de poursuite | 5 s (plage à tester 4–6) |
| Dégâts | = `stats.damage` de la bombe |
| Rayon d'explosion finale | = échelle d'explosion de la bombe (réutilisée) |
| Couleur du corps | = couleur du tier d'origine (`bomb_skin`, réutilisée) |
| Son de réveil | id SFX vanilla + volume (à choisir en jeu) |

## Hors périmètre (YAGNI)

- Pas d'item/upgrade modulant le % de réveil.
- Pas de variation par personnage.
- Pas de comptage dans le cap d'ennemis / affichage minimap.
- Corps : aucun art neuf (réutilise les bombes colorées existantes). Seul nouvel asset = le
  visage en surcouche (placeholder d'abord). Son : réutilisé (placeholder). Finalisation art/son
  ultérieure possible.

## Points à affiner en jeu (humain)

- Choix du **son vanilla** de réveil qui « claque » le mieux.
- Calibrage final : vitesse exacte, durée du minuteur, % de réveil, instant de réveil.
- Validation visuelle du sprite et lisibilité de la menace (solo + coop).
- Récupération des joueurs vivants depuis une entité maison (accès à la liste des joueurs de
  la run via la scène principale / `EntitySpawner._players`) — à confirmer à l'implémentation.

# Bomberman — idées en réserve

Réserve d'idées pour le mod Bomberto. Rien ici n'est engagé ni planifié : c'est un
carnet, pas une feuille de route. Une idée en sort quand elle devient une spec dans
`../specs/`.

## Défis in-game (chaîne de déblocage)

En cours de brainstorming (2026-07-11). L'idée : les bombes ne sont plus toutes
données d'office, chacune se mérite en maîtrisant la précédente.

- Bombe normale **IV** → débloque la **Bombe de Glace**
- Bombe de Glace **IV** → débloque la **Bombe de Foudre**
- Bombe de Foudre **IV** → débloque la **Bombe de Poison**
- Les **quatre bombes en inventaire en même temps** (4 slots sur 6) → débloque la
  **Bombe de Soin**

Faisabilité vérifiée dans le jeu décompilé :

- `ChallengeService` (`singletons/challenge_service.gd`) accepte nos propres
  `ChallengeData` ; `complete_challenge(hash, also_complete_platform_challenge = false)`
  garde le défi **100 % local** (aucun appel Steam).
- Persistance gratuite : `ProgressData.challenges_completed`, sauvegardé sur disque.
- Récompense gratuite : `unlock_reward()` sait débloquer une arme, un objet, un perso…
- Le verrouillage est **réellement respecté par le magasin** : `init_unlocked_pool()`
  (`singletons/item_service.gd:119-127`) ne verse une arme dans les pools que si son
  `weapon_id_hash` est dans `ProgressData.weapons_unlocked`. Une arme verrouillée
  n'apparaît ni en boutique ni au choix d'arme de départ.
- Le déblocage porte sur le `weapon_id`, **commun aux 4 tiers** → débloquer « la Glace »
  débloque toute la famille d'un coup.
- UI gratuite : `challenge_completed_ui.tscn` (pop-up) et `progress_challenge_ui.tscn`
  (écran Progression) affichent déjà les défis.

⚠️ **Pas de succès Steam possible** : les succès sont déclarés par l'éditeur dans le
backend Steamworks de l'AppID 1942280. `steam.setAchievement()` ne fait que cocher un
succès **déjà déclaré** ; un mod ne peut pas en créer.

➡️ **Sortie du carnet** : la chaîne des trois bombes est désormais spécifiée dans
`../specs/2026-07-11-defis-chaine-bombes-design.md` (déblocage à la run suivante, comme
tous ceux du jeu ; popup de migration en solo pour les joueurs qui ont déjà les bombes).
La **Bombe de Soin** et la **Bombe Frag** ci-dessous restent au carnet.

## Nouvelles bombes

### Bombe de Soin

Une bombe qui **soigne le joueur** au lieu de blesser les ennemis. Contre-pied
savoureux sur un perso à -75 % de dégâts. Récompense finale de la chaîne ci-dessus.

À creuser : soigne-t-elle à la détonation dans un rayon (donc il faut rester dans le
souffle, ce qui va à l'encontre du réflexe de fuite) ? Soigne-t-elle les coéquipiers en
coop ? Se cumule-t-elle avec le régénération/vol de vie ?

### Bombe Frag

Idée en réserve, pas encore définie. À distinguer nettement de la Bombe de Foudre, qui
projette déjà une salve d'éclairs en étoile — sinon les deux feront doublon.

Note : la chaîne de déblocage est faite pour accueillir un maillon de plus (il suffit
d'insérer un défi). Mais si le défi final exige **tous** les types de bombe en
inventaire, chaque bombe ajoutée mange un slot : à 5 bombes, il ne resterait qu'un slot
libre sur 6, et la boutique élargie de Bomberto (explosifs, mêlée à knockback)
deviendrait inutilisable pendant la tentative.

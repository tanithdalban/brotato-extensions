# Défis in-game — la chaîne de déblocage des bombes

**Date** : 2026-07-11
**Mod** : Tanith-Bomberman
**Statut** : design validé, à planifier

## L'intention

Les trois bombes élémentaires (Glace, Foudre, Poison) sont aujourd'hui données
d'office. Elles se **mériteront** désormais : chaque bombe se débloque en maîtrisant la
précédente. Bomberto gagne ainsi la boucle de progression du jeu de base, sans qu'on
ajoute la moindre arme nouvelle — on ne fait que verrouiller l'existant et le rendre
gagnable.

Aucun **succès Steam** n'est possible (voir « Ce qu'on ne peut pas faire »). Tout se
joue dans le système de défis **interne** au jeu, qui offre gratuitement la persistance,
le déblocage de récompense et l'affichage.

## La chaîne

| Défi | Condition | Récompense |
|---|---|---|
| `chal_bomb_ice` | Posséder une **Bombe** de niveau IV | Débloque la **Bombe de Glace** |
| `chal_bomb_storm` | Posséder une **Bombe de Glace** de niveau IV | Débloque la **Bombe de Foudre** |
| `chal_bomb_poison` | Posséder une **Bombe de Foudre** de niveau IV | Débloque la **Bombe de Poison** |

**Bomberto lui-même reste débloqué d'office.** On ne verrouille que les trois bombes
élémentaires. La Bombe normale est l'arme de départ **forcée** du personnage
(`effect_starting_bomb`) : la chaîne démarre donc toujours, quoi que fasse le joueur.

**« Posséder », et non « fusionner ».** La fusion de deux bombes III en une IV est le
chemin normal, mais ce n'est pas le seul : en fin de run, le magasin propose directement
des armes de niveau IV à l'achat. Un défi accroché à la seule fusion laisserait ce
joueur bloqué sans comprendre pourquoi. La condition est donc « une bombe de niveau IV
entre dans l'inventaire », quel qu'en soit le moyen.

**Le déblocage prend effet à la run suivante**, comme tous les déblocages du jeu. Le
défi se *complète* pendant la run (pop-up « Défi accompli » + écran de récompense de fin
de run, tous deux gratuits), mais l'arme n'entre dans les pools qu'au démarrage suivant,
puisque `init_unlocked_pool()` est rappelé à chaque début de run (`run_data.gd:574`).
Conséquence assumée : **la chaîne s'étale sur au moins 4 runs**, une par palier. C'est la
cadence de Brotato.

## Ce qu'on ne peut pas faire : les succès Steam

Les succès Steam sont déclarés par l'éditeur dans le backend Steamworks de l'AppID
1942280. `SteamPlatform.complete_challenge()` (`singletons/platforms/steam.gd:109`) ne
fait qu'appeler `steam.setAchievement(nom)`, qui **coche un succès déjà déclaré** — un
mod ne peut pas en créer. Un `setAchievement` sur un nom inconnu est un no-op.

Nos défis passent donc par `ChallengeService.complete_challenge(hash, false)` : le second
paramètre (`also_complete_platform_challenge`) coupe tout appel à la plateforme. Les
défis restent **100 % locaux**.

Note : le jeu ne police pas les mods. `inactive_mods` n'est qu'une liste de préférences,
et `is_unlock_all_save` ne protège que les **succès Steam** du jeu (il les désactive sur
un profil « tout débloquer »). Il n'y a ni anti-triche, ni télémétrie, ni validation de
sauvegarde.

## L'architecture

Quatre points de contact, tous minces.

### 1. Enregistrer les défis

Nos `ChallengeData` sont poussés dans `ChallengeService.challenges` depuis l'extension
`extensions/singletons/item_service.gd` (là où le mod injecte déjà armes et personnage).

⚠️ Il faut renseigner `my_id_hash` **nous-mêmes** : `ChallengeService._generate_hashes()`
se protège derrière un drapeau `_hashes_generated` et ne repassera pas après son `_ready()`.

Chaque `ChallengeData` porte `reward_type = RewardType.WEAPON` et `reward` = la
`WeaponData` de tier I de la bombe à débloquer (`unlock_reward()` déverrouille par
`weapon_id`, qui est **commun aux 4 tiers** — débloquer « la Glace » débloque toute sa
famille d'un coup).

### 2. Détecter

Extension de `singletons/run_data.gd` surchargeant `add_weapon()` : après l'appel au
parent, si l'arme entrante est une bombe de niveau IV, on complète le défi correspondant.

`add_weapon()` (`run_data.gd:982`) est l'**entonnoir unique** de toute acquisition
d'arme : fusion en boutique (`base_shop.gd:693`), achat direct (`base_shop.gd:615/620`),
arme de départ. Aucun angle mort.

### 3. Débloquer

`ChallengeService.complete_challenge(hash, false)`. Le reste est natif : `unlock_reward()`
écrit dans `ProgressData.weapons_unlocked`, `ProgressData.save()` persiste,
`challenges_completed_this_run` alimente l'écran de fin de run.

**Rien à coder pour le timing** : on ne rappelle PAS `init_unlocked_pool()` à chaud.

### 4. Verrouiller

`unlocked_by_default = false` sur les 12 `.tres` de données des bombes glace / foudre /
poison (`bomb_{ice,storm,poison}_{1..4}_data.tres`).

Le verrouillage est alors **respecté nativement** : `init_unlocked_pool()`
(`singletons/item_service.gd:119-127`) ne verse une arme dans les pools du magasin que si
son `weapon_id_hash` figure dans `ProgressData.weapons_unlocked` ; l'écran de choix
d'arme de départ filtre sur la même liste. Une arme verrouillée n'apparaît donc **ni en
boutique, ni au départ**. On ne code rien.

⚠️ Le mod rejoue `ProgressData.add_unlocked_by_default()` dans `item_service._ready()`
(pour réparer le déblocage des armes injectées après le passage natif). Ce replay
respecte le drapeau `unlocked_by_default` de chaque arme : il ne débloquera donc plus les
trois bombes élémentaires. **À vérifier en jeu** — c'est le point le plus fragile du
verrouillage.

## La migration des joueurs existants

Les déblocages sont persistés sur disque. La Glace, la Foudre et le Poison étant
aujourd'hui `unlocked_by_default`, ils sont **déjà inscrits dans la sauvegarde de tous
ceux qui ont lancé le mod**. Passer le drapeau à `false` ne les leur retire pas : la
chaîne existerait mais ne se déclencherait jamais pour eux.

**On leur pose la question.** En **solo uniquement**, à la sélection de Bomberto, si le
joueur possède déjà les bombes et qu'on ne lui a jamais demandé, un popup à deux boutons
s'ouvre :

> **Nouveauté — les bombes se méritent**
> Les bombes de Glace, de Foudre et de Poison se débloquent désormais en relevant des
> défis : montez une bombe au niveau IV pour gagner la suivante.
> Vous les possédez déjà. Voulez-vous les reverrouiller pour vivre la progression, ou
> les conserver ?
>
> `[ Vivre la progression ]` `[ Garder mes bombes ]`

La réponse est **définitive** — reverrouiller n'est pas une perte sèche, c'est un défi
rendu à nouveau disponible.

**Pourquoi solo uniquement.** Le choix engage la sauvegarde du **propriétaire** du jeu.
En couch coop, un popup natif capte **n'importe quel device** (c'est la leçon qui a fait
retirer les `OptionButton` de ShopConfig) : la manette d'un invité pourrait reverrouiller
la progression de l'hôte d'une pression distraite. On ne pose donc jamais la question en
coop ; le joueur garde ses bombes jusqu'à ce qu'il lance une partie solo. On règle le
problème par la géométrie plutôt qu'en se battant contre le moteur.

**Un joueur qui découvre le mod ne voit jamais ce popup** : il n'a rien à perdre, la
chaîne s'applique naturellement.

**Le popup.** Le composant vanilla `ui/popups/popup_anouncement.tscn` ne sait
qu'**annoncer** (un seul bouton de validation). On construit donc le nôtre en code, sur
le même patron — c'est sans commune mesure avec l'écran de ShopConfig, entièrement bâti
en code lui aussi.

**La mémoire du « déjà demandé »** est un **défi caché sans récompense**, jamais affiché,
qu'on complète au moment où le joueur répond. Il atterrit dans
`ProgressData.challenges_completed`, que le jeu sauvegarde. **Aucun fichier maison, aucune
persistance à écrire.**

## Les libellés

Tout passe par `content/i18n/bomberman_translations.gd` (le mod n'a pas de `.csv` —
ModLoader exige un `.translation` compilé, donc **chaque** libellé y est codé en dur), en
FR et EN. Propositions, à caler :

- **Artificier de glace** — *Obtenez une Bombe de niveau IV.*
- **Artificier de foudre** — *Obtenez une Bombe de Glace de niveau IV.*
- **Artificier de poison** — *Obtenez une Bombe de Foudre de niveau IV.*

## Les tests

**Logique pure, en headless** — nouveau module `content/logic/bomb_challenges.gd`, sans
aucune dépendance aux autoloads (comme `bomb_placement.gd` et `bomb_timing.gd`). Il
répond à une seule question : *étant donné un `weapon_id` et un `tier`, quel défi cela
complète-t-il ?*

- Bombe IV → défi glace ; Glace IV → défi foudre ; Foudre IV → défi poison.
- Un tier < IV ne complète rien.
- Une arme non-bombe ne complète rien.
- Poison IV ne complète rien (fin de chaîne).

**En jeu (humain)** — l'essentiel se joue là :

- une sauvegarde neuve ne propose ni Glace, ni Foudre, ni Poison — **ni en boutique, ni
  au choix d'arme de départ** (vérifie le point fragile du replay de
  `add_unlocked_by_default`) ;
- monter une Bombe au niveau IV déclenche le pop-up de défi, et la Glace est disponible
  à la run suivante ;
- le déblocage marche aussi par **achat direct** d'une bombe IV, sans fusion ;
- le popup de migration ne s'affiche **qu'une fois**, **qu'en solo**, et jamais sur une
  sauvegarde neuve ;
- retirer le mod ne casse pas la sauvegarde vanilla.

## Les risques

**On écrit dans la sauvegarde permanente du joueur.** `ProgressData.challenges_completed`
recevra les hash de nos défis. C'est le mécanisme prévu, mais c'est le **premier mod du
dépôt à toucher à la progression persistante**. Si le joueur désinstalle, ces hash
inconnus resteront dans son fichier : le jeu les ignore proprement (`get_chal()` renvoie
`null`, `complete_challenge()` sort sur `chal_data == null`), mais ça vaut d'être
mentionné dans la description Workshop.

**`_sync_platform_challenges()`** (`challenge_service.gd:165`) boucle au démarrage sur
**tous** les défis, dont les nôtres, et appelle `Platform.complete_challenge` **sans** le
garde-fou `false`. Sur Steam, un `setAchievement` avec un nom inconnu est un no-op —
inoffensif, mais à confirmer en jeu.

**Le verrouillage repose sur le drapeau `unlocked_by_default`** et sur le fait que notre
replay de `add_unlocked_by_default()` le respecte. C'est le point à vérifier en premier
en jeu : s'il ne le respectait pas, les bombes resteraient débloquées et toute la
fonctionnalité serait sans effet.

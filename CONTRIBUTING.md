# Contribuer

Les corrections et reprises du projet sont bienvenues. Décrire le problème, les étapes de reproduction, le modèle du Player et les résultats observés. Utiliser des titres et médias de démonstration dans les captures publiques.

Voir aussi les [contrats et responsabilités des modules](docs/ARCHITECTURE.md).

## Organisation

- `app/` : application QML native et ressources embarquées.
- `PlexService.qml` : compte/profils, bibliothèques, progression et API Plex.
- `PlaybackSession.qml`, `Playback.js`, `main.qml` : préparation des flux, lecteur et commandes.
- `tests/` : fonctions JavaScript, serveur/package Python, scènes QML et scénarios matériels.
- `tools/` : lancement, rendu, contrôles et emballage.
- `docs/` : audit et limites ; `distribution/` : brouillon de distribution et captures fictives.

Installer Node 20+ et Python 3.10+ ; la CI utilise Node 22/Python 3.12. Les commandes de vérification sont dans README. Les scripts de rendu utilisent PySide6 sur PC, tandis que le Player utilise un Qt plus ancien : garder la syntaxe JavaScript compatible, les imports existants et vérifier tout nouvel appel sur le matériel. Le DOM XML embarqué utilise des collections indexées, sans méthode `.item()`.

## Essais matériels facultatifs

Ces outils sont destinés au développeur qui possède le Player et le PMS de test. Ils lisent le jeton PMS du profil Windows en mémoire, sans le demander dans un fichier versionné. `Detecter-Devialet.cmd` crée `.local/players.json`. `tools/preview-library.py` prépare un aperçu privé. Les contrôles natifs attendent aussi `.local/playback-probe-media.json`, contenant l’objet de métadonnées d’un média de test (au minimum son `ratingKey`) ; les essais par codec utilisent `.local/codec-samples.json` avec des entrées `{media, streamId}`.

```powershell
python -X utf8 tools/check-ui.py
python -X utf8 tools/check-catalog.py
python -X utf8 tools/check-playback.py --integration --direct
python -X utf8 tools/check-playback.py --integration --direct --soak-seconds 600
python -X utf8 tools/check-playback.py --integration --soak-seconds 600
python -X utf8 tools/check-playback.py --integration --audio-language eng --subtitle-language fra --soak-seconds 60
python -X utf8 tools/check-playback.py --sample video:hevc
```

Les essais remplacent temporairement l’application visible sur la TV. Les trois contrôles utilisent des identifiants d’application distincts, sans modifier la connexion ni les préférences de l’application normale. `check-ui.py` emploie seulement des données fictives et n’accède pas au PMS ; il lui suffit de `.local/players.json`. Les autres contrôles servent leurs accès en mémoire uniquement à ce Player. Le contrôle de lecture emploie l’application complète avec les écritures de progression neutralisées et restaure les pistes d’origine après l’essai, y compris celles de l’épisode suivant. Il relit ensuite les métadonnées et les sessions PMS pour vérifier ces restaurations, l’historique inchangé et l’arrêt des encodeurs. Relancer ensuite `Lancer-Cinema.cmd`. Ne pas lancer ces outils sur le serveur d’un tiers ni pendant une lecture en cours.

Le contrôle catalogue vérifie les douze ordres sur PMS. Les titres suivent la collation du serveur. Les valeurs numériques et les dates sont comparées dans la réponse ; pour une œuvre à plusieurs versions, PMS trie la durée minimale en ascendant et la maximale en descendant. Les pages sans notes sont parcourues jusqu’à obtenir plusieurs valeurs comparables. Il faut au moins une bibliothèque contenant plusieurs films notés.

`--soak-seconds` ajoute de 0 à 1800 secondes de lecture continue avant les changements de pistes et les pannes simulées. Le scénario contrôle la progression toutes les dix secondes, sans repli ni perte des pistes audio/vidéo ; il vérifie ensuite une pause de 35 secondes, un saut de générique contrôlé conservant la suite et une fin de flux réelle après déplacement vers les dernières secondes. Ce n’est pas la lecture d’un épisode entier. Le média d’intégration doit avoir un épisode suivant et être suffisamment long. Les rapports prolongés incluent `-soak`, la durée et les éventuels codes de langue dans leur nom. `--sample` vérifie un seul échantillon converti, avec pause/reprise, audio/vidéo et décision d’incrustation pour un échantillon de sous-titres ; une ancienne référence de piste est refusée.

Pour un contrôle visuel précis, les options `--audio-language` et `--subtitle-language` sélectionnent des pistes disponibles par leur code Plex, uniquement dans le scénario de conversion. Les sous-titres choisis ainsi sont complets, pas limités aux passages forcés. Le test refuse une langue absente, vérifie la décision d’incrustation, puis choisit une autre piste audio pendant la pause. L’écoute et la lecture des sous-titres sur la TV restent nécessaires pour confirmer leur langue et leur synchronisation.

Un test simulé ne valide ni une lecture physique, ni un accès distant, ni une installation Store. Indiquer précisément le niveau de preuve dans chaque contribution. Les cas de recette manquants sont dans `docs/AUDIT.md`.

## Diffusion

Ne jamais ajouter `.local/`, `.tools/`, `dist/`, fichiers personnels, captures réelles ou jetons. `tools/store_assets.py` copie uniquement les captures fictives dont les empreintes ont été validées par `preview.py --store`. Les téléchargements de SDK tiers restent hors dépôt.

Conserver les mentions de licence et de marque. Une contribution de code original est proposée sous la licence MIT du dépôt ; joindre la provenance et la licence pour tout nouveau composant tiers.

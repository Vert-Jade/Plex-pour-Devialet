# Contribuer

Les corrections et reprises du projet sont bienvenues. Décrire le problème, les étapes de reproduction, le modèle du Player et les résultats observés. Utiliser des titres et médias de démonstration dans les captures publiques.

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
python -X utf8 tools/check-catalog.py
python -X utf8 tools/check-playback.py --integration --direct
```

Les essais remplacent temporairement l’application visible sur la TV et servent des accès en mémoire uniquement à ce Player. Le contrôle catalogue utilise un identifiant d’application distinct. Le contrôle de lecture emploie l’application complète avec les écritures de progression neutralisées et restaure les pistes d’origine après l’essai. Relancer ensuite `Lancer-Cinema.cmd`. Ne pas lancer ces outils sur le serveur d’un tiers ni pendant une lecture en cours.

Un test simulé ne valide ni une lecture physique, ni un accès distant, ni une installation Store. Indiquer précisément le niveau de preuve dans chaque contribution. Les cas de recette manquants sont dans `docs/AUDIT.md`.

## Diffusion

Ne jamais ajouter `.local/`, `.tools/`, `dist/`, fichiers personnels, captures réelles ou jetons. `tools/store_assets.py` copie uniquement les captures fictives dont les empreintes ont été validées par `preview.py --store`. Les téléchargements de SDK tiers restent hors dépôt.

Conserver les mentions de licence et de marque. Une contribution de code original est proposée sous la licence MIT du dépôt ; joindre la provenance et la licence pour tout nouveau composant tiers.

# Repères pour maintenir l’application

Le client s’exécute sur le Player et communique directement avec Plex et le PMS choisi. Le serveur Python sert uniquement les fichiers pendant les essais développeur ; il n’est pas nécessaire à une future version installée.

## Responsabilités

| Fichier | Responsabilité |
|---|---|
| `app/main.qml` | Lecteur natif, position absolue, télécommande, reprise et après-lecture |
| `app/PlaybackSession.qml` | Pistes, décision PMS, sessions de conversion, replis bornés et arrêt des encodeurs |
| `app/Playback.js` | Profil de lecture, plafonds, langues, choix direct/conversion et détection des blocages |
| `app/PlexService.qml` | Compte/profil, serveur, bibliothèques, catalogue, Watchlist et progression |
| `app/Request.qml` | Transport annulable, délai, JSON/XML, protection contre les réponses périmées |
| `app/Plex.js` | Métadonnées, chemins, filtres, marqueurs et préférences |
| `app/Shell.qml` | Navigation, focus, fiches et panneaux |
| `app/AppInfo.js`, `app/Brand.qml` | Identité publique, version et présentation du nom avec le logo existant |
| `app/RemoteHints.qml`, `app/TvIcon.qml` | Touches de télécommande et légendes communes, sans ajouter de commandes au focus |
| `tools/devialet.py` | Détection, lancement développeur et liste des ressources publiques |
| `tools/package_freestore.py` | Paquet reproductible et rapport de contrôle ; aucun dépôt automatique |

Les composants visuels reçoivent `api` ou `session`. Ils ne lisent pas la configuration personnelle du PC et ne créent pas de jetons. Conserver les fonctions pures dans les fichiers JS lorsque cela évite d’ajouter de l’état à l’interface. Le service et le Shell restent volumineux ; une extraction future doit préserver leurs contrats et les tests de parcours.

## Invariants à conserver

- `ownerToken` sert au choix Home, `accountToken` appartient au profil actif, `serverToken` vient de la ressource Plex de ce profil. Ne jamais remplacer silencieusement un profil refusé par le propriétaire.
- Un changement de profil ou de serveur annule les requêtes et vide les métadonnées, recherches, reprises et files de progression du contexte précédent.
- `Request.cancel()` invalide la génération et détache les callbacks avant d’annuler le transport. Une réponse d’un ancien écran ne doit pas modifier le nouveau.
- Les textes issus du serveur utilisent `Text.PlainText`. Les images passent par la validation d’URL ; aucun jeton n’est ajouté aux images externes.
- Les dossiers PMS peuvent ignorer la pagination : la vue Dossiers découpe localement la réponse. Playlists et collections utilisent la pagination serveur.
- En direct, `lastPosition` est la position du fichier. En conversion, elle vaut `streamBase + player.position`. Ne pas envoyer le temps relatif du nouveau flux à PMS.
- Une pause utilisateur et un blocage du lecteur sont distincts. Après remplacement de source, appliquer la pause après la notification native de démarrage.
- Les replis automatiques sont bornés. L’échec final libère la source et demande l’arrêt de l’encodeur ; les options restent disponibles pour une action explicite Réessayer.
- L’arrêt des anciens encodeurs conserve des transports indépendants, bornés et suivis en mémoire. Éviter de créer puis détruire des composants QML de requête à chaque transition : cette variante a échoué lors de la recette matérielle.
- Changer `manifest.identifier` change l’espace Settings du Player. Le nom public peut évoluer sans changer l’identifiant de développement.

## Vérification et données

La CI exécute Node/Python, les deux bancs QML et la construction du paquet. Les tests Node exécutent les fonctions extraites des composants ; ils ne remplacent pas l’ancien moteur Qt du Player. Les captures publiques utilisent exclusivement les données fictives de `tests/preview/`.

Les contrôles matériels ont des identifiants d’application distincts. Ils ne chargent pas la connexion mémorisée de l’application normale. Le contrôle de lecture neutralise la progression et sauvegarde les choix de pistes du média initial et de l’épisode suivant avant de lancer le scénario. À sa sortie, il restaure ces choix et relit PMS pour contrôler les pistes, l’historique et l’arrêt des encodeurs. Une fermeture forcée de l’outil peut interrompre ce nettoyage ; privilégier la fin du scénario. Traces et échantillons restent dans `.local/`.

Voir les exigences ouvertes dans [AUDIT.md](AUDIT.md), les limites réseau/stockage dans [SECURITY.md](../SECURITY.md), et les commandes dans [README.md](../README.md).

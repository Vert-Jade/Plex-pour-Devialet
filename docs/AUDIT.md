# Audit comparatif — 15 octobre 2026

## Conclusion

**Le contrat « aussi complet et fiable que Plex officiel » n’est pas encore rempli.** Cette version couvre une part importante de la consultation et de la lecture des films/séries personnels sur Devialet. Elle possède des vérifications automatisées et matérielles utiles, mais plusieurs fonctions manquent et la recette d’installation/d’utilisation distante reste ouverte. Il serait prématuré d’annoncer « mieux que Plex », « tous les formats » ou « prêt pour le FreeStore ».

## Méthode et périmètre

Le code de ce dépôt a été examiné et exécuté. Pour P2F, la référence est la [présentation et l’historique publiés par son auteur](https://p2f-freebox.fr/) : fonctions annoncées, pas nouvelle validation de l’application installée. Aucun dépôt source public P2F n’a été identifié lors de cette recherche ; cela ne prouve pas qu’il n’en existe aucun. Aucune décompilation n’a été effectuée. Les causes de fermetures de P2F ne peuvent pas être déduites de son site.

« Plex officiel » couvre plusieurs applications, pas un produit identique sur tous les appareils. Le référentiel utilisé est la [navigation grand écran](https://support.plex.tv/articles/navigating-the-big-screen-apps/), complétée par les [réglages Android TV](https://support.plex.tv/articles/settings-android-tv/), les [réglages HTPC](https://support.plex.tv/articles/htpc-settings/) et le [parcours après lecture](https://support.plex.tv/articles/202605013-play-queue-post-play-screen/). Une fonction documentée pour une plateforme n’est pas attribuée automatiquement à toutes les Smart TV. Les sources ont été consultées pendant l’audit ; certains accès ultérieurs à l’assistance Plex ont renvoyé HTTP 403.

## Couverture fonctionnelle

Dans la colonne P2F, « annoncé » signifie uniquement documenté par son auteur. « ND » signifie non établi par la source consultée, jamais « absent ».

| Parcours | P2F documenté | Référence Plex grand écran | État de ce projet et limite |
|---|---|---|---|
| Connexion et reprise de session | PIN, mot de passe | Connexion et ouverture automatique | Association par code, case Rester connecté ; aucun mot de passe dans le client |
| Profils et accès séparés | Multiprofil annoncé | Plex Home et profil mémorisé | Liste réelle vérifiée ; choix/PIN implémentés, échange de profil simulé dans les tests |
| Plusieurs comptes racines | Multicompte annoncé | Dépend du client | Un compte racine actif ; déconnexion nécessaire pour changer de compte |
| Plusieurs serveurs | Édition IP annoncée | Sources partagées | Découverte authentifiée, choix si plusieurs ; saisie manuelle absente |
| Personnalisation des sources | Templates annoncés | Sources épinglées | Épingles par profil/serveur ; interface unique, pas de thèmes de disposition |
| Accueil | ND | Reprises et ajouts | Reprises puis ajouts des bibliothèques épinglées ; pas de hubs éditoriaux personnalisables |
| Films, séries, saisons | Annoncé | Bibliothèques | Implémenté et catalogue réel consulté |
| Filtres et tris | ND | Bibliothèque filtrable | Statut, genre et sept tris ; pas de combinaisons avancées enregistrées |
| Recherche | ND | Recherche de contenus | Titres dans les bibliothèques autorisées, pagination complète ; pas de recherche vocale/universelle de personnes |
| Recherche adulte | ND | Dépend des profils/services | Option de résultats explicites, bibliothèques signalables ; dépend des métadonnées, pas un contrôle parental |
| Watchlist | ND | Ma liste | API cloud, résolution locale, ajout/retrait ; écritures couvertes par simulations |
| Collections | Annoncé | Collections | Parcours exposé et endpoint réel testé |
| Playlists | Annoncé | Playlists | Consultation des listes existantes et de leurs titres depuis le menu de bibliothèque ; édition, création et enchaînement de la playlist absents. Aucun contenu de playlist réel disponible sur le serveur de recette |
| Navigation par dossiers | Annoncé | Selon bibliothèque/client | Accessible depuis Bibliothèque, réponse JSON et retour parent vérifiés sur Devialet ; pagination locale |
| Fiches et distribution | Annoncé | Fiches détaillées | Résumé, technique, distribution ; filmographie limitée à la bibliothèque source, pas de biographie acteur complète |
| Thèmes musicaux | Annoncé | Selon client/serveur | Thème du titre/série, volume et activation ; source requise côté serveur |
| Bandes-annonces et bonus | ND | Extras Plex | Extras jouables du serveur ; une bande-annonce avant film en option, pas tout le programme Cinema Trailers officiel |
| Lecture directe/stream/conversion | Annoncé | Adaptation au client | Direct prioritaire puis HTTP Matroska H.264/AAC ou AC3, conversion plafonnée à 1080p |
| Audio, sous-titres, qualité | Annoncé | Choix en lecture | Pistes exposées par Plex, langues par défaut, qualité, taille ; sous-titres incrustés si sélectionnés |
| Sous-titres en ligne et décalage | ND | Selon client | Téléchargement/recherche et décalage temporel absents |
| Reprise et synchronisation | Annoncé | Progression partagée | Envois réguliers et file finale avec réessais ; perte possible si arrêt brutal avant confirmation |
| Intros et génériques | ND | Repères Plex et options | Sauts automatiques par défaut, scènes après générique préservées ; repères serveur nécessaires |
| Chapitres et déplacement | ND | Navigation de lecture | Chapitres et leurs images lorsqu’exposées ; pas de bande d’aperçus BIF pendant l’avance rapide |
| Épisode suivant | Lecture continue annoncée | File et écran après lecture | Suite chronologique, 15 secondes annulables, garde de deux heures ; pas de PlayQueue éditable ni suggestions après lecture |
| AirPlay / contrôle depuis téléphone | AirPlay annoncé | Selon plateforme | Non implémenté |
| Musique, photos, TV/DVR | Vidéo/séries annoncées | Écosystème plus large | Hors couverture actuelle : seulement films/séries personnels |
| Catalogue gratuit Plex / Discover complet | ND | Services cloud selon client | Non implémenté ; Watchlist seule ne remplace pas Discover |
| Installation et mises à jour | FreeStore annoncé | Distribution de chaque plateforme | Lanceur développeur et générateur .fbxqml ; installation Store non validée |
| Utilisation hors du domicile | ND | Accès distant Plex | Découverte HTTPS/relais prévue ; aucune recette complète sur un autre réseau dans cet audit |
| Démarrage local sans Internet | ND | Dépend du client et de sa session | Non pris en charge : restauration et découverte nécessitent actuellement les services Plex |

Les dépendances de repères et d’extras sont décrites par Plex : [génériques](https://support.plex.tv/articles/credits-detection/), [Cinema Trailers et extras](https://support.plex.tv/articles/202934883-cinema-trailers-extras/). Les [droits de lecture distante](https://support.plex.tv/articles/requirements-for-remote-playback-of-personal-media/) doivent aussi être vérifiés pour le compte et le serveur utilisés.

## Défauts traités pendant l’audit

- Suppression de la personnalisation privée injectée par le lanceur et mise à jour de la documentation publique.
- Progression finale auparavant susceptible d’être perdue si une requête était déjà active : file de requêtes, réessais bornés et rafraîchissement après confirmation.
- Recherche précédemment limitée à une bibliothèque : agrégation paginée des bibliothèques autorisées, annulation des anciennes réponses.
- Profils Home, préférences de langue, chapitres, collections, filmographie, bonus et enchaînement ajoutés ou rendus accessibles.
- DOM XML embarqué différent de celui du PC : remplacement des appels `.item()` par l’accès indexé, vérifié sur Player.
- Focus des réglages devenu invisible après reconstruction du modèle : resynchronisation de l’index et défilement explicite, avec assertions de visibilité.
- Option Rester connecté : désactivation effaçant les jetons persistants tout en préservant la session active ; absence de repli silencieux vers le propriétaire.
- Masquage d’un nom de dossier spécifique remplacé par épingles et réglages génériques de recherche ; ligne Retour redondante retirée des profils.
- Refus des chemins média traversants/absolus et contrôle du contenu exact de l’index Git avant diffusion.

## Corrections supplémentaires de la version 0.5.1

- Changement de serveur : purge des caches, résultats et requêtes du serveur précédent, même lorsque les identifiants des médias se ressemblent.
- Transport : exceptions natives et réponses JSON malformées libèrent l’état de chargement ; une réponse tardive ou répétée ne termine pas la nouvelle requête.
- Profil temporaire expiré : retour au choix Home sans perdre le compte racine en mémoire et sans rétablir ses droits silencieusement. Rafraîchir ou annuler le choix du profil conserve la bonne destination.
- Préférences invalides : valeurs normalisées au démarrage, JSON corrompu récupéré sans effacer une connexion valide.
- Affichage : métadonnées en texte brut ; le serveur ne peut plus injecter des balises de présentation ou des images dans ces textes.
- Statut vu/non vu : mise à jour cohérente dans l’accueil, la recherche et la Watchlist après confirmation serveur.
- Lecture : échec final libérant la source et la session, arrêt des encodeurs borné, déplacement direct borné même en pause, commandes Lecture/Pause idempotentes.
- Identité publique centralisée, logo jade conservé après « pour », sélecteur de vues sans glyphe manquant et véritable icône Dossier.
- Aides de télécommande réunies dans un composant commun : touches dessinées, actions alignées, séparateurs et libellés contextuels. Le lecteur, les réglages, les menus, la recherche et les profils utilisent cette présentation. Numéros d’épisode normalisés en `S02E02`, y compris les cartes de reprise.

Les responsabilités et invariants du code sont décrits dans [ARCHITECTURE.md](ARCHITECTURE.md).

## Niveaux de preuve

1. **Tests JavaScript simulés** : authentification, choix de profil/PIN, isolation des données, pagination, Watchlist, progression, langues, marqueurs, conversion, reprises, réessais et épingles/recherche adulte. Ils ne prouvent pas les écritures réelles vers Plex.
2. **Tests Python locaux** : ressources du lanceur, refus des chemins privés, paquet reproductible complet, contrôle de publication. Le nombre exact et les résultats sont consignés dans `distribution/VERIFICATIONS.txt` et par la CI.
3. **QML sur PC, données fictives, 720p/1080p** : navigation, focus, connexion/checkbox, profils/PIN, listes, menus, réglages et options de chapitres. Les captures publiques proviennent de ce banc, jamais d’une médiathèque privée.
4. **Catalogue sur Devialet réel** : recherche, collections, métadonnées enrichies, requête acteur, lecture XML des profils Home et recherche de l’épisode suivant. Contrôle dédié sans changement de compte ni écriture d’historique. La recette du 15 octobre ajoute le parcours réel des dossiers et le point d’accès des playlists (liste vide sur le serveur de test).
5. **Lecture sur Devialet réel** : image/son en direct, reprise, saut d’intro contrôlé, blocage simulé puis conversion, changement audio en pause, déplacement, deuxième repli et arrêt des sessions. L’application complète a aussi affiché l’après-lecture et lancé l’épisode suivant avec image/son après une fin injectée par le test. Ce dernier essai ne remplace pas la lecture naturelle de deux épisodes complets. Les marqueurs image/son du backend ne prouvent pas la qualité acoustique d’un mix surround.
Le scénario de lecture a été renforcé avec des commandes Lecture/Pause répétées, un échec final injecté et une action Réessayer. Une variante de nettoyage créant/détruisant des composants QML temporaires a interrompu plusieurs essais matériels. Elle a été écartée après un essai comparatif ; la méthode retenue conserve des transports indépendants, avec expiration et nombre borné. Cette comparaison ne constitue pas une analyse interne du firmware Free.

La nouvelle passe du 15 octobre a observé **600 secondes continues en direct et 600 secondes en conversion** sans blocage ni repli non demandé. Le spectateur a confirmé la synchronisation image/son dans les deux modes, puis l’affichage correct des sous-titres français lors d’un scénario VO/ST français explicite. L’application complète a aussi passé une pause de 35 secondes, un changement réel de piste audio, un saut de générique injecté laissant la scène suivante jouable et une fin de flux native après déplacement vers les dernières secondes. Cela ne remplace pas la lecture d’un film entier.

Le premier scénario prolongé direct a signalé deux erreurs d’assertion après ses dix minutes continues : départ converti arrondi à la seconde et notification de position native décalée par rapport au compteur du lecteur. Les mesures détaillées ont permis de corriger le banc ; les scénarios complets suivants passent. Les journaux initiaux restent conservés dans les données privées. Les contrôles finaux relisent PMS pour vérifier les pistes restaurées du média initial et de l’épisode suivant, l’historique inchangé et l’absence de nouvelles sessions de conversion de test restantes.

6. **Échantillons de codecs rejoués sur Devialet le 15 octobre** : 15 conversions réussies avec progression, pause/reprise et pistes audio/vidéo actives. Vidéo : H.264, HEVC, AV1, MJPEG, MPEG-4 ; audio : AAC, E-AC3, AC3, DTS, MP3, WMA v2 ; sous-titres : SRT, ASS, PGS, texte MP4 (`mov_text`). La décision d’incrustation a été vérifiée pour les quatre échantillons de sous-titres. Chaque extrait dure environ six secondes après démarrage, avec une pause supplémentaire : ce contrôle ne valide ni toutes les variantes de ces formats ni la synchronisation visuelle de chaque piste. Le scénario VO/ST français distinct a reçu une confirmation visuelle du spectateur. Les traces et médias de référence restent privés.

## Avant une candidature Store stable

| Priorité | Preuve encore nécessaire | Critère de réussite |
|---|---|---|
| P0 | Nouvelle installation et redémarrage à froid | Choix des bibliothèques, association, session conservée ou effacée selon la case ; aucun ancien profil affiché |
| P0 | Changement Home réel, PIN erroné/valide et compte restreint | Droits et historique séparés, aucun retour propriétaire, refus d’accès clair |
| P0 | Films entiers et épisodes consécutifs | Pas de fermeture, son/sous-titres synchronisés, progression correcte dans un autre client |
| P0 | Panne réseau et arrêt brutal | Erreur récupérable, absence de sessions orphelines, limite de dernière progression documentée |
| P0 | Autre réseau, débit faible et relais | Association, navigation, conversion et reprise utilisables avec les droits Plex requis |
| P0 | Identité publique et marques | Accord écrit pour le logo Plex recoloré et son icône ; examen du nom et de la présentation. Voir [NOTICE.md](../NOTICE.md) |
| P0 | Distribution FreeFactory | Compte actif, identifiant reconnu, métadonnées/visuels conformes, droits de marque examinés |
| P0 | Installation FreeStore et mise à jour réelle | Application durable, favoris, paramètres conservés lors d’une mise à jour |
| P1 | Recherche/filtrage sur très gros serveur | Temps acceptable, listes complètes, aucune réponse ancienne après annulation |
| P1 | Tests TV visuels et télécommande physique | Lisibilité et focus sur longues listes, absence de débordement à 95 %, scènes vides/erreurs correctes |
| P1 | Compléments de parité | Édition/enchaînement des playlists, aperçus BIF, sous-titres en ligne/décalage, PlayQueue |

L’état ouvert de ces points est volontairement visible dans le dépôt. Une publication du code permet la collaboration ; elle ne certifie pas une application Store achevée.

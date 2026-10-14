# Confidentialité

Le client communique directement avec Plex pour l’association, les profils, les serveurs partagés et la Watchlist, et avec le Plex Media Server choisi pour les métadonnées, images, thèmes, vidéos et progression. Les images cloud autorisées peuvent venir de Plex, TMDB ou TheTVDB, sans ajout du jeton Plex à ces URL externes. Aucun serveur de collecte, publicité ou outil de mesure d’audience propre à ce projet n’est intégré.

## Sur le Player

« Rester connecté », activé par défaut, enregistre les jetons de compte et de profil dans `fbx.application.Settings`. Le mot de passe Plex et le PIN du profil ne sont jamais enregistrés par le client. Aucun chiffrement matériel de ce stockage n’a été vérifié et il n’est pas présenté comme un coffre-fort.

Désactiver cette option efface les jetons persistants et conserve seulement la session active en mémoire. Fermer puis rouvrir l’application nécessite alors une association. « Déconnecter ce Devialet » efface également la session active et les métadonnées en mémoire. Les préférences d’affichage, identifiant aléatoire de client et listes d’identifiants de bibliothèques restent locaux. Cette action ne révoque pas les sessions des autres clients Plex.

Le profil mémorisé peut se rouvrir sans PIN, comme une session déjà connectée. Pour choisir le profil à chaque lancement, désactiver « Retrouver mon profil ». Pour un Player partagé sans confiance, désactiver aussi « Rester connecté ». Une révocation par Plex peut imposer une nouvelle association, même si cette option est activée.

## Bibliothèques et recherche

Aucun nom de bibliothèque n’est interdit dans le client. Les épingles sont propres au couple profil/serveur sur ce Player et contrôlent le menu et l’accueil. La recherche parcourt les bibliothèques autorisées par Plex, y compris celles qui ne sont pas épinglées.

Par défaut, la recherche exclut les titres identifiés explicitement adultes (classification X, XXX, Adult ou R18, ou indicateur adulte) et les bibliothèques signalées « Adultes » dans Mes bibliothèques. Un classement 18+, NC-17 ou TV-MA seul n’entraîne pas d’exclusion. L’option « Résultats adultes dans la recherche » autorise ou masque ces résultats. La modification efface immédiatement les anciens résultats en mémoire.

Un contenu non classé peut passer ce filtre ; il faut signaler sa bibliothèque. Ce réglage ne s’applique pas à la Watchlist ni à une bibliothèque ouverte explicitement et ne constitue pas un contrôle parental. Les restrictions effectives d’accès doivent être attribuées aux profils dans Plex ; le client utilise le jeton du profil choisi et ne revient pas silencieusement au propriétaire si ce jeton est révoqué.

## Réseau et développement

Les échanges cloud et distants utilisent HTTPS. Une connexion HTTP de réseau privé peut être utilisée localement si le serveur l’autorise. Sur ce réseau, les requêtes peuvent donc être lisibles par un tiers capable d’intercepter le trafic. L’identité annoncée du serveur est comparée à celle découverte par Plex avant l’envoi du jeton serveur.

Le lanceur développeur sert uniquement une liste de fichiers de l’application, jamais le dossier du projet. Les outils matériels facultatifs peuvent lire le jeton du PMS local en mémoire ; les données d’essai restent dans `.local/`, exclu de Git. Ne pas exposer le mode développeur à Internet.

Les politiques de Free et Plex restent applicables à leurs propres services. Ce document décrit le comportement du code, pas une certification de sécurité.

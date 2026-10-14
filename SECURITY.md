# Sécurité

Cette version est en développement. Aucun audit de sécurité externe ni certification Free n’a été obtenu.

## Signaler un problème

Utiliser l’onglet Security du dépôt, « Report a vulnerability », lorsqu’il est disponible. Ne pas placer de jeton, PIN, mot de passe, IP personnelle, capture de médiathèque ou journal brut dans une issue publique. Si le signalement privé est indisponible, ouvrir une issue demandant un canal privé sans publier les détails exploitables.

## Protections présentes

- Association Plex par code ; aucun mot de passe demandé dans l’application.
- Option de persistance explicite, déconnexion avec confirmation, purge du cache lors d’un changement de profil.
- Échec de PIN conservant le profil courant ; jeton de profil révoqué redirigeant vers le choix du profil, sans repli sur le compte propriétaire.
- HTTPS cloud/distant, vérification de l’identité du serveur avant envoi de son jeton, refus des URL média absolues et chemins traversants.
- Images externes limitées à une liste de domaines, sans jeton de compte/serveur ajouté.
- Requêtes annulables, délais bornés et générations empêchant les réponses tardives de restaurer d’anciennes données.
- Lanceur à liste de ressources explicite ; configuration QA temporaire servie au seul Player sélectionné.
- Contrôle de l’index Git avant publication et en CI ; historique créé à partir de fichiers nettoyés.

## Limites à traiter avant une version stable

Le stockage natif Settings et le suivi des redirections HTTP du moteur Qt n’ont pas fait l’objet d’un audit de plateforme. Le HTTP local reste possible. Les jetons nécessaires aux flux multimédias peuvent apparaître dans les diagnostics du firmware ; le lanceur masque les URL et ne conserve que des marqueurs applicatifs, mais ne contrôle pas les journaux système de Free ou PMS.

Le filtre adulte est un réglage de présentation, pas une frontière de sécurité. Le serveur doit imposer les restrictions de ses profils. La progression finale est réessayée en mémoire ; une coupure électrique immédiate peut perdre la dernière mise à jour.

## Avant chaque publication

Examiner `git diff --cached`, exécuter `python -X utf8 tools/check_public.py`, vérifier les images et l’identité auteur Git. Le contrôle examine l’index exact et peut lire des termes privés supplémentaires dans `.local/private-terms.json` ; il n’affiche jamais les valeurs trouvées. Ce contrôle complète la revue humaine, il ne remplace pas l’examen des images et fichiers binaires.

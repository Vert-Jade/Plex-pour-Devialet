# Ressources

`plex-logo.svg` : logo récupéré le 14 octobre 2026 depuis le site officiel Plex, à https://www.plex.tv/wp-content/themes/plex/assets/img/plex-logo.svg . Chevron recoloré en jade à la demande de l'utilisateur ; original conservé dans `plex-logo-original.svg`. Marque Plex, utilisée pour identifier la connexion au compte Plex. L'application Le Pavillon de Jade pour Plex est un client indépendant.

`app-icon.png` : rendu 512 × 512 du même logo vectoriel sur fond noir, produit par `tools/store_assets.py`. Les captures `distribution/images/*-demo.png` utilisent les titres et affiches fictifs du banc de vérification QML ; elles ne contiennent pas la bibliothèque privée. Les dimensions finales exigées pour le dépôt restent à confirmer dans la console FreeFactory.

`login-lounge.png` : fond préparé avec l'outil intégré imagegen à partir de la référence de connexion fournie par l'utilisateur le 14 octobre 2026. La composition de référence guide les coordonnées QML ; le décor restauré est une reconstruction, pas une copie de pixels garantie. Les textes, le panneau et le bouton restent des composants natifs. Prompt : retirer uniquement les éléments d'interface, conserver le salon sombre, canapé et plaid jade, plante éclairée, table avec popcorn et télécommande, affiches murales, cadrage et éclairage de la référence ; aucun nouveau texte ni élément.

Les affiches et fonds des titres sont chargés depuis le serveur Plex de l'utilisateur. Aucun média privé n'est inclus dans les fichiers distribués de l'application.

Référence de disposition et navigation : Plex Big Screen, https://support.plex.tv/articles/navigating-the-big-screen-apps/ (captures consultées le 14 octobre 2026, stockées dans `.local/references/`). Les composants QML, les icônes vectorielles Canvas et le dégradé sont implémentés dans ce projet.

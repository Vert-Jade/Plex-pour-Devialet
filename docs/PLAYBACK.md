# Lecture et compatibilité

## Stratégie

Le fichier original est tenté en premier lorsque les options le permettent. Si le lecteur échoue, reste bloqué 20 secondes ou subit trois blocages d’au moins trois secondes dans une minute, la préparation Plex reprend à la position connue. Le premier échec de lancement est borné par un délai de 45 secondes. Une pause demandée ou le menu d’options ne compte pas comme un blocage.

Le lecteur Qt embarqué ne permet pas de sélectionner toutes les pistes dans un fichier direct. Une piste différente du défaut du fichier, des sous-titres sélectionnés, un fichier en plusieurs parties ou une qualité manuelle peuvent donc imposer le passage par le serveur dès le départ. La compatibilité des choix demandés prime dans ces cas.

## Sorties serveur

| Paramètre | Comportement |
|---|---|
| Transport | HTTP Matroska ; HLS écarté après un échec réel du backend embarqué |
| Vidéo | H.264, cible maximale 1080p, 8 bits ; la vidéo compatible peut être conservée avant un échec |
| Audio | AAC stéréo ; option AC3 5.1 ; repli de stabilité en stéréo |
| Sous-titres | Incrustés par PMS, selon les pistes qu’il sait décoder |
| Automatique local | Plafond de conversion 1080p/12 Mbit/s |
| Automatique distant | 720p/4 Mbit/s ; relais 480p/1,5 Mbit/s |
| Choix manuel | De 360p/700 kbit/s à 1080p/20 Mbit/s |
| Replis bornés | Conversion au plafond choisi, puis maximum 720p et 480p ; jamais d’augmentation d’un plafond inférieur |

Les plafonds concernent la préparation serveur, pas le fichier original lu directement. L’application n’altère pas les fichiers de la médiathèque.

Pause, reprise, changement de piste et déplacement conservent la position absolue. Les anciennes sessions de conversion sont arrêtées lors d’un changement ; les sessions actives reçoivent un maintien, y compris en pause. La progression est envoyée régulièrement et à l’arrêt. L’arrêt final est réessayé deux fois en cas de panne temporaire ; cette file est en mémoire, pas durable après une coupure électrique.

## Limites

La prise en charge universelle n’est pas démontrée. Les codecs/profils que PMS ne décode pas, fichiers corrompus/protégés, droits insuffisants, serveur saturé ou réseau trop lent peuvent échouer. Les sous-titres doivent être reconnus par PMS ; leur recherche en ligne et leur décalage ne sont pas implémentés. Les extras sans identifiant convertible restent en lecture directe.

La conservation de 4K/HDR/Dolby Vision, Atmos et audio sans perte n’est pas un objectif de cette sortie de compatibilité 1080p. Un signal indiquant audio/vidéo actifs ne constitue pas une écoute de contrôle du surround. Les chapitres utilisent les offsets et éventuelles images fournis par PMS ; il n’existe pas encore de bande d’aperçus BIF pendant les déplacements.

Voir [AUDIT.md](AUDIT.md) pour les essais réellement effectués et ceux qui restent nécessaires. Aucune modification de la configuration globale du serveur n’est requise par le client ; les choix de pistes et la progression sont des écritures normales de lecture vers Plex.

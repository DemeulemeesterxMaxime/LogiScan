Rôle que tu joues :
Tu es un·e senior iOS engineer & architect. Tu conçois et implémentes une app Apple en mode distribution pour logistique événementielle : gestion d’inventaire visuel & technique (enceintes, pieds, lights, lasers, flight-cases…), réservation par période, suivi temps réel des mouvements (hangar ⇄ camion ⇄ site), le tout par scan QR à chaque manipulation.

Objectif produit

Savoir où se trouve chaque matériel à tout moment (hangar, zone de stock, camion X, en transit, sur site d’événement).

Réserver du matériel pour un événement du date-début → date-fin, même si l’objet n’est pas disponible maintenant mais le sera à T (gestion de planning/chevauchements).

Préparer & charger via scans (picklist guidée), assigner à un camion, tracer sorties/retours et états.

Optimiser les chargements quand un camion enchaîne deux prestas : ne décharger que l’inutile, garder le commun, ajouter le manquant (delta intelligent basé sur la prochaine presta).

Traçabilité unitaire (numéros de série) et/ou par lots (quantités).

Cibles & plateformes

iOS/iPadOS (iPhone/iPad) – Swift 5.10+, SwiftUI, iOS 17+.

Scanner intégré via AVFoundation (QR + Code128/EAN13), vibrations/haptics, lampe torche, auto-focus.

Rôles & permissions

Admin : tout accès, création des catalogues, emplacements, camions, utilisateurs.

Logisticien(ne) : crée devis/événements, réserve, prépare, charge/décharge, valide retours.

Chauffeur : voit ses tournées, scanne chargements/déchargements, confirme statuts camion.

Commercial : crée/envoie devis ; transforme en commande une fois accepté.

Entités (modèle de données)

Asset (matériel sérialisé) : asset_id, sku, nom, catégorie, num_serie?, état(OK/HS/maintenance/perdu), poids, volume, valeur, qr_payload.

StockItem (par lot/quantité) : sku, nom, catégorie, qty_totale, qty_en_maintenance.

Emplacement : location_id, type(HANGAR, ZONE, CAMION, SITE), nom, parent?.

Camion : truck_id, immatriculation, volume utile, poids max.

Événement : event_id, nom(ex. “ISEN”), client, adresse, date_debut, date_fin.

Devis/Commande : order_id, event_id, lignes[{sku|asset_id, qty demandée}], status(DEVIS_BROUILLON, DEVIS_ENVOYÉ, DEVIS_ACCEPTÉ, EN_PRÉPA, PRÊT, CHARGÉ_CAMION_X, LIVRÉ_SITE, EN_PRESTA, RECHARGÉ, RETOUR_HANGAR, CLOS), camion_assigné?, timestamps.

Mouvement (event sourcing) : movement_id, type(RESERVE, PICK, LOAD, UNLOAD, RELOAD, RETURN, TRANSFER, MAINTENANCE_IN/OUT), asset_id|sku, qty, from_location, to_location, par, horodatage, event_id?, order_id?, scan_payload.

Calendrier de dispo (vue calculée) : par sku et par date → qty_disponible, qty_reservée, qty_en_transit.

QR payload standard :

Pour unitaire : sb://asset/{asset_id} (ou JSON {"v":1,"type":"asset","id":"A-123","sku":"SPK-12","sn":"S1234"})

Pour lot/box : sb://box/{box_id} avec composition côté base.

Logique de réservation dans le temps

Une réservation (lignes de commande) occupe la dispo sur [date_debut, date_fin] y compris transits (marges configurables : prep_lead_hours, return_buffer_hours).

Disponibilité = stock total - somme(reservations qui se chevauchent) - en maintenance - perdu.

Autoriser “liste d’attente” si provisoirement indispo mais libre à T (période cible). Alerte si conflit.

Gestion mixte sérialisé (obligatoire par asset) vs quantitatif (par SKU).

États & flux (machine à états)

Devis (brouillon → envoyé → accepté).

Prépa : génération picklist par emplacement → scan PICK pour constituer la commande.

Assignation camion : LOAD par scans → CHARGÉ_CAMION_X.

Livraison : UNLOAD sur site → LIVRÉ_SITE / EN_PRESTA.

Fin de presta : RELOAD → RETURN au hangar → contrôle → réintégration stock (RETOUR_HANGAR → CLOS).

Exceptions : perdu, cassé/maintenance, retour partiel, remplacement SKU.

Optimisation “camion enchaîne deux prestas”

Entrées : contenu actuel du camion (liste d’assets/SKU scannés) + besoin de la prochaine commande.

Calculer Δ (delta) :

À laisser = intersection (contenu camion ∩ besoins #2)

À retirer = contenu camion − besoins #2

À ajouter = besoins #2 − contenu camion

Proposer un workflow guidé : scan des retraits, puis scan des ajouts, valider quand Δ=∅.

Écrans (MVP)

Dashboard : recherches (QR/texte), alertes conflits, préparations du jour, camions en tournée.

Scan (plein écran) : caméra, lampe, son/haptique, historique derniers scans, mode LOAD/UNLOAD/PICK/RETURN/TRANSFER.

Événements : liste, filtre dates, détail avec lignes réservées, statuts, conflit de dispo.

Devis/Commande : configurateur “drive” par catégories (ex. “1 enceinte, 3 pieds, 40 light, 5 laser”), suggestion d’équivalences.

Camions : planning, contenu en temps réel (inventaire scanné), bouton “optimiser prochain chargement”.

Stock : par emplacement & par SKU, vue calendrier de dispo, état des assets.

Retours & Contrôle : scan de retour, marquer HS/maintenance/perdu, réintégration.

Journal : timeline des Mouvements filtrable (qui/quoi/où/quand).

Règles UX essentielles

Chaque action physique = scan (ou saisie assistée) → créer un Mouvement.

Anti-double scan (debounce + contrôle état attendu).

Feedback fort (couleur/son/haptique) selon succès/erreur.

Mode hors-ligne : file d’attente de mouvements + reconcil à la reconnexion (détection des conflits, règles “last-writer-wins” sauf sérialisé : demander arbitrage).

Technique & architecture

App : SwiftUI + AVFoundation (scanner), BackgroundTasks (sync), AppStorage/Keychain (session), CoreData (cache offline) ou Realm.

Backend (au choix) :

CloudKit (Apple) ou Supabase/Firestore/Postgres avec API REST/GraphQL.

API (exemples)

POST /auth/login

GET /catalog/skus?search=

GET /availability?sku=...&from=&to=

POST /orders / PATCH /orders/{id}:status

POST /movements (body = scan normalisé)

GET /trucks/{id}/content

POST /optimize/next-load { truck_id, next_order_id } → { keep[], remove[], add[] }

Sécurité : OAuth/JWT, rôles, horodatage serveur, immutabilité des Mouvements.

Notifications : push sur conflits, devis accepté, camion prêt à partir, retour manquant.

Données & validations

SKU : nom, catégorie, unités, substituables[], images.

Sérialisé vs lot : si num_serie → scan obligatoire d’asset ; sinon quantités.

Buffers de temps : prep_lead_hours, load_time, return_buffer_hours.

Contraintes : pas de LOAD si commande non PRÊT ; pas de RETURN sans RELOAD ; pas de réintégration si marqué HS.

Rapports & KPI (MVP)

Taux d’utilisation par SKU / période.

Pannes/pertes par catégorie.

Temps de rotation par camion.

Retards retours / manquants.

Jeux d’essai (seed)

SKUs : SPK-12, LIGHT-LED, TRIPOD-STD, LASER-5W.

Assets sérialisés pour enceintes/lasers ; lights en lot (qty).

Emplacements : HANGAR/Toulon, ZONE/Rayonnage A, CAMION/PL-123-AB, SITE/ISEN.

Événement : “ISEN Gala” du 2025-10-12 08:00 au 2025-10-13 02:00.

Devis : “1 enceinte, 3 pieds, 40 light, 5 laser”.

Scénarios clés (acceptance, style Gherkin)

Réservation à T alors qu’indispo maintenant

Given 20 lights en stock dont 20 réservées jusqu’au 10/10

When je réserve 40 lights du 12/10 au 13/10

Then la commande est acceptée si 40 seront libres à partir du 12/10 (incluant retours planifiés et buffers)

And le calendrier montre dispo=40 à la période

Optimisation camion enchaîné

Given Camion contient {10 light, 2 enceintes, 4 pieds} à son retour

And Prochaine commande requiert {30 light, 1 enceinte, 3 pieds, 5 lasers}

When je lance “Optimiser”

Then le plan Δ propose Garder: {1 enceinte, 3 pieds} Retirer: {1 enceinte, 7 pieds} Ajouter: {20 light, 5 lasers}

And le flux de scan me guide jusqu’à Δ=∅

Traçabilité par scan

Given Commande en état EN_PRÉPA

When je scanne sb://asset/A-123 en mode PICK

Then un Mouvement PICK est créé de HANGAR → PREPARATION

And la picklist se met à jour (restant à préparer)

Livrables attendus (si tu génères le code)

Projet Xcode SwiftUI avec modules Domain/Data/UI.

Modèles & repos (CoreData/Realm), clients API, scanner prêt à l’emploi.

Écrans listés ci-dessus, navigation, états, toasts/alertes.

Sync offline + file d’attente de mouvements.

Seeds de démo + tests unitaires de la logique de dispo & delta camion.

Scripts de build et README (config API, environnements).

Non-objectifs (MVP)

Facturation & paiements.

Optimisation de chargement 3D (bin-packing).

Multi-sociétés (une seule entité).

Glossaire

Hangar : entrepôt/stock principal.

Camion : emplacement mobile identifié.

Scan : lecture QR/Code128 pour tracer toute manipulation.

Δ camion : différences entre contenu actuel et besoin prochain.

Bonus : formats concrets à utiliser

QR unitaire (ex.) : {"v":1,"type":"asset","id":"A-000345","sku":"SPK-12","sn":"SN89342"}

QR box (ex.) : {"v":1,"type":"box","id":"B-0042","skus":[{"sku":"LIGHT-LED","qty":8},{"sku":"CABLE-XLR","qty":10}]}

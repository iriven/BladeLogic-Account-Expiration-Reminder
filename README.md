# NSH-SCRIPT: Account Expiration Notifier

Script de verification de la date d'expiration des comptes Unix. Ce script s execute 
sur un serveur et n'envoie un mail au support que si au moins un des comptes listés 
dans le fichier UserList.txt ou leur mot de passe est expiré ou en voie d'expiration.   

----------------------------------------------------------------------------- 

* Author: Alfred TCHONDJO 
* Date: 2015-10-30

-----------------------------------------------------------------------------

Revisions
									
* G1R0C0 : 	Creation du script le 30/10/2015 (AT)
* G1R0C1 : 	Amelioration des expressions regulières le 10/11/2015 (AT)	
* G1R0C2 : 	Prise en charge toute version AIX le 16/11/2015 (AT)	
* G1R0C3 : 	Mise en forme de la sortie HTML(email) le 18/11/2015 (AT)

-----------------------------------------------------------------------------	


#Caractéristiques du script 

Type: Script Bladelogic Type 1  
Compatibilité : tout systèmes Unix (AIX, Solaris, Linux)

#Les étapes d’exécutions
-	Récupération des paramètres 
-	Lecture du fichier contenant les users applicatifs et système
-	Pour chacun des users
-
	•	Vérification de son existence ou non  sur le host cible et passage au user suivant si non - 
	•	Vérification de l’état du compte et du password, stocke l’information dans un fichier si l’un des deux est expiré ou en voie d’expiration
-
-	A la fin des vérifications, envoie un mail au support si au moins un compte ou password est expiré ou en voie d’expiration.

NB : un compte ou un mot de passe est considéré comme étant en voie d’expiration lorsqu’il arrive à expiration des moins de 40 jours

#Les paramètres d’entrées 
- [HOST] = Liste des serveurs cibles
- [REPO_SERVER] = serveur sur lequel se trouve le [USERS_FILE]
- [USERS_FILE] = chemin du fichier contenant la liste des users à verifier
- [MAIL_SERVER] = serveur(sendmail) chargé d’envoyer le mail
- [MAIL_TO] = destinataire du mail


#Les sorties du script
-	Génération d’un fichier de mail « /var/tmp/ AUDIT_EXPIRATION_COMPTES_<DATE>.txt » (suivie de sa suppression à la fin du script)
-	Retour de Code statut en fin d’exécution (exit=0 qd succès ; exit=1 qd echec)

# contrôles
-	Contrôle de saisie des paramètres  obligatoires à l’exécution du script
-	Contrôle de l’existence du fichier
-	Arrêt immédiat du script en cas d’erreur

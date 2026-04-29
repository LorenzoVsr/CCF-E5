#!/bin/bash

. .envExploit

### Déclaration des variables ###

	ANNEEMOIS=$1 
	ANNEEMOISJOUR="${ANNEEMOIS}-01"
	EH=$2
	ANNEE=`echo "$ANNEEMOIS" | cut -c1-4`
	MOIS=`echo "$ANNEEMOIS" | cut -c6-7`
	PERIODE="${ANNEE}${MOIS}"

	REP_TRAVAIL="./prod/$EH/$ANNEEMOIS"

    #Chargement des options de l'eh dans un tableau
    . ${REP_UTILITAIRES}/uti_getOptionEH.sh $EH

### Fin déclaration variables générales ###

### Bloc obligatoire ###

#Nombre de secondes a attendre avant de considerer que le job est planté
DUREEMAX=43200 

#recuperation de l'heure de démarrage
HREDEMARRAGE=$SECONDS

if [ $# -ne 2 ] ; then
	echo "Le traitement se lance avec les parametres : anneemois, eh"
	echo "Exemple : . ./exp_genMandat.sh 2023-07 22016"
	return
fi

#****************************
#   Génération de Token
#****************************
if [ "$HOST_TOKEN" == "" ]; then
. ${REP_UTILITAIRES}/uti_connexionBulle.sh $EH 
fi

if [ "$MESSAGE_ERREUR_CONNEXION" != "" ]; then
	echo "$MESSAGE_ERREUR_CONNEXION"
	return
fi	

### Fin bloc obligatoire ###

### Début du script ###

## lancement du webservice PH7 de génération du fichier HOPAYRA

export recup_mandat=$(curl -s -w "%{http_code}\n" -o $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip -X GET "$HOST_BULLE:$PORT_BULLE/back/utils/postpaie/mandatuniv/$EH/$ANNEEMOIS" \
 -H "Content-Type: application/json" \
 -H "accept: application/json" \
 -H "Authorization: Bearer $KEYCLOAK_TOKEN" \
 -H "Cookie: _Ph7Cookie_=$KEYCLOAK_COOKIE") 
 
 	## test si le webservice s'est bien éxécuté
	if [ "${recup_mandat}" == "200" -o "${recup_mandat}" == "204" -o "${recup_mandat}" == "202" ]; then
		
		echo "Mandatuniv généré"	
    fi

#On récupère la valeur de l'option GEF
GEF=${OPTS[GEF]}


#On teste la valeur GEF
case $GEF in
    "GEF")

        echo "intégration du fichier en base" 
        . ${REP_UTILITAIRES}/uti_uploadFichier.sh $EH "EN_ATTENTE" "EN_ATTENTE" MANDAT.$EH.$PERIODE.zip $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip "MENSUEL"
    ;;

    "UNIV" | "MAGH2" | "M9")

        #Nettoyage des anciens mandats"
        echo "-----> Nettoyage des anciens mandats"
        rm -f $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt -f MANDATUNIV.MAG.${EH}${ANNEEMOIS}.txt -f $REP_TRAVAIL/E140_${EH}_${ANNEEMOIS}.pdf -f $REP_TRAVAIL/X140_${EH}_${ANNEEMOIS}.xls 
        #unzip du dossier
        echo "-----> unzip du mandat"
        unzip $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip -d $REP_TRAVAIL
        #suppression de l'ancien dossier pour pouvoir créer le nouveau par la suite
        echo "-----> suppression du dossier zip"
        rm -f $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip
        #verif étape 8000
        . ${REP_UTILITAIRES}/uti_getEtatEtape.sh $EH $ANNEEMOIS "8000"
            if [ "$GET_ETAT" == "TERMINEE" ]; then
                echo "-----> validation terminée, intégration de la lettre V en fin de fichier"
                sed 's/[[:space:]]*$/V/' $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt > $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}-tmp 
                mv ${REP_TRAVAIL}/mandatuniv_${EH}_${ANNEEMOIS}-tmp ${REP_TRAVAIL}/MANDATUNIV.MAG.${EH}${ANNEEMOIS}.txt
            else 
                echo "-----> validation non terminée, intégration de la lettre T en fin de fichier"
                sed 's/[[:space:]]*$/T/' $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt > $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}-tmp
                mv ${REP_TRAVAIL}/mandatuniv_${EH}_${ANNEEMOIS}-tmp ${REP_TRAVAIL}/MANDATUNIV.MAG.${EH}${ANNEEMOIS}.txt
            fi

        #Zip
        cd $REP_TRAVAIL
        echo "-----> zip du mandat"
        zip MANDAT.$EH.$PERIODE.zip MANDATUNIV.MAG.${EH}${ANNEEMOIS}.txt E140_${EH}_${ANNEEMOIS}.pdf X140_${EH}_${ANNEEMOIS}.xls 
        cd -

        #intégration du fichier zip en base
        echo "-----> intégration du fichier zip en base"   
        . ${REP_UTILITAIRES}/uti_uploadFichier.sh $EH "EN_ATTENTE" "EN_ATTENTE" MANDAT.$EH.$PERIODE.zip $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip "MENSUEL"

        #Nettoyage des anciens mandats"
        rm -f $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt -f MANDATUNIV.MAG.${EH}${ANNEEMOIS}.txt -f $REP_TRAVAIL/E140_${EH}_${ANNEEMOIS}.pdf -f $REP_TRAVAIL/X140_${EH}_${ANNEEMOIS}.xls 
    ;;

    "MEDIANE" | "CHEVALIER")

        #Nettoyage des anciens mandats"
        echo "-----> Nettoyage des anciens mandats"
        rm -f $REP_TRAVAIL/MANDATMEDIANE.${EH}${PERIODE}.txt -f $REP_TRAVAIL/E140_${EH}_${ANNEEMOIS}.pdf -f $REP_TRAVAIL/X140_${EH}_${ANNEEMOIS}.xls 
        rm -f $REP_TRAVAIL/MANDATJCL.${EH}${PERIODE}.txt -f $REP_TRAVAIL/E140_${EH}_${ANNEEMOIS}.pdf -f $REP_TRAVAIL/X140_${EH}_${ANNEEMOIS}.xls 
        #unzip du dossier
        echo "-----> unzip du mandat"
        unzip $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip -d $REP_TRAVAIL
        #suppression de l'ancien dossier pour pouvoir créer le nouveau par la suite
        echo "-----> suppression du dossier zip"
        rm -f $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip

        if [ "$GEF" = "MEDIANE" ]; then
            #Pour MEDIANE transforme dans un fichier temporaire puis le change en fichier MANDATMEDIANE txt
            echo "-----> validation terminée, transformation des retours chariot pour du Windows"
            sed 's/$/!/' "$REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt" | tr '!' '\r' > "$REP_TRAVAIL/MANDATMEDIANE.${EH}${PERIODE}.txt"

            #Zip
            cd $REP_TRAVAIL
            echo "-----> zip du mandat"
            zip MANDAT.$EH.$PERIODE.zip MANDATMEDIANE.${EH}${PERIODE}.txt E140_${EH}_${ANNEEMOIS}.pdf X140_${EH}_${ANNEEMOIS}.xls 
            cd -
        else
            #Pour CHEVALIER transforme dans un fichier temporaire puis le change en fichier MANDATJCL txt
            echo "-----> validation terminée, transformation des retours chariot pour du Windows"
            sed 's/$/!/' "$REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt" | tr '!' '\r' > "$REP_TRAVAIL/MANDATJCL.${EH}${PERIODE}.txt"

            #Zip
            cd $REP_TRAVAIL
            echo "-----> zip du mandat"
            zip MANDAT.$EH.$PERIODE.zip  $REP_TRAVAIL/MANDATJCL.${EH}${PERIODE}.txt E140_${EH}_${ANNEEMOIS}.pdf X140_${EH}_${ANNEEMOIS}.xls 
            cd -
        fi

        #intégration du fichier zip en base
        echo "-----> intégration du fichier zip en base"   
        . ${REP_UTILITAIRES}/uti_uploadFichier.sh $EH "EN_ATTENTE" "EN_ATTENTE" MANDAT.$EH.$PERIODE.zip $REP_TRAVAIL/MANDAT.$EH.$PERIODE.zip "MENSUEL"

        #Nettoyage des anciens mandats"
        rm -f $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt -f $REP_TRAVAIL/E140_${EH}_${ANNEEMOIS}.pdf -f $REP_TRAVAIL/X140_${EH}_${ANNEEMOIS}.xls 
        rm -f $REP_TRAVAIL/MANDATMEDIANE.${EH}${PERIODE}.txt
        rm -f $REP_TRAVAIL/MANDATJCL.${EH}${PERIODE}.txt
    ;;

    *)
    echo "autre valeur"
    ;;
esac


# echo "-----> validation terminée, transformation des retours chariot pour du Windows"
#             sed 's/$/!/' $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}.txt > $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}-tmp
#             tr '!' '\r' < $REP_TRAVAIL/mandatuniv_${EH}_${ANNEEMOIS}-tmp > $REP_TRAVAIL/MANDATJCL.${EH}_${ANNEEMOIS}-tmp
#             mv ${REP_TRAVAIL}/mandatuniv_${EH}_${ANNEEMOIS}-tmp ${REP_TRAVAIL}/MANDATJCL.${EH}_${ANNEEMOIS}.txt

#!/usr/bin/env bash

# exit when any command fails
set -e

inputFileOrDir=$1;
userDatasetId=$2
metadataFile=$3

export NLS_LANG='AMERICAN_AMERICA.UTF8';

exportInvestigation.pl -a -m $inputFileOrDir

# basename of last directory modified
study="$(basename $(\ls -1dt ./*/ | head -n 1))"

ontologyTermsToTabDelim.pl ${study}/ontologyMapping.xml ${study}

ga GUS::Supported::Plugin::InsertExternalDatabase --name $study --commit;
ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName $study --databaseVersion dontcare --commit;

ga GUS::Supported::Plugin::InsertExternalDatabase --name "${study}_terms" --commit;
ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName "${study}_terms" --databaseVersion dontcare --commit;

ga GUS::Supported::Plugin::InsertOntologyFromTabDelim \
    --termFile $study/ontology_terms.txt \
    --relFile $study/ontology_relationships.txt \
    --relTypeExtDbRlsSpec "Ontology_Relationship_Types_RSRC|1.3" \
    --extDbRlsSpec "${study}_terms|dontcare" \
    --commit

#touch $PWD/$study/valueMapping.txt
#touch $PWD/$study/termOverride.xml

ga ApiCommonData::Load::Plugin::InsertEntityGraph \
    --metaDataRoot $PWD \
    --investigationSubset $study \
    --investigationBaseName investigation.xml \
    --isSimpleConfiguration \
    --ontologyMappingFile $PWD/$study/ontologyMapping.xml \
    --extDbRlsSpec "${study}|dontcare" \
    --dateObfuscationFile $PWD/$study/dateObfuscation.txt \
    --schema ApidbUserDatasets \
    --userDatasetId $userDatasetId \
    --commit #    --valueMappingFile $PWD/$study/valueMapping.txt  --ontologyMappingOverrideFileBaseName termOverride.xml


ga ApiCommonData::Load::Plugin::LoadAttributesFromEntityGraph \
    --extDbRlsSpec "${study}|dontcare" \
    --schema ApidbUserDatasets \
    --ontologyExtDbRlsSpec "${study}_terms|dontcare" \
    --logDir $PWD \
    --runRLocally \
    --commit

ga ApiCommonData::Load::Plugin::LoadEntityTypeAndAttributeGraphs \
    --logDir $PWD \
    --extDbRlsSpec "${study}|dontcare" \
    --schema ApidbUserDatasets \
    --ontologyExtDbRlsSpec "${study}_terms|dontcare" \
    --commit

 ga ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph \
    --extDbRlsSpec "${study}|dontcare" \
    --schema ApidbUserDatasets \
    --commit

 ga ApiCommonData::Load::Plugin::InsertUserDatasetAttributes \
     --userDatasetId $userDatasetId \
     --metadataFile $metadataFile \
     --commit

 # clean out tables not used by the application with partial delete
 deleteStudy.pl $userDatasetId 1

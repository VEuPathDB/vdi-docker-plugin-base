#!/usr/bin/env bash

# exit when any command fails
set -e

biomMetadataFile=$1;
biomTsvFile=$2
userDatasetId=$3
metadataFile=$4

export NLS_LANG='AMERICAN_AMERICA.UTF8';

biomFilesToTsv.pl $biomTsvFile $biomMetadataFile

# basename of last directory modified
study="$(basename $(\ls -1dt ./*/ | head -n 1))"
externalDatabaseName=MicrobiomeStudyEDA_${study}_RSRC

ga GUS::Supported::Plugin::InsertExternalDatabase --name $externalDatabaseName --commit;
ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName $externalDatabaseName --databaseVersion dontcare --commit;

ga GUS::Supported::Plugin::InsertExternalDatabase --name "${externalDatabaseName}_terms" --commit;
ga GUS::Supported::Plugin::InsertExternalDatabaseRls --databaseName "${externalDatabaseName}_terms" --databaseVersion dontcare --commit;

touch $study/ontology_relationships.txt;

ga GUS::Supported::Plugin::InsertOntologyFromTabDelim \
    --termFile $study/ontology_terms.txt \
    --relFile $study/ontology_relationships.txt \
    --relTypeExtDbRlsSpec "Ontology_Relationship_Types_RSRC|1.3" \
    --extDbRlsSpec "${externalDatabaseName}_terms|dontcare" \
    --commit

ga ApiCommonData::Load::Plugin::MBioInsertEntityGraph \
  --commit \
  --investigationFile $PWD/$study/investigation.xml \
  --sampleDetailsFile $PWD/$study/source.tsv \
  --mbioResultsDir $PWD/$study/results  \
  --mbioResultsFileExtensions '{ampliconTaxa => "abundance.tsv", wgsTaxa => "NA", level4ECs => "NA", pathwayAbundances => "NA", pathwayCoverages => "NA", eukdetectCpms => "NA", massSpec => "NA" }' \
  --dieOnFirstError 1 \
  --ontologyMappingFile $PWD/$study/ontologyMapping.xml \
  --extDbRlsSpec "${externalDatabaseName}|dontcare" \
  --schema ApidbUserDatasets \
  --userDatasetId $userDatasetId

ga ApiCommonData::Load::Plugin::LoadAttributesFromEntityGraph \
    --extDbRlsSpec "${externalDatabaseName}|dontcare" \
    --schema ApidbUserDatasets \
    --ontologyExtDbRlsSpec "${externalDatabaseName}_terms|dontcare" \
    --logDir $PWD \
    --runRLocally \
    --commit

ga ApiCommonData::Load::Plugin::LoadEntityTypeAndAttributeGraphs \
    --logDir $PWD \
    --extDbRlsSpec "${externalDatabaseName}|dontcare" \
    --schema ApidbUserDatasets \
    --ontologyExtDbRlsSpec "${externalDatabaseName}_terms|dontcare" \
    --commit

 ga ApiCommonData::Load::Plugin::LoadDatasetSpecificEntityGraph \
    --extDbRlsSpec "${externalDatabaseName}|dontcare" \
    --schema ApidbUserDatasets \
    --commit

 ga ApiCommonData::Load::Plugin::InsertUserDatasetAttributes \
     --userDatasetId $userDatasetId \
     --metadataFile $metadataFile \
     --commit

 # This is temporary solution;  remove when merge with megastudy branch
 updateHasCollections.pl $userDatasetId

 # clean out tables not used by the application with partial delete
 deleteStudy.pl $userDatasetId 1

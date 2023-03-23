#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::Supported::GusConfig;

use DBI;
use DBD::Oracle;

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $dsn = $gusConfig->getDbiDsn();
my $user = $gusConfig->getDatabaseLogin();
my $pass = $gusConfig->getDatabasePassword();

my $dbh = DBI->connect($dsn, $user, $pass, {RaiseError=>0,PrintError=>1}) or die DBI::errstr;

my $userDatasetId = $ARGV[0];
my $partial = $ARGV[1];

my $studies = &queryStudy($dbh, $userDatasetId);

foreach my $studyId (keys %$studies) {
    my $entityTypeIds = &queryEntityType($dbh, $studyId);

    my $studyInternalAbbrev = $studies->{$studyId}->{internal_abbrev};

    foreach my $entityTypeId (keys %$entityTypeIds) {
        my $entityTypeInternalAbbrev = $entityTypeIds->{$entityTypeId};

        &dropDatasetSpecificTables($dbh, $studyInternalAbbrev, $entityTypeInternalAbbrev) unless($partial);
        &deleteGraphTables($dbh, $studyId, $partial);
        &deleteAttributeTables($dbh, $entityTypeId);
        &deleteProcessAttributes($dbh, $entityTypeId);

        $dbh->do("delete ApidbUserDatasets.datasetattributes where user_dataset_id = $userDatasetId")  unless($partial);

        &deleteOtherEda($dbh, $studyId, $entityTypeId, $partial);
    }

    my $extDbRlsId = $studies->{$studyId}->{external_database_release_id};
    my $extDbRlsVer = $studies->{$studyId}->{external_database_ver};

    my $extDbName = $studies->{$studyId}->{external_database_name};
    my $extDbId = $studies->{$studyId}->{external_database_id};

    my $termsExtDbName = $extDbName . "_terms";
    my $termsExtDbVer = "dontcare";

    my ($termsExtDbRlsId, $termsExtDbId) = &queryExternalDatabase($dbh, $termsExtDbName, $termsExtDbVer);

    &deleteOntology($dbh, $termsExtDbRlsId) unless($partial);

    foreach($extDbRlsId, $termsExtDbRlsId) {
        &deleteByExternalDatabaseReleaseId($dbh, $_, "ExternalDatabaseRelease") unless($partial);
    }

    foreach($extDbId, $termsExtDbId) {
        $dbh->do("delete SRES.ExternalDatabase where external_database_id = $_") unless($partial);
    }
}

sub queryExternalDatabase {
    my ($dbh, $name, $version) = @_;

    my $sql = "select d.external_database_id, r.external_database_release_id from sres.externaldatabase d, sres.externaldatabaserelease r where r.external_database_id = d.external_database_id and d.name = '$name' and r.version = '$version'";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    my ($extDbId, $extDbRlsId) = $sh->fetchrow_array();
    $sh->finish();

    unless($extDbRlsId) {
        print STDERR "could not find external database info for spec $name|$version";
    }

    return ($extDbRlsId, $extDbId);
}

sub deleteOntology {
    my ($dbh, $extDbRlsId) = @_;

    foreach("OntologyRelationship", "OntologySynonym") {
        &deleteByExternalDatabaseReleaseId($dbh, $extDbRlsId, $_);
    }
}

sub deleteOtherEda {
    my ($dbh, $studyId, $entityTypeId, $partial) = @_;

    foreach("EntityAttributes", "AttributeUnit") {
        #deleteByEntityTypeId($dbh, $entityTypeId, $_);
        &truncateTable($dbh, $_);
    }

    foreach("studycharacteristic", "EntityType", "Study") {
        deleteByStudyId($dbh, $studyId, $_) unless($partial);;
    }

}


sub deleteProcessAttributes {
    my ($dbh, $entityTypeId) = @_;

    $dbh->do("truncate table ApidbUserDatasets.processattributes");
#    $dbh->do("delete ApidbUserDatasets.processattributes where in_entity_id in (select entity_attributes_id from ApidbUserDatasets.entityattributes where entity_type_id = $entityTypeId)");#
#    $dbh->do("delete ApidbUserDatasets.processattributes where out_entity_id in (select entity_attributes_id from ApidbUserDatasets.entityattributes where entity_type_id = $entityTypeId)");
}


sub deleteGraphTables {
    my ($dbh, $studyId, $partial) = @_;

    &truncateTable($dbh, "AttributeGraph");
    &deleteByStudyId($dbh, $studyId, "EntityTypeGraph") unless($partial);
}

sub deleteAttributeTables {
    my ($dbh, $entityTypeId) = @_;

    foreach("Attribute", "AttributeValue") {
        &truncateTable($dbh, $_);
    }
}

sub deleteByEntityTypeId {
    my ($dbh, $entityTypeId, $table) = @_;

    $dbh->do("delete ApidbUserDatasets.${_} where entity_type_id=$entityTypeId");
}

sub deleteByExternalDatabaseReleaseId {
    my ($dbh, $extDbRlsId, $table) = @_;

    $dbh->do("delete SRES.${table} where external_database_release_id = $extDbRlsId");
}



sub truncateTable {
    my ($dbh, $table) = @_;

    $dbh->do("truncate table apidbuserdatasets.${table}");
}

sub deleteByStudyId {
    my ($dbh, $studyId, $table) = @_;

    $dbh->do("delete ApidbUserDatasets.${table} where study_id = $studyId");
}

sub dropDatasetSpecificTables {
    my ($dbh, $studyInternalAbbrev, $entityTypeInternalAbbrev) = @_;

    foreach("ANCESTORS", "COLLECTIONATTRIBUTE", "COLLECTION", "ATTRIBUTEVALUE", "ATTRIBUTEGRAPH") {
        $dbh->do("drop table ApidbUserDatasets.${_}_${studyInternalAbbrev}_${entityTypeInternalAbbrev}");
    }
}

sub queryEntityType {
    my ($dbh, $studyId) = @_;

    my %rv;
    my $sql = "select entity_type_id, internal_abbrev from ApidbUserDatasets.entitytype where study_id = ?";

    my $sh = $dbh->prepare($sql);
    $sh->execute($studyId);

    while(my ($entityTypeId, $internalAbbrev) = $sh->fetchrow_array()) {
        $rv{$entityTypeId} = $internalAbbrev;
    }
    $sh->finish();

    unless(scalar keys %rv > 0) {
        print STDERR "Could not find entitytype for study $studyId";
    }

    return \%rv;
}


sub queryStudy {
    my ($dbh, $userDatasetId) = @_;

    my %rv;

    my $sql = "select s.study_id, s.internal_abbrev, s.external_database_release_id, r.version, d.name, d.external_database_id from ApidbUserDatasets.study s, sres.externaldatabase d, sres.externaldatabaserelease r where s.user_dataset_id = ? and s.external_database_release_id = r.external_database_release_id and r.external_database_id = d.external_database_id";
    my $sh = $dbh->prepare($sql);
    $sh->execute($userDatasetId);

    while(my ($studyId, $internalAbbrev, $extDbRlsId, $dbVer, $dbName, $extDbId) = $sh->fetchrow_array()) {
        $rv{$studyId} = {internal_abbrev => $internalAbbrev,
                         external_database_release_id => $extDbRlsId,
                         external_database_name => $dbName,
                         external_database_version => $dbVer,
                         external_database_id => $extDbId,
        };
    }
    $sh->finish();

    unless(scalar keys %rv > 0) {
        print STDERR "Could not find study for user dataset $userDatasetId.  Nothing to delete";
    }
    return \%rv;
}

$dbh->disconnect;

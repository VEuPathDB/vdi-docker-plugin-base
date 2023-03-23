#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;
use DBD::Oracle;

use CBIL::Util::PropertySet;

my $userDatasetId = $ARGV[0];

die "Missing required arg for user dataset id" unless($userDatasetId);

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($dbiDsn, $dbiUser, $dbiPswd) or die DBI->errstr;
$dbh->{RaiseError} = 1;

$dbh->do("update apidbuserdatasets.entitytypegraph set HAS_ATTRIBUTE_COLLECTIONS = 1 where study_id in (select study_id from apidbuserdatasets.study where user_dataset_id = $userDatasetId)");
$dbh->commit();
$dbh->disconnect();

1;

use DBI;
use Test::More;
use Test::DBI::Utils;
use Data::Dumper;

BEGIN {
  use_ok('WyrlsX::Series::Season');
#  use_ok('WyrlsX::Series::Episode');
  use_ok('DBI');
}

my $DBI = "DBI";

my ($DBH, $DB, $DS, $USER, $PASS ) = (undef, 'database=test;host=localhost;port=3306', "DBI:mysql:database=test;host=localhost;port=3306", "root", "work-penchang021");
$DBH = $DBI->connect( $DS, $USER, $PASS, { RaiseError => 1 } );

my $dbi_utils = Test::DBI::Utils->new( DBH => $DBH );

$dbi_utils->construct_sqlstatement('t/schema.yaml');
$dbi_utils->construct_sqlstatement('t/fixtures.yaml');



my $SEASON_TEST_CASES = [
  # function, raw_input, expected_result, expected_result_is_hash
  ["valid_series",
      ["DISNEYSTORY"],
      1],
  ["_get_series",
      undef,
      "[,2015-04-07 02:40:33,Disney Story,,1,DISNEYSTORY]",
      1],

  ["has_current_season",
      undef,
      1],
  ["_get_season",
      undef,
      "[DISNEYSTORY,2015-04-01,2,2015-04-07 02:41:42,Season 2,,,2,2015-04-30,30.00,30,S02]",
      1],

  ["valid_season",
      undef,
      1],
  ["valid_season",
      ["S01"],
      1],
  ["_get_season",
      undef,
      "[DISNEYSTORY,2015-03-01,1,2015-04-07 02:41:42,Season 1,,,1,2015-03-31,30.00,31,S01]",
      1],

  # Current Season
  ["has_season_pass",
      ["09358465792", undef, 1],
      0],
  ["_get_season_pass",
      undef,
      "[]",
      1],

  ["has_season_pass",
      ["09358465792", "S01"],
      1],
  ["_get_season_pass",
      undef,
      "[0000-00-00 00:00:00,2015-02-28 16:00:00,S01,,09358465792,30.00,0,1,2,1,31]",
      1],

  ["has_season_pass",
      ["09358465792"],
      1],
  ["_get_season_pass",
      undef,
      "[0000-00-00 00:00:00,2015-02-28 16:00:00,S01,,09358465792,30.00,0,1,2,1,31]",
      1],

  ["grant_season_pass", 
      ["09358465795"], 
      1],

  ["expire_season_pass", 
      ["09358465795"], 
      undef],
  ["expire_season_pass", 
      ["09358465795", "4"], 
      0],
  ["expire_season_pass", 
      ["09358465795", "6"], 
      1],

  ["get_season_pass_targets", 
      undef, 
      "[09178680114,09358465792,09999999999,09178681136]",
      2],

  # Get owned season
  ["valid_season",
      ["S01"],
      1],
  ["has_next_episode", 
      [ "09358465792" ], 
      0],
  ["_get_episode",
      undef,
      "[]",
      1],

  # Get owned season
  ["valid_season",
      ["S01"],
      1],
  ["has_next_episode", 
      [ "09178680114" ], 
      1],
  ["_get_episode",
      undef,
      "[2,2015-04-07 02:42:30,Episode 2,S01,test,,2,,E02]",
      1],
  ["_get_next_episode_sequence",
      undef, 
      2],

  ["has_next_episode", 
      [ "09358465792", 1 ], 
      1],
  ["_get_episode",
      undef,
      "[1,2015-04-07 02:42:30,Episode 1,S01,test,,1,,E01]",
      1],

  ["valid_season",
      ["S02"],
      1],
  ["has_next_episode", 
      [ "09358465792" ], 
      1],
  ["_get_next_episode_sequence",
      undef, 
      1],
  ["_get_episode",
      undef,
      "[1,2015-04-07 02:42:30,Episode 1,S02,test,,3,,E01]",
      1],


  ["valid_season",
      ["S01"],
      1],
  ["valid_episode",
      ["E02"],
      1],
  ["_get_episode",
      undef,
      "[2,2015-04-07 02:42:30,Episode 2,S01,test,,2,,E02]",
      1],

  ["log_episode_delivery",
      ["S01", "E02", "09178680114"],
      1],

   ["_get_episode_delivery_log",
      undef,
      "[,2015-04-07 02:50:21,2,09178680114,2]",
      1],
 

];

my $CLASS = "WyrlsX::Series::Season";
{
  my $o = $CLASS->new( DBH => $DBH );

  foreach my $tc (@$SEASON_TEST_CASES) {

    my $func = $tc->[0];
    my $raw_input = $tc->[1] || undef;
    my $expected_result = $tc->[2];
    my $hash_result = ($tc->[3] eq 1) ? 1 : 0;
    my $array_result = ($tc->[3] eq 2) ? 1 : 0;

    my $actual = (defined($raw_input)) ? $o->$func(@{$raw_input}) : $o->$func();
    $actual = "[" . join (",", values%$actual) . "]" if $hash_result; 
    $actual = "[" . join (",", @{$actual}) . "]" if $array_result; 

    is $actual, $expected_result, "$func()";

  }
} 

#$dbi_utils->construct_sqlstatement('t/truncate_tmptables.yaml');
$dbi_utils->construct_sqlstatement('t/drop_tmptables.yaml');

done_testing()


__END__

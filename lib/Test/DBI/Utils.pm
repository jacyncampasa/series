package Test::DBI::Utils;
use strict;
use Moose;
use YAML qw /LoadFile/;

has 'DBH'           => ( isa => 'Ref', is => 'rw', required => 1);

sub construct_sqlstatement {
    my ($self, $sqlfile) = @_;

    my $sqlstatements = LoadFile($sqlfile);

    foreach my $sql (@{$sqlstatements}) {
        my $sth = $self->DBH->prepare($sql->{data});
        my $result = $sth->execute();
    }

}



1;

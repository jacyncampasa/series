package WyrlsX::Series::Season;
use strict;
use Moose;
use POSIX;
use Data::Dumper;

has 'DBH'                   => ( isa => 'Ref', is => 'rw', required => 1);
has 'series'                => ( isa => 'Ref', is => 'ro', required => 0, writer => '_set_series', reader => '_get_series', );
has 'season'                => ( isa => 'Ref', is => 'ro', required => 0, writer => '_set_season', reader => '_get_season', );
has 'season_pass'           => ( isa => 'Ref', is => 'ro', required => 0, writer => '_set_season_pass', reader => '_get_season_pass', );
has 'episode'               => ( isa => 'Ref', is => 'ro', required => 0, writer => '_set_episode', reader => '_get_episode', );
has 'episode_delivery'      => ( isa => 'Ref', is => 'ro', required => 0, writer => '_set_episode_delivery_log', reader => '_get_episode_delivery_log', );
has 'next_episode_sequence' => ( isa => 'Int', is => 'ro', required => 0, writer => '_set_next_episode_sequence', reader => '_get_next_episode_sequence', );

my $sth_get_series                  = undef;
my $sth_get_current_season          = undef;
my $sth_get_season                  = undef;
my $sth_insert_season_pass          = undef;
my $sth_get_unexpired_season_pass   = undef;
my $sth_get_season_pass             = undef;
my $sth_expire_season_pass          = undef;
my $sth_get_season_pass_targets     = undef;
my $sth_get_next_sequence           = undef;
my $sth_get_series_episode          = undef;
my $sth_get_series_episode_by_code  = undef;
my $sth_insert_episode_delivery     = undef;
my $sth_get_episode_delivery        = undef;

my $INIT_COMPLETE = 0;

sub BUILD {
    my $self = shift;

    $sth_get_series                 = $self->DBH->prepare("SELECT * 
                                                        FROM series 
                                                        WHERE code = ?;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_current_season         = $self->DBH->prepare("SELECT * 
                                                        FROM series_season 
                                                        WHERE series_code = ? AND ( run_start_date < CURRENT_DATE AND run_end_date > CURRENT_DATE );") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_insert_season_pass         = $self->DBH->prepare("INSERT INTO 
                                                        season_pass (season_id, msisdn, charged_amount, charged_datetime, created)
                                                        VALUES (?, ?, ?, ?, NOW())
                                                    ON DUPLICATE KEY UPDATE expired=0, charged_amount=?, charged_datetime=?;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_season                 = $self->DBH->prepare("SELECT * 
                                                        FROM series_season
                                                        WHERE series_code = ? AND code = ?;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_unexpired_season_pass  = $self->DBH->prepare("SELECT ss.code as season_code, sp.*, episode_daily_delivery_cap, COUNT(sed.id) AS episode_delivered
                                                        FROM series_season AS ss LEFT OUTER JOIN season_pass AS sp ON (ss.id = sp.season_id)
                                                          LEFT OUTER JOIN series_episode_delivery AS sed ON (sp.id = sed.season_pass_id)
                                                        WHERE ss.series_code = ? AND sp.msisdn = ? AND sp.expired = 0
                                                        GROUP BY sed.season_pass_id
                                                        HAVING episode_delivered < episode_daily_delivery_cap
                                                        ORDER BY sed.season_pass_id DESC 
                                                        LIMIT 1;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_season_pass            = $self->DBH->prepare("SELECT ss.code as season_code, sp.*, episode_daily_delivery_cap, COUNT(sed.id) AS episode_delivered
                                                        FROM series_season AS ss LEFT OUTER JOIN season_pass AS sp ON (ss.id = sp.season_id)
                                                          LEFT OUTER JOIN series_episode_delivery AS sed ON (sp.id = sed.season_pass_id)
                                                        WHERE ss.series_code = ? AND ss.code = ? AND sp.msisdn = ? AND sp.expired = 0
                                                        GROUP BY sed.season_pass_id
                                                        LIMIT 1;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_expire_season_pass         = $self->DBH->prepare("UPDATE season_pass
                                                        SET expired = 1
                                                        WHERE id = ? AND msisdn = ? AND expired = 0;") 
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_season_pass_targets    = $self->DBH->prepare("SELECT sp.msisdn, episode_daily_delivery_cap, COUNT(sed.id) AS episode_delivered
                                                        FROM series_season AS ss LEFT OUTER JOIN season_pass AS sp ON (ss.id = sp.season_id)
                                                          LEFT OUTER JOIN series_episode_delivery AS sed ON (sp.id = sed.season_pass_id)
                                                        WHERE ss.series_code = ? AND sp.msisdn IS NOT NULL AND sp.expired = 0
                                                        GROUP BY sed.season_pass_id, msisdn
                                                        HAVING episode_delivered < episode_daily_delivery_cap;") 
                                                    or die "$0: FATAL: prepare failed\n";


    # Season Episode
    $sth_get_next_sequence          = $self->DBH->prepare("SELECT se.sequence+1 AS next_episode_sequence
                                                        FROM series_season AS ss LEFT OUTER JOIN season_pass AS sp ON (ss.id = sp.season_id)
                                                          LEFT OUTER JOIN series_episode_delivery AS sed ON (sp.id = sed.season_pass_id)
                                                          RIGHT OUTER JOIN series_episode AS se ON (sed.episode_id = se.id)
                                                        WHERE ss.series_code = ? and ss.code = ? AND sp.msisdn = ?
                                                        ORDER BY next_episode_sequence DESC
                                                        LIMIT 1;")
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_series_episode         = $self->DBH->prepare("SELECT * 
                                                        FROM series_episode
                                                        WHERE season_code = ? AND sequence = ?")
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_series_episode_by_code = $self->DBH->prepare("SELECT * 
                                                        FROM series_episode
                                                        WHERE season_code = ? AND code = ?")
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_insert_episode_delivery    = $self->DBH->prepare("INSERT INTO
                                                        series_episode_delivery(season_pass_id, episode_id, msisdn, delivery_datetime, created) 
                                                        VALUES(?, ?, ?, ?, NOW());")
                                                    or die "$0: FATAL: prepare failed\n";

    $sth_get_episode_delivery       = $self->DBH->prepare("SELECT sp.id as season_pass_id, se.id as episode_id, sp.msisdn, sed.delivery_datetime, sed.created
                                                        FROM series_season AS ss LEFT OUTER JOIN season_pass AS sp ON (ss.id = sp.season_id)
                                                          LEFT OUTER JOIN series_episode_delivery AS sed ON (sp.id = sed.season_pass_id)
                                                          RIGHT OUTER JOIN series_episode AS se ON (ss.code = se.season_code)
                                                        WHERE ss.series_code = ? AND ss.code = ? AND se.code = ? AND sp.msisdn = ?;")
                                                    or die "$0: FATAL: prepare failed\n";

    $INIT_COMPLETE = 1;

}

sub valid_series {
    my ($self, $series_code) = @_;

    my $result = $sth_get_series->execute( $series_code ) or die "$0: valid_series() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_series({});
        return 0;
    } else {
        my $data = $sth_get_series->fetchrow_hashref() or die "$0: valid_series() FATAL: fetchrow_hashref query failed\n";
        $self->_set_series($data);
        return 1;
    }

    return undef;
}

sub has_current_season {
    my ($self) = @_;
    return undef if (not defined($self->_get_series->{code}));

    my $result = $sth_get_current_season->execute( $self->_get_series->{code} ) or die "$0: has_current_season() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_season({});
        return 0;
    } else {
        my $data = $sth_get_current_season->fetchrow_hashref() or die "$0: has_current_season() FATAL: fetchrow_hashref query failed\n";
        $self->_set_season($data);
        return 1;
    }

    return undef;
}

sub valid_season {
    my ($self, $season_code) = @_;
    $season_code = $self->_get_season->{code} if (not defined($season_code));

    my $result = $sth_get_season->execute( $self->_get_series->{code}, $season_code ) or die "$0: valid_season() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_season({});
        return 0;
    } else {
        my $data = $sth_get_season->fetchrow_hashref() or die "$0: valid_season() FATAL: fetchrow_hashref query failed\n";
        $self->_set_season($data);
        return 1;
    }

    return undef;
}

sub has_season_pass {
    my ($self, $msisdn, $season_code, $current_season) = @_;
    $current_season = 0 if (not defined($current_season));
    return undef unless(defined($self->_get_series->{code}));

    my $sth;
    if ( (not defined($season_code)) && (not $current_season) ) {
        $sth = $sth_get_unexpired_season_pass;
        $sth->bind_param(1, $self->_get_series->{code} );
        $sth->bind_param(2, $msisdn );
    }
    else {

        if ((not $current_season) and (defined($season_code))) {
            return undef unless($self->valid_season($season_code));
        } elsif ($current_season) {
            return undef unless($self->has_current_season());  
        }

        $sth = $sth_get_season_pass;
        $sth->bind_param(1, $self->_get_series->{code} );
        $sth->bind_param(2, $self->_get_season->{code} );
        $sth->bind_param(3, $msisdn );
    }

    my $result = $sth->execute() or die "$0: has_season_pass() FATAL: Unable to execute query\n"; 
    if ($result eq '0E0') {
        $self->_set_season_pass({});
        return 0;
    } else {
        my $data = $sth->fetchrow_hashref() or die "$0: has_season_pass()1 FATAL: fetchrow_hashref query failed\n";
        $self->_set_season_pass($data);
        return 1;
    }

    return undef;
}

sub grant_season_pass {
    my ($self, $msisdn, $charged_datetime) = @_;
    return undef if ($self->has_season_pass($msisdn, undef, 1));

    $charged_datetime = strftime "%Y-%m-%d %H:%M:%S", localtime if (not defined($charged_datetime));

    my $result = $sth_insert_season_pass->execute( $self->_get_season->{id}, $msisdn, $self->_get_season->{price}, $charged_datetime, $self->_get_season->{price}, $charged_datetime ) or die "$0: get_current_season() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        return 0;
    } else {
        return 1;
    }

    return undef;
}

sub expire_season_pass {
    my ($self, $msisdn, $season_pass_id) = @_;
    return undef if (not defined($season_pass_id));

    my $result = $sth_expire_season_pass->execute( $season_pass_id, $msisdn ) or die "$0: get_current_season() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        return 0;
    } else {
        return 1;
    }

    return undef;
}

sub get_season_pass_targets {
    my ($self) = @_;
    return undef if (not defined($self->_get_series->{code}));

    my $result = $sth_get_season_pass_targets->execute( $self->_get_series->{code} ) or die "$0: get_season_pass_targets() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        return [];
    } else {
        my $data = $sth_get_season_pass_targets->fetchall_hashref('msisdn') or die "$0: get_current_season() FATAL: fetchrow_hashref query failed\n";
        my @targets = keys%{$data};
        return \@targets;
    }

    return undef;

}

sub get_next_episode_sequence {
    my ($self, $msisdn) = @_;
    return undef unless(defined($self->_get_series->{code}) and defined($self->_get_season->{code}));

    my $result = $sth_get_next_sequence->execute( $self->_get_series->{code}, $self->_get_season->{code}, $msisdn ) or die "$0: get_season_pass_targets() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        return 1;
    } else {
        my $data = $sth_get_next_sequence->fetchrow_hashref() or die "$0: get_current_season() FATAL: fetchrow_hashref query failed\n";
        return $data->{next_episode_sequence};
    }

    return undef;

}

sub has_next_episode {
    my ($self, $msisdn, $next_episode_sequence) = @_;
    return undef unless(defined($self->_get_series->{code}) and defined($self->_get_season->{code}));

    if (defined($next_episode_sequence)) {
        $self->_set_next_episode_sequence( $next_episode_sequence );
    }
    else {
        $self->_set_next_episode_sequence( $self->get_next_episode_sequence($msisdn) );
    }

    my $result = $sth_get_series_episode->execute( $self->_get_season->{code}, $self->_get_next_episode_sequence ) or die "$0: get_season_pass_targets() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_episode({});
        return 0;
    } else {
        my $data = $sth_get_series_episode->fetchrow_hashref() or die "$0: get_current_season() FATAL: fetchrow_hashref query failed\n";
        $self->_set_episode($data);
        return 1;
    }

    return undef;

}

sub valid_episode {
    my ($self, $episode_code) = @_;
    return undef unless(defined($self->_get_season->{code}) and defined($episode_code));

    my $result = $sth_get_series_episode_by_code->execute( $self->_get_season->{code}, $episode_code ) or die "$0: get_season_pass_targets() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_episode({});
        return 0;
    } else {
        my $data = $sth_get_series_episode_by_code->fetchrow_hashref() or die "$0: get_current_season() FATAL: fetchrow_hashref query failed\n";
        $self->_set_episode($data);
        return 1;
    }

    return undef;
}

sub log_episode_delivery {
    my ($self, $season_code, $episode_code, $msisdn, $charged_datetime) = @_;
    return undef unless( defined($season_code) and defined($episode_code) and defined($msisdn) );
    return undef unless( $self->has_season_pass($msisdn, $season_code) and $self->valid_episode($episode_code) );

    $charged_datetime = strftime "%Y-%m-%d %H:%M:%S", localtime if (not defined($charged_datetime));

    my $result = $sth_insert_episode_delivery->execute( $self->_get_season_pass->{id}, $self->_get_episode->{id}, $msisdn, $charged_datetime ) or die "$0: get_current_season() FATAL: Unable to execute query\n";
    if ($result eq '0E0') {
        $self->_set_episode_delivery_log({});
        return 0;
    } else {
        $result = $sth_get_episode_delivery->execute( $self->_get_series->{code}, $self->_get_season->{code}, $self->_get_episode->{code}, $msisdn ) or die "$0: get_current_season() FATAL: Unable to execute query\n";
        my $data = $sth_get_episode_delivery->fetchrow_hashref() or die "$0: get_current_season() FATAL: fetchrow_hashref query failed\n";
        $self->_set_episode_delivery_log($data);
        return 1;
    }

    return undef;

}


END {

    if ($INIT_COMPLETE) {

        $sth_get_series->finish();
        $sth_get_current_season->finish();  
        $sth_get_season->finish();
        $sth_insert_season_pass->finish();
        $sth_get_unexpired_season_pass->finish();
        $sth_get_season_pass->finish();
        $sth_expire_season_pass->finish();
        $sth_get_season_pass_targets->finish();
        $sth_get_next_sequence->finish();
        $sth_get_series_episode->finish();
        $sth_get_series_episode_by_code->finish();
        $sth_insert_episode_delivery->finish();
        $sth_get_episode_delivery->finish();

    }
}

1;

__END__

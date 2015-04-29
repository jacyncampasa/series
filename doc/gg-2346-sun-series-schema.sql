

create table if not exists `series` (
    id integer unsigned not null auto_increment,
    code varchar(64) not null,  /* automediatype of service; format: DISNEYSTORY */
    name varchar(128) not null,
    remarks text,
    created datetime,
    last_modified timestamp,
    primary key(id),
    unique key (code),
    index (code)
) engine=InnoDB default charset=utf8;


create table if not exists `series_season` (
    id integer unsigned not null auto_increment,
    series_code varchar(64) not null,
    code varchar(64) not null, /* format: S01...Sxx */
    name varchar(128),
    sequence integer unsigned not null,
    run_start_date date not null,
    run_end_date date not null,
    price decimal(65,2) unsigned not null,
    episode_daily_delivery_cap integer unsigned not null,
    remarks text,
    created datetime,
    last_modified timestamp,
    primary key (id),
    constraint foreign key (series_code) references series(code) on update cascade,
    unique key (series_code, code),
    index (series_code, code),
    index (code)
) engine=InnoDB default charset=utf8;


create table if not exists `series_episode` (
    id integer unsigned not null auto_increment,
    season_code varchar(64) not null,
    code varchar(64) not null, /* format: E01...Exx */
    name varchar(128),
    sequence integer unsigned not null,
    command_hook varchar(128) not null,
    remarks text,
    created datetime,
    last_modified timestamp,
    primary key (id),
    constraint foreign key (season_code) references series_season(code) on update cascade,
    unique key (season_code, code),
    index (season_code, code),
    index (code)
) engine=InnoDB default charset=utf8;


create table if not exists `season_pass` (
    id integer unsigned not null auto_increment,
    season_id integer unsigned not null,
    msisdn varchar(32) not null,
    charged_amount decimal(65,2) unsigned not null,
    charged_datetime timestamp,
    expired boolean default False,
    created datetime,
    last_modified timestamp,
    primary key (id),
    constraint foreign key (season_id) references series_season(id) on update cascade,
    unique key (season_id, msisdn),
    index(season_id, msisdn)
) engine=InnoDB default charset=utf8;

create table if not exists `series_episode_delivery` (
    id integer unsigned not null auto_increment,
    season_pass_id integer unsigned not null,
    episode_id integer unsigned not null,
    msisdn varchar(32) not null,
    delivery_datetime timestamp,
    created datetime,
    last_modified timestamp,
    primary key (id),
    constraint foreign key (episode_id) references series_episode(id) on update cascade,
    constraint foreign key (season_pass_id) references season_pass(id) on update cascade,
    unique key (season_pass_id, episode_id, msisdn),
    index(season_pass_id, episode_id, msisdn)
) engine=InnoDB default charset=utf8;

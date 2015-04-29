-- *************************************************************
-- FOR REVIEW
-- *************************************************************

-- 1. Re-optin Scenario
"""
  cmdif, vartable,
  note:
    cap and date > 30days = reset current status of season
    SOLUTION: set Expired = 1 on Season pass table (if reoptin is 30days after optout)
"""

-- 2. Log Sent
"""
  note: NEED TO LOG on sent_log due to failure of delivery status queue up
"""


-- *************************************************************
-- Prepare Push Targets
-- *************************************************************

-- 1. CHARGING BUNDLE

"""
targets criteria: season_pass has expired and completed previous season_pass
step:
  1. get active autosubs
  2. get exclusions (see sql statement below)
      input: series_code
"""

select ss.code, sp.msisdn, episode_daily_delivery_cap, count(sed.id) as episode_delivered
from series_season as ss left outer join season_pass as sp on (ss.id = sp.season_id)
    left outer join series_episode_delivery as sed on (sp.id = sed.season_pass_id)
where ss.series_code = ? and sp.msisdn is not null and sp.expired = 0
group by sed.season_pass_id, msisdn
having episode_delivered < episode_daily_delivery_cap;

"""
  3. exclude exclusions from active autosubs
  4. start push
      (next_message_sequence): #--> QUESTION: no need to define automedia entries? 1 dummy entry only?
      bundle (array):
        charging
        cmd (FORMAT: deliver_series_episode DISNEYSTORY)
      message_sequence_sent_hook
        get current season_id (see sql below)
        on_sent_log === log payment to season_pass table (see sql statement below)
        hook command
"""
select * from series_season where series_code = ?
insert into season_pass(season_id, msisdn, charged_amount, charged_datetime, created) values(?, ?, ?, ?, ?);


-- 2. FREE BUNDLE - SEND CONTENT ONLY

"""
targets criteria: season_pass are not yet expired and not yet completed
step:
  1. get active autosubs
  2. get inclusions (see sql statement below)
      input: series_code
"""

select ss.code, sp.msisdn, episode_daily_delivery_cap, count(sed.id) as episode_delivered
from series_season as ss left outer join season_pass as sp on (ss.id = sp.season_id)
    left outer join series_episode_delivery as sed on (sp.id = sed.season_pass_id)
where ss.series_code = ? and sp.msisdn is not null and sp.expired = 0
group by sed.season_pass_id, msisdn
having episode_delivered < episode_daily_delivery_cap;


"""
  3. merge inclusions and active autosubs
  4. start push
      (next_message_sequence): #--> QUESTION: no need to define automedia entries? 1 dummy entry only?
      bundle (array):
        free
        cmd (FORMAT: deliver_series_episode DISNEYSTORY)
      message_sequence_sent_hook
        hook command
"""

-- *************************************************************
-- Prepare / Send Series Episode (Hooked command)
-- *************************************************************

"""
steps:
  1. get episode_id of next sequence
      input: series_code, msisdn
      errors: if no pass yet, bad packet...
"""

select se.season_code, se.sequence+1 as next_episode_sequence
from series_season as ss left outer join season_pass as sp on (ss.id = sp.season_id)
    left outer join series_episode_delivery as sed on (sp.id = sed.season_pass_id)
    right outer join series_episode as se on (sed.episode_id = se.id)
where ss.series_code = ? ss.id = ? and sp.msisdn = ?
order by next_episode_sequence desc
limit 1;

"""
  2. get episode details(command hook) of next episode
      input: season_code, next_episode_sequence
      errors:
        a. if nxt episode is not found.
"""

select *
from series_episode
where season_code = ? and sequence = ?


"""
  3. hook command of next episode
      media entry: 
        mms: must be uploaded, to be checked by send_content daemon
        cmdhook: delivered_series_episode <series_code> <season_code> <episode_code> 
          - to map season_pass_id and episode_id that will be used to add to series_episode_delivery table 
"""

-- *************************************************************
-- Successfully Delivered Episode - Log 
-- *************************************************************

"""
steps:
  1. get need details(season_pass_id, episode_id) for adding delivery status (see sql below)
      input: series_code, season_code, episode_code, msisdn
"""

select sp.id as season_pass_id, se.id as episode_id, sp.msisdn
from series_season as ss left outer join season_pass as sp on (ss.id = sp.season_id)    
    right outer join series_episode as se on (ss.code = se.season_code)
where ss.series_code = ? and ss.code = ? and se.code = ? and sp.msisdn = ?


"""
  2. add delivery status to series_episode_delivery table (see sql below)
      input: season_pass_id, episode_id, msisdn, timestamp_sent, created 
"""

insert into series_episode_delivery(season_pass_id, episode_id, msisdn, delivery_datetime, created) values(?, ?, ?, ?, ?);


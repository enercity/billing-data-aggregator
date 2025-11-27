do $$
begin
	set timezone = 'Europe/Berlin';
	
	if exists (select from information_schema.tables where table_schema = 'receivablemanagement_vault') and exists (select from information_schema.tables where table_schema = 'dunning_vault') and exists (select from information_schema.tables where table_schema = 'dunninglock_vault') then
		if exists (select from receivablemanagement_vault.case_receivables) then
			-- dunning and receivablemanagement vaults exist
			drop table if exists tmp_dunning;
			create temp table tmp_dunning as
			select distinct on (cr.mba)
				cr.id::text as id
				,cr.created_at
				,cr.mba
				,cr.status::text
			from receivablemanagement_vault.case_receivables cr
			left join receivablemanagement_vault.dunning_locks dl
				on dl.deleted = 'false' 
				and dl.mba = cr.mba
			-- where cr.mba = 'en-4054196235'
			order by cr.mba, cr.created_at desc, dl.updated_at desc
			;
			
			drop table if exists tmp_dunning_locks;
			create temp table tmp_dunning_locks as
			select distinct on (dl.mba)
				 dl.mba
				,coalesce((dl.expires_at at time zone 'UTC')::date, '9999-12-31')::date as dunning_lock_until
				,dl.reason::text as dunning_lock_reason
				,dl.deleted
				-- select *
			from dunninglock_vault.dunning_locks dl
			-- where coalesce((dl.expires_at at time zone 'UTC')::date, '9999-12-31')::date >= now()::date
			-- where mba = 'en-4054196235'
			order by dl.mba, dl.created_at desc, dl.updated_at desc
			;
			delete from tmp_dunning_locks where deleted;
			delete from tmp_dunning_locks where dunning_lock_until < now()::date;
			
			drop table if exists tmp_receivables_delta;
			create temp table tmp_receivables_delta as
			select coalesce(d.mba, dl.mba) as mba
				,d.id
				,d.created_at
				,d.status::text
				,dl.dunning_lock_until
				,dl.dunning_lock_reason::text
				-- select *
			from tmp_dunning d
			full join tmp_dunning_locks dl
				on dl.mba = d.mba
			-- where coalesce(d.mba, dl.mba) = 'en-4054196235'
			; -- select * from tmp_receivables_delta where mba = 'en-gz2087658'
			
			drop table if exists report_oibl.base_data_dunning;
			create table report_oibl.base_data_dunning as 
			select 
				 rd.mba
				,dc.dunning_level::integer as dunning_level
				,dc.scenario  as dunning_scenario
				,c.status::text as status
				,case when rd.status in ('DUNNING', 'BLOCKING', 'INKASSO') then rd.status::text end as dunning_status
				,rd.dunning_lock_until
				,rd.dunning_lock_reason::text
				,row_number() over(partition by rd.mba order by rd.created_at desc) as rnk
				-- select *
			from tmp_receivables_delta rd
			left join receivablemanagement_vault.dunning_claims dc on dc.case_receivable_id::text = rd.id::text
			left join dunning_vault.claims c on dc.dunning_claim_id::text = c.id::text
			-- where rd.mba = 'en-4054196235'
			; -- select * from report_oibl.base_data_dunning where status is null;
			delete from report_oibl.base_data_dunning where rnk != 1;
			-- DEV-59359 show all, not only active
			/*update report_oibl.base_data_dunning
			set dunning_level = null,
				dunning_scenario = null,
				status = null,
				dunning_status = null
			where coalesce(status, '') != 'active'
			;*/
		else
			drop table if exists report_oibl.base_data_dunning;
			create table report_oibl.base_data_dunning (
				mba varchar NULL,
				dunning_level int4 NULL,
				dunning_scenario varchar NULL,
				status varchar NULL,
				dunning_status varchar NULL,
				dunning_lock_until date NULL,
				dunning_lock_reason text NULL,
				rnk int8 NULL
			);
		end if;
	else
		drop table if exists report_oibl.base_data_dunning;
		create table report_oibl.base_data_dunning (
			mba varchar NULL,
			dunning_level int4 NULL,
			dunning_scenario varchar NULL,
			status varchar NULL,
			dunning_status varchar NULL,
			dunning_lock_until date NULL,
			dunning_lock_reason text NULL,
			rnk int8 NULL
		);
	end if;

	create index on report_oibl.base_data_dunning(mba);

end $$;
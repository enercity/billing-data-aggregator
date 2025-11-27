DO $$
declare
	data_sap_bookings_exists boolean := false;
begin

	-- create bookings table if not exists
	-- full load prod -> ~22m!
	-- drop table if exists data_sap_bookings;
	
	select exists (
		select 1, *
		from information_schema.tables
		WHERE 1=1 
			and table_schema LIKE 'report_boil'
	        and table_name = 'data_sap_bookings'
	) into data_sap_bookings_exists;
	
	-- create only if not extists
	IF NOT data_sap_bookings_exists THEN
	
		-- bookings data
		drop table if exists report_boil.base_data_bseg;
		create table report_boil.base_data_bseg as
		select 
			 booking_execution_id as bseg_booking_execution_id
			,booking_created as bseg_booking_created
			-- etract data from JSON
			,bseg->>'key' 					as key
			,bseg->>'aufnr' 				as aufnr
			,bseg->>'gsber' 				as gsber
			,bseg->>'kostl' 				as kostl
			,bseg->>'mwskz' 				as mwskz
			,bseg->>'newbk' 				as newbk
			,bseg->>'newbs' 				as newbs
			,bseg->>'newko' 				as newko
			,bseg->>'prced' 				as prced
			,bseg->>'sgtxt' 				as sgtxt
			,bseg->>'vbund' 				as vbund
			,bseg->>'wrbed' 				as wrbed
			,bseg->>'xblnr' 				as xblnr
			,bseg->>'xstba' 				as xstba 
			,bseg->>'zterm' 				as zterm
			,bseg->>'zuonr' 				as zuonr
			,bseg->>'psegment' 				as psegment
			-- create one row for each element in the JSON list
			,(relatedAggregateIds) as relatedAggregateIds
				from
				(
							select 
								-- JSON wuth containing SAP booking data
								json_array_elements(daten::JSON)::JSON as bseg
								-- create clean JSON with aggregateIDs
								,(concat ('{', TRIM(both '[]' from (json_array_elements(daten::JSON)::JSON->>'relatedAggregateIds'::text)),'}')::text[] )as relatedAggregateIds
								,booking_execution_id
								,booking_created
							from 
							(			
								SELECT 
									br.id as booking_execution_id
									,timestamp as booking_created
									-- pull SAP Booking data from JSON String
									,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
									,json_extract_path(summary::JSON,'sap')->>'bbseg' as daten  
								FROM bookings_vault.booking_runs br
								WHERE 	1=1
										and summary IS NOT NULL 
										-- select un-deleted booking runs 
										AND deleted = 0 
										--and br.id = 1300
										--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg' )	
							) as x	
							where booking_pfad = 'bbseg'
			) as bseg_data
		; -- select * from report_boil.base_data_bseg
		create index idx_base_data_bseg_primary on report_boil.base_data_bseg(xblnr,bseg_booking_execution_id);
		create index idx_base_data_bseg_secondary on report_boil.base_data_bseg(xblnr,bseg_booking_execution_id,newko,newbs);
		
		
		drop table if exists report_boil.base_data_bbkpf;
		create table report_boil.base_data_bbkpf as
		select 
			bbkpf->>'ba' 					as ba
			,to_date(bbkpf->>'budat' , 'dd.mm.yyyy')::date as budat
			,bbkpf->>'bukrs' 				as bukrs
			,bbkpf->>'xblnr' 				as xbelnr
			,to_date(bbkpf->>'beldat' , 'dd.mm.yyyy')::date as beldat
			,*
		FROM(
				select 
					-- JSON wuth containing SAP booking data
					json_array_elements(daten::JSON)::JSON as bbkpf
					-- create clean JSON with aggregateIDs
					,booking_execution_id
					,booking_created
				from 
				(			
					SELECT 
						br.id as booking_execution_id
						,timestamp as booking_created
						-- pull SAP Booking data from JSON String
						,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
						,json_extract_path(summary::JSON,'sap')->>'bbkpf' as daten  
						-- SELECT * 
					FROM bookings_vault.booking_runs br
					WHERE 	1=1
							and summary IS NOT NULL 
							-- select un-deleted booking runs 
							AND deleted = 0 
							--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg'  )	
				) as x	
				where booking_pfad = 'bbkpf'
		) as bkpf_sub
		; -- select * from report_boil.base_data_bbkpf
		
		drop table if exists report_boil.base_data_seg;
		create table report_boil.base_data_seg as
		select 
			 segments->>'wrbed' 				as wrbed
			,segments->>'xblnr' 				as xbelnr
			,segments->>'newbs' 				as newbs
			,segments->>'newko' 				as newko
			,segments->>'mwskz' 				as mwskz2
			,segments->>'amountCalculation' 	as amount_calculation
			,segments->>'relatedAggregateId' 	as aggregate_id
			,*
		FROM(
					select 
						-- JSON wuth containing SAP booking data
						json_array_elements(daten::JSON)::JSON as segments
						-- create clean JSON with aggregateIDs
						,booking_execution_id
						,booking_created
					from 
					(			
						SELECT 
							br.id as booking_execution_id
							,timestamp as booking_created
							-- pull SAP Booking data from JSON String
							,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
							,json_extract_path(summary::JSON,'sap')->>'rawSegments' as daten  
							-- SELECT * 
						FROM bookings_vault.booking_runs br
						WHERE 	1=1
								and summary IS NOT NULL 
								-- select un-deleted booking runs 
								AND deleted = 0 
								--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg'  )	
					) as x	
					where booking_pfad = 'rawSegments'
			) as seg_sub
		--where segments->>'mwskz' != '/'
		;-- select * from report_boil.base_data_seg where aggregate_id in ('LoS9M8ZVdqp0AKPVGnmkGaKYjfU=', 'QNfMiRRLnYtpBB+mj5cS57G0sNs=')
		
		/*
		drop table if exists tmp_vat_booking_accounts;
		create temp table tmp_vat_booking_accounts(
			mwskz varchar(2) primary key,
			account varchar(20)
		);
		insert into tmp_vat_booking_accounts values
		('11', '76100030'),
		('1A', '76100030'),
		('21', '76100030'),
		('2A', '76100030'),
		('12', '76100101'),
		('1B', '76100101'),
		('22', '76100100'),
		('2B', '76100100'),
		('59', '76110005'),
		('5W', '76110005'),
		('69', '76110005'),
		('6W', '76110005'),
		('51', '76110030'),
		('5A', '76110030'),
		('61', '76110030'),
		('6A', '76110030'),
		('62', '76110030'),
		('6B', '76110030'),
		('81', 'RC'),
		('8A', 'RC')
		;
		create index idx_tmp_vat_booking_accounts_mwskz on tmp_vat_booking_accounts(mwskz);
		*/
		
		
		/*
		drop table if exists tmp_bbtax;
		create temp table tmp_bbtax as
		select 
			 booking_execution_id 	as bbtax_booking_execution_id
			,booking_created 		as bbtax_booking_created
			-- etract data from JSON
			,'/' 					as key
			,'/' 					as aufnr
			,'/' 					as gsber
			,'/' 					as kostl
			,bbtax_data->>'mwskz' 	as mwskz
			,'/' 					as newbk
			,bbtax_data->>'bs' 		as newbs
			,vba.account			as newko
			,'/' 					as prced
			,'/' 					as sgtxt
			,'/' 					as vbund
			,bbtax_data->>'xblnr' 	as xblnr
			,'/' 					as xstba 
			,'/' 					as zterm
			,'/' 					as zuonr
			,'/' 					as psegment
			,bbtax_data->>'fwste' 	as wrbed
			,bbtax_data->>'fwbas' 	as fwbas
			,''						as aggregate_id
			,'vat.Amount'			as amount_calculation
		from
		(
			select 
				-- JSON wuth containing SAP booking data
				json_array_elements(daten::JSON)::JSON as bbtax_data
				-- create clean JSON with aggregateIDs
				,booking_execution_id
				,booking_created
			from 
			(			
				SELECT 
					id as booking_execution_id
					,timestamp as booking_created
					-- pull SAP Booking data from JSON String
					,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
					,json_extract_path(summary::JSON,'sap')->>'bbtax' as daten  
				FROM bookings_vault.booking_runs
				WHERE 	1=1
					and summary IS NOT NULL 
					-- select un-deleted booking runs 
					AND deleted = 0
					--and id = 1300 ----------------------------------------------------------------------------------- REMOVE ME
			) as x	
			where booking_pfad = 'bbtax'
		) as bseg_data
		left join tmp_vat_booking_accounts vba
			on vba.mwskz = bbtax_data->>'mwskz'
		;
		
		select xblnr, wrbed, fwbas, count(distinct concat(newbs, mwskz)), string_agg(distinct concat(newbs, mwskz), ', ') 
		from tmp_bbtax
		group by xblnr, wrbed, fwbas
		having count(distinct concat(newbs, mwskz)) > 1
		;
		
		select *
		from bookings_vault.aggregated_charges ;
		*/
		/*
		 * select 
			 booking_execution_id as bseg_booking_execution_id
			,booking_created as bseg_booking_created
			-- etract data from JSON
			,bseg->>'key' 					as key
			,bseg->>'aufnr' 				as aufnr
			,bseg->>'gsber' 				as gsber
			,bseg->>'kostl' 				as kostl
			,bseg->>'mwskz' 				as mwskz
			,bseg->>'newbk' 				as newbk
			,bseg->>'newbs' 				as newbs
			,bseg->>'newko' 				as newko
			,bseg->>'prced' 				as prced
			,bseg->>'sgtxt' 				as sgtxt
			,bseg->>'vbund' 				as vbund
			,bseg->>'wrbed' 				as wrbed
			,bseg->>'xblnr' 				as xblnr
			,bseg->>'xstba' 				as xstba 
			,bseg->>'zterm' 				as zterm
			,bseg->>'zuonr' 				as zuonr
			,bseg->>'psegment' 				as psegment
			-- create one row for each element in the JSON list
			,(relatedAggregateIds) as relatedAggregateIds
		 */
		
		drop table if exists report_boil.data_sap_bookings;
		create table if not exists report_boil.data_sap_bookings as
		select 
		  bkpf.booking_execution_id
		, bkpf.booking_created
		, 'bbseg' booking_src
		, bseg."key"
		, bkpf.ba
		, bkpf.budat
		, bkpf.bukrs
		, bkpf.beldat
		, bseg.aufnr
		, bseg.gsber
		, bseg.kostl
		, bseg.mwskz
		, bseg.newbk
		, bseg.newbs
		, bseg.newko
		, seg.mwskz2
		, bseg.prced
		, bseg.sgtxt
		, bseg.vbund
		, bseg.wrbed as wrbed_total
		, seg.wrbed as wrbed_aggregate
		, bseg.xblnr
		, bseg.xstba
		, bseg.zterm
		, bseg.zuonr
		, bseg.psegment
		, seg.aggregate_id
		, seg.amount_calculation
		-- select *
		from report_boil.base_data_bseg as bseg
		left JOIN report_boil.base_data_bbkpf as		bkpf
		on bseg.xblnr = bkpf.xbelnr
		 	and  bseg.bseg_booking_execution_id = bkpf.booking_execution_id
		left JOIN report_boil.base_data_seg as seg
		on seg.xbelnr = bkpf.xbelnr
			and seg.booking_execution_id = bseg.bseg_booking_execution_id 
			and seg.newko = bseg.newko
			and seg.newbs = bseg.newbs
			and seg.aggregate_id = any(bseg.relatedAggregateIds)
		;
		create index idx_data_sap_bookings_aggregate_id on report_boil.data_sap_bookings(aggregate_id); -- 1m
		-- select * from report_boil.data_sap_bookings where booking_execution_id = 1300
	
	end if; -- create fresh sap_bookings
	
	-- if fresh db create hash table first
	-- drop table if exists report_boil.hash_booking_runs;
	create table if not exists report_boil.hash_booking_runs as
	select id, "timestamp", md5(coalesce(summary::text,''::text)) as hash
	from bookings_vault.booking_runs br
	;
	------ snip ----
	-- delete from report_boil.hash_booking_runs where id = 253;
	-- update report_boil.hash_booking_runs set hash = '1234' where id = 1000;
	------ snip ----
	
	-- create temp table with current hashes
	drop table if exists report_boil.inc_hash_booking_runs;
	create table report_boil.inc_hash_booking_runs as
	select id, "timestamp", md5(coalesce(summary::text,'')) as hash
	from bookings_vault.booking_runs br
	; -- select * from report_boil.inc_hash_booking_runs
	
	
	-- do the actual loading
	drop table if exists report_boil.inc_sap_bookings;
	create table report_boil.inc_sap_bookings as
	select 
	  bkpf.booking_execution_id
	, bkpf.booking_created
	, 'bbseg' booking_src
	, bseg."key"
	, bkpf.ba
	, bkpf.budat
	, bkpf.bukrs
	, bkpf.beldat
	, bseg.aufnr
	, bseg.gsber
	, bseg.kostl
	, bseg.mwskz
	, bseg.newbk
	, bseg.newbs
	, bseg.newko
	, bseg.prced
	, bseg.sgtxt
	, bseg.vbund
	, bseg.wrbed as wrbed_total
	, seg.wrbed as wrbed_aggregate
	, bseg.xblnr
	, bseg.xstba
	, bseg.zterm
	, bseg.zuonr
	, bseg.psegment
	, seg.aggregate_id
	, seg.amount_calculation
	from 
	(
	select 
		 booking_execution_id as bseg_booking_execution_id
		,booking_created as bseg_booking_created
		-- etract data from JSON
		,bseg->>'key' 					as key
		,bseg->>'aufnr' 				as aufnr
		,bseg->>'gsber' 				as gsber
		,bseg->>'kostl' 				as kostl
		,bseg->>'mwskz' 				as mwskz
		,bseg->>'newbk' 				as newbk
		,bseg->>'newbs' 				as newbs
		,bseg->>'newko' 				as newko
		,bseg->>'prced' 				as prced
		,bseg->>'sgtxt' 				as sgtxt
		,bseg->>'vbund' 				as vbund
		,bseg->>'wrbed' 				as wrbed
		,bseg->>'xblnr' 				as xblnr
		,bseg->>'xstba' 				as xstba 
		,bseg->>'zterm' 				as zterm
		,bseg->>'zuonr' 				as zuonr
		,bseg->>'psegment' 				as psegment
		-- create one row for each element in the JSON list
		,(relatedAggregateIds) as relatedAggregateIds
			from
			(
						select 
							-- JSON wuth containing SAP booking data
							json_array_elements(daten::JSON)::JSON as bseg
							-- create clean JSON with aggregateIDs
							,(concat ('{', TRIM(both '[]' from (json_array_elements(daten::JSON)::JSON->>'relatedAggregateIds'::text)),'}')::text[] )as relatedAggregateIds
							,booking_execution_id
							,booking_created
						from 
						(			
							SELECT 
								br.id as booking_execution_id
								,timestamp as booking_created
								-- pull SAP Booking data from JSON String
								,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
								,json_extract_path(summary::JSON,'sap')->>'bbseg' as daten  
							FROM bookings_vault.booking_runs br
							join (
								select tmp.id
								from report_boil.inc_hash_booking_runs tmp
								left join report_boil.hash_booking_runs cur
									on cur.id = tmp.id
									and cur.hash = tmp.hash
								where cur.id is null
							) inc on inc.id = br.id
							WHERE 	1=1
									and summary IS NOT NULL 
									-- select un-deleted booking runs 
									AND deleted = 0 
									--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg' )	
						) as x	
						where booking_pfad = 'bbseg'
		) as bseg_data
	) as bseg
	left JOIN(	
			select 
				bbkpf->>'ba' 					as ba
				,to_date(bbkpf->>'budat' , 'dd.mm.yyyy')::date as budat
				,bbkpf->>'bukrs' 				as bukrs
				,bbkpf->>'xblnr' 				as xbelnr
				,to_date(bbkpf->>'beldat' , 'dd.mm.yyyy')::date as beldat
				,*
			FROM(
						select 
							-- JSON wuth containing SAP booking data
							json_array_elements(daten::JSON)::JSON as bbkpf
							-- create clean JSON with aggregateIDs
							,booking_execution_id
							,booking_created
						from 
						(			
							SELECT 
								br.id as booking_execution_id
								,timestamp as booking_created
								-- pull SAP Booking data from JSON String
								,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
								,json_extract_path(summary::JSON,'sap')->>'bbkpf' as daten  
								-- SELECT * 
							FROM bookings_vault.booking_runs br
							join (
								select tmp.id
								from report_boil.inc_hash_booking_runs tmp
								left join report_boil.hash_booking_runs cur
									on cur.id = tmp.id
									and cur.hash = tmp.hash
								where cur.id is null
							) inc on inc.id = br.id
							WHERE 	1=1
									and summary IS NOT NULL 
									-- select un-deleted booking runs 
									AND deleted = 0 
									--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg'  )	
						) as x	
						where booking_pfad = 'bbkpf'
				) as bkpf_sub	
			) as		bkpf
	on bseg.xblnr = bkpf.xbelnr
	 and  bseg.bseg_booking_execution_id = bkpf.booking_execution_id
	left JOIN(	
			select 
				 segments->>'wrbed' 				as wrbed
				,segments->>'xblnr' 				as xbelnr
				,segments->>'newbs' 				as newbs
				,segments->>'newko' 				as newko
				,segments->>'amountCalculation' 	as amount_calculation
				,segments->>'relatedAggregateId' 	as aggregate_id
				,*
			FROM(
						select 
							-- JSON wuth containing SAP booking data
							json_array_elements(daten::JSON)::JSON as segments
							-- create clean JSON with aggregateIDs
							,booking_execution_id
							,booking_created
						from 
						(			
							SELECT 
								br.id as booking_execution_id
								,timestamp as booking_created
								-- pull SAP Booking data from JSON String
								,json_object_keys((summary::JSON->>'sap')::JSON)::varchar as booking_pfad 
								,json_extract_path(summary::JSON,'sap')->>'rawSegments' as daten  
								-- SELECT * 
							FROM bookings_vault.booking_runs br
							join (
								select tmp.id
								from report_boil.inc_hash_booking_runs tmp
								left join report_boil.hash_booking_runs cur
									on cur.id = tmp.id
									and cur.hash = tmp.hash
								where cur.id is null
							) inc on inc.id = br.id
							WHERE 	1=1
									and summary IS NOT NULL 
									-- select un-deleted booking runs 
									AND deleted = 0 
									--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg'  )	
						) as x	
						where booking_pfad = 'rawSegments'
				) as seg_sub	
			) as seg
	on seg.xbelnr = bkpf.xbelnr
		and seg.booking_execution_id = bseg.bseg_booking_execution_id 
		and seg.newko = bseg.newko
		and seg.newbs = bseg.newbs
	;
	
	-- drop data which might be present
	delete from report_boil.data_sap_bookings sap
	using (
		select tmp.id
		from report_boil.inc_hash_booking_runs tmp
		left join report_boil.hash_booking_runs cur
			on cur.id = tmp.id
			and cur.hash = tmp.hash
		where cur.id is null
	) del
	where del.id = sap.booking_execution_id;
	
	-- insert new stuff into sap bookings
	insert into report_boil.data_sap_bookings
	select *
	from report_boil.inc_sap_bookings
	;

	/*
	select tmp.id
	from report_boil.inc_hash_booking_runs tmp
	left join report_boil.hash_booking_runs cur
		on cur.id = tmp.id
		and cur.hash = tmp.hash
	where cur.id is null;
	
	select distinct bseg_booking_execution_id
	from report_boil.sap_bookings
	
	select *
	from bookings_vault.booking_runs
	where id in ()
	*/
	
	-- overwrite table with new hashes
	drop table if exists report_boil.hash_booking_runs;
	create table report_boil.hash_booking_runs as
	select *
	from report_boil.inc_hash_booking_runs;

END $$;
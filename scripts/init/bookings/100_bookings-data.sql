-- bookings data
drop table if exists report_oibl.base_data_bseg;
create table report_oibl.base_data_bseg as
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
; -- select * from tmp_bseg
create index idx_base_data_bseg_primary on report_oibl.base_data_bseg(xblnr,bseg_booking_execution_id);
create index idx_base_data_bseg_secondary on report_oibl.base_data_bseg(xblnr,bseg_booking_execution_id,newko,newbs);


drop table if exists report_oibl.base_data_bbkpf;
create table report_oibl.base_data_bbkpf as
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
					--and br.id = 593
		) as x	
		where booking_pfad = 'bbkpf'
) as bkpf_sub
; -- select * from report_oibl.base_data_bbkpf where xbelnr = 'BR_TRPC-012632'
-- select json_extract_path(summary::JSON,'sap'), * from bookings_vault.booking_runs where id = 593

drop table if exists report_oibl.base_data_seg;
create table report_oibl.base_data_seg as
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
						--and br.id = 1385
						--and br.id > (select coalesce(max(booking_execution_id),0) from  kpi.agg_sap_bookings where booking_src = 'bbseg'  )	
			) as x	
			where booking_pfad = 'rawSegments'
	) as seg_sub
--where segments->>'mwskz' != '/'
;-- select * from report_oibl.base_data_seg where aggregate_id in ('LoS9M8ZVdqp0AKPVGnmkGaKYjfU=', 'QNfMiRRLnYtpBB+mj5cS57G0sNs=')

-- select * from report_oibl.base_data_bbtax where xblnr like 'BR_REBK%'
drop table if exists report_oibl.base_data_bbtax;
create table report_oibl.base_data_bbtax as
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
	,ca.aggregateid			as aggregate_id
	,'vat.Amount'			as amount_calculation
	--,coalesce(bbtax_data->>'taxAggregateOuid','-1')::numeric as tax_aggregate_ouid
from
(
	select 
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
			--and id = 941 ----------------------------------------------------------------------------------- REMOVE ME
	) as x	
	where booking_pfad = 'bbtax'
) as bseg_data
left join report_oibl.client_data_vat_booking_accounts vba
	on vba.mwskz = bbtax_data->>'mwskz'
left join datalake_vault.tax_aggregate ta
	on ta.ouid = coalesce(bbtax_data->>'taxAggregateOuid','-1')::numeric
left join datalake_vault.charge_aggregate ca
	on ta.chargeaggregateouid = ca.ouid
----------------------------------------------------------------------------------- REMOVE ME
--where bbtax_data->>'xblnr' = 'BR_TRPC-029603'
--and bbtax_data->>'mwskz' = '2A'
----------------------------------------------------------------------------------- REMOVE ME
;


drop table if exists report_oibl.data_sap_bookings;
create table if not exists report_oibl.data_sap_bookings as
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
, null::bigint as tax_aggregate_ouid
-- select *
from report_oibl.base_data_bseg as bseg
left JOIN report_oibl.base_data_bbkpf as		bkpf
on bseg.xblnr = bkpf.xbelnr
 and  bseg.bseg_booking_execution_id = bkpf.booking_execution_id
left JOIN report_oibl.base_data_seg as seg
on seg.xbelnr = bkpf.xbelnr
	and seg.booking_execution_id = bseg.bseg_booking_execution_id 
	and seg.newko = bseg.newko
	and seg.newbs = bseg.newbs
	and seg.aggregate_id = any(bseg.relatedAggregateIds)
;
create index idx_data_sap_bookings_aggregate_id on report_oibl.data_sap_bookings(aggregate_id); -- 1m

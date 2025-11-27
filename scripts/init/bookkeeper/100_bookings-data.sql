-- delete first to prevent deadlocks
drop table if exists report_oibl.data_sap_bookings;
drop table if exists report_oibl.base_data_bbtax;
drop table if exists report_oibl.base_data_bbkpf;

drop table if exists tmp_account_metadata;
create temp table tmp_account_metadata as
select 
	 journal_entry_items_uuid
	,max(case when "type" in ('rfbibl','schleupen') and "key" = 'gsber' then value end) as gsber
	,max(case when "type" in ('rfbibl','schleupen') and "key" = 'aufnr' then value end) as aufnr
	,max(case when "type" in ('rfbibl','schleupen') and "key" = 'mwskz' then value end) as mwskz
from bookkeeper_vault.journal_entry_item_account_metadata jeiam
group by journal_entry_items_uuid
;
create index idx_tmp_account_metadata on tmp_account_metadata(journal_entry_items_uuid);

create table report_oibl.data_sap_bookings as
select
	-1 as booking_execution_id -- can't assign an execution id, closest thing would be summary uuid but that's not numerical
	,least(s.file_created_at::date,create_time::date) as booking_created
	,'bbseg' as booking_src
	,'' as "key"
	,'ED' as ba -- check if this needs to be changed for a different client
	,je."date" as budat
	,'100' as bukrs
	,s.create_time::date as beldat
	,coalesce(metadata.aufnr, '/') as aufnr
	,coalesce(metadata.gsber, '/') as gsber
	,'/' as kostl
	,coalesce(metadata.mwskz, '/') as mwskz
	,'/' as newbk
	,case when jei.amount < 0 then '50' else '40' end as newbs
	,jei.account as newko
	,'/' as prced
	,'/' as sgtxt
	,'/' as vbund
	,replace(round(cast(abs(jeisi.amount) as numeric(20,2)) / 100, 2)::text, '.', ',') as wrbed_aggregate
	,replace(round(cast(abs(jei.amount) as numeric(20,2)) / 100, 2)::text, '.', ',') as wrbed_total
	,je.id as xblnr
	,case when jeisi.tax_index is not null then 'X' else '/' end as xstba
	,'/' as zterm
	,'/' as zuonr
	,'/' as psegment
	,ti.external_reference as aggregate_id
	,jeisi.amount_formula as amount_calculation
	,tit.external_reference::bigint as tax_aggregate_ouid
-- select greatest(balanced, coalesce(export, false)), *
from bookkeeper_vault.summaries s
join bookkeeper_vault.journal_entries je
	on je.summaries_uuid = s.uuid
join bookkeeper_vault.journal_entry_items jei
	on jei.journal_entries_uuid = je.uuid
left join tmp_account_metadata metadata
	on metadata.journal_entry_items_uuid = jei.uuid
left join bookkeeper_vault.journal_entry_item_sources jeis
	on jeis.journal_entry_items_uuid = jei.uuid
left join bookkeeper_vault.journal_entry_item_source_items jeisi
	on jeisi.journal_entry_item_sources_uuid = jeis.uuid
left join bookkeeper_vault.transaction_items ti
	on ti.uuid = jeisi.transaction_items_uuid
left join bookkeeper_vault.transaction_item_taxes tit
	on tit.uuid = jeisi.transaction_item_taxes_uuid
where coalesce(s.export, false)
-- and je.id = 'BR_TRPC-058822'
-- and ti.external_reference = '5gfuzsdiGZlqNAUnWYTH5K7bR7s='
; -- select count(*) from report_oibl.data_sap_bookings
create index idx_data_sap_bookings_aggregate_id on report_oibl.data_sap_bookings(aggregate_id);

-- bbtax
create table report_oibl.base_data_bbtax as
select 
	 -1						as bbtax_booking_execution_id
	,least(s.file_created_at::date,create_time::date)	as bbtax_booking_created
	,'/' 					as key
	,'/' 					as aufnr
	,'/' 					as gsber
	,'/' 					as kostl
	,coalesce(metadata.mwskz, '/') as mwskz
	,'/' 					as newbk
	,case when jeit.amount < 0 then '50' else '40' end as newbs
	,vba.account			as newko
	,'/' 					as prced
	,'/' 					as sgtxt
	,'/' 					as vbund
	,je.id 					as xblnr
	,'/' 					as xstba 
	,'/' 					as zterm
	,'/' 					as zuonr
	,'/' 					as psegment
	,replace(round(cast(abs(jeitsi.amount) as numeric(20,2)) / 100, 2)::text, '.', ',') as wrbed
	,replace(round(cast(abs(jeitsi.base_amount) as numeric(20,2)) / 100, 2)::text, '.', ',') as fwbas
	,ti.external_reference 	as aggregate_id
	,jeitsi.amount_formula 	as amount_calculation
-- select *
from bookkeeper_vault.summaries s
join bookkeeper_vault.journal_entries je
	on je.summaries_uuid = s.uuid
join bookkeeper_vault.journal_entry_items jei
	on jei.journal_entries_uuid = je.uuid
left join tmp_account_metadata metadata
	on metadata.journal_entry_items_uuid = jei.uuid
join bookkeeper_vault.journal_entry_item_taxes jeit 
	on jeit.journal_entry_items_uuid = jei.uuid 
join bookkeeper_vault.journal_entry_item_tax_sources jeits 
	on jeits.journal_entry_item_taxes_uuid = jeit.uuid 
left join bookkeeper_vault.journal_entry_item_tax_source_items jeitsi 
	on jeitsi.journal_entry_item_tax_sources_uuid = jeits.uuid 
left join bookkeeper_vault.transaction_items ti 
	on ti.uuid = jeitsi.transaction_items_uuid 
left join report_oibl.client_data_vat_booking_accounts vba
	on vba.mwskz = metadata.mwskz
where coalesce(s.export, false)
--where ti.external_reference = 'xfkYiKvsZlWNVKnnbSewrT8lJMw='
;

-- bbkpf
create table report_oibl.base_data_bbkpf as
select
	 je."date" as budat
	,je.id as xbelnr
from bookkeeper_vault.summaries s
join bookkeeper_vault.journal_entries je
	on je.summaries_uuid = s.uuid
where coalesce(s.export, false)
;
	
	
	
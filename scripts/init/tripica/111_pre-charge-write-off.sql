set timezone = 'Europe/Berlin';
-- write off charges
drop table if exists base_data_write_offs_t;
create temp table base_data_write_offs_t as
select 
	 p.orderdate::date as write_off_date
	,p."characteristics"->>'CANCELLATION_REASON' as write_off_reason
	,unnest(string_to_array(p."characteristics"->>'CHARGES_OUIDS', ',')) as charge_ouid_text
	,n.text as write_off_note
	,row_number() over(partition by unnest(string_to_array(p."characteristics"->>'CHARGES_OUIDS', ',')) order by p.orderdate desc) as rnk
from datalake_vault.product p
left join datalake_vault.order_item oi
	on oi.product_ouid = p.ouid
left join datalake_vault.note n
	on n.productorderouid = oi.productorderouid
left join datalake_vault.product_order po
	on po.ouid = oi.productorderouid
where p.name like '%ACTCHARGESCANCELLATION%'
and po.state = 'COMPLETED' -- there are some write offs which are cancelled or still in progress
;
drop table if exists report_oibl.base_data_write_offs;
create table report_oibl.base_data_write_offs as
select 
	 write_off_date
	,write_off_reason
	,write_off_note
	,case when charge_ouid_text ~ '^[0-9]*.?[0-9]*$' then charge_ouid_text::bigint end as charge_ouid
from base_data_write_offs_t
where rnk = 1
;
create index idx_base_data_write_offs on report_oibl.base_data_write_offs(charge_ouid);

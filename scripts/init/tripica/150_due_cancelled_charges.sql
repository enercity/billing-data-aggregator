set timezone = 'Europe/Berlin';
-- drop tables first to prevent deadlocks
drop table if exists report_oibl.base_data_due_cancelled_charges;
drop table if exists report_oibl.base_data_due_cancelled_balances;
drop table if exists report_oibl.data_due_cancelled_charges;


-- prepare some stuff for charges which have a due_cancelled state in the connected balance
create table report_oibl.base_data_due_cancelled_charges as
select sum(taxincludedamount) over(partition by transactionid) as sum_charges, taxincludedamount, transactionid, ouid, count(*) over(partition by transactionid,taxincludedamount order by ouid) cnt
from datalake_vault.applied_billing_charge c
join report_oibl.client_data_due_charge_type ct
	on c.glid like ct.glid
	and coalesce(c.analyticaxis,'') like ct.analyticaxis
where c.aggregateid is null
--and c.transactionid = 'xa5-4485-025694'
; --  SELECT * FROM report_oibl.base_data_due_cancelled_charges where transactionid = 'xa5-4871-021455'

create table report_oibl.base_data_due_cancelled_balances as
select amount, transactionid, count(*) over(partition by transactionid,amount order by ouid) cnt, datetimelastmodif
from datalake_vault.billing_account_balance b
where b.status = 'DUE_CANCELLED'
--and b.transactionid = 'xa5-3792-001185'
;

-- special case for cancelled manual bonus charges
drop table if exists tmp_cancelled_manual_bonus;
create temp table tmp_cancelled_manual_bonus as
select distinct billingaccountouid, customerouid, taxincludedamount, datetimecreate
from datalake_vault.applied_billing_charge
where glid like '%_MANUAL_BONUS_CANCELLATION'
-- and transactionid = 'xa5-4890-007991'
;
create index on tmp_cancelled_manual_bonus(billingaccountouid, customerouid, taxincludedamount);
-- select count(*) from tmp_cancelled_manual_bonus

create table report_oibl.data_due_cancelled_charges as
select ouid, datetimelastmodif
from report_oibl.base_data_due_cancelled_charges c
join report_oibl.base_data_due_cancelled_balances b
	on b.transactionid = c.transactionid
	and b.amount = c.taxincludedamount
	and b.cnt = c.cnt
union
select ouid, datetimelastmodif
from report_oibl.base_data_due_cancelled_charges c
join report_oibl.base_data_due_cancelled_balances b
	on b.transactionid = c.transactionid
	and b.amount = c.sum_charges
union
select abc.ouid, can.datetimecreate
from datalake_vault.applied_billing_charge abc
join tmp_cancelled_manual_bonus can
	on can.billingaccountouid = abc.billingaccountouid
	and can.customerouid = abc.customerouid
	and abs(can.taxincludedamount) = abs(abc.taxincludedamount) 
where abc.glid like '%_MANUAL_BONUS'
-- and abc.transactionid = 'xa5-4871-021455'
;
--where c.transactionid = 'xa5-4448-033638'
;
create index idx_data_due_cancelled_charges on report_oibl.data_due_cancelled_charges(ouid);
-- select * from report_oibl.data_due_cancelled_charges

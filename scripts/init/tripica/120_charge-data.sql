do $$

declare 

-- Logging variables declaration 
	v_StartScriptTimestamp TIMESTAMP;
	v_LastTaskTimestamp TIMESTAMP;
	v_ScriptName TEXT;
	v_RunID TEXT;
	v_StepName TEXT;

begin

set timezone = 'Europe/Berlin';

-- Logging parameter setting
v_Scriptname := '120_charge-data.sql';
v_RunID := to_char(clock_timestamp(), 'YYMMDD_HH24MISS'); 
v_StartScriptTimestamp := clock_timestamp(); 
v_LastTaskTimestamp := clock_timestamp(); 
RAISE NOTICE E'\n \nLog for: \nScript: % \nRun ID: %\n', v_ScriptName,v_RunID;

v_StepName = '01.';

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '1','report_oibl.tables','Drop','Start');

-- first, delete all tables that possible would need to be deleted to prevent deadlocks
drop table if exists report_oibl.base_data_charges;
drop table if exists report_oibl.base_data_vat_aggregate_sign;
drop table if exists report_oibl.base_data_taxes;
drop table if exists report_oibl.data_charges;
drop table if exists report_oibl.tax_amounts_per_tax_aggregate;
drop table if exists report_oibl.data_overpayment_balance_dates;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '1','report_oibl.tables','Drop','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '2','report_oibl.base_data_charges','Create','Start');

-- charge data
create table report_oibl.base_data_charges as
select 
	abc.ouid as applied_billing_charge_ouid
	,bac.ouid as billing_account_ouid
	,l.ouid as login_ouid
	,abc.datetimelastmodif as datetimelastmodif
	,coalesce(bas.mba,bac.name) as mba
	,bas.cba as cba
	,l.externalid as customer_id
	,(abc.datetimecreate at time zone 'Europe/Berlin')::date as datetimecreate
	,abc.transactionid
	,abc.glid
	,abc.analyticaxis
	,abc.aggregateid
	,abc.accountingid
	,(abc.taxexcludedamount::numeric(20,2))/100 * case when glid similar to '(OVERPAYMENT_CREDIT|%_MANUAL_BONUS)' then -1 else 1 end as taxexcludedamount
	,(abc.taxincludedamount::numeric(20,2))/100 * case when glid similar to '(OVERPAYMENT_CREDIT|%_MANUAL_BONUS)' then -1 else 1 end as taxincludedamount
	,case when abc.glid like '%_FEE' and abc.settlementnoteadviceouid is not null then
	coalesce(dd2.due_date,csbd.due_date,bd.due_date,abc.datetimecreate)::date 
	when abc.glid like '%_CANCELLATION_BALANCE' then coalesce(dd.due_date, dd2.due_date)::date
	else coalesce(dd.due_date,csbd.due_date,bd.due_date,abc.datetimecreate)::date
	end as due_date
	,sna.id as bill_id
	,case when csbd.charge_ouid is not null then csbd.balance_date else bd.balance_date end as balance_date
	,wo.write_off_date
	,wo.write_off_reason
	,wo.write_off_note
	,d.dunning_lock_until
	,d.dunning_lock_reason
	,d.dunning_status
	,d.dunning_scenario
	,d.dunning_level
	,coalesce(bac."characteristics"->>'migrationFlag', bas.migration_flag) as migration_flag
	,true as can_be_due
from datalake_vault.applied_billing_charge abc
left join datalake_vault.billing_account as bac
	on bac.ouid = abc.billingaccountouid
LEFT JOIN datalake_vault.login AS l 
	ON l.customerouid = bac.customerouid
left join datalake_vault.settlement_note_advice sna
	on sna.ouid = abc.settlementnoteadviceouid
left join report_oibl.base_data_billing_accounts bas
	on bac.name = bas.cba
left join report_oibl.base_data_charge_specific_due_date dd
	on dd.charge_ouid = abc.ouid
left join report_oibl.base_data_charge_specific_due_date dd2
	on dd2.transactionid = abc.transactionid
left join report_oibl.base_data_charge_specific_balance_date csbd
	on csbd.charge_ouid = abc.ouid
left join report_oibl.base_data_migrated_bill_due_date mbd
	on mbd.transactionid = abc.transactionid
	and abc.glid like '%_BILL_MIGRATION'
left join report_oibl.base_data_balance_date bd
	on bd.transactionid = abc.transactionid
left join report_oibl.base_data_write_offs as wo
	on wo.charge_ouid = abc.ouid
left join report_oibl.base_data_dunning d
	on coalesce(bas.mba,bac.name) = d.mba
where (abc.datetimelastmodif at time zone 'Europe/Berlin')::date > '2019-07-30'
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '2','report_oibl.base_data_charges','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '3','idx_base_data_charges_ouid','Create','Start');

create index idx_base_data_charges_ouid on report_oibl.base_data_charges(applied_billing_charge_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '3','idx_base_data_charges_ouid','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '4','report_oibl.base_data_charges','Update','Start');

-- set MANUAL_BONUS charges that don't have a related balance (e.g. december payout special manual bonus) to not due
update report_oibl.base_data_charges
set can_be_due = false
where glid like '%MANUAL_BONUS'
	and analyticaxis like '%special%'
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '4','report_oibl.base_data_charges','Update','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5','report_oibl.base_data_charges','Update','Start');

-- set can_be_due as false for all charges with the analytic axis cancellation
update report_oibl.base_data_charges
set can_be_due = false
where analyticaxis like '%cancellation%'
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5','report_oibl.base_data_charges','Update','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5.1','report_oibl.tmp_bcmc_bill_id','Create','Start');

-- set bill id for BCMC 
create temp table tmp_bcmc_bill_id as (
select distinct abc.transactionid as transactionid, p."characteristics"->>'billId' as bill_id  
from datalake_vault.applied_billing_charge abc 
inner join datalake_vault.product p on 
p.billingaccountouid = abc.billingaccountouid and
p.name = abc.productname and 
p.startdatetime = abc.startdatetime and
p.enddatetime = abc.enddatetime and 
date_trunc('hour',p.orderdate) = date_trunc('hour',abc.datetimecreate)  -- additional join constraint
where abc.glid like '%_MANUAL_CONSUMPTION'
and p."characteristics"->>'billId' is not null
);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5.1','report_oibl.tmp_bcmc_bill_id','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5.2','report_oibl.base_data_charges','Update','Start');

update report_oibl.base_data_charges bdc
set bill_id = tmp_bcmc_bill_id.bill_id
from tmp_bcmc_bill_id
where bdc.transactionid = tmp_bcmc_bill_id.transactionid
and bdc.bill_id is null;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5.2','report_oibl.base_data_charges','Update','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '6','report_oibl.base_data_vat_aggregate_sign','Create','Start');

-- new
create table report_oibl.base_data_vat_aggregate_sign as
select 
	case when sum(t.amount) < 0 then -1 else 1 end as total_sign,
	case when sum(c.taxincludedamount * case when glid similar to '(OVERPAYMENT_CREDIT|%_MANUAL_BONUS)' then -1 else 1 end) < 0 then -1 else 1 end  as total_sign_taxincludedamount,
	case when sum(c.taxexcludedamount * case when glid similar to '(OVERPAYMENT_CREDIT|%_MANUAL_BONUS)' then -1 else 1 end) < 0 then -1 else 1 end as total_sign_taxexcludedamount,
	c.aggregateid
from datalake_vault.applied_billing_tax_rate t
left join datalake_vault.applied_billing_charge c
	on c.ouid = t.appliedbillingchargeouid
where coalesce(c.aggregateid,'') != ''
and t.taxcategory = 'VAT'
group by c.aggregateid
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '6','report_oibl.base_data_vat_aggregate_sign','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '7','idx_base_data_vat_aggregate_sign','Create','Start');

create index idx_base_data_vat_aggregate_sign on report_oibl.base_data_vat_aggregate_sign(aggregateid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '7','idx_base_data_vat_aggregate_sign','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '8','report_oibl.base_data_taxes','Create','Start');


create table report_oibl.base_data_taxes as
select 
	 appliedbillingchargeouid 
	,sum(((case when taxcategory in ('VAT') then (amount::numeric(20,2))/100 end ))) as taxamount
	,sum(((case when taxcategory in ('gasTax','electricityTax') then (amount::numeric(20,2))/100  end ))) as energytaxamount
from datalake_vault.applied_billing_tax_rate
where taxcategory in ('gasTax','electricityTax','VAT')
group by 1
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '8','report_oibl.base_data_taxes','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '9','report_oibl.data_charges','Create','Start');

create table report_oibl.data_charges as
select distinct c.*, t.*, s.total_sign as tax_total_aggregate_sign, s.total_sign_taxincludedamount, s.total_sign_taxexcludedamount
from report_oibl.base_data_charges c
join report_oibl.base_data_taxes t
	on c.applied_billing_charge_ouid = t.appliedbillingchargeouid
left join report_oibl.base_data_vat_aggregate_sign s
	on s.aggregateid = c.aggregateid
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '9','report_oibl.data_charges','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '10','idx_data_charges_applied_billing_charge_ouid','Create','Start');

create index idx_data_charges_applied_billing_charge_ouid on report_oibl.data_charges(applied_billing_charge_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '10','idx_data_charges_applied_billing_charge_ouid','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '11','idx_data_charges_aggregateid','Create','Start');

create index idx_data_charges_aggregateid on report_oibl.data_charges(aggregateid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '11','idx_data_charges_aggregateid','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '12','report_oibl.tax_amounts_per_tax_aggregate','Create','Start');


-- there are multiple taxes for a single charge (e.g. when there are mixed tax rates which also can result in positive and negative taxes per one charge)
-- In order to reflect these bookings correctly, a list of such is needed.
create table report_oibl.tax_amounts_per_tax_aggregate as
select distinct (abtr.amount::numeric(20,2))/100 as amount, abtr.ouid as tax_ouid, abc.ouid as charge_ouid, ta.ouid as tax_aggregate_ouid, abtr.taxrate, (ta.amount::numeric(20,2))/100 as tax_aggregate_amount, case when ta.amount < 0 then -1 when ta.amount > 0 then 1 else 0 end as tax_total_sign_via_tax_aggregate, ta.taxcategory
from datalake_vault.charge_aggregate ca
left join datalake_vault.tax_aggregate ta
	on ta.chargeaggregateouid = ca.ouid
left join datalake_vault.applied_billing_charge abc
	on abc.aggregateid = ca.aggregateid
left join datalake_vault.applied_billing_tax_rate abtr
	on abtr.appliedbillingchargeouid = abc.ouid
	and ta.taxrate = abtr.taxrate
	and ta.taxcategory = abtr.taxcategory
where 1=1
and ta.taxcategory in ('VAT', 'gasTax', 'electricityTax')
and abtr.amount is not null
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '12','report_oibl.tax_amounts_per_tax_aggregate','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '13','tax_amounts_per_tax_aggregate(tax_aggregate_ouid)','Create','Start');

create index on report_oibl.tax_amounts_per_tax_aggregate(tax_aggregate_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '13','tax_amounts_per_tax_aggregate(tax_aggregate_ouid)','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '14','tax_amounts_per_tax_aggregate(charge_ouid)','Create','Start');

create index on report_oibl.tax_amounts_per_tax_aggregate(charge_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '14','tax_amounts_per_tax_aggregate(charge_ouid)','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '15','report_oibl.data_overpayment_balance_dates','Create','Start');


-- overpayment due dates
--
-- As overpayments can be partially used for another transaction we want to list all the OVERPAYMENT charges in a transaction to be open until all of it is settled.
-- This ensures we can still move "backwards in time" which may be illustrated by the following example
-- Transaction xa5-0000-001234 has an OVERPAYMENT_CREDIT charge in it. This charge will have the due date = creation date.
-- Then some of the overpayment is used to settle another transaction. An OVERPAYMENT_USED charge is created as a result.
-- This charge will also have the due date as a creation date. However it will not have a balance date yet.
-- A second transaction causes the remaining bits of the overpayment to be used resulting in yet another OVERPAYMENT_USED charge.
-- Now all of the charges will receive the balance date = creation date of the latest OVERPAYMENT_USED charge.
create table report_oibl.data_overpayment_balance_dates as
select 
	case when 
		sum(case when glid = 'OVERPAYMENT_CREDIT' then taxincludedamount end) <= sum(case when glid = 'OVERPAYMENT_USED' then taxincludedamount end)
			then max(case when glid = 'OVERPAYMENT_USED' then datetimecreate::date end )
	end as fully_used_at,
	transactionid
from datalake_vault.applied_billing_charge abc
where glid in ('OVERPAYMENT_CREDIT', 'OVERPAYMENT_USED')
group by transactionid
; 
-- overpayments which are cancelled as of a rejection must also be balanced to the date of the rejection

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '15','report_oibl.data_overpayment_balance_dates','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '16','report_oibl.data_overpayment_balance_dates','Insert','Start');

insert into report_oibl.data_overpayment_balance_dates
select distinct
	datetimecreate::date as fully_used_at
	,"characteristics"->>'rejectedChargeTransactionId' as transactionid
from datalake_vault.applied_billing_charge abc
where glid = 'OVERPAYMENT_CREDIT_REJECTED'
and "characteristics"->>'rejectedChargeTransactionId' is not null
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '16','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '17','report_oibl.data_overpayment_balance_dates','Insert','Start');

-- before rejections where linked via the charge characteristics, the link was done via the payment item
insert into report_oibl.data_overpayment_balance_dates
select abc.datetimecreate::date as fully_used_at, pr.transactionid as transactionid
from datalake_vault.applied_billing_charge abc
left join datalake_vault.billing_account_balance bab
	on bab.transactionid = abc.transactionid
left join datalake_vault.payment_item pit
	on pit.referredouid = bab.ouid
left join datalake_vault.payment_request pr
	on pr.ouid = pit.paymentouid
where abc.glid = 'OVERPAYMENT_REFUND_CANCEL' -- indicates that the overpayment has been transfered back to the customer
and pr.transactionid is not null
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '17','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '18','report_oibl.data_overpayment_balance_dates','Insert','Start');

-- overpayments which were created by a payment request that is now in the status REJECTED should be balanced
insert into report_oibl.data_overpayment_balance_dates
select distinct pr.datelastchangestatus::date as fully_used_at, pr.transactionid
from datalake_vault.applied_billing_charge abc
left join datalake_vault.payment_request pr
	on pr.transactionid = abc.transactionid
where abc.glid in ('OVERPAYMENT_CREDIT', 'OVERPAYMENT_USED')
and pr.status = 'REJECTED'
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '18','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '19','report_oibl.data_overpayment_balance_dates','Insert','Start');

-- overpayments that were created as part of a cancelled payment
insert into report_oibl.data_overpayment_balance_dates
select pr.datelastchangestatus::date as fully_used_at, pr.transactionid as transactionid 
from datalake_vault.applied_billing_charge abc
join datalake_vault.payment_request pr
	on pr.transactionid = abc.transactionid
join datalake_vault.billing_account_balance bab
	on bab.transactionid = abc.transactionid
	and bab.status = 'PAID'
where abc.glid = 'OVERPAYMENT_CREDIT'
and pr.status = 'CANCELLED'
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '19','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '20','tmp_overpayments_different_transaction_cancelled_balance','Create','Start');

-- overpayments that were used via a different transaction (BALANCE_CANCELLED)
drop table if exists tmp_overpayments_different_transaction_cancelled_balance;
create temp table tmp_overpayments_different_transaction_cancelled_balance as
select used.ouid as used_charge_ouid, used.transactionid as used_transactionid, credit.ouid as credit_charge_ouid, credit.transactionid as credit_transactionid, used.datetimecreate::date as balance_date, row_number() over(partition by credit.ouid order by pr.transactionid) as used_rank, row_number() over(partition by used.ouid order by credit.transactionid) as credit_rank
from datalake_vault.applied_billing_charge used
left join datalake_vault.payment_request pr
	on pr.transactionid = used.transactionid
left join datalake_vault.payment_item pi2
	on pi2.paymentouid  = pr.ouid
left join datalake_vault.billing_account_balance bab
	on bab.ouid = pi2.referredouid
	and pi2.amount = bab.amount
left join datalake_vault.applied_billing_charge credit
	on credit.transactionid = bab.transactionid
	and bab.billingaccountouid = credit.billingaccountouid
	and bab.amount = credit.taxincludedamount
	and credit.glid = 'OVERPAYMENT_CREDIT'
where pi2.referredtype = 'CANCELLED_BALANCE'
and used.glid = 'OVERPAYMENT_USED'
and credit.ouid is not null
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '20','tmp_overpayments_different_transaction_cancelled_balance','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '21','tmp_overpayments_different_transaction_cancelled_balance','Delete','Start');

delete from tmp_overpayments_different_transaction_cancelled_balance
where used_rank != credit_rank
; 

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '21','tmp_overpayments_different_transaction_cancelled_balance','Delete','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '22','report_oibl.data_overpayment_balance_dates','Insert','Start');

insert into report_oibl.data_overpayment_balance_dates
select distinct balance_date::date as fully_used_at, used_transactionid as transactionid
from tmp_overpayments_different_transaction_cancelled_balance
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '22','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '23','report_oibl.data_overpayment_balance_dates','Insert','Start');

insert into report_oibl.data_overpayment_balance_dates
select distinct balance_date::date as fully_used_at, credit_transactionid as transactionid
from tmp_overpayments_different_transaction_cancelled_balance
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '23','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '24','tmp_op_balance_dates','Create','Start');

-- remove duplicates from the list of balance dates
drop table if exists tmp_op_balance_dates;
create temp table tmp_op_balance_dates as
select distinct on (transactionid)
	transactionid, fully_used_at
from report_oibl.data_overpayment_balance_dates
order by transactionid, fully_used_at desc nulls last
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '24','tmp_op_balance_dates','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '25','report_oibl.data_overpayment_balance_dates','Truncate','Start');

truncate report_oibl.data_overpayment_balance_dates;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '25','report_oibl.data_overpayment_balance_dates','Truncate','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '26','report_oibl.data_overpayment_balance_dates','Insert','Start');

insert into report_oibl.data_overpayment_balance_dates
select fully_used_at, transactionid
from tmp_op_balance_dates
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '26','report_oibl.data_overpayment_balance_dates','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '27','idx_data_overpayment_balance_dates_transactionid','Create','Start');

create index idx_data_overpayment_balance_dates_transactionid on report_oibl.data_overpayment_balance_dates(transactionid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '27','idx_data_overpayment_balance_dates_transactionid','Create','Stop');


RAISE NOTICE E'\nScript finished: \nScript: % \nRun ID: %\n', v_ScriptName,v_RunID;

END $$;

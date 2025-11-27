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
v_Scriptname := '500_oibl_creation.sql';
v_RunID := to_char(clock_timestamp(), 'YYMMDD_HH24MISS'); 
v_StartScriptTimestamp := clock_timestamp(); 
v_LastTaskTimestamp := clock_timestamp(); 
RAISE NOTICE E'\n \nLog for: \nScript: % \nRun ID: %\n', v_ScriptName,v_RunID;

v_StepName = '01.';

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '1','report_oibl.new_oibl_tripica','Create','Start');

drop table if exists report_oibl.new_oibl_tripica cascade;
create table report_oibl.new_oibl_tripica as
select distinct on (applied_billing_charge_ouid)
	-- technical info
	applied_billing_charge_ouid::text 			as applied_billing_charge_ouid,
	billing_account_ouid::text					as billing_account_ouid,
	login_ouid::text 							as login_ouid,
	''											as billing_account_balance_ouid,
	''											as tax_item_ouid,
	c.datetimelastmodif,
	-- general info
	cba											as cba,
	mba											as mba,
	customer_id									as customer_id,
	-- position info
	datetimecreate								as date_created,
	c.transactionid								as transaction_id,
	c.glid										as glid,
	coalesce(c.analyticaxis,'')					as analyticaxis,
	bill_id										as bill_id,
	due_date									as due_date,
	cast(case
		when c.glid in ('OVERPAYMENT_CREDIT', 'OVERPAYMENT_USED') then overpayment_balance.fully_used_at -- special case for overpayment charges
		when c.balance_date is not null then c.balance_date -- best case: use letteringdate of balance
		when dcc.ouid is not null then dcc.datetimelastmodif -- in case the charge is cancelled via balance consider the charge balanced
		when c.accountingid = 'ignored' then c.datetimelastmodif
		else b.budat										
	end as date)								as balance_date,
	write_off_date								as write_off_date,
	write_off_reason							as write_off_reason,
	write_off_note								as write_off_note,
	dunning_lock_until							as dunning_lock_until,
	dunning_lock_reason							as dunning_lock_reason,
	dunning_status								as dunning_status,
	dunning_scenario							as dunning_scenario,
	dunning_level								as dunning_level,
	-- position amounts
	taxexcludedamount							as amount_net,
	taxincludedamount							as amount_gross,
	taxamount 									as amount_vat,
	energytaxamount 							as amount_energy_tax,
	-- booking info
	null::varchar								as aggregate_id,
	null::varchar								as accounting_id,
	null::int4									as booking_execution_id,
	null::date									as booking_created_at,
	null::date									as booking_date,
	null::text									as booking_order_number,
	null::text									as booking_tax_code,
	null::text									as booking_mainledger_account,
	null::text									as booking_reference_document_number,
	-- booking amounts
	null::numeric(20,2)							as booking_debit_amount,
	null::numeric(20,2)							as booking_credit_amount,
	null::text									as booking_amount_indicator,
	c.migration_flag							as migration_flag
from report_oibl.data_charges c
join report_oibl.client_data_due_charge_type y
	on c.glid like y.glid
	and coalesce(c.analyticaxis,'') like y.analyticaxis
left join report_oibl.data_sap_bookings b
	on b.aggregate_id = c.aggregateid
left join report_oibl.data_due_cancelled_charges dcc
	on dcc.ouid = c.applied_billing_charge_ouid
left join report_oibl.data_overpayment_balance_dates overpayment_balance
	on overpayment_balance.transactionid = c.transactionid
WHERE c.can_be_due
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '1','report_oibl.new_oibl_tripica','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '2','charge_tax_aggregate_link','Create','Start');

drop table if exists charge_tax_aggregate_link;
create temp table charge_tax_aggregate_link as
select distinct ta.ouid as tax_aggregate_ouid, abc.ouid as charge_ouid
from datalake_vault.applied_billing_charge abc
left join datalake_vault.charge_aggregate ca
	on ca.aggregateid = abc.aggregateid
left join datalake_vault.tax_aggregate ta
	on ta.chargeaggregateouid = ca.ouid
	and ta.taxcategory = 'VAT'
left join datalake_vault.applied_billing_tax_rate abtr
	on abtr.appliedbillingchargeouid = abc.ouid
	and abtr.taxcategory = ta.taxcategory
	and abtr.taxrate = ta.taxrate 
where abtr.ouid is not null
-- and abc.ouid = 602372814
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '2','charge_tax_aggregate_link','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '3','charge_tax_aggregate_link(tax_aggregate_ouid)','Create','Start');

create index on charge_tax_aggregate_link(tax_aggregate_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '3','charge_tax_aggregate_link(tax_aggregate_ouid)','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '4','charge_tax_aggregate_link(charge_ouid)','Create','Start');

create index on charge_tax_aggregate_link(charge_ouid);

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '4','charge_tax_aggregate_link(charge_ouid)','Create','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5','report_oibl.new_oibl_tripica','Insert','Start');

insert into report_oibl.new_oibl_tripica
select distinct
	-- technical info
	applied_billing_charge_ouid::text 			as applied_billing_charge_ouid,
	billing_account_ouid::text					as billing_account_ouid,
	login_ouid::text 							as login_ouid,
	''											as billing_account_balance_ouid,
	tax.tax_ouid::text							as tax_item_ouid,
	c.datetimelastmodif,
	-- general info
	cba											as cba,
	mba											as mba,
	customer_id									as customer_id,
	-- position info
	c.datetimecreate								as date_created,
	transactionid								as transaction_id,
	glid										as glid,
	coalesce(analyticaxis,'')					as analyticaxis,
	bill_id										as bill_id,
	null::date 									as due_date,
	null::date									as balance_date,
	write_off_date								as write_off_date,
	write_off_reason							as write_off_reason,
	write_off_note								as write_off_note,
	dunning_lock_until							as dunning_lock_until,
	dunning_lock_reason							as dunning_lock_reason,
	dunning_status								as dunning_status,
	dunning_scenario							as dunning_scenario,
	dunning_level								as dunning_level,
	-- position amounts
	taxexcludedamount							as amount_net,
	taxincludedamount							as amount_gross,
	taxamount 									as amount_vat,
	energytaxamount 							as amount_energy_tax,
	-- booking info
	aggregateid									as aggregate_id,
	accountingid								as accounting_id,
	booking_execution_id						as booking_execution_id,
	booking_created::date						as booking_created_at,
	budat										as booking_date,
	aufnr										as booking_order_number,
	mwskz										as booking_tax_code,
	coalesce(newko, concat('tax code: ', mwskz)) as booking_mainledger_account,
	xblnr										as booking_reference_document_number,
	-- booking amounts
	case when newbs = '40' then
		case
			-- special case for DISCOUNT charges before 2023-01-18
			when glid like '%_DISCOUNT_%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date > '2021-06-06' and booking_created::date < '2023-01-18' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_DISCOUNT_%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date > '2021-06-06' and booking_created::date < '2023-01-18' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when glid like '%_DISCOUNT_%' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date < '2023-01-18' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_DISCOUNT_%' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date < '2023-01-18' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for MANUAL_BONUS before 2020-12-02
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and newko like '4%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date > '2020-11-01' and booking_created::date < '2020-11-12' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			-- special case for MANUAL_BONUS before 2023-01-18
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('ac.TaxIncludedAmount','TaxIncludedAmount') and booking_created::date > '2020-11-12'  and booking_created::date < '2023-01-13' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX', 'VATExcludedAmount') and booking_created::date > '2020-11-12'  and booking_created::date < '2023-01-13' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for write-off charges before 2023-01-02
			when coalesce(analyticaxis,'') like '%write-off%' and newko like '5%' and booking_created::date < '2023-01-02' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			-- special case for bill cancellations before 2021-06-07 which have the wrong amount_calculation indicators (other way around than actually booked)
			when amount_calculation = 'ac.TaxIncludedAmount' and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation = 'TaxIncludedAmount' and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for EPILOT charges
			when glid like 'EPILOT_%' and amount_calculation in ('TaxIncludedAmount','ac.TaxIncludedAmount') then case when taxamount != 0 then coalesce(taxincludedamount,0) * tax_total_aggregate_sign else coalesce(taxincludedamount,0) end
			when glid like 'EPILOT_%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') then case when taxamount != 0 then coalesce(taxexcludedamount,0) * tax_total_aggregate_sign else coalesce(taxexcludedamount,0) end
			-- normal cases
			when amount_calculation = 'TaxIncludedAmount' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation in ('VATExcludedAmount', 'TaxIncludedAmount - VAT') then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when amount_calculation = 'ac.TaxIncludedAmount' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when amount_calculation in ('energyTax.Amount', 'GASTAX', 'ELECTRICITYTAX') and tax.tax_aggregate_ouid is not null then coalesce(energytaxamount,0) * tax_total_sign_via_tax_aggregate
			when amount_calculation in ('energyTax.Amount', 'GASTAX', 'ELECTRICITYTAX') then abs(coalesce(energytaxamount,0))
			when amount_calculation in ('vat.Amount', 'VAT') and c.datetimecreate < '2021-10-09' then abs(coalesce(taxamount,0)) -- before 2021-10-09 charges were summed up via abs in the aggregation process
			-- TODO special case for old bookings? when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_aggregate_sign
			-- when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then abs(coalesce(tax.amount,0))
			when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_sign_via_tax_aggregate
			-- when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_aggregate_sign
			when amount_calculation in ('vat.Amount', 'VAT') and booking_created::date < '2024-01-04' then abs(coalesce(taxamount,0)) -- TODO lookup actual switch date
			when amount_calculation in ('vat.Amount', 'VAT') then coalesce(taxamount,0) * tax_total_aggregate_sign
			else 0 -- error case when negative
		end
	end											as booking_debit_amount,
	case when newbs = '50' then
		case
			-- special case for DISCOUNT charges before 2023-01-18
			when glid like '%_DISCOUNT_%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date > '2021-06-06' and booking_created::date < '2023-01-18' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_DISCOUNT_%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date > '2021-06-06' and booking_created::date < '2023-01-18' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when glid like '%_DISCOUNT_%' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date < '2023-01-18' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_DISCOUNT_%' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date < '2023-01-18' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for MANUAL_BONUS before 2020-12-02
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and newko like '4%' and amount_calculation in ('ac.TaxIncludedAmount', 'TaxIncludedAmount') and booking_created::date > '2020-11-01' and booking_created::date < '2020-11-12' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			-- special case for MANUAL_BONUS before 9999-12-31
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('ac.TaxIncludedAmount','TaxIncludedAmount') and booking_created::date > '2020-11-12'  and booking_created::date < '2023-01-13' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when glid like '%_MANUAL_BONUS' and coalesce(analyticaxis,'') not like '%cancellation%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX', 'VATExcludedAmount') and booking_created::date > '2020-11-12'  and booking_created::date < '2023-01-13' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for write-off charges before 2023-01-02
			when coalesce(analyticaxis,'') like '%write-off%' and newko like '5%' and booking_created::date < '2023-01-02' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			-- special case for bill cancellations before 2021-06-07 which have the wrong amount_calculation indicators (other way around than actually booked)
			when amount_calculation = 'ac.TaxIncludedAmount' and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation = 'TaxIncludedAmount' and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') and booking_created::date < '2021-06-08' and coalesce(analyticaxis,'') like '%cancellation%' and glid like '%_SUBSCRIPTION_%' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			-- special case for EPILOT charges
			when glid like 'EPILOT_%' and amount_calculation in ('TaxIncludedAmount','ac.TaxIncludedAmount') then case when taxamount != 0 then coalesce(taxincludedamount,0) * tax_total_aggregate_sign else coalesce(taxincludedamount,0) end
			when glid like 'EPILOT_%' and amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') then case when taxamount != 0 then coalesce(taxexcludedamount,0) * tax_total_aggregate_sign else coalesce(taxexcludedamount,0) end
			-- normal cases
			when amount_calculation = 'TaxIncludedAmount' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when amount_calculation in ('TaxExcludedAmount - energyTax.Amount', 'VATExcludedAmount - GASTAX', 'VATExcludedAmount - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - ENERGYTAX', 'TaxIncludedAmount - VAT - ELECTRICITYTAX', 'TaxIncludedAmount - VAT - GASTAX') then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount - coalesce(energytaxamount,0) * tax_total_aggregate_sign
			when amount_calculation in ('VATExcludedAmount', 'TaxIncludedAmount - VAT') then coalesce(taxexcludedamount,0) * total_sign_taxexcludedamount
			when amount_calculation = 'ac.TaxIncludedAmount' then coalesce(taxincludedamount,0) * total_sign_taxincludedamount
			when amount_calculation in ('energyTax.Amount', 'GASTAX', 'ELECTRICITYTAX') and tax.tax_aggregate_ouid is not null then coalesce(energytaxamount,0) * tax_total_sign_via_tax_aggregate
			when amount_calculation in ('energyTax.Amount', 'GASTAX', 'ELECTRICITYTAX') then abs(coalesce(energytaxamount,0))
			when amount_calculation in ('vat.Amount', 'VAT') and c.datetimecreate < '2021-10-09' then abs(coalesce(taxamount,0)) -- before 2021-10-09 charges were summed up via abs in the aggregation process
			-- TODO special case for old bookings? when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_aggregate_sign
			-- when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then abs(coalesce(tax.amount,0))
			-- when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null and tax.tax_aggregate_amount < 0 and tax.amount < 0 then abs(coalesce(tax.amount,0))
			when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_sign_via_tax_aggregate
			-- when amount_calculation in ('vat.Amount', 'VAT') and tax.tax_aggregate_ouid is not null then coalesce(tax.amount,0) * tax_total_aggregate_sign
			when amount_calculation in ('vat.Amount', 'VAT') and booking_created::date < '2024-01-04' then abs(coalesce(taxamount,0)) -- TODO lookup actual switch date
			when amount_calculation in ('vat.Amount', 'VAT') then coalesce(taxamount,0) * tax_total_aggregate_sign
			else 0 -- error case when negative
		end
	end											as booking_credit_amount,
	amount_calculation							as booking_amount_indicator, --technical debugging
	c.migration_flag							as migration_flag
from report_oibl.data_charges c
left join charge_tax_aggregate_link tal
	on tal.charge_ouid = c.applied_billing_charge_ouid
join report_oibl.data_sap_bookings b
	on b.aggregate_id = c.aggregateid
	and c.aggregateid != '' -- exclude empty aggregates
	and case
		when b.tax_aggregate_ouid is not null
				and tal.tax_aggregate_ouid is not null
				and b.amount_calculation in ('vat.Amount', 'VAT') -- only applies to VAT bookings
			then b.tax_aggregate_ouid = tal.tax_aggregate_ouid else true end
left join report_oibl.tax_amounts_per_tax_aggregate tax
	on tax.tax_aggregate_ouid = b.tax_aggregate_ouid
	and tax.charge_ouid = c.applied_billing_charge_ouid
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '5','report_oibl.new_oibl_tripica','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '6','report_oibl.new_oibl_tripica','Insert','Start');

insert into report_oibl.new_oibl_tripica
select
	-- technical info
	'' 											as applied_billing_charge_ouid,
	'' 											as billing_account_ouid,
	'' 											as login_ouid,
	c.ouid::text								as billing_account_balance_ouid,
	''											as tax_item_ouid,
	datetimelastmodif,
	-- general info
	cba											as cba,
	mba											as mba,
	customer_id									as customer_id,
	-- position info
	datetimecreate								as date_created,
	transactionid								as transaction_id,
	glid										as glid,
	analyticaxis								as analyticaxis,
	''											as bill_id,
	null	 									as due_date,
	null										as balance_date,
	null 										as write_off_date,
	null										as write_off_reason,
	null										as write_off_note,
	null										as dunning_lock_until,
	null	 									as dunning_lock_reason,
	null										as dunning_status,
	null										as dunning_scenario,
	null										as dunning_level,
	-- position amounts
	taxincludedamount							as amount_net,
	taxincludedamount							as amount_gross,
	0		 									as amount_vat,
	0				 							as amount_energy_tax,
	-- booking info
	aggregateid									as aggregate_id,
	accountingid								as accounting_id,
	booking_execution_id						as booking_execution_id,
	beldat										as booking_created_at,
	budat										as booking_date,
	aufnr										as booking_order_number,
	mwskz										as booking_tax_code,
	coalesce(newko, concat('tax code: ', mwskz)) as booking_mainledger_account,
	xblnr										as booking_reference_document_number,
	-- booking amounts
	case when newbs = '40' then
		case
			when amount_calculation = 'TaxIncludedAmount' then abs(coalesce(taxincludedamount,0))
			else -1 -- error case when negative
		end
	end											as booking_debit_amount,
	case when newbs = '50' then
		case
			when amount_calculation = 'TaxIncludedAmount' then abs(coalesce(taxincludedamount,0))
			else -1 -- error case when negative
		end
	end											as booking_credit_amount,
	amount_calculation							as booking_amount_indicator, --technical debugging
	c.migration_flag							as migration_flag
from report_oibl.data_balances c
join report_oibl.data_sap_bookings b
	on b.aggregate_id = c.aggregateid
	and c.aggregateid != ''
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '6','report_oibl.new_oibl_tripica','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '7','report_oibl.new_oibl_tripica','Insert','Start');

insert into report_oibl.new_oibl_tripica
select distinct
	-- technical info
	coalesce(applied_billing_charge_ouid::text,'')	as applied_billing_charge_ouid,
	coalesce(billing_account_ouid::text,'')		as billing_account_ouid,
	coalesce(login_ouid::text,'') 				as login_ouid,
	''											as billing_account_balance_ouid,
	''											as tax_item_ouid,
	datetimelastmodif,
	-- general info
	cba											as cba,
	mba											as mba,
	coalesce(customer_id,'')					as customer_id,
	-- position info
	datetimecreate								as date_created,
	coalesce(transactionid,'')					as transaction_id,
	coalesce(glid,'')							as glid,
	coalesce(analyticaxis,'')					as analyticaxis,
	coalesce(bill_id,'')						as bill_id,
	null::date	 								as due_date,
	null::date									as balance_date,
	write_off_date								as write_off_date,
	write_off_reason							as write_off_reason,
	write_off_note								as write_off_note,
	dunning_lock_until							as dunning_lock_until,
	dunning_lock_reason							as dunning_lock_reason,
	dunning_status								as dunning_status,
	dunning_scenario							as dunning_scenario,
	dunning_level								as dunning_level,
	-- position amounts
	coalesce(
		taxexcludedamount,
		replace(fwbas,',','.')::numeric(20,2) -- fallback for legacy tax bookings (without reference to aggregate)
	)											as amount_net,
	coalesce(
		taxincludedamount,
		replace(fwbas,',','.')::numeric(20,2) -- fallback for legacy tax bookings (without reference to aggregate)
			+ replace(wrbed,',','.')::numeric(20,2)
	)											as amount_gross,
	coalesce(
		taxamount,
		replace(wrbed,',','.')::numeric(20,2)
	)											as amount_vat,
	0				 							as amount_energy_tax,
	-- booking info
	coalesce(aggregate_id,'')					as aggregate_id,
	coalesce(accountingid,'')					as accounting_id,
	bbtax_booking_execution_id					as booking_execution_id,
	bbtax_booking_created::date					as booking_created_at,
	budat										as booking_date,
	aufnr										as booking_order_number,
	mwskz										as booking_tax_code,
	coalesce(newko, concat('tax code: ', mwskz)) as booking_mainledger_account,
	xblnr										as booking_reference_document_number,
	-- booking amounts
	case when newbs = '40' then
		case
			when amount_calculation in ('vat.Amount', 'VAT') then coalesce(
						taxamount * tax_total_aggregate_sign,
						abs(replace(wrbed,',','.')::numeric(20,2))
					)
			else -1 -- error case when negative
		end
	end											as booking_debit_amount,
	case when newbs = '50' then
		case
			when amount_calculation in ('vat.Amount', 'VAT') then coalesce(
						taxamount * tax_total_aggregate_sign,
						abs(replace(wrbed,',','.')::numeric(20,2))
					)
			else -1 -- error case when negative
		end
	end												as booking_credit_amount,
	tax.amount_calculation							as booking_amount_indicator, --technical debugging
	c.migration_flag								as migration_flag
from report_oibl.base_data_bbtax tax
left join report_oibl.data_charges c
	on tax.aggregate_id = c.aggregateid
	and c.aggregateid != ''
join report_oibl.base_data_bbkpf bbkpf
	on bbkpf.xbelnr = tax.xblnr
where (tax.xblnr like 'BR_TRPC%' or tax.xblnr like 'BR_REBK%' or xblnr like 'BR_CANC%' or tax.xblnr like 'BR_MAN%')
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '7','report_oibl.new_oibl_tripica','Insert','Stop');
v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '8','report_oibl.new_oibl_tripica','Insert','Start');

--PAS Bookings Addition
with pas_bookings as 
(
	select
		-- technical info
		null                                       as applied_billing_charge_ouid
		,null                                       as billing_account_ouid
		,null                                       as login_ouid
		,null                                       as billing_account_balance_ouid
		,null                                       as tax_item_ouid
		,null::date                                 as datetimelastmodif
		-- general info
		,null                                       as cba
		,null                                       as mba
		,null                                       as customer_id
		-- position info
		,null::date                                 as date_created
		,null                                       as transaction_id
		,concat('PAS_',ps.payment_status)			as glid
		,null                                       as analyticaxis
		,null                                       as bill_id
		,null::date									as due_date
		,null::date									as balance_date
		,null::date									as write_off_date
		,null										as write_off_reason
		,null										as write_off_note
		,null::date									as dunning_lock_until
		,null	 									as dunning_lock_reason
		,null										as dunning_status
		,null										as dunning_scenario
		,null::integer								as dunning_level
		-- position amounts
		,p.amount 									as amount_net
		,p.amount 									as amount_gross
		,0											as amount_vat
		,null::integer	 							as amount_energy_tax
		-- booking info
		,b.id 										as aggregate_id	
		,null        								as accounting_id
		,null::integer                				as booking_execution_id
		,book.beldat 								as booking_created_at
		,book.budat									as booking_date
		,book.aufnr									as booking_order_number
		,book.mwskz									as booking_tax_code
		,book.newko									as booking_mainledger_account
		,book.xblnr									as booking_reference_document_number
		,case when newbs = '40' then p.amount end	as booking_debit_amount
		,case when newbs = '50' then p.amount end	as booking_credit_amount
		,book.amount_calculation 					as booking_amount_indicator
		,null           							as migration_flag
	from paymentallocation_vault.bookings b
	join paymentallocation_vault.payments p
		on p.id = b.payment_id
	join paymentallocation_vault.payment_states ps
		on b.payment_state_id = ps.id 
	inner join report_oibl.data_sap_bookings book
		on (b.id::text = book.aggregate_id and beldat <= '2024-01-31'::timestamp) 
union
	select
		-- technical info
		null                                       as applied_billing_charge_ouid
		,null                                       as billing_account_ouid
		,null                                       as login_ouid
		,null                                       as billing_account_balance_ouid
		,null                                       as tax_item_ouid
		,null::date                                 as datetimelastmodif
		-- general info
		,null                                       as cba
		,null                                       as mba
		,null                                       as customer_id
		-- position info
		,null::date                                 as date_created
		,null                                       as transaction_id
		,concat('PAS_',ps.payment_status)			as glid
		,null                                       as analyticaxis
		,null                                       as bill_id
		,null::date									as due_date
		,null::date									as balance_date
		,null::date									as write_off_date
		,null										as write_off_reason
		,null										as write_off_note
		,null::date									as dunning_lock_until
		,null	 									as dunning_lock_reason
		,null										as dunning_status
		,null										as dunning_scenario
		,null::integer								as dunning_level
		-- position amounts
		,p.amount 									as amount_net
		,p.amount 									as amount_gross
		,0											as amount_vat
		,null::integer	 							as amount_energy_tax
		-- booking info
		,b.id 										as aggregate_id	
		,null        								as accounting_id
		,null::integer                				as booking_execution_id
		,book.beldat 								as booking_created_at
		,book.budat									as booking_date
		,book.aufnr									as booking_order_number
		,book.mwskz									as booking_tax_code
		,book.newko									as booking_mainledger_account
		,book.xblnr									as booking_reference_document_number
		,case when newbs = '40' then p.amount end	as booking_debit_amount
		,case when newbs = '50' then p.amount end	as booking_credit_amount
		,book.amount_calculation 					as booking_amount_indicator
		,null           							as migration_flag
	from paymentallocation_vault.bookings b
	join paymentallocation_vault.payments p
		on p.id = b.payment_id
	join paymentallocation_vault.payment_states ps
		on b.payment_state_id = ps.id 
	inner join report_oibl.data_sap_bookings book
		on  (book.xblnr = b.sap_id and beldat >= '2024-01-31'::timestamp) 
)
insert into report_oibl.new_oibl_tripica 
select * from pas_bookings
;


v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '8','report_oibl.new_oibl_tripica','Insert','Stop');


v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '9','report_oibl.new_oibl_tripica','Update','Start');

-- Fix negative ELECTRICITYTAX debit amounts (related to DEV-100149)
with affected_aggregates as (
	select aggregate_id
	from report_oibl.new_oibl_tripica
	group by aggregate_id
	having SUM(booking_debit_amount) <> SUM(booking_credit_amount)
)
Update report_oibl.new_oibl_tripica AS noibl
set booking_debit_amount = ABS(noibl.booking_debit_amount)
from affected_aggregates aa
where noibl.aggregate_id = aa.aggregate_id
  and noibl.booking_amount_indicator = 'VATExcludedAmount - ELECTRICITYTAX'
  and noibl.booking_debit_amount < 0 
;

v_LastTaskTimestamp = job_monitoring.func_run_log(v_ScriptName,v_RunID,v_LastTaskTimestamp,v_StartScriptTimestamp,v_StepName || '9','report_oibl.new_oibl_tripica','Update','Stop');
RAISE NOTICE E'\nScript finished: \nScript: % \nRun ID: %\n', v_ScriptName,v_RunID;

end $$;
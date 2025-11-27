set timezone = 'Europe/Berlin';
-- balance data
drop table if exists report_oibl.data_balances;
create table report_oibl.data_balances as
select
	 bab.ouid
	,bab.datetimelastmodif as datetimelastmodif  
	,coalesce(bas.mba,bac.name) as mba
	,bas.cba as cba
	,l.externalid as customer_id
	,(bab.datetimecreate at time zone 'Europe/Berlin')::date::date as datetimecreate
	,bab.transactionid
	,'PAYMENT_TRANSACTION' as glid
	,'BALANCE' as 	analyticaxis
	,bab.aggregateid
	,bab.accountingid
	,abs(bab.amount::numeric(20,2))/100 as taxincludedamount
	,bab.startdatetime::date as balance_date
	,coalesce(bac."characteristics"->>'migrationFlag', bas.migration_flag) as migration_flag
	--select *
from datalake_vault.billing_account_balance as bab
left join datalake_vault.billing_account as bac
	on bac.ouid = bab.billingaccountouid 
LEFT JOIN datalake_vault.login AS l
	ON l.customerouid = bac.customerouid
left join report_oibl.base_data_billing_accounts bas
	on bac.name = bas.cba
where bab.aggregateid is not null
and (bab.datetimecreate at time zone 'Europe/Berlin')::date > '2019-07-30'
; -- select * from 

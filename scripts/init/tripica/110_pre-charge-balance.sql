set timezone = 'Europe/Berlin';
-- delete first to prevent deadlocks
drop table if exists report_oibl.base_data_billing_accounts;
drop table if exists report_oibl.base_data_balance_date;
drop table if exists report_oibl.base_data_original_due_dates;
drop table if exists report_oibl.base_data_charge_specific_balance_date;
drop table if exists report_oibl.base_data_charge_specific_due_date;
drop table if exists report_oibl.base_data_migrated_bill_due_date;


-- pre charge data (always do this, also in incremental)
-- cba -> mba mapping
create table report_oibl.base_data_billing_accounts as
select mba."name" as mba, cba."name" as cba, mba."characteristics"->>'migrationFlag' as migration_flag
from datalake_vault.billing_account mba
join datalake_vault.billing_account_relationship bar 
	on bar.targetbillingaccountouid = mba.ouid
join datalake_vault.billing_account cba
	on bar.billingaccountouid = cba.ouid
-- where mba."name" = '30889198'
;
create index idx_base_data_billing_accounts on report_oibl.base_data_billing_accounts(cba);

/*
-- due dates (separate query as there are some duplicated payment requests per transaction)
drop table if exists report_oibl.base_data_due_date;
create table report_oibl.base_data_due_date as
select transactionid, least(max(daterequest), max(datelastchangestatus)) due_date
from datalake_vault.payment_request pr
--where transactionid like '30001795-20230812%'
group by transactionid
; -- select * from report_oibl.base_data_due_date
create index idx_base_data_due_date on report_oibl.base_data_due_date(transactionid);
*/

-- balance lettering dates for transactions with only one DUE% balance
create table report_oibl.base_data_balance_date as
select transactionid, coalesce(max((letteringdate AT TIME zone 'Europe/Berlin')::date), max(case when status in ('DUE_LETTERED', 'DUE_CANCELLED') then datetimelastmodif AT TIME zone 'Europe/Berlin' end))::date as balance_date, max(startdatetime::date) as due_date
from datalake_vault.billing_account_balance
where status like 'DUE%'
group by transactionid
;
create index idx_base_data_balance_date on report_oibl.base_data_balance_date(transactionid);

-- special case: charges that are the result of a payment rejection must have the same due date as the original charge
-- This is also the case for rejections of rejections. Basically, the original due date should be kept througout the rejection history
do $$
begin
	--original charges
	create table report_oibl.base_data_original_due_dates as
	select 'original' as src, abc.transactionid, coalesce(max(dd.due_date),max(abc.datetimecreate)) as due_date -- use payment due date, with the fallback of creation date
	from datalake_vault.applied_billing_charge abc
	left join report_oibl.base_data_balance_date dd
		on dd.transactionid = abc.transactionid
	where "characteristics"->>'rejectedChargeTransactionId' is null
	group by abc.transactionid
	;
	create index idx_base_data_original_due_dates on report_oibl.base_data_original_due_dates(transactionid);
	--reject charges
	drop table if exists reject_charges;
	create temp table reject_charges as
	select abc.transactionid, "characteristics"->>'rejectedChargeTransactionId' as original_transactionid
	from datalake_vault.applied_billing_charge abc
	where "characteristics"->>'rejectedChargeTransactionId' is not null
	group by abc.transactionid, "characteristics"->>'rejectedChargeTransactionId'
	;
	
	-- for loop, until all dependencies are resolved (max 5 times)
	for counter in 1..6 loop
		raise notice 'loop exec no %', counter;
		
		drop table if exists tobe_charges;
		create temp table tobe_charges as
		select reject.transactionid, original.due_date
		from reject_charges reject
		join report_oibl.base_data_original_due_dates original
			on original.transactionid = reject.original_transactionid
		;
		
		insert into report_oibl.base_data_original_due_dates(src, transactionid, due_date)
		select 'rejection' as src, transactionid, due_date
		from tobe_charges
		;
		
		delete from reject_charges r
		using tobe_charges t
		where r.transactionid = t.transactionid
		;
	
		-- exit early if everything was processed
		exit when (select count(*) from reject_charges) < 1;
	end loop;
	-- for loop end


	/*

	-- This script updates due dates for customer transactions in the `report_oibl.base_data_original_due_dates` table.
	-- It handles three specific cases: BCMC customer transactions, transactions with partiallyPaidChargeTransactionId, 
	-- and transactions with rejectedChargeTransactionId. Temporary tables are used to calculate and store intermediate results.

	-- Steps:
	-- 1. Update due dates for BCMC customer transactions:
	--    - BCMC transactions are identified by `glid` values containing '%MANUAL_CONSUMPTION' or '%_MANUAL_BILL'.
	--    - The due date is derived as the minimum `daterequest` from the `datalake_vault.payment_request` table.
	--    - Updates the `due_date` field in `report_oibl.base_data_original_due_dates` for matching transactions.
	--    - Logs the number of adjusted BCMC transactions.

	-- 2. Update due dates for transactions with partiallyPaidChargeTransactionId:
	--    - These transactions reference a parent transaction via the `partiallyPaidChargeTransactionId` characteristic.
	--    - The due date is updated to match the parent transaction's due date.
	--    - Logs the number of updated transactions.

	-- 3. Update due dates for transactions with rejectedChargeTransactionId:
	--    - These transactions reference a parent transaction via the `rejectedChargeTransactionId` characteristic.
	--    - The parent transaction's will be set as the new due date. The parent transaction's due date is updated in the previous step.
	--    - Logs the number of updated transactions.

	-- Temporary tables:
	-- - `tmp_bcmc_due_dates`: Stores BCMC transactions and their calculated due dates.
	-- - `tmp_partially_paid_due_dates`: Stores transactions with partiallyPaidChargeTransactionId and their parent due dates.
	-- - `tmp_rejected_due_dates`: Stores transactions with rejectedChargeTransactionId and their child due dates.

	-- Notes:
	-- - The script uses `raise notice` statements to log the number of transactions updated in each step.
	-- - Ensure that the required tables (`datalake_vault.applied_billing_charge`, `datalake_vault.payment_request`, 
	--   and `report_oibl.base_data_original_due_dates`) are available and properly populated before running this script.
	*/


	create temp table tmp_bcmc_due_dates as
	select 
		abc.transactionid,
		min(pr.daterequest::date) as bcmc_due_date
	from datalake_vault.applied_billing_charge abc
	join datalake_vault.payment_request pr
		on pr.transactionid = abc.transactionid
	where abc.glid like '%_MANUAL_CONSUMPTION'
	group by abc.transactionid;

    update report_oibl.base_data_original_due_dates bodd
    set due_date = bc.bcmc_due_date
    from tmp_bcmc_due_dates bc
    where bodd.transactionid = bc.transactionid;

    -- Step 1: Update due dates for transactions with partiallyPaidChargeTransactionId
    -- This sets the due date to the parent transaction's due date


    create temp table tmp_partially_paid_due_dates as
    select 
        abc.transactionid,
        parent_due.due_date::date as parent_due_date
    from datalake_vault.applied_billing_charge abc
    join report_oibl.base_data_original_due_dates parent_due
        on abc.characteristics ->> 'partiallyPaidChargeTransactionId' = parent_due.transactionid
    where abc.characteristics ->> 'partiallyPaidChargeTransactionId' is not null;
    
    update report_oibl.base_data_original_due_dates child_due
    set due_date = ppdd.parent_due_date
    from tmp_partially_paid_due_dates ppdd
    where child_due.transactionid = ppdd.transactionid;
    
        
    -- Step 2: Update due dates for transactions with rejectedChargeTransactionId
    -- This sets the due date to the parent transaction's due date which has been updated in the previous step
    create temp table tmp_rejected_due_dates as
    select 
        abc.transactionid,
        parent_due.due_date::date as parent_due_date
    from datalake_vault.applied_billing_charge abc
    join report_oibl.base_data_original_due_dates parent_due
        on abc.characteristics ->> 'rejectedChargeTransactionId' = parent_due.transactionid
    where abc.characteristics ->> 'rejectedChargeTransactionId' is not null;
    
    update report_oibl.base_data_original_due_dates parent_due
    set due_date = rdd.parent_due_date
    from tmp_rejected_due_dates rdd
    where parent_due.transactionid = rdd.transactionid;
    

	create index idx_base_data_original_due_dates_src on report_oibl.base_data_original_due_dates(src);
	
	--> overwrite cases where a rejection due date is available
	/*
	delete from report_oibl.base_data_due_date fallback
	using report_oibl.base_data_original_due_dates reject
	where reject.transactionid = fallback.transactionid
	and src != 'original' -- we only want to update rejection charges
	;
	insert into report_oibl.base_data_due_date
	select transactionid, due_date
	from  report_oibl.base_data_original_due_dates
	where src != 'original' -- we only want to update rejection charges
	;
	*/
	update report_oibl.base_data_balance_date bd
	set due_date = dd.due_date
	from report_oibl.base_data_original_due_dates dd
	where bd.transactionid = dd.transactionid
	;

end $$;




-- balance lettering dates for transactions with split balance statuses
create temp table tmp_double_balance as
select transactionid, count(distinct status), string_agg(distinct bab.status, ', ') 
from datalake_vault.billing_account_balance bab
where bab.status like 'DUE%'
group by 1
having count(distinct status) > 1
;
create index on tmp_double_balance(transactionid);

create table report_oibl.base_data_charge_specific_balance_date as
select distinct abc.ouid as charge_ouid, bab.status, bab.transactionid, coalesce((letteringdate AT TIME zone 'Europe/Berlin')::date, case when status in ('DUE_LETTERED', 'DUE_CANCELLED') then bab.datetimelastmodif AT TIME zone 'Europe/Berlin' end)::date as balance_date, bab.startdatetime::date as due_date
from datalake_vault.billing_account_balance bab
join tmp_double_balance db
	on db.transactionid = bab.transactionid
left join datalake_vault.applied_billing_charge abc
	on abc.transactionid = bab.transactionid
	and abc.taxincludedamount = bab.amount
	and abc.billingaccountouid = bab.billingaccountouid
where bab.status like 'DUE%'
;

create temp table tmp_partially_paid_charge_due_dates AS
select 
    abc.transactionid AS child_transaction_id,
    abc.characteristics ->> 'partiallyPaidChargeTransactionId' AS parent_transaction_id,
    bd.due_date AS parent_due_date
from datalake_vault.applied_billing_charge abc
join report_oibl.base_data_balance_date bd
    on abc.characteristics ->> 'partiallyPaidChargeTransactionId' = bd.transactionid
where abc.characteristics ->> 'partiallyPaidChargeTransactionId' is not null;

update report_oibl.base_data_charge_specific_balance_date csbd
set due_date = ppcd.parent_due_date
from tmp_partially_paid_charge_due_dates ppcd
where csbd.transactionid = ppcd.child_transaction_id;



-- balance date for MANUAL BONUS charges with REFUND charge created for it
drop table if exists tmp_manual_bonus_refund;
create temp table tmp_manual_bonus_refund as
select distinct transactionid, taxincludedamount, datetimecreate, billingaccountouid
from datalake_vault.applied_billing_charge abc
where glid like '%_MANUAL_BONUS_REFUND'
and coalesce(accountingid,'') != 'ignored'
;
create index on tmp_manual_bonus_refund(transactionid, taxincludedamount, billingaccountouid);
insert into report_oibl.base_data_charge_specific_balance_date
select abc.ouid as charge_ouid, '' as status, abc.transactionid, (mbf.datetimecreate AT TIME zone 'Europe/Berlin')::date as balance_date, (abc.datetimecreate AT TIME zone 'Europe/Berlin')::date as due_date
from datalake_vault.applied_billing_charge abc
join tmp_manual_bonus_refund mbf
	on mbf.billingaccountouid = abc.billingaccountouid
	and mbf.transactionid = abc.transactionid
	and mbf.taxincludedamount = abc.taxincludedamount
where glid like '%_MANUAL_BONUS'
and coalesce(accountingid,'') != 'ignored'
;
create index on report_oibl.base_data_charge_specific_balance_date(charge_ouid);

create table report_oibl.base_data_charge_specific_due_date as
select abc.ouid as charge_ouid, transactionid, max(coalesce(sna.paymentduedate::date, sna.datetimecreate::date)) as due_date
from datalake_vault.applied_billing_charge abc
join datalake_vault.settlement_note_advice sna
	on sna.ouid = abc.settlementnoteadviceouid
where (glid like '%_BILL' or glid like '%_BILL_MIGRATION')
group by abc.ouid, transactionid
;
insert into report_oibl.base_data_charge_specific_due_date
select abc.ouid, abc.transactionid, (abc.datetimecreate AT TIME zone 'Europe/Berlin')::date as due_date
from datalake_vault.applied_billing_charge abc
where abc.glid like '%_MANUAL_BONUS'
and abc.analyticaxis not like '%special%'
;
create index on report_oibl.base_data_charge_specific_due_date(charge_ouid);

create table report_oibl.base_data_migrated_bill_due_date as
select distinct on(transactionid) transactionid, (daterequest AT TIME zone 'Europe/Berlin')::date as due_date
from datalake_vault.payment_request pr
where bpmeventname = 'migrated'
order by transactionid, datetimelastmodif
;
create index on report_oibl.base_data_migrated_bill_due_date(transactionid);

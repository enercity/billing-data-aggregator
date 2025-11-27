DO $$
declare
	data_charges_exists boolean := false;
begin
	-- drop table if exists report_boil.data_charges
	select exists (
		select 1, *
		from information_schema.tables
		WHERE 1=1 
			and table_schema LIKE 'report_boil' 
	        and table_name = 'data_charges'
	) into data_charges_exists;
	
	-- create only if not extists
	IF NOT data_charges_exists THEN
		
		drop table if exists report_boil.base_data_charges;
		create table report_boil.base_data_charges as
		select 
			abc.ouid as applied_billing_charge_ouid
			,bac.ouid as billing_account_ouid
			,l.ouid as login_ouid
			,abc.datetimelastmodif as datetimelastmodif
			,bac.name as billing_account
			,l.externalid as customer_id
			,(abc.datetimecreate at time zone 'Europe/Berlin')::date as datetimecreate
			,abc.transactionid
			,abc.glid
			,abc.analyticaxis
			,abc.aggregateid
			,abc.accountingid
			,abs(abc.taxexcludedamount::numeric(20,2))/100 as taxexcludedamount
			,abs(abc.taxincludedamount::numeric(20,2))/100 as taxincludedamount
			,coalesce(pr.daterequest,abc.datetimecreate)::date as due_date
			,sna.id as bill_id
		from datalake_vault.applied_billing_charge abc
		left join datalake_vault.billing_account as bac
			on bac.ouid = abc.billingaccountouid
		LEFT JOIN datalake_vault.login AS l 
			ON l.customerouid = bac.customerouid
		left join datalake_vault.payment_request pr
			on pr.transactionid = abc.transactionid
		left join datalake_vault.settlement_note_advice sna
			on sna.ouid = abc.settlementnoteadviceouid
		where (abc.datetimecreate at time zone 'Europe/Berlin')::date > '2019-07-30';
		create index idx_base_data_charges_ouid on report_boil.base_data_charges(applied_billing_charge_ouid);
	
		drop table if exists report_boil.base_data_taxes;
		create table report_boil.base_data_taxes as
		select 
			 appliedbillingchargeouid 
			,sum(((case when taxcategory in ('VAT') then abs(amount::numeric(20,2))/100 end ))) as taxamount
			,sum(((case when taxcategory in ('gasTax','electricityTax') then abs(amount::numeric(20,2))/100  end ))) as energytaxamount
		from datalake_vault.applied_billing_tax_rate 
		where taxcategory in ('gasTax','electricityTax','VAT')  
		group by 1
		;
	
		drop table if exists report_boil.data_charges;
		create table report_boil.data_charges as
		select *
		from report_boil.base_data_charges c
		left join report_boil.base_data_taxes t
			on c.applied_billing_charge_ouid = t.appliedbillingchargeouid
		;
		create index idx_data_charges_applied_billing_charge_ouid on report_boil.data_charges(applied_billing_charge_ouid);
		create index idx_data_charges_aggregateid on report_boil.data_charges(aggregateid);
	
	-- select * from report_boil.data_charges
	
	end if;

end $$;

/***
 * create table for incremental load. Append charge ouids which should be loaded incrementally
 */
drop table if exists report_boil.inc_applied_billing_charge_ouid;
create table if not exists report_boil.inc_applied_billing_charge_ouid (ouid int8 /*primary key*/);


/***
 * applied billing charge load -> 2m 30s
 */
DO $$
declare
	hash_applied_billing_charge_exists boolean := false;
begin
	
	select exists (
		select 1, *
		from information_schema.tables
		WHERE 1=1 and table_schema LIKE 'report_boil' 
	        and table_name = 'hash_applied_billing_charge'
	) into hash_applied_billing_charge_exists;
	
	-- create only if not extists
	IF NOT hash_applied_billing_charge_exists THEN -- table does not exist -> full load
	
		-- full load took 3m 30s on prod
		-- drop table if exists hash_applied_billing_charge
		create table if not exists hash_applied_billing_charge as
		select md5(concat(abc.datetimelastmodif::text, abc.aggregateid)) as hash, ouid
		from datalake_vault.applied_billing_charge abc
		; -- select * from hash_applied_billing_charge
		
		/*
		insert into inc_applied_billing_charge_ouid
		select ouid
		from hash_applied_billing_charge
		-- on conflict do nothing
		;
		*/
	
	ELSE  -- incremental load 
		
		------ snip ----
		--delete from hash_applied_billing_charge where ouid > (select max(ouid) - 10 from hash_applied_billing_charge);
		--update hash_applied_billing_charge set hash = '1234' where ouid > (select max(ouid) - 10 from hash_applied_billing_charge);
		------ snip ----
		
		drop table if exists inc_hash_applied_billing_charge;
		create table inc_hash_applied_billing_charge as
		select md5(concat(abc.datetimelastmodif::text, abc.aggregateid)) as hash, ouid
		from datalake_vault.applied_billing_charge abc
		; -- select * from tmp_hash_applied_billing_charge
		
		insert into inc_applied_billing_charge_ouid
		select ouid
		from (
			select ouid, hash
			from inc_hash_applied_billing_charge
			except all
			select ouid, hash
			from hash_applied_billing_charge
		) inc
		-- on conflict do nothing
		; -- select * from report_boil.inc_applied_billing_charge_ouid
		
		delete from hash_applied_billing_charge h
		using inc_applied_billing_charge_ouid tmp
		where h.ouid = tmp.ouid
		;
		
		insert into hash_applied_billing_charge
		select tmp.*
		from inc_applied_billing_charge_ouid inc
		join inc_hash_applied_billing_charge tmp
			on inc.ouid = tmp.ouid
		;
	
	END IF;

end $$;

/***
 * billing account load -> 21s
 */
DO $$
declare
	lastmodif_billing_account_exists boolean := false;
begin
	
	select exists (
		select 1
		from information_schema.tables
		WHERE 1=1
			and table_schema LIKE 'report_boil' 
	        and table_name = 'lastmodif_billing_account'
	) into lastmodif_billing_account_exists;
	
	-- create only if not extists
	IF NOT lastmodif_billing_account_exists THEN -- table does not exist -> full load
	
		-- drop table if exists lastmodif_billing_account
		create table if not exists report_boil.lastmodif_billing_account as
		select datetimelastmodif, ouid
		from datalake_vault.billing_account
		; -- select * from hash_billing_account
		
		/*
		insert into inc_applied_billing_charge_ouid
		select abc.ouid
		from datalake_vault.applied_billing_charge abc
		join lastmodif_billing_account ba
			on ba.ouid = abc.billingaccountouid
		on conflict do nothing
		;
		*/
	
	ELSE  -- incremental load 
		
		------ snip ----
		--delete from lastmodif_billing_account where datetimelastmodif::date = '2022-08-08';
		--update lastmodif_billing_account set datetimelastmodif = '2022-01-01' where datetimelastmodif::date = '2022-11-04';
		------ snip ----
		
		drop table if exists report_boil.inc_lastmodif_billing_account;
		create table report_boil.inc_lastmodif_billing_account as
		select datetimelastmodif, ouid
		from datalake_vault.billing_account abc
		; -- select * from tmp_lastmodif_billing_account
		
		drop table if exists report_boil.inc_billing_account_ouid;
		create table report_boil.inc_billing_account_ouid as
		select ouid, datetimelastmodif
		from report_boil.inc_lastmodif_billing_account
		where datetimelastmodif > (select max(datetimelastmodif) from lastmodif_billing_account)
		; -- select * from inc_billing_account_ouid
		
		insert into report_boil.inc_applied_billing_charge_ouid
		select abc.ouid
		from report_boil.inc_billing_account_ouid inc
		join datalake_vault.applied_billing_charge abc
			on inc.ouid = abc.billingaccountouid
		on conflict do nothing
		; -- select * from inc_applied_billing_charge_ouid
		
		delete from report_boil.inc_lastmodif_billing_account h
		using report_boil.inc_billing_account_ouid tmp
		where h.ouid = tmp.ouid
		;
		
		insert into report_boil.inc_lastmodif_billing_account
		select tmp.*
		from report_boil.inc_billing_account_ouid inc
		join report_boil.inc_lastmodif_billing_account tmp
			on inc.ouid = tmp.ouid
		;
	
	END IF;

end $$;

/***
 * login load -> 15s
 */
DO $$
declare
	hash_login_exists boolean := false;
begin
	
	select exists (
		select 1, *
		from information_schema.tables
		WHERE 1=1 
			and table_schema LIKE 'report_boil' 
	        and table_name = 'hash_login'
	) into hash_login_exists;
	
	-- create only if not extists
	IF NOT hash_login_exists THEN -- table does not exist -> full load
	
		-- drop table if exists hash_login
		create table if not exists report_boil.hash_login as
		select md5(externalid::text) as hash, ouid, customerouid
		from datalake_vault.login
		where customerouid > 0
		; -- select * from hash_login
		
		/*
		insert into inc_applied_billing_charge_ouid
		select abc.ouid
		from datalake_vault.applied_billing_charge abc
		join hash_login l
			on l.customerouid = abc.customerouid
		-- on conflict do nothing
		;
		*/
	
	ELSE  -- incremental load 
		
		------ snip ----
		--delete from hash_login where ouid > (select max(ouid) - 10000 from hash_login);
		--update hash_login set hash = '1234' where ouid > (select max(ouid) - 10000 from hash_login);
		------ snip ----
		
		drop table if exists report_boil.inc_hash_login;
		create table report_boil.inc_hash_login as
		select  md5(externalid::text) as hash, ouid, customerouid
		from datalake_vault.login
		where customerouid > 0
		; -- select * from tmp_hash_login
		
		drop table if exists report_boil.inc_login_ouid;
		create table report_boil.inc_login_ouid as
		select ouid, hash, customerouid
		from report_boil.inc_hash_login
		except all
		select ouid, hash, customerouid
		from report_boil.hash_login
		; -- select * from inc_login_ouid
		
		insert into report_boil.inc_applied_billing_charge_ouid
		select abc.ouid
		from report_boil.inc_login_ouid inc
		join datalake_vault.applied_billing_charge abc
			on inc.ouid = abc.billingaccountouid
		-- on conflict do nothing
		; -- select * from inc_applied_billing_charge_ouid
		
		delete from report_boil.hash_login h
		using report_boil.inc_login_ouid tmp
		where h.ouid = tmp.ouid
		;
		
		insert into report_boil.hash_login
		select tmp.*
		from report_boil.inc_login_ouid inc
		join report_boil.inc_hash_login tmp
			on inc.ouid = tmp.ouid
		;
	
		-- select count(*) from hash_login
	
	END IF;

end $$;

/***
 * tax load -> 3m 14s
 */
DO $$
declare
	lastmodif_applied_billing_tax_rate_exists boolean := false;
begin
	
	select exists (
		select 1, *
		from information_schema.tables
		WHERE 1=1 
			and table_schema LIKE 'report_boil'
	        and table_name = 'lastmodif_applied_billing_tax_rate'
	) into lastmodif_applied_billing_tax_rate_exists;
	
	-- create only if not extists
	IF NOT lastmodif_applied_billing_tax_rate_exists THEN -- table does not exist -> full load
	
		-- drop table if exists lastmodif_applied_billing_tax_rate
		create table if not exists report_boil.lastmodif_applied_billing_tax_rate as
		select datetimelastmodif, ouid, appliedbillingchargeouid
		from datalake_vault.applied_billing_tax_rate tax
		where taxcategory in ('VAT','electricityTax','gasTax')
		; -- select * from lastmodif_applied_billing_tax_rate
		--create index idx_tmp_lastmodif_applied_billing_tax_rate_ouid on tmp_lastmodif_applied_billing_tax_rate(datetimelastmodif);
	
		/*
		insert into report_boil.inc_applied_billing_charge_ouid
		select tax.appliedbillingchargeouid as ouid
		from lastmodif_applied_billing_tax_rate tax
		-- on conflict do nothing
		; -- select * from inc_applied_billing_charge_ouid
		*/
	
	ELSE  -- incremental load 
		
		------ snip ----
		delete from report_boil.lastmodif_applied_billing_tax_rate where datetimelastmodif > '2022-11-22';
		update report_boil.lastmodif_applied_billing_tax_rate set datetimelastmodif = '2022-01-01' where datetimelastmodif > '2022-11-21';
		------ snip ----
		
		drop table if exists report_boil.inc_lastmodif_applied_billing_tax_rate;
		create table if not exists report_boil.inc_lastmodif_applied_billing_tax_rate as
		select datetimelastmodif, ouid, appliedbillingchargeouid
		from datalake_vault.applied_billing_tax_rate tax
		where taxcategory in ('VAT','electricityTax','gasTax')
		; -- select * from report_boil.inc_lastmodif_applied_billing_tax_rate -- 18s
		create index idx_inc_lastmodif_applied_billing_tax_rate_datetimelastmodif on report_boil.inc_lastmodif_applied_billing_tax_rate(datetimelastmodif); -- 12s
		
		drop table if exists report_boil.inc_applied_billing_tax_rate_ouid;
		create table report_boil.inc_applied_billing_tax_rate_ouid as
		select ouid, datetimelastmodif, appliedbillingchargeouid
		from report_boil.inc_lastmodif_applied_billing_tax_rate
		where datetimelastmodif > (select max(datetimelastmodif) from report_boil.lastmodif_applied_billing_tax_rate) 
		; -- select * from inc_applied_billing_tax_rate_ouid -- 9s
		
		insert into report_boil.inc_applied_billing_charge_ouid
		select inc.appliedbillingchargeouid as ouid
		from report_boil.inc_applied_billing_tax_rate_ouid inc
		-- on conflict do nothing
		; -- select * from inc_applied_billing_charge_ouid
		
		delete from report_boil.lastmodif_applied_billing_tax_rate h
		using report_boil.inc_applied_billing_tax_rate_ouid tmp
		where h.ouid = tmp.ouid
		;
		
		insert into report_boil.lastmodif_applied_billing_tax_rate
		select tmp.*
		from report_boil.inc_applied_billing_tax_rate_ouid inc
		join report_boil.inc_lastmodif_applied_billing_tax_rate tmp
			on inc.ouid = tmp.ouid
		;
	
		-- select count(*) from report_boil.lastmodif_applied_billing_tax_rate
	
	END IF;

end $$;


drop table if exists report_boil.inc_data_charges;
create table report_boil.inc_data_charges as
select 
	abc.ouid as applied_billing_charge_ouid
	,bac.ouid as billing_account_ouid
	,l.ouid as login_ouid
	,abc.datetimelastmodif as datetimelastmodif
	,bac.name as billing_account
	,l.externalid as customer_id
	,(abc.datetimecreate at time zone 'Europe/Berlin')::date as datetimecreate
	,abc.transactionid
	,abc.glid
	,abc.analyticaxis
	,abc.aggregateid
	,abc.accountingid
	,abs(abc.taxexcludedamount::numeric(20,2))/100 as taxexcludedamount
	,abs(abc.taxincludedamount::numeric(20,2))/100 as taxincludedamount
	,coalesce(pr.daterequest,abc.datetimecreate)::date as due_date
	,sna.id as bill_id
from (
	select distinct ouid
	from report_boil.inc_applied_billing_charge_ouid
) inc
join datalake_vault.applied_billing_charge abc
	on inc.ouid = abc.ouid
left join datalake_vault.billing_account as bac
	on bac.ouid = abc.billingaccountouid
left join datalake_vault.payment_request pr
	on pr.transactionid = abc.transactionid
LEFT JOIN datalake_vault.login AS l 
	ON l.customerouid = bac.customerouid
left join datalake_vault.settlement_note_advice sna
	on sna.ouid = abc.settlementnoteadviceouid
; -- select * from report_boil.inc_data_charges

drop table if exists report_boil.inc_data_taxes;
create table report_boil.inc_data_taxes as
select 
	 appliedbillingchargeouid 
	,sum(((case when taxcategory in ('VAT') then abs(amount::numeric(20,2))/100 end ))) as taxamount
	,sum(((case when taxcategory in ('gasTax','electricityTax') then abs(amount::numeric(20,2))/100  end ))) as energytaxamount
from (
	select distinct ouid
	from report_boil.inc_applied_billing_charge_ouid
) inc
join datalake_vault.applied_billing_tax_rate tax
	on tax.appliedbillingchargeouid = inc.ouid
where taxcategory in ('gasTax','electricityTax','VAT')  
group by 1
; -- select * from report_boil.inc_data_taxes

-- delete old lines
delete from report_boil.data_charges c
using (
	select distinct ouid
	from report_boil.inc_applied_billing_charge_ouid
) inc
where c.applied_billing_charge_ouid = inc.ouid
;

-- insert updated/ new lines
insert into report_boil.data_charges
select *
from report_boil.inc_data_charges c
left join report_boil.inc_data_taxes t
	on c.applied_billing_charge_ouid = t.appliedbillingchargeouid
; -- select * from report_boil.data_charges dc

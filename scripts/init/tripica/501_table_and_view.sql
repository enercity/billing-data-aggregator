set timezone = 'Europe/Berlin';

drop table if exists report_oibl.oibl_tripica cascade;
alter table report_oibl.new_oibl_tripica rename to oibl_tripica;

-- create view with a limited column set
create or replace view report_oibl.oibl_customer as
select
	cba,
	mba,
	customer_id,
	date_created,
	transaction_id,
	glid,
	analyticaxis,
	bill_id,
	due_date,
	balance_date,
	write_off_date,
	write_off_reason,
	write_off_note,
	dunning_lock_until,
	dunning_lock_reason,
	dunning_scenario,
	dunning_level,
	amount_net,
	amount_gross,
	amount_vat,
	amount_energy_tax,
	aggregate_id,
	accounting_id,
	booking_created_at,
	booking_date,
	booking_order_number,
	booking_tax_code,
	booking_mainledger_account,
	booking_reference_document_number,
	booking_debit_amount,
	booking_credit_amount,
	booking_amount_indicator,
	migration_flag
from report_oibl.oibl_tripica
;
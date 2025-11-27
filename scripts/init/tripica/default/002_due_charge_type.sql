-- we assume that charges are due if they have the aggregation key T_PAYMENT which is currently a global config (not client specific)
-- These defintions can be found here: https://github.com/enercity/bookings-lambdas/tree/develop/apps/tripica-charges-converter/tools/mapping_row_generator (aggregation_key_v1.csv or newer versions)
-- There might be some differences in whether the aggregate is actually used
insert into report_oibl.client_data_due_charge_type (glid) values
	('BANK_FEE'),
	--('BANK_FEE_MIGRATION'),
	-- ('BANK_FEE_REJECTED'),
	-- ('BANK_FEE_RETURN'),
	('DUNNING_FEE'),
	--('DUNNING_FEE_MIGRATION'),
	-- ('DUNNING_FEE_REJECTED'),
	('%_ABSCHLAG'),
	-- ('%_ABSCHLAG_REJECTED'),
	('%_BILL'),
	('%_BILL_MIGRATION'),
	-- ('%_BILL_REJECTED'),
	('%_CANCELLATION_BALANCE'),
	-- ('%_CANCELLATION_BALANCE_REJECTED'),
	('%_MANUAL_BILL'),
	-- ('%_MANUAL_BILL_REJECTED'),
	-- ('%_MANUAL_BONUS_REFUND'),
	-- ('%_MANUAL_BONUS_REFUND_REJECTED'),
	('%_MANUAL_BONUS'),
	('EPILOT_%_LEASE_PAY'),
	-- ('EPILOT_%_LEASE_PAY_REJECTED'),
	('EPILOT_%_SERVICE_PAY'),
	-- ('EPILOT_%_SERVICE_PAY_REJECTED'),
	('EPILOT_%_UNIT_PAY'),
	-- ('EPILOT_%_UNIT_PAY_REJECTED'),
	('OVERPAYMENT_CREDIT'),
	-- ('OVERPAYMENT_CREDIT_REJECTED'),
	('OVERPAYMENT_REFUND'),
	-- ('OVERPAYMENT_REFUND_REJECTED'),
	('OVERPAYMENT_USED'),
	-- ('PAYMENT_TRANSACTION'),
	('METER_BLOCKING_%_FEE'),
	('METER_BLOCKING_LETTER'),
	('METER_UNBLOCKING_%_FEE'),
	-- ('METER_BLOCKING_%_FEE_REJECTED'),
	-- ('METER_UNBLOCKING_%_FEE_REJECTED'),
	-- ('METER_BLOCKING_LETTER_REJECTED'),
	('%_CANCELLATION_BALANCE_WRITE_OFF')
;
/*
insert into report_oibl.client_data_due_charge_type (glid, analyticaxis) values
	('%_BILL_CANCEL', '%credit%')
;
*/
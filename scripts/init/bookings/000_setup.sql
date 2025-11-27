/*
 * Create the schema if it doesn't already exists
 */
create schema if not exists report_oibl; -- create new schema if not exists. Older versions of the OIBL were stored to the report_boil schema

/* Setup mwskz mapping table. This must be set for every client individually, based on what account the tax booking will be made. For now new need to include this translation in this report as it is decided by e.g. SAP Core during import of the bookings data and is therefore not available in the bookings data.
 */
drop table if exists report_oibl.client_data_vat_booking_accounts;
create table report_oibl.client_data_vat_booking_accounts(
	mwskz varchar(2) primary key,
	account varchar(20)
);

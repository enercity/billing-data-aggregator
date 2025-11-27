/*
 * Create the schema if it doesn't already exists
 */
create schema if not exists report_oibl; -- create new schema if not exists. Older versions of the OIBL were stored to the report_boil schema


/*
 * Setup table to look up charges which can be "open items" by definition. As this is client specific, this only adds the table and client data needs to be inserted via a client specific script.
 */
drop table if exists report_oibl.client_data_due_charge_type;
create table report_oibl.client_data_due_charge_type (
	glid varchar(255),
	analyticaxis varchar(255) default '%',
	PRIMARY KEY (glid, analyticaxis)
);

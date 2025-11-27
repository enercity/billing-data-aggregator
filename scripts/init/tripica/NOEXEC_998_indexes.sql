set timezone = 'Europe/Berlin';

-- create indexes
create index if not exists idx_oibl_tripica_cba on report_oibl.oibl_tripica(cba);
create index if not exists idx_oibl_tripica_mba on report_oibl.oibl_tripica(mba);
create index if not exists idx_oibl_tripica_customer_id on report_oibl.oibl_tripica(customer_id);
create index if not exists idx_oibl_tripica_transaction_id on report_oibl.oibl_tripica(transaction_id);
create index if not exists idx_oibl_tripica_aggregate_id on report_oibl.oibl_tripica(aggregate_id);
create index if not exists idx_oibl_tripica_booking_mainledger_account on report_oibl.oibl_tripica(booking_mainledger_account);
create index if not exists idx_oibl_tripica_booking_reference_document_number on report_oibl.oibl_tripica(booking_reference_document_number);

-- insert mwskz mappings into respective table, but clear contents first
truncate report_oibl.client_data_vat_booking_accounts;
insert into report_oibl.client_data_vat_booking_accounts values
('11', '76100030'),
('1A', '76100030'),
('21', '76100030'),
('2A', '76100030'),
('12', '76100101'),
('1B', '76100101'),
('22', '76100100'),
('2B', '76100100'),
('59', '76110005'),
('5W', '76110005'),
('69', '76110005'),
('6W', '76110005'),
('51', '76110030'),
('5A', '76110030'),
('61', '76110030'),
('6A', '76110030'),
('62', '76110030'),
('6B', '76110030'),
('81', 'RC'),
('8A', 'RC')
;
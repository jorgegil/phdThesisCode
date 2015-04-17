--DROP TABLE analysis.mobility_patterns_pcode_diff CASCADE;
CREATE TABLE analysis.mobility_patterns_pcode_diff AS SELECT * FROM survey.mobility_patterns_pcode;
SELECT column_name, ordinal_position FROM INFORMATION_SCHEMA.columns WHERE table_name = 'mobility_patterns_pcode_diff' ORDER BY ordinal_position;
SELECT _phd_updatecolumns('analysis','mobility_patterns_pcode_diff', 12, 87, 'foo.', '-bb.', ' FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''origins randstad''');

--DROP TABLE analysis.mobility_patterns_pcode_pcchange CASCADE;
CREATE TABLE analysis.mobility_patterns_pcode_pcchange AS SELECT * FROM analysis.mobility_patterns_pcode_diff;
SELECT _phd_updatecolumns('analysis','mobility_patterns_pcode_pcchange', 12, 87, 'round(((foo.', '/bb.', ')*100.00)::numeric,2) FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''origins randstad''');

UPDATE analysis.mobility_patterns_pcode_pcchange SET car=car*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET motorised=motorised*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET short_car=short_car*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET medium_car=medium_car*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET far_car=far_car*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET car_dist=car_dist*(-1);
UPDATE analysis.mobility_patterns_pcode_pcchange SET inter_urban=inter_urban*(-1);
SELECT _phd_updatecolumns('analysis','mobility_patterns_pcode_pcchange', 42, 45, ' ', NULL, '*(-1)');
SELECT _phd_updatecolumns('analysis','mobility_patterns_pcode_pcchange', 51, 87, ' ', NULL, '*(-1)');


--DROP TABLE analysis.mobility_patterns_custom_diff CASCADE;
CREATE TABLE analysis.mobility_patterns_custom_diff AS SELECT * FROM survey.mobility_patterns_custom;
SELECT column_name, ordinal_position FROM INFORMATION_SCHEMA.columns WHERE table_name = 'mobility_patterns_custom_diff' ORDER BY ordinal_position;
SELECT _phd_updatecolumns('analysis','mobility_patterns_custom_diff', 12, 87, 'foo.', '-bb.', ' FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''custom randstad''');

--DROP TABLE analysis.mobility_patterns_custom_pcchange CASCADE;
CREATE TABLE analysis.mobility_patterns_custom_pcchange AS SELECT * FROM analysis.mobility_patterns_custom_diff;
SELECT _phd_updatecolumns('analysis','mobility_patterns_custom_pcchange', 12, 87, 'round(((foo.', '/bb.', ')*100.00)::numeric,2) FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''custom randstad''');

UPDATE analysis.mobility_patterns_custom_pcchange SET car=car*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET motorised=motorised*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET short_car=short_car*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET medium_car=medium_car*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET far_car=far_car*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET car_dist=car_dist*(-1);
UPDATE analysis.mobility_patterns_custom_pcchange SET inter_urban=inter_urban*(-1);
SELECT _phd_updatecolumns('analysis','mobility_patterns_custom_pcchange', 42, 45, ' ', NULL, '*(-1)');
SELECT _phd_updatecolumns('analysis','mobility_patterns_custom_pcchange', 51, 87, ' ', NULL, '*(-1)');


--DROP TABLE analysis.mobility_patterns_home_diff CASCADE;
CREATE TABLE analysis.mobility_patterns_home_diff AS SELECT * FROM survey.mobility_patterns_home;
SELECT column_name, ordinal_position FROM INFORMATION_SCHEMA.columns WHERE table_name = 'mobility_patterns_home_diff' ORDER BY ordinal_position;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_diff', 12, 87, 'foo.', '-bb.', ' FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home randstad''');

--DROP TABLE analysis.mobility_patterns_home_pcchange CASCADE;
CREATE TABLE analysis.mobility_patterns_home_pcchange AS SELECT * FROM analysis.mobility_patterns_home_diff;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_pcchange', 12, 87, 'round(((foo.', '/bb.', ')*100.00)::numeric,2) FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home randstad''');

UPDATE analysis.mobility_patterns_home_pcchange SET car=car*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET motorised=motorised*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET short_car=short_car*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET medium_car=medium_car*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET far_car=far_car*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET car_dist=car_dist*(-1);
UPDATE analysis.mobility_patterns_home_pcchange SET inter_urban=inter_urban*(-1);
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_pcchange', 42, 45, ' ', NULL, '*(-1)');
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_pcchange', 51, 87, ' ', NULL, '*(-1)');


--DROP TABLE analysis.mobility_patterns_home_od_diff CASCADE;
CREATE TABLE analysis.mobility_patterns_home_od_diff AS SELECT * FROM survey.mobility_patterns_home_od;
SELECT column_name, ordinal_position FROM INFORMATION_SCHEMA.columns WHERE table_name = 'mobility_patterns_home_od_diff' ORDER BY ordinal_position;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_diff', 12, 87, 'foo.', '-bb.', ' FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home od randstad''');

--DROP TABLE analysis.mobility_patterns_home_od_pcchange CASCADE;
CREATE TABLE analysis.mobility_patterns_home_od_pcchange AS SELECT * FROM analysis.mobility_patterns_home_od_diff;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_pcchange', 12, 87, 'round(((foo.', '/bb.', ')*100.00)::numeric,2) FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home od randstad''');

UPDATE analysis.mobility_patterns_home_od_pcchange SET car=car*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET motorised=motorised*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET short_car=short_car*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET medium_car=medium_car*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET far_car=far_car*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET car_dist=car_dist*(-1);
UPDATE analysis.mobility_patterns_home_od_pcchange SET inter_urban=inter_urban*(-1);
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_pcchange', 42, 45, ' ', NULL, '*(-1)');
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_pcchange', 51, 87, ' ', NULL, '*(-1)');


--DROP TABLE analysis.mobility_patterns_home_od_transit_diff CASCADE;
CREATE TABLE analysis.mobility_patterns_home_od_transit_diff AS SELECT * FROM survey.mobility_patterns_home_od_transit_diff WHERE transit IS NOT NULL AND transit > 0;
SELECT column_name, ordinal_position FROM INFORMATION_SCHEMA.columns WHERE table_name = 'mobility_patterns_home_od_diff' ORDER BY ordinal_position;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_transit_diff', 12, 87, 'foo.', '-bb.', ' FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home od randstad transit''');

--DROP TABLE analysis.mobility_patterns_home_od_transit_pcchange CASCADE;
CREATE TABLE analysis.mobility_patterns_home_od_transit_pcchange AS SELECT * FROM analysis.mobility_patterns_home_od_transit_diff;
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_transit_pcchange', 12, 87, 'round(((foo.', '/bb.', ')*100.00)::numeric,2) FROM analysis.mobility_patterns_stats as bb WHERE bb.measure=''home od randstad transit''');

UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET car=car*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET motorised=motorised*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET short_car=short_car*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET medium_car=medium_car*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET far_car=far_car*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET car_dist=car_dist*(-1);
UPDATE analysis.mobility_patterns_home_od_transit_pcchange SET inter_urban=inter_urban*(-1);
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_transit_pcchange', 42, 45, ' ', NULL, '*(-1)');
SELECT _phd_updatecolumns('analysis','mobility_patterns_home_od_transit_pcchange', 51, 87, ' ', NULL, '*(-1)');

-- Calculate descriptive stats for sustainable mobility indicators - pcode, home, home OD
DROP TABLE analysis.mobility_patterns CASCADE;

CREATE TABLE analysis.mobility_patterns (LIKE survey.mobility_patterns_pcode);
ALTER TABLE analysis.mobility_patterns RENAME pcode TO measure;
ALTER TABLE analysis.mobility_patterns DROP COLUMN sid;
ALTER TABLE analysis.mobility_patterns DROP COLUMN the_geom;
ALTER TABLE analysis.mobility_patterns DROP COLUMN the_boundary;

-- pcode
DROP TABLE temp_mobility_patterns CASCADE;
CREATE TEMP TABLE temp_mobility_patterns AS SELECT * FROM survey.mobility_patterns_pcode WHERE journeys >= 60;

INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode maximum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.max FROM (SELECT max(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode maximum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode minimum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.min FROM (SELECT min(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode minimum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode mean');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.avg FROM (SELECT avg(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode mean''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode standard dev');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.stddev_samp FROM (SELECT stddev_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode standard dev''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode variance');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.var_samp FROM (SELECT var_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode variance''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode range');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.range FROM (SELECT range(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode range''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('pcode median');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.median FROM (SELECT median(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''pcode median''');

-- custom
DROP TABLE temp_mobility_patterns CASCADE;
CREATE TEMP TABLE temp_mobility_patterns AS SELECT * FROM survey.mobility_patterns_custom WHERE journeys >= 60;

INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom maximum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.max FROM (SELECT max(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom maximum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom minimum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.min FROM (SELECT min(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom minimum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom mean');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.avg FROM (SELECT avg(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom mean''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom standard dev');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.stddev_samp FROM (SELECT stddev_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom standard dev''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom variance');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.var_samp FROM (SELECT var_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom variance''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom range');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.range FROM (SELECT range(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom range''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('custom median');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.median FROM (SELECT median(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''custom median''');

-- home
DROP TABLE temp_mobility_patterns CASCADE;
CREATE TEMP TABLE temp_mobility_patterns AS SELECT * FROM survey.mobility_patterns_home WHERE journeys >= 60;

INSERT INTO analysis.mobility_patterns (measure) VALUES ('home maximum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.max FROM (SELECT max(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home maximum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home minimum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.min FROM (SELECT min(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home minimum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home mean');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.avg FROM (SELECT avg(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home mean''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home standard dev');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.stddev_samp FROM (SELECT stddev_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home standard dev''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home variance');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.var_samp FROM (SELECT var_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home variance''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home range');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.range FROM (SELECT range(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home range''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home median');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.median FROM (SELECT median(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home median''');

-- home od
DROP TABLE temp_mobility_patterns CASCADE;
CREATE TEMP TABLE temp_mobility_patterns AS SELECT * FROM survey.mobility_patterns_home_od WHERE journeys >= 60;

INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od maximum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.max FROM (SELECT max(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od maximum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od minimum');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.min FROM (SELECT min(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od minimum''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od mean');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.avg FROM (SELECT avg(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od mean''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od standard dev');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.stddev_samp FROM (SELECT stddev_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od standard dev''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od variance');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.var_samp FROM (SELECT var_samp(', NULL, ') FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od variance''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od range');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.range FROM (SELECT range(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od range''');
INSERT INTO analysis.mobility_patterns (measure) VALUES ('home od median');
SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, 'pcode.median FROM (SELECT median(', NULL, '::numeric) FROM temp_mobility_patterns) as pcode WHERE foo.measure=''home od median''');


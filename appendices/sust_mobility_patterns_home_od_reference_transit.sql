-- CREATE TABLE analysis.mobility_patterns_stats (LIKE survey.mobility_patterns_pcode);
-- ALTER TABLE analysis.mobility_patterns_stats RENAME pcode TO measure;
INSERT INTO analysis.mobility_patterns_stats (measure) SELECT 'home od randstad transit';

--SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, '0 WHERE pattern.measure=''home od randstad transit''',NULL,NULL);
--SELECT _phd_updatecolumns('analysis','mobility_patterns', 5, 87, '0 WHERE ',NULL,' IS NULL AND pattern.measure=''home od randstad transit''');

-- pre-select all transit postcodes
CREATE TEMP TABLE temp_transit_pcode AS SELECT * FROM survey.randstad_journeys WHERE agg_pcode=home_pcode 
AND home_pcode IN (SELECT pcode FROM survey.mobility_patterns_home_od WHERE transit IS NOT NULL AND transit>0);

-- base data necessary for the caluclation of the various indicators
UPDATE analysis.mobility_patterns_stats AS pattern SET journeys=temp.total
FROM (SELECT count(*) total FROM temp_transit_pcode
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET legs=temp.total
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET persons=temp.total
FROM (SELECT count(*) total FROM 
(SELECT persid FROM temp_transit_pcode GROUP BY persid) AS aa) AS temp WHERE
pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET distance=temp.total
FROM (SELECT sum(afstv)/10.0 total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET duration=temp.total
FROM (SELECT sum(rsdduur) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET distance_legs=temp.total
FROM (SELECT sum(afstr)/10.0 total FROM temp_transit_pcode WHERE agg_pcode=home_pcode) AS temp 
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET duration_legs=temp.total
FROM (SELECT sum(rrsdduur) total FROM temp_transit_pcode WHERE agg_pcode=home_pcode) AS temp 
WHERE pattern.measure='home od randstad transit';


-- mode related indicators, based on legs
UPDATE analysis.mobility_patterns_stats AS pattern SET walk=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE (mode_leg='1' OR mode_leg='12') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET cycle=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg='2' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET car=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE (mode_leg='3' OR mode_leg='4') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET bus=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg='5' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET tram=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg='6' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET train=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg='7' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET non_car=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg<>'3' AND mode_leg<>'4' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET motorised=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg NOT IN ('1','2','12') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET transit=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mode_leg IN ('5','6','7','8','11') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET multimodal=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode WHERE mm_code IN (1,2,4,5) AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

-- distance restricted mode indicators
UPDATE analysis.mobility_patterns_stats AS pattern SET short=temp.total
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE afstr<=15 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium=temp.total
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far=temp.total
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE afstr>=100 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';


UPDATE analysis.mobility_patterns_stats AS pattern SET short_walk=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE (mode_leg='1' OR mode_leg='12') AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short_cycle=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='2' AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short_car=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short_bus=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='5' AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short_tram=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='6' AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short_transit=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr<=15 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_cycle=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='2' AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_car=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_bus=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='5' AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_tram=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='6' AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_train=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='7' AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium_transit=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr>15 AND afstr<100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far_bus=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='5' AND afstr>=100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far_tram=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='6' AND afstr>=100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far_train=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg='7' AND afstr>=100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far_car=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr>=100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far_transit=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr>=100 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';


-- total distance share
UPDATE analysis.mobility_patterns_stats AS pattern SET transit_dist=round(((temp.total/distance_legs::double precision)*100)::numeric,2)
FROM (SELECT sum(afstr)/10.0 total FROM temp_transit_pcode WHERE
mode_leg IN ('5','6','7','8','11') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET car_dist=round(((temp.total/distance_legs::double precision)*100)::numeric,2)
FROM (SELECT sum(afstr)/10.0 total FROM temp_transit_pcode WHERE
(mode_leg='3' OR mode_leg='4') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET transit_dur=round(((temp.total/duration_legs::double precision)*100)::numeric,2)
FROM (SELECT sum(rrsdduur) total FROM temp_transit_pcode WHERE
mode_leg IN ('5','6','7','8','11') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET car_dur=round(((temp.total/duration_legs::double precision)*100)::numeric,2)
FROM (SELECT sum(rrsdduur) total FROM temp_transit_pcode WHERE
(mode_leg='3' OR mode_leg='4') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';


-- person based indicators
UPDATE analysis.mobility_patterns_stats as pattern SET avg_journeys_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats as pattern SET avg_dist_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats as pattern SET avg_dur_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';


-- location based indicators
UPDATE analysis.mobility_patterns_stats AS pattern SET neighbourhood=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND vertpc=aankpc AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET urban=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND vertgem=aankgem AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET inter_urban=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND vertgem<>aankgem AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET short=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND afstv<=15 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET medium=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND afstv>15 AND afstv<100 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET far=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT count(*) total FROM temp_transit_pcode 
WHERE mm_code <> 3 AND afstv>=100 AND agg_pcode=home_pcode) AS temp WHERE pattern.measure='home od randstad transit';


-- distance related indicators
UPDATE analysis.mobility_patterns_stats SET avg_dist=round((distance/journeys::double precision)::numeric,2);

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_home=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND aankbzh='1' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_work=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_edu=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_shop=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_serv=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_leisure=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_visit=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dist_tour=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';


-- duration related indicators
UPDATE analysis.mobility_patterns_stats SET avg_dur=round((duration/journeys::double precision)::numeric,2);

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_home=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(afstv)/10.0 total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND aankbzh='1' AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_work=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_edu=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_shop=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_serv=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_leisure=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_visit=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET avg_dur_tour=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT sum(rsdduur) total, count(*) journeys FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';


------------------------------------------------------------------------------------
-- for calculating median distance and duration values instead of mean

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_home=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (aankbzh='1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_work=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_edu=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_shop=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_serv=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_leisure=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_visit=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dist_tour=temp.median
FROM (SELECT median(afstv)/10.0 median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_home=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (aankbzh='1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_work=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_edu=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_shop=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_serv=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_leisure=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_visit=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

UPDATE analysis.mobility_patterns_stats AS pattern SET med_dur_tour=temp.median
FROM (SELECT median(rsdduur) median FROM temp_transit_pcode 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode=home_pcode) AS temp
WHERE pattern.measure='home od randstad transit';

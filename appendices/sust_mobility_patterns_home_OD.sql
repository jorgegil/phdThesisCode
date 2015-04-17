-- DROP TABLE survey.mobility_patterns_home_od CASCADE;

CREATE TABLE survey.mobility_patterns_home_od ( sid serial not null, the_geom geometry, the_boundary geometry, pcode character varying, journeys integer,
legs integer, persons integer, distance double precision, duration double precision, distance_legs double precision, duration_legs double precision,
walk double precision, cycle double precision, car double precision, bus double precision, tram double precision, train double precision,
non_car double precision, motorised double precision, transit double precision, multimodal double precision, 
short_walk double precision, short_cycle double precision, short_car double precision, short_bus double precision, short_tram double precision, short_transit double precision, 
medium_cycle double precision, medium_car double precision, medium_bus double precision, medium_tram double precision, medium_train double precision,
medium_transit double precision, far_bus double precision, far_tram double precision, far_train double precision, far_car double precision, far_transit double precision, 
transit_dist double precision, car_dist double precision, transit_dur double precision, car_dur double precision, avg_journeys_pers double precision, avg_dist_pers double precision, avg_dur_pers double precision,  
neighbourhood double precision, urban double precision, inter_urban double precision, short double precision, medium double precision, far double precision, 
avg_dist double precision, avg_dist_home double precision, avg_dist_work double precision, avg_dist_edu double precision, avg_dist_shop double precision,
avg_dist_serv double precision, avg_dist_leisure double precision, avg_dist_visit double precision, avg_dist_tour double precision, 
avg_dur double precision, avg_dur_home double precision, avg_dur_work double precision, avg_dur_edu double precision, avg_dur_shop double precision,
avg_dur_serv double precision, avg_dur_leisure double precision, avg_dur_visit double precision, avg_dur_tour double precision);

ALTER TABLE survey.mobility_patterns_home_od ADD CONSTRAINT mobility_patterns_home_od_pkey PRIMARY KEY (sid);

INSERT INTO survey.mobility_patterns_home_od (pcode) SELECT DISTINCT ON (home_pcode) home_pcode 
FROM survey.randstad_journeys WHERE home_pcode IN (SELECT pcode FROM survey.sampling_points);

-- base data necessary for the caluclation of the various indicators
UPDATE survey.mobility_patterns_home_od AS pattern SET journeys=temp.total
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET legs=temp.total
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys
WHERE agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET persons=temp.total
FROM (SELECT pcode, count(*) total FROM 
(SELECT home_pcode pcode, persid FROM survey.randstad_journeys 
WHERE agg_pcode = home_pcode GROUP BY home_pcode, persid) AS aa 
GROUP BY pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET distance=temp.total
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET duration=temp.total
FROM (SELECT home_pcode pcode, sum(rsdduur) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET distance_legs=temp.total
FROM (SELECT home_pcode pcode, sum(afstr)/10.0 total FROM survey.randstad_journeys 
WHERE agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET duration_legs=temp.total
FROM (SELECT home_pcode pcode, sum(rrsdduur) total FROM survey.randstad_journeys 
WHERE agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;


-- mode related indicators, based on legs
UPDATE survey.mobility_patterns_home_od AS pattern SET walk=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET walk=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='1' OR mode_leg='12') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET cycle=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET cycle=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='2' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET car=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET car=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET bus=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET bus=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='5' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET tram=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET tram=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='6' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET train=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET train=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='7' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET non_car=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET non_car=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg<>'3' AND mode_leg<>'4' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET motorised=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET motorised=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg NOT IN ('1','2','12') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET transit=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET transit=round(((temp.total/legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET multimodal=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET multimodal=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code IN (1,2,4,5) AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


-- distance restricted mode indicators
UPDATE survey.mobility_patterns_home_od AS pattern SET short=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short=temp.total
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium=temp.total
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET far=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET far=temp.total
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_walk=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_walk=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='1' OR mode_leg='12') AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_cycle=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_cycle=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='2' AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_car=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_car=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_bus=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_bus=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='5' AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_tram=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_tram=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='6' AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short_transit=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short_transit=round(((temp.total/short)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_cycle=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_cycle=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='2' AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_car=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_car=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_bus=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_bus=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='5' AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_tram=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_tram=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='6' AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_train=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_train=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='7' AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium_transit=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium_transit=round(((temp.total/medium)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr>15 AND afstr<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home AS pattern SET far_bus=0;
UPDATE survey.mobility_patterns_home AS pattern SET far_bus=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='5' AND afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home AS pattern SET far_tram=0;
UPDATE survey.mobility_patterns_home AS pattern SET far_tram=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='6' AND afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET far_train=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET far_train=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg='7' AND afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET far_car=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET far_car=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET far_transit=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET far_transit=round(((temp.total/far)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND afstr>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


-- total distance share
UPDATE survey.mobility_patterns_home_od AS pattern SET transit_dist=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET transit_dist=round(((temp.total/distance_legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstr)/10.0 total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET car_dist=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET car_dist=round(((temp.total/distance_legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstr)/10.0 total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET transit_dur=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET transit_dur=round(((temp.total/duration_legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rrsdduur) total FROM survey.randstad_journeys 
WHERE mode_leg IN ('5','6','7','8','11') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET car_dur=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET car_dur=round(((temp.total/duration_legs::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rrsdduur) total FROM survey.randstad_journeys 
WHERE (mode_leg='3' OR mode_leg='4') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


-- person based indicators
UPDATE survey.mobility_patterns_home_od as pattern SET avg_journeys_pers=0;
UPDATE survey.mobility_patterns_home_od as pattern SET avg_journeys_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od as pattern SET avg_dist_pers=0;
UPDATE survey.mobility_patterns_home_od as pattern SET avg_dist_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od as pattern SET avg_dur_pers=0;
UPDATE survey.mobility_patterns_home_od as pattern SET avg_dur_pers=round((temp.total/persons::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;


-- location based indicators
UPDATE survey.mobility_patterns_home_od AS pattern SET neighbourhood=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET neighbourhood=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND vertpc=aankpc AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET urban=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET urban=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND vertgem=aankgem AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET inter_urban=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET inter_urban=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND vertgem<>aankgem AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET short=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET short=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND afstv<=15 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET medium=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET medium=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND afstv>15 AND afstv<100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od AS pattern SET far=0;
UPDATE survey.mobility_patterns_home_od AS pattern SET far=round(((temp.total/journeys::double precision)*100)::numeric,2)
FROM (SELECT home_pcode pcode, count(*) total FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND afstv>=100 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp WHERE temp.pcode=pattern.pcode;


-- distance related indicators
UPDATE survey.mobility_patterns_home_od SET avg_dist=0;
UPDATE survey.mobility_patterns_home_od SET avg_dist=round((distance/journeys::double precision)::numeric,2);

UPDATE survey.mobility_patterns_home_od SET avg_dist_home = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_home=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND aankbzh='1' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_work = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_work=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_edu = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_edu=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_shop = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_shop=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_serv = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_serv=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_leisure = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_leisure=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_visit = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_visit=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dist_tour = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dist_tour=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


-- duration related indicators
UPDATE survey.mobility_patterns_home_od SET avg_dur=0;
UPDATE survey.mobility_patterns_home_od SET avg_dur=round((duration/journeys::double precision)::numeric,2);

UPDATE survey.mobility_patterns_home_od SET avg_dur_home = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_home=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(afstv)/10.0 total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND aankbzh='1' AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_work = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_work=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_edu = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_edu=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_shop = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_shop=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

---UPDATE survey.mobility_patterns_home_od SET avg_dur_serv = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_serv=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_leisure = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_leisure=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_visit = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_visit=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

UPDATE survey.mobility_patterns_home_od SET avg_dur_tour = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET avg_dur_tour=round((temp.total/temp.journeys::double precision)::numeric,2)
FROM (SELECT home_pcode pcode, sum(rsdduur) total, count(*) journeys FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


------------------------------------------------------------------------------------
-- for calculating median distance and duration values instead of mean

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_home double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_home = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_home=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (aankbzh='1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_work double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_work = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_work=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_edu double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_edu = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_edu=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_shop double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_shop = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_shop=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_serv double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_serv = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_serv=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_leisure double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_leisure = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_leisure=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_visit double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_visit = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_visit=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dist_tour double precision;
UPDATE survey.mobility_patterns_home_od SET med_dist_tour = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dist_tour=temp.median
FROM (SELECT home_pcode pcode, median(afstv)/10.0 median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_home double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_home = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_home=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (aankbzh='1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_work double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_work = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_work=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='1' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_edu double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_edu = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_edu=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='5' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_shop double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_shop = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_shop=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='4' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_serv double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_serv = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_serv=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='3' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_leisure double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_leisure = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_leisure=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='7' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_visit double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_visit = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_visit=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='6' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;

ALTER TABLE survey.mobility_patterns_home_od ADD COLUMN med_dur_tour double precision;
UPDATE survey.mobility_patterns_home_od SET med_dur_tour = 0;
UPDATE survey.mobility_patterns_home_od AS pattern SET med_dur_tour=temp.median
FROM (SELECT home_pcode pcode, median(rsdduur) median FROM survey.randstad_journeys 
WHERE mm_code <> 3 AND (kmotief='8' AND aankbzh<>'1') AND agg_pcode = home_pcode GROUP BY home_pcode) AS temp
WHERE temp.pcode=pattern.pcode;


-- upate geometry
UPDATE survey.mobility_patterns_home_od as pc SET the_geom=bag.the_geom FROM source.bag_postcodes_4digit as bag WHERE bag.pcode=pc.pcode;
UPDATE survey.mobility_patterns_home_od as pc SET the_boundary=geo.the_geom FROM source.geodan_nlp4_boundaries_09 as geo WHERE geo."PC4CODE"=pc.pcode;
--SELECT populate_geometry_columns();
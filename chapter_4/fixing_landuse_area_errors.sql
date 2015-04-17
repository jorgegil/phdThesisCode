----------------------------
-- fix land use NULL values
DROP TABLE buildings_to_fix;
CREATE TEMP TABLE buildings_to_fix AS SELECT building_id FROM urbanform.landuse WHERE area IN (999999,99999,9999,93799,949999) GROUP BY building_id;

DROP TABLE temp_agg_landuse CASCADE;
CREATE TEMP TABLE temp_agg_landuse AS SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='residential' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET residential_area=lnd.sumarea  FROM temp_agg_landuse as lnd  WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='lodging' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET lodging_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='retail' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET retail_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='office' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET office_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='education' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET education_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='health' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET health_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='sports' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET sports_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='assembly' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET assembly_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='industry' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET industry_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

INSERT INTO temp_agg_landuse SELECT building_id, sum(CASE WHEN area IN (999999,99999,9999,93799,949999) THEN 0 ELSE area END) sumarea FROM urbanform.landuse WHERE building_id IN (SELECT building_id FROM buildings_to_fix) AND function='other' GROUP BY building_id;
UPDATE urbanform.buildings_randstad bld SET other_area=lnd.sumarea  FROM temp_agg_landuse lnd WHERE bld.sid=lnd.building_id::numeric;
DELETE FROM temp_agg_landuse;

UPDATE urbanform.buildings_randstad as a SET floor_area= coalesce(residential_area,0) + coalesce(lodging_area,0) + coalesce(retail_area,0) + coalesce(office_area,0) + coalesce(education_area,0) + coalesce(health_area,0) + coalesce(sports_area,0) + coalesce(assembly_area,0) + coalesce(industry_area,0) + coalesce(other_area,0)
WHERE sid in (SELECT building_id::numeric FROM buildings_to_fix);


-------------------------------
-- fix land use decimal values
DROP TABLE buildings_to_fix;
CREATE TEMP TABLE buildings_to_fix AS SELECT sid FROM urbanform.buildings_randstad WHERE floor_area=10000*round(area::numeric,4)
OR floor_area>10000*area;

UPDATE urbanform.buildings_randstad SET residential_area=residential_area::float/10000, lodging_area=lodging_area::float/10000, retail_area=retail_area::float/10000, office_area=office_area::float/10000, education_area=education_area::float/10000, health_area=health_area::float/10000, sports_area=sports_area::float/10000, assembly_area=assembly_area::float/10000, industry_area=industry_area::float/10000, other_area=other_area::float/10000 
WHERE sid IN (SELECT sid FROM buildings_to_fix);

DELETE FROM buildings_to_fix;
INSERT INTO buildings_to_fix SELECT sid FROM urbanform.buildings_randstad WHERE floor_area=1000*round(area::numeric,3)
OR (floor_area>1000*area AND floor_area<10000*area);

UPDATE urbanform.buildings_randstad SET residential_area=residential_area::float/1000, lodging_area=lodging_area::float/1000, retail_area=retail_area::float/1000, office_area=office_area::float/1000, education_area=education_area::float/1000, health_area=health_area::float/1000, sports_area=sports_area::float/1000, assembly_area=assembly_area::float/1000, industry_area=industry_area::float/1000, other_area=other_area::float/1000 
WHERE sid IN (SELECT sid FROM buildings_to_fix);


DELETE FROM buildings_to_fix;
INSERT INTO buildings_to_fix SELECT sid FROM urbanform.buildings_randstad WHERE floor_area=100*round(area::numeric,4)
OR (floor_area>100*area AND floor_area<1000*area AND units=1);

UPDATE urbanform.buildings_randstad SET residential_area=residential_area::float/100, lodging_area=lodging_area::float/100, retail_area=retail_area::float/100, office_area=office_area::float/100, education_area=education_area::float/100, health_area=health_area::float/100, sports_area=sports_area::float/100, assembly_area=assembly_area::float/100, industry_area=industry_area::float/100, other_area=other_area::float/100 
WHERE sid IN (SELECT sid FROM buildings_to_fix);


DELETE FROM buildings_to_fix;
INSERT INTO buildings_to_fix SELECT sid FROM urbanform.buildings_randstad WHERE (floor_area>20*area AND floor_area<100*area and units=1);

UPDATE urbanform.buildings_randstad SET residential_area=residential_area::float/10, lodging_area=lodging_area::float/10, retail_area=retail_area::float/10, office_area=office_area::float/10, education_area=education_area::float/10, health_area=health_area::float/10, sports_area=sports_area::float/10, assembly_area=assembly_area::float/10, industry_area=industry_area::float/10, other_area=other_area::float/10
WHERE sid IN (SELECT sid FROM buildings_to_fix);


DELETE FROM buildings_to_fix;
INSERT INTO buildings_to_fix SELECT sid FROM urbanform.buildings_randstad WHERE
floor_area=10000*round(area::numeric,4)
OR floor_area>10000*area
OR floor_area=1000*round(area::numeric,3)
OR (floor_area>1000*area AND floor_area<10000*area)
OR floor_area=1000*round(area::numeric,3)
OR (floor_area>1000*area AND floor_area<10000*area) 
OR floor_area=100*round(area::numeric,4)
OR (floor_area>100*area AND floor_area<1000*area AND units=1)
OR (floor_area>20*area AND floor_area<100*area and units=1);

UPDATE urbanform.buildings_randstad as a SET floor_area= coalesce(residential_area,0) + coalesce(lodging_area,0) + coalesce(retail_area,0) + coalesce(office_area,0) + coalesce(education_area,0) + coalesce(health_area,0) + coalesce(sports_area,0) + coalesce(assembly_area,0) + coalesce(industry_area,0) + coalesce(other_area,0)
WHERE sid in (SELECT sid FROM buildings_to_fix);
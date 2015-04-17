-- SAMPLING POINTS
DROP TABLE temp_buildings CASCADE;
CREATE TEMP TABLE temp_buildings AS SELECT * FROM urbanform.buildings WHERE sid IN (SELECT building_id FROM survey.sampling_points);
CREATE INDEX temp_buildings_idx ON temp_buildings USING GIST (the_geom);

-- DROP TABLE temp_road_network;
CREATE TEMP TABLE temp_road_network AS SELECT * FROM network.roads WHERE coalesce(car,'yes')<>'no' OR road_type='service';
CREATE INDEX temp_road_idx ON temp_road_network USING GIST (the_geom);

SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_roads_interfaces');

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(bicycle,'yes')<>'no' OR road_type='service';
SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_roads_interfaces');

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(pedestrian,'yes')<>'no' OR road_type='service';
SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_roads_interfaces');

SELECT _phd_eliminate_duplicates('survey.sampling_roads_interfaces');

ALTER TABLE survey.sampling_roads_interfaces ADD COLUMN length double precision;
UPDATE survey.sampling_roads_interfaces SET length=ST_Length(the_geom);
ALTER TABLE survey.sampling_roads_interfaces ADD COLUMN pcode character varying;
UPDATE survey.sampling_roads_interfaces as int SET pcode=smp.pcode FROM survey.sampling_points as smp WHERE int.building_id=smp.building_id;

ALTER TABLE survey.sampling_roads_interfaces ADD COLUMN sid serial NOT NULL;
ALTER TABLE survey.sampling_roads_interfaces ADD CONSTRAINT sampling_roads_int_pk PRIMARY KEY (sid);




-- RESIDENTIAL SAMPLING POINTS
DROP TABLE temp_buildings CASCADE;
CREATE TEMP TABLE temp_buildings AS SELECT * FROM urbanform.buildings WHERE sid IN (SELECT building_id FROM survey.sampling_residential);

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(car,'yes')<>'no' OR road_type='service';
SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_resi_roads_interfaces');

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(bicycle,'yes')<>'no' OR road_type='service';
SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_resi_roads_interfaces');

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(pedestrian,'yes')<>'no' OR road_type='service';
SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'temp_road_network', 'the_geom', 'sid', '', '', 'survey.sampling_resi_roads_interfaces');

SELECT _phd_eliminate_duplicates('survey.sampling_resi_roads_interfaces');

ALTER TABLE survey.sampling_resi_roads_interfaces ADD COLUMN length double precision;
UPDATE survey.sampling_resi_roads_interfaces SET length=ST_Length(the_geom);
ALTER TABLE survey.sampling_resi_roads_interfaces ADD COLUMN pcode character varying;
UPDATE survey.sampling_resi_roads_interfaces as int SET pcode=smp.pcode FROM survey.sampling_residential as smp WHERE int.building_id=smp.building_id;

ALTER TABLE survey.sampling_resi_roads_interfaces ADD COLUMN sid serial NOT NULL;
ALTER TABLE survey.sampling_resi_roads_interfaces ADD CONSTRAINT sampling_resi_roads_int_pk PRIMARY KEY (sid);




-- ALL BUILDINGS
-- DROP TABLE temp_road_network;
-- CREATE TEMP TABLE temp_road_network AS SELECT * FROM network.roads WHERE coalesce(car,'yes')<>'no' OR road_type='service';
-- CREATE INDEX temp_road_idx ON temp_road_network USING GIST (the_geom);

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(car,'yes')<>'no' OR road_type='service';

SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 0, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 500000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 1000000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 1500000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 2000000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 2500000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');
SELECT _phd_link_objects_pll('temp.buildings_active', 'the_geom', 'sid', 3000000, 500000, 'temp_road_network', 'the_geom', 'sid', '', '', 'urbanform.buildings_roads_interfaces');

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(bicycle,'yes')<>'no' OR road_type='service';
-- repeat previous sequence of _phd_link_objects_pll

DELETE FROM temp_road_network;
INSERT INTO temp_road_network SELECT * FROM network.roads WHERE coalesce(pedestrian,'yes')<>'no' OR road_type='service';
-- repeat previous sequence of _phd_link_objects_pll

SELECT _phd_eliminate_duplicates('urbanform.buildings_roads_interfaces');

ALTER TABLE urbanform.buildings_roads_interfaces ADD COLUMN length double precision;
UPDATE urbanform.buildings_roads_interfaces SET length=ST_Length(the_geom);

ALTER TABLE urbanform.buildings_roads_interfaces ADD COLUMN sid serial NOT NULL;
ALTER TABLE urbanform.buildings_roads_interfaces ADD CONSTRAINT building_roads_int_pk PRIMARY KEY (sid);

CREATE INDEX buildings_roads_interfaces_geom_idx ON urbanform.buildings_roads_interfaces USING GIST (the_geom);
CREATE INDEX buildings_roads_interfaces_object_idx ON urbanform.buildings_roads_interfaces (object_id);
CREATE INDEX buildings_roads_interfaces_target_idx ON urbanform.buildings_roads_interfaces (target_id)


--now for pedestrian areas is slightly different
--DROP TABLE temp_buildings CASCADE;
CREATE TEMP TABLE temp_buildings AS SELECT * FROM temp.buildings_active WHERE sid IN 
	(SELECT DISTINCT tmp.sid FROM temp.buildings_active as tmp, urbanform.pedestrian_areas as rd
	WHERE ST_DWithin(tmp.the_geom,rd.the_geom,200));
CREATE INDEX temp_buildings_idx ON temp_buildings USING GIST (the_geom);

--SELECT _phd_buildings_interfaces_strict('temp_buildings', 'the_geom', 'sid', 'urbanform.pedestrian_areas', 'the_geom', 'sid', '', '', 'urbanform.buildings_areas_interfaces');
--SELECT _phd_buildings_interfaces_strict('urbanform.pedestrian_areas', 'the_geom', 'sid', 'temp_buildings', 'the_point', 'sid', '', '', 'urbanform.buildings_areas_interfaces');
SELECT _phd_link_objects_pll('temp_buildings', 'the_geom', 'sid', 0, 150000, 'urbanform.pedestrian_areas', 'the_geom', 'sid', '', '', 'urbanform.buildings_areas_interfaces');
	
ALTER TABLE urbanform.buildings_areas_interfaces ADD COLUMN length double precision;
UPDATE urbanform.buildings_areas_interfaces SET length=ST_Length(the_geom);
DELETE FROM urbanform.buildings_areas_interfaces WHERE length>25;

ALTER TABLE urbanform.buildings_areas_interfaces ADD COLUMN sid serial NOT NULL;
ALTER TABLE urbanform.buildings_areas_interfaces ADD CONSTRAINT buildings_areas_int_pk PRIMARY KEY (sid);

CREATE INDEX buildings_areas_interfaces_geom_idx ON urbanform.buildings_areas_interfaces USING GIST (the_geom);
CREATE INDEX buildings_areas_interfaces_object_idx ON urbanform.buildings_areas_interfaces (object_id);
CREATE INDEX buildings_areas_interfaces_target_idx ON urbanform.buildings_areas_interfaces (target_id)

DELETE FROM urbanform.buildings_areas_interfaces WHERE sid IN 
	(SELECT DISTINCT tmp.sid FROM urbanform.buildings_areas_interfaces as tmp, temp_road_network as rd
	WHERE ST_Crosses(tmp.the_geom,rd.the_geom));

DELETE FROM urbanform.buildings_areas_interfaces WHERE sid IN 
	(SELECT DISTINCT tmp.sid FROM urbanform.buildings_areas_interfaces as tmp, temp.noncross_water as rd
	WHERE ST_Crosses(tmp.the_geom,rd.the_geom));

DELETE FROM urbanform.buildings_areas_interfaces WHERE sid IN 
	(SELECT DISTINCT tmp.sid FROM urbanform.buildings_areas_interfaces as tmp, temp_buildings as rd
	WHERE ST_Crosses(tmp.the_geom,rd.the_geom) AND tmp.object_id<>rd.sid);

select populate_geometry_columns();
-- shortest route and service area calculation for the Geoinformation and Cartography book chapter

-- select origin buildings
-- DROP TABLE geoinfo.sources CASCADE;
-- using building IDs
CREATE TABLE geoinfo.sources AS SELECT multimodal_sid sid, the_geom::geometry(MultiPolygon, 28992) FROM urbanform.buildings_randstad WHERE multimodal_sid IN (3994220,3997563,3993123,3998579,3996592,3999072,4003403,3991893,3997452,5875983);
SELECT populate_geometry_columns('geoinfo.sources'::regclass,false);
ALTER TABLE geoinfo.sources ADD COLUMN nme text;
UPDATE geoinfo.sources SET nme='A' WHERE sid = 3994220;
UPDATE geoinfo.sources SET nme='B' WHERE sid = 3997563;
UPDATE geoinfo.sources SET nme='C' WHERE sid = 3993123;
UPDATE geoinfo.sources SET nme='D' WHERE sid = 3998579;
UPDATE geoinfo.sources SET nme='E' WHERE sid = 3996592;
UPDATE geoinfo.sources SET nme='F' WHERE sid = 3999072;
UPDATE geoinfo.sources SET nme='FF' WHERE sid = 4003403;
UPDATE geoinfo.sources SET nme='G' WHERE sid = 3991893;
UPDATE geoinfo.sources SET nme='H' WHERE sid = 3997452;
UPDATE geoinfo.sources SET nme='T' WHERE sid = 5875983;
-- add selected road/entrance IDs
ALTER TABLE geoinfo.sources ADD COLUMN entrance text;
UPDATE geoinfo.sources SET entrance=30567 WHERE nme='A';
UPDATE geoinfo.sources SET entrance=477163 WHERE nme='B';
UPDATE geoinfo.sources SET entrance=1302574 WHERE nme='C';
UPDATE geoinfo.sources SET entrance=50697 WHERE nme='D';
UPDATE geoinfo.sources SET entrance=30579 WHERE nme='E';
UPDATE geoinfo.sources SET entrance=54368 WHERE nme='F';
UPDATE geoinfo.sources SET entrance=1302118 WHERE nme='FF';
UPDATE geoinfo.sources SET entrance=1302264 WHERE nme='G';
UPDATE geoinfo.sources SET entrance=473433 WHERE nme='H';
UPDATE geoinfo.sources SET entrance=1302346 WHERE nme='T';

------------------------------
-- prepare mode graph tables
-- DROP TABLE temp_pedestrian_graph CASCADE;
CREATE TEMP TABLE temp_pedestrian_graph AS SELECT * FROM graph.multimodal_amsterdam WHERE mobility IN ('private','building') AND pedestrian IS NOT FALSE;
--SELECT populate_geometry_columns('temp_pedestrian_graph'::regclass,false);
CREATE INDEX temp_pedestrian_source_idx ON temp_pedestrian_graph (source);
CREATE INDEX temp_pedestrian_target_idx ON temp_pedestrian_graph (target);
-- DROP TABLE temp_car_graph CASCADE;
CREATE TEMP TABLE temp_car_graph AS SELECT * FROM graph.multimodal_amsterdam WHERE mobility IN ('private','building') AND car IS NOT FALSE;
CREATE INDEX temp_car_source_idx ON temp_car_graph (source);
CREATE INDEX temp_car_target_idx ON temp_car_graph (target);
-- DROP TABLE temp_transit_graph CASCADE;
CREATE TEMP TABLE temp_transit_graph AS SELECT * FROM graph.multimodal_amsterdam WHERE pedestrian IS NOT FALSE;
CREATE INDEX temp_transit_source_idx ON temp_transit_graph (source);
CREATE INDEX temp_transit_target_idx ON temp_transit_graph (target);
-- DROP TABLE temp_pedestrian_basic_graph CASCADE;
CREATE TEMP TABLE temp_pedestrian_basic_graph AS SELECT * FROM graph.multimodal_amsterdam WHERE mobility IN ('private','building') AND pedestrian IS NOT FALSE AND source NOT IN (SELECT road_sid FROM network.areas_randstad) AND target NOT IN (SELECT road_sid FROM network.areas_randstad);
--SELECT populate_geometry_columns('temp_pedestrian_basic_graph'::regclass,false);
CREATE INDEX temp_pedestrian_basic_source_idx ON temp_pedestrian_basic_graph (source);
CREATE INDEX temp_pedestrian_basic_target_idx ON temp_pedestrian_basic_graph (target);

--------------------------------
-- calculate shortest routes
-- DROP TABLE geoinfo.routes CASCADE;
CREATE TABLE geoinfo.routes (sid serial NOT NULL PRIMARY KEY, the_geom geometry(Linestring, 28992), node_id integer, link_id integer, dist double precision, od text, modality text);
SELECT populate_geometry_columns('geoinfo.routes'::regclass,false);
-- DELETE FROM geoinfo.routes;
-- test
SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM geoinfo.sources WHERE nme='A')::int, (SELECT entrance FROM geoinfo.sources WHERE nme='B')::int, false, false);

SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_basic_graph', (SELECT entrance FROM geoinfo.sources WHERE nme='A')::int, (SELECT entrance FROM geoinfo.sources WHERE nme='B')::int, false, false);

WITH this_route AS (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM geoinfo.sources WHERE nme='A')::integer, (SELECT entrance FROM geoinfo.sources WHERE nme='B')::integer, false, false))
INSERT INTO geoinfo.routes (link_id,dist,od,modality) SELECT vertex_id,cost,'A-B','pedestrian' FROM this_route;

-- pedestrian
SELECT _phd_route_test('temporal_ped','pedestrian','A','B');
SELECT _phd_route_test('temporal_ped','pedestrian','C','D');
SELECT _phd_route_test('temporal_ped','pedestrian','E','F');
SELECT _phd_route_test('temporal_ped','pedestrian','E','FF');
SELECT _phd_route_test('temporal_ped','pedestrian','G','H');
SELECT _phd_route_test('temporal_ped','pedestrian','A','T');
SELECT _phd_route_test('temporal_ped','pedestrian','B','T');
SELECT _phd_route_test('temporal_ped','pedestrian','C','T');
SELECT _phd_route_test('temporal_ped','pedestrian','D','T');
SELECT _phd_route_test('temporal_ped','pedestrian','E','T');
SELECT _phd_route_test('temporal_ped','pedestrian','F','T');
SELECT _phd_route_test('temporal_ped','pedestrian','FF','T');
SELECT _phd_route_test('temporal_ped','pedestrian','G','T');
SELECT _phd_route_test('temporal_ped','pedestrian','H','T');

-- pedestrian basic
SELECT _phd_route_test('temporal_ped','pedestrian_basic','A','B');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','C','D');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','E','F');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','E','FF');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','G','H');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','A','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','B','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','C','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','D','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','E','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','F','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','FF','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','G','T');
SELECT _phd_route_test('temporal_ped','pedestrian_basic','H','T');

-- car
SELECT _phd_route_test('temporal','car','A','B');
SELECT _phd_route_test('temporal','car','C','D');
SELECT _phd_route_test('temporal','car','E','F');
SELECT _phd_route_test('temporal','car','E','FF');
SELECT _phd_route_test('temporal','car','G','H');
SELECT _phd_route_test('temporal','car','A','T');
SELECT _phd_route_test('temporal','car','B','T');
SELECT _phd_route_test('temporal','car','C','T');
SELECT _phd_route_test('temporal','car','D','T');
SELECT _phd_route_test('temporal','car','E','T');
SELECT _phd_route_test('temporal','car','F','T');
SELECT _phd_route_test('temporal','car','FF','T');
SELECT _phd_route_test('temporal','car','G','T');
SELECT _phd_route_test('temporal','car','H','T');

-- transit
SELECT _phd_route_test('temporal_ped','transit','A','B');
SELECT _phd_route_test('temporal_ped','transit','C','D');
SELECT _phd_route_test('temporal_ped','transit','E','F');
SELECT _phd_route_test('temporal_ped','transit','E','FF');
SELECT _phd_route_test('temporal_ped','transit','G','H');
SELECT _phd_route_test('temporal_ped','transit','A','T');
SELECT _phd_route_test('temporal_ped','transit','B','T');
SELECT _phd_route_test('temporal_ped','transit','C','T');
SELECT _phd_route_test('temporal_ped','transit','D','T');
SELECT _phd_route_test('temporal_ped','transit','E','T');
SELECT _phd_route_test('temporal_ped','transit','F','T');
SELECT _phd_route_test('temporal_ped','transit','FF','T');
SELECT _phd_route_test('temporal_ped','transit','G','T');
SELECT _phd_route_test('temporal_ped','transit','H','T');


-- update geometry column
UPDATE geoinfo.routes a SET the_geom=b.the_geom FROM network.roads_randstad b WHERE a.node_id = b.sid;
UPDATE geoinfo.routes a SET the_geom=b.the_geom FROM network.areas_randstad b WHERE a.node_id = b.road_sid;
UPDATE geoinfo.routes a SET the_geom=b.the_geom FROM network.transit_stops b WHERE a.node_id = b.multimodal_sid;


--------------------------------
-- calculate service areas
-- DROP TABLE geoinfo.service_areas CASCADE;
CREATE TABLE geoinfo.service_areas (sid serial NOT NULL PRIMARY KEY, the_roads geometry(Linestring, 28992), the_buildings geometry(MultiPolygon, 28992), the_stops geometry(Point, 28992), node_id integer, dist double precision, origin text, modality text);
SELECT populate_geometry_columns('geoinfo.routes'::regclass,false);
CREATE INDEX service_areas_node_idx ON geoinfo.service_areas (node_id);
-- DELETE FROM geoinfo.service_areas;
-- test
SELECT seq, id1 AS node, cost FROM pgr_drivingDistance('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM geoinfo.sources WHERE nme='A')::integer, 5.0::double precision, false, false);

WITH this_service AS (SELECT seq, id1 AS node_id, cost FROM pgr_drivingDistance('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM geoinfo.sources WHERE nme='A')::integer, 5.0::double precision, false, false))
INSERT INTO geoinfo.service_areas (node_id, dist, origin, modality) SELECT node_id,cost,'A','pedestrian' FROM this_service;


-- pedestrian
SELECT _phd_service_test('temporal_ped','pedestrian','A','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','B','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','C','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','D','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','E','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','F','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','G','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','H','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','FF','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian','T','10.0');

-- pedestrian basic
SELECT _phd_service_test('temporal_ped','pedestrian_basic','A','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','B','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','C','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','D','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','E','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','F','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','G','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','H','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','FF','10.0');
SELECT _phd_service_test('temporal_ped','pedestrian_basic','T','10.0');

-- car
SELECT _phd_service_test('temporal','car','A','5.0');
SELECT _phd_service_test('temporal','car','B','5.0');
SELECT _phd_service_test('temporal','car','C','5.0');
SELECT _phd_service_test('temporal','car','D','5.0');
SELECT _phd_service_test('temporal','car','E','5.0');
SELECT _phd_service_test('temporal','car','F','5.0');
SELECT _phd_service_test('temporal','car','G','5.0');
SELECT _phd_service_test('temporal','car','H','5.0');
SELECT _phd_service_test('temporal','car','FF','5.0');
SELECT _phd_service_test('temporal','car','T','5.0');

-- transit
SELECT _phd_service_test('temporal_ped','transit','A','10.0');
SELECT _phd_service_test('temporal_ped','transit','B','10.0');
SELECT _phd_service_test('temporal_ped','transit','C','10.0');
SELECT _phd_service_test('temporal_ped','transit','D','10.0');
SELECT _phd_service_test('temporal_ped','transit','E','10.0');
SELECT _phd_service_test('temporal_ped','transit','F','10.0');
SELECT _phd_service_test('temporal_ped','transit','G','10.0');
SELECT _phd_service_test('temporal_ped','transit','H','10.0');
SELECT _phd_service_test('temporal_ped','transit','FF','10.0');
SELECT _phd_service_test('temporal_ped','transit','T','10.0');

-- update geoemetry columns
UPDATE geoinfo.service_areas a SET the_roads=b.the_geom FROM network.roads_randstad b WHERE a.node_id = b.sid;
UPDATE geoinfo.service_areas a SET the_roads=b.the_geom FROM network.areas_randstad b WHERE a.node_id = b.road_sid;
UPDATE geoinfo.service_areas a SET the_stops=b.the_geom FROM network.transit_stops b WHERE a.node_id = b.multimodal_sid;
UPDATE geoinfo.service_areas a SET the_buildings=b.the_geom FROM urbanform.buildings_randstad b WHERE a.the_roads IS NULL AND a.the_stops IS NULL AND a.node_id = b.multimodal_sid;

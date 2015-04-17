-- shortest route and service area calculation for appendix d of the thesis

-- select origin buildings
-- DROP TABLE distances.sources CASCADE;
-- using building IDs
CREATE TABLE distances.sources AS SELECT multimodal_sid sid, the_geom geometry FROM urbanform.buildings_randstad WHERE multimodal_sid IN (1993893,2042963,2002182,2002995);
SELECT populate_geometry_columns();
-- source building name
ALTER TABLE distances.sources ADD COLUMN nme text;
UPDATE distances.sources SET nme='Delft Central Station' WHERE sid = 1993893;
UPDATE distances.sources SET nme='Bouwpub' WHERE sid = 2042963;
UPDATE distances.sources SET nme='Filmhuis Lumen' WHERE sid = 2002182;
UPDATE distances.sources SET nme='Market Square' WHERE sid = 2002995;
-- simpler code
ALTER TABLE distances.sources ADD COLUMN code text;
UPDATE distances.sources SET code='A' WHERE sid = 1993893;
UPDATE distances.sources SET code='B' WHERE sid = 2042963;
UPDATE distances.sources SET code='C' WHERE sid = 2002182;
UPDATE distances.sources SET code='D' WHERE sid = 2002995;
-- source building select entrance to use
ALTER TABLE distances.sources ADD COLUMN entrance integer;
UPDATE distances.sources SET entrance= 1600807 WHERE sid = 1993893;
UPDATE distances.sources SET entrance= 1538398 WHERE sid = 2042963;
UPDATE distances.sources SET entrance= 1382304 WHERE sid = 2002182;
UPDATE distances.sources SET entrance= 536712 WHERE sid = 2002995;

------------------------------
-- prepare graph
-- DROP TABLE temp_pedestrian_graph CASCADE;
CREATE TEMP TABLE temp_pedestrian_graph AS SELECT * FROM graph.multimodal_randstad WHERE mobility='private' AND pedestrian IS NOT FALSE AND randstad_code != 'Outer ring';
--SELECT populate_geometry_columns('temp_pedestrian_graph'::regclass,false);
CREATE INDEX temp_pedestrian_source_idx ON temp_pedestrian_graph (source);
CREATE INDEX temp_pedestrian_target_idx ON temp_pedestrian_graph (target);


--------------------------------
-- calculate shortest routes
-- DROP TABLE distances.routes CASCADE;
CREATE TABLE distances.routes (sid serial NOT NULL PRIMARY KEY, the_geom geometry, node_id integer, link_id integer, dist double precision, od text, distance_type text);
SELECT populate_geometry_columns();
-- DELETE FROM distances.routes;
-- test
SELECT * FROM shortest_path('SELECT sid AS id,source::int4, target::int4, axial::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM distances.sources WHERE code='A')::int, (SELECT entrance FROM distances.sources WHERE code='B')::int, false, false);
-- add one
WITH this_route AS (SELECT * FROM shortest_path('SELECT sid AS id,source::int4, target::int4, metric::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM distances.sources WHERE code='A')::integer, (SELECT entrance FROM distances.sources WHERE code='B')::integer, false, false))
INSERT INTO distances.routes (link_id,dist,od,distance_type) SELECT vertex_id,cost,'A-B','metric' FROM this_route;

-- add the rest for every type of distance
SELECT _phd_route_test_distance('metric','pedestrian','A','B');
SELECT _phd_route_test_distance('metric','pedestrian','B','C');
SELECT _phd_route_test_distance('metric','pedestrian','C','A');

SELECT _phd_route_test_distance('temporal','pedestrian','A','B');
SELECT _phd_route_test_distance('temporal','pedestrian','B','C');
SELECT _phd_route_test_distance('temporal','pedestrian','C','A');

SELECT _phd_route_test_distance('cumangular','pedestrian','A','B');
SELECT _phd_route_test_distance('cumangular','pedestrian','B','C');
SELECT _phd_route_test_distance('cumangular','pedestrian','C','A');

SELECT _phd_route_test_distance('axial','pedestrian','A','B');
SELECT _phd_route_test_distance('axial','pedestrian','B','C');
SELECT _phd_route_test_distance('axial','pedestrian','C','A');

SELECT _phd_route_test_distance('continuity_v2','pedestrian','A','B');
SELECT _phd_route_test_distance('continuity_v2','pedestrian','B','C');
SELECT _phd_route_test_distance('continuity_v2','pedestrian','C','A');

SELECT _phd_route_test_distance('segment','pedestrian','A','B');
SELECT _phd_route_test_distance('segment','pedestrian','B','C');
SELECT _phd_route_test_distance('segment','pedestrian','C','A');

-- update geometry column
UPDATE distances.routes a SET the_geom=b.the_geom FROM network.roads_randstad b WHERE a.node_id = b.sid;
UPDATE distances.routes a SET the_geom=b.the_geom FROM network.areas_randstad b WHERE a.node_id = b.road_sid;


--------------------------------
-- calculate service areas
-- DROP TABLE distances.service_areas CASCADE;
CREATE TABLE distances.service_areas (sid serial NOT NULL PRIMARY KEY, the_roads geometry, the_buildings geometry, node_id integer, dist double precision, origin text, distance_type text, max_distance double precision);
SELECT populate_geometry_columns();
CREATE INDEX service_areas_node_idx ON distances.service_areas (node_id);
-- DELETE FROM distances.service_areas;
-- test
SELECT * FROM driving_distance('SELECT sid AS id,source::int4, target::int4, metric::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM distances.sources WHERE code='D')::integer, 400.0::double precision, false, false);

WITH this_service AS (SELECT seq, id1 AS node_id, cost FROM pgr_drivingDistance('SELECT sid AS id,source::int4, target::int4, temporal_ped::float8 AS cost FROM temp_pedestrian_graph', (SELECT entrance FROM distances.sources WHERE code='D')::integer, 400.0::double precision, false, false))
INSERT INTO distances.service_areas (node_id, dist, origin, distance_type,max_distance) SELECT node_id,cost,'D','metric',400.0 FROM this_service;

-- add the rest for every type of distance
SELECT _phd_service_test_distance('metric','pedestrian','D','800.0');
SELECT _phd_service_test_distance('temporal','pedestrian','D','5.0');
SELECT _phd_service_test_distance('cumangular','pedestrian','D','360.0');
SELECT _phd_service_test_distance('axial','pedestrian','D','5');
SELECT _phd_service_test_distance('continuity_v2','pedestrian','D','5');
SELECT _phd_service_test_distance('segment','pedestrian','D','20');

-- update geometry columns
UPDATE distances.service_areas a SET the_roads=b.the_geom FROM network.roads_randstad b WHERE a.node_id = b.sid;
UPDATE distances.service_areas a SET the_roads=b.the_geom FROM network.areas_randstad b WHERE a.node_id = b.road_sid;

-- buildings
CREATE TEMP TABLE temp_relevant_links AS SELECT target_id, object_mm_id FROM urbanform.buildings_roads_interfaces_randstad WHERE target_id IN (SELECT node_id FROM distances.service_areas WHERE node_id IS NOT NULL);
CREATE TEMP TABLE temp_relevant_buildings AS SELECT * FROM temp_relevant_links aa JOIN urbanform.buildings_randstad bb ON (aa.object_mm_id=bb.multimodal_sid);
INSERT INTO distances.service_areas (node_id, the_buildings, dist, origin, distance_type, max_distance) SELECT DISTINCT ON (b.multimodal_sid,a.origin,a.distance_type, a.max_distance) b.multimodal_sid, b.the_geom, a.dist, a.origin, a.distance_type, a.max_distance FROM distances.service_areas a JOIN temp_relevant_buildings b ON (a.node_id=b.target_id) ORDER BY b.multimodal_sid, a.max_distance ASC;

-- shortest route and service area calculation for the Geoinformation and Cartography book chapter
-- this example uses a primal graph for private modes

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
UPDATE geoinfo.sources SET nme='S' WHERE sid = 4003403;
UPDATE geoinfo.sources SET nme='G' WHERE sid = 3991893;
UPDATE geoinfo.sources SET nme='H' WHERE sid = 3997452;
UPDATE geoinfo.sources SET nme='T' WHERE sid = 5875983;
-- add selected road/entrance IDs
ALTER TABLE geoinfo.sources ADD COLUMN entrance_primal text;
UPDATE geoinfo.sources SET entrance_primal=204378 WHERE nme='A';
UPDATE geoinfo.sources SET entrance_primal=889514 WHERE nme='B';
UPDATE geoinfo.sources SET entrance_primal=472024 WHERE nme='C';
UPDATE geoinfo.sources SET entrance_primal=577586 WHERE nme='D';
UPDATE geoinfo.sources SET entrance_primal=1004855 WHERE nme='E';
UPDATE geoinfo.sources SET entrance_primal=418743 WHERE nme='F';
UPDATE geoinfo.sources SET entrance_primal=564860 WHERE nme='S';
UPDATE geoinfo.sources SET entrance_primal=491059 WHERE nme='G';
UPDATE geoinfo.sources SET entrance_primal=547966 WHERE nme='H';
UPDATE geoinfo.sources SET entrance_primal=45416 WHERE nme='T';

------------------------------
-- prepare mode graph tables
-- DROP TABLE temp_pedestrian_graph_primal CASCADE;
CREATE TEMP TABLE temp_pedestrian_graph_primal AS SELECT * FROM graph.roads_primal WHERE pedestrian IS NOT FALSE;
--SELECT populate_geometry_columns('temp_pedestrian_graph_primal'::regclass,false);
CREATE INDEX temp_pedestrian_source_primal_idx ON temp_pedestrian_graph_primal (source);
CREATE INDEX temp_pedestrian_target_primal_idx ON temp_pedestrian_graph_primal (target);
-- DROP TABLE temp_car_graph_primal CASCADE;
CREATE TEMP TABLE temp_car_graph_primal AS SELECT * FROM graph.roads_primal WHERE car IS NOT FALSE;
CREATE INDEX temp_car_source_primal_idx ON temp_car_graph_primal (source);
CREATE INDEX temp_car_target_primal_idx ON temp_car_graph_primal (target);
-- DROP TABLE temp_pedestrian_basic_graph_primal CASCADE;
CREATE TEMP TABLE temp_pedestrian_basic_graph_primal AS SELECT * FROM graph.roads_primal WHERE pedestrian IS NOT FALSE AND link_id NOT IN (SELECT road_sid FROM network.areas_randstad);
--SELECT populate_geometry_columns('temp_pedestrian_basic_graph_primal'::regclass,false);
CREATE INDEX temp_pedestrian_basic_source_primal_idx ON temp_pedestrian_basic_graph_primal (source);
CREATE INDEX temp_pedestrian_basic_target_primal_idx ON temp_pedestrian_basic_graph_primal (target);

--------------------------------
-- calculate shortest routes
-- DROP TABLE geoinfo.routes_primal CASCADE;
CREATE TABLE geoinfo.routes_primal (sid serial NOT NULL PRIMARY KEY, the_geom geometry(Linestring, 28992), node_id integer, link_id integer, dist double precision, od text, modality text);
SELECT populate_geometry_columns('geoinfo.routes_primal'::regclass,false);
-- DELETE FROM geoinfo.routes_primal;
-- test
SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT link_id AS id,source::int4, target::int4, time_ped::float8 AS cost FROM temp_pedestrian_graph_primal', (SELECT entrance_primal FROM geoinfo.sources WHERE nme='A')::int, (SELECT entrance_primal FROM geoinfo.sources WHERE nme='B')::int, false, false);

SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT link_id AS id,source::int4, target::int4, time_ped::float8 AS cost FROM temp_pedestrian_basic_graph_primal', (SELECT entrance_primal FROM geoinfo.sources WHERE nme='A')::int, (SELECT entrance_primal FROM geoinfo.sources WHERE nme='B')::int, false, false);

WITH this_route AS (SELECT seq, id1 AS node, id2 AS edge, cost FROM pgr_dijkstra('SELECT link_id AS id,source::int4, target::int4, time_ped::float8 AS cost FROM temp_pedestrian_basic_graph_primal', (SELECT entrance_primal FROM geoinfo.sources WHERE nme='A')::integer, (SELECT entrance_primal FROM geoinfo.sources WHERE nme='B')::integer, false, false))
INSERT INTO geoinfo.routes_primal (node_id,link_id,dist,od,modality) SELECT node,edge,cost,'A-B','pedestrian' FROM this_route;

-- pedestrian
SELECT _phd_route_test_primal('time_ped','pedestrian','A','B');
SELECT _phd_route_test_primal('time_ped','pedestrian','C','D');
SELECT _phd_route_test_primal('time_ped','pedestrian','E','F');
SELECT _phd_route_test_primal('time_ped','pedestrian','E','S');
SELECT _phd_route_test_primal('time_ped','pedestrian','G','H');
SELECT _phd_route_test_primal('time_ped','pedestrian','A','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','B','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','C','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','D','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','E','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','F','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','S','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','G','T');
SELECT _phd_route_test_primal('time_ped','pedestrian','H','T');

-- pedestrian basic
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','A','B');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','C','D');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','E','F');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','E','S');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','G','H');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','A','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','B','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','C','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','D','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','E','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','F','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','S','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','G','T');
SELECT _phd_route_test_primal('time_ped','pedestrian_basic','H','T');

-- car
SELECT _phd_route_test_primal('time_ped','car','A','B');
SELECT _phd_route_test_primal('time_ped','car','C','D');
SELECT _phd_route_test_primal('time_ped','car','E','F');
SELECT _phd_route_test_primal('time_ped','car','E','S');
SELECT _phd_route_test_primal('time_ped','car','G','H');
SELECT _phd_route_test_primal('time_ped','car','A','T');
SELECT _phd_route_test_primal('time_ped','car','B','T');
SELECT _phd_route_test_primal('time_ped','car','C','T');
SELECT _phd_route_test_primal('time_ped','car','D','T');
SELECT _phd_route_test_primal('time_ped','car','E','T');
SELECT _phd_route_test_primal('time_ped','car','F','T');
SELECT _phd_route_test_primal('time_ped','car','S','T');
SELECT _phd_route_test_primal('time_ped','car','G','T');
SELECT _phd_route_test_primal('time_ped','car','H','T');

-- update geometry column
UPDATE geoinfo.routes_primal a SET the_geom=b.the_geom FROM network.roads_randstad b WHERE a.link_id != -1 AND a.link_id = b.sid;
UPDATE geoinfo.routes_primal a SET the_geom=b.the_geom FROM network.areas_randstad b WHERE a.link_id != -1 AND a.link_id = b.road_sid;

--------------------------------
-- calculate service areas
-- DROP TABLE geoinfo.service_areas_primal CASCADE;
CREATE TABLE geoinfo.service_areas_primal (sid serial NOT NULL PRIMARY KEY, the_nodes geometry(Point, 28992), node_id integer, dist double precision, origin text, modality text, max_dist double precision);
SELECT populate_geometry_columns('geoinfo.service_areas_primal'::regclass,false);
CREATE INDEX service_areas_node_primal_idx ON geoinfo.service_areas_primal (node_id);
-- DELETE FROM geoinfo.service_areas_primal;
-- test
SELECT seq, id1 AS node, cost FROM pgr_drivingDistance('SELECT link_id AS id,source::int4, target::int4, time_ped::float8 AS cost FROM temp_pedestrian_graph_primal', (SELECT entrance_primal FROM geoinfo.sources WHERE nme='A')::integer, 5.0::double precision, false, false);

WITH this_service AS (SELECT seq, id1 AS node_id, cost FROM pgr_drivingDistance('SELECT link_id AS id,source::int4, target::int4, time_ped::float8 AS cost FROM temp_pedestrian_graph_primal', (SELECT entrance_primal FROM geoinfo.sources WHERE nme='A')::integer, 5.0::double precision, false, false))
INSERT INTO geoinfo.service_areas_primal (node_id, dist, origin, modality, max_dist) SELECT node_id,cost,'A','pedestrian', 5.0 FROM this_service;


-- pedestrian
SELECT _phd_service_test_primal('time_ped','pedestrian','A','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','B','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','C','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','D','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','E','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','F','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','G','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','H','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','FF','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','T','5.0');

SELECT _phd_service_test_primal('time_ped','pedestrian','A','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','B','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','C','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','D','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','E','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','F','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','G','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','H','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','FF','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian','T','10.0');

-- pedestrian basic
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','A','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','B','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','C','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','D','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','E','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','F','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','G','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','H','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','FF','5.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','T','5.0');

SELECT _phd_service_test_primal('time_ped','pedestrian_basic','A','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','B','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','C','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','D','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','E','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','F','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','G','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','H','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','FF','10.0');
SELECT _phd_service_test_primal('time_ped','pedestrian_basic','T','10.0');

-- on the car network
SELECT _phd_service_test_primal('time_ped','car','A','5.0');
SELECT _phd_service_test_primal('time_ped','car','B','5.0');
SELECT _phd_service_test_primal('time_ped','car','C','5.0');
SELECT _phd_service_test_primal('time_ped','car','D','5.0');
SELECT _phd_service_test_primal('time_ped','car','E','5.0');
SELECT _phd_service_test_primal('time_ped','car','F','5.0');
SELECT _phd_service_test_primal('time_ped','car','G','5.0');
SELECT _phd_service_test_primal('time_ped','car','H','5.0');
SELECT _phd_service_test_primal('time_ped','car','FF','5.0');
SELECT _phd_service_test_primal('time_ped','car','T','5.0');

SELECT _phd_service_test_primal('time_ped','car','A','10.0');
SELECT _phd_service_test_primal('time_ped','car','B','10.0');
SELECT _phd_service_test_primal('time_ped','car','C','10.0');
SELECT _phd_service_test_primal('time_ped','car','D','10.0');
SELECT _phd_service_test_primal('time_ped','car','E','10.0');
SELECT _phd_service_test_primal('time_ped','car','F','10.0');
SELECT _phd_service_test_primal('time_ped','car','G','10.0');
SELECT _phd_service_test_primal('time_ped','car','H','10.0');
SELECT _phd_service_test_primal('time_ped','car','FF','10.0');
SELECT _phd_service_test_primal('time_ped','car','T','10.0');

-- update geoemetry columns
UPDATE geoinfo.service_areas_primal a SET the_nodes=b.the_geom FROM network.roads_nodes_randstad b WHERE a.node_id = b.sid;

-- add columns for roads and building geometry
ALTER TABLE geoinfo.service_areas_primal ADD COLUMN the_buildings geometry(MultiPolygon, 28992);
ALTER TABLE geoinfo.service_areas_primal ADD COLUMN the_roads geometry(Linestring, 28992);
ALTER TABLE geoinfo.service_areas_primal ADD COLUMN link_id integer;
ALTER TABLE geoinfo.service_areas_primal ADD COLUMN building_id integer;
SELECT populate_geometry_columns('geoinfo.service_areas_primal'::regclass,false);
-- roads
INSERT INTO geoinfo.service_areas_primal (node_id, dist, origin, modality, max_dist, link_id, the_roads) SELECT DISTINCT ON (b.sid,a.origin,a.modality, a.max_dist) a.node_id, a.dist, a.origin, a.modality, a.max_dist, b.sid, b.the_geom FROM geoinfo.service_areas_primal a JOIN network.roads_randstad b ON (a.node_id=b.start_id OR a.node_id=b.end_id) ORDER BY b.sid, a.max_dist ASC;
-- pedestrian areas
INSERT INTO geoinfo.service_areas_primal (node_id, dist, origin, modality, max_dist, link_id, the_roads) SELECT DISTINCT ON (b.road_sid,a.origin,a.modality, a.max_dist) a.node_id, a.dist, a.origin, a.modality, a.max_dist, b.road_sid, b.the_geom FROM geoinfo.service_areas_primal a JOIN network.areas_randstad b ON (a.node_id=b.start_id OR a.node_id=b.end_id) ORDER BY b.road_sid, a.max_dist ASC;
-- buildings
CREATE TEMP TABLE temp_relevant_links AS SELECT target_id, object_mm_id FROM urbanform.buildings_roads_interfaces_randstad WHERE target_id IN (SELECT link_id FROM geoinfo.service_areas_primal WHERE link_id IS NOT NULL);
CREATE TEMP TABLE temp_relevant_buildings AS SELECT * FROM temp_relevant_links aa JOIN urbanform.buildings_randstad bb ON (aa.object_mm_id=bb.multimodal_sid);
INSERT INTO geoinfo.service_areas_primal (node_id, dist, origin, modality, max_dist, building_id, the_buildings) SELECT DISTINCT ON (b.multimodal_sid,a.origin,a.modality, a.max_dist) a.node_id, a.dist, a.origin, a.modality, a.max_dist, b.multimodal_sid, b.the_geom FROM geoinfo.service_areas_primal a JOIN temp_relevant_buildings b ON (a.link_id=b.target_id) ORDER BY b.multimodal_sid, a.max_dist ASC;
-- to undo if necessary
DELETE FROM geoinfo.service_areas_primal WHERE the_roads IS NOT NULL;
DELETE FROM geoinfo.service_areas_primal WHERE the_buildings IS NOT NULL;

-- keeping relevant duplicates
SELECT DISTINCT ON (b.sid,a.origin,a.modality, a.max_dist) a.node_id, a.dist, a.origin, a.modality, a.max_dist, b.sid, b.the_geom FROM geoinfo.service_areas_primal a JOIN network.roads_randstad b ON (a.node_id=b.start_id OR a.node_id=b.end_id) ORDER BY b.sid, a.max_dist ASC;
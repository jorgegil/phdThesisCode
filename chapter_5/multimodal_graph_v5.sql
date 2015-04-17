-- NATIONAL MODEL
-- create multimodal table based on the personal transport modes.
DROP TABLE graph.multimodal CASCADE;
CREATE TABLE graph.multimodal AS SELECT source, target, the_geom, metric, cumangular, axial, continuity_v2, segment, temporal, 
randstad, randstad_code, transfer, car, bicycle, pedestrian FROM graph.roads_dual;
ALTER TABLE graph.multimodal ADD COLUMN sid serial NOT NULL PRIMARY KEY;
ALTER TABLE graph.multimodal ADD COLUMN mobility character varying;
UPDATE graph.multimodal SET mobility='private';

-- add the links from roads to public transport
INSERT INTO graph.multimodal (source, target, the_geom, mobility, transfer, metric, segment, temporal, randstad, randstad_code) 
SELECT multimodal_id, road_id, the_geom, 'public', 1.0, 0.0, 1.0, temporal, randstad, randstad_code FROM network.transit_roads_interfaces;
-- add the links from areas to public transport
INSERT INTO graph.multimodal (source, target, the_geom, mobility, transfer, metric, segment, temporal, randstad, randstad_code) 
SELECT multimodal_id, road_id, the_geom, 'public', 1.0, 0.0, 1.0, temporal, randstad, randstad_code FROM network.transit_areas_interfaces; 

-- update the modes of the above links
ALTER TABLE graph.multimodal ADD COLUMN rail boolean;
ALTER TABLE graph.multimodal ADD COLUMN tram boolean;
ALTER TABLE graph.multimodal ADD COLUMN metro boolean;
ALTER TABLE graph.multimodal ADD COLUMN bus boolean;
ALTER TABLE graph.multimodal ADD COLUMN ferry boolean;

CREATE TEMP TABLE temp_filter AS SELECT multimodal_sid FROM network.transit_stops WHERE network='rail';
UPDATE graph.multimodal SET rail=TRUE WHERE transfer=1 AND mobility='public' AND source IN (SELECT multimodal_sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT multimodal_sid FROM network.transit_stops WHERE network='tram';
UPDATE graph.multimodal SET tram=TRUE WHERE transfer=1 AND mobility='public' AND source IN (SELECT multimodal_sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT multimodal_sid FROM network.transit_stops WHERE network='metro';
UPDATE graph.multimodal SET metro=TRUE WHERE transfer=1 AND mobility='public' AND source IN (SELECT multimodal_sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT multimodal_sid FROM network.transit_stops WHERE network='bus';
UPDATE graph.multimodal SET bus=TRUE WHERE transfer=1 AND mobility='public' AND source IN (SELECT multimodal_sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT multimodal_sid FROM network.transit_stops WHERE network='ferry';
UPDATE graph.multimodal SET ferry=TRUE WHERE transfer=1 AND mobility='public' AND source IN (SELECT multimodal_sid FROM temp_filter); 
DELETE FROM temp_filter;

-- add the transit links and transit interfaces from the transit graph
INSERT INTO graph.multimodal (source, target, the_geom, mobility, transfer, metric, segment, temporal, ferry, bus, tram, metro, rail, randstad, randstad_code) SELECT source, target, the_geom, 'public', transfer, length, 1.0, temporal, ferry, bus, tram, metro, rail, randstad, randstad_code FROM graph.transit_multimodal;

-- add the links from roads to buildings
INSERT INTO graph.multimodal (source, target, the_geom, pedestrian, mobility, transfer, metric, cumangular, axial, continuity_v2, segment, temporal, randstad, randstad_code) SELECT object_mm_id, target_id, the_geom, True, 'building', 1.0, length, 1.0, 1.0, 1.0, 1.0, 1.0, randstad, randstad_code FROM urbanform.buildings_roads_interfaces;
-- add the links from area segments, to areas to buildings
INSERT INTO graph.multimodal (source, target, the_geom, pedestrian, mobility, transfer, metric, cumangular, axial, continuity_v2, segment, temporal, randstad, randstad_code) SELECT intr.object_mm_id, ar.road_sid, ST_MakeLine( ST_StartPoint(intr.the_geom), ar.the_point), True, 'building', 1.0, ST_Distance( ST_StartPoint(intr.the_geom), ar.the_point), 1.0, 1.0, 1.0, 1.0, 1.0, intr.randstad, intr.randstad_code FROM network.areas as ar JOIN urbanform.buildings_areas_interfaces as intr ON (ar.group_id=intr.target_id);

UPDATE graph.multimodal SET transfer=0 WHERE transfer IS NULL;
UPDATE graph.multimodal SET metric=0 WHERE metric IS NULL;
UPDATE graph.multimodal SET segment=0 WHERE segment IS NULL;
UPDATE graph.multimodal SET cumangular=0 WHERE cumangular IS NULL;
UPDATE graph.multimodal SET continuity_v2=0 WHERE continuity_v2 IS NULL;
UPDATE graph.multimodal SET axial=0 WHERE axial IS NULL;
UPDATE graph.multimodal SET temporal=0 WHERE axial IS NULL;

CREATE INDEX multimodal_geom_idx ON graph.multimodal USING GIST (the_geom);
CREATE INDEX multimodal_source_idx ON graph.multimodal (source);
CREATE INDEX multimodal_target_idx ON graph.multimodal (target);
CREATE INDEX multimodal_transfer_idx ON graph.multimodal (transfer);
CREATE INDEX multimodal_mobility_idx ON graph.multimodal (mobility);
CREATE INDEX multimodal_rail_idx ON graph.multimodal (rail);
CREATE INDEX multimodal_tram_idx ON graph.multimodal (tram);
CREATE INDEX multimodal_metro_idx ON graph.multimodal (metro);
CREATE INDEX multimodal_bus_idx ON graph.multimodal (bus);
CREATE INDEX multimodal_ferry_idx ON graph.multimodal (ferry);
CREATE INDEX multimodal_car_idx ON graph.multimodal (car);
CREATE INDEX multimodal_pedestrian_idx ON graph.multimodal (pedestrian);
CREATE INDEX multimodal_bicycle_idx ON graph.multimodal (bicycle);
CREATE INDEX multimodal_randstad_idx ON graph.multimodal (randstad);
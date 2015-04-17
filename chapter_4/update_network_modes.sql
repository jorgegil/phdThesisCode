UPDATE network.roads SET car=NULL, bicycle=NULL, pedestrian=NULL;

UPDATE network.roads SET car=True WHERE main=True;
UPDATE network.roads SET car=False WHERE road_type in ('footway','pedestrian','steps','walkway','cycleway','moped_link','cycleway;service','closed','local'
,'path','track','bridleway','crossing','access','ford','trail','dog track','construction','Molenpad');
UPDATE network.roads SET pedestrian=True WHERE road_type in ('footway','pedestrian','living_street','walkway','steps');
UPDATE network.roads SET bicycle=True WHERE road_type in ('cycleway','living_street','moped_link','cycleway;service','local','closed');
UPDATE network.roads SET pedestrian=False, bicycle=False WHERE motorway=TRUE OR road_type in ('construction','Molenpad');
UPDATE network.roads set bicycle=NULL, pedestrian=NULL WHERE road_class in ('S','s') AND motorway IS NULL AND unlink<>'tunnel';

UPDATE network.roads SET bicycle=True WHERE (bicycle = False OR bicycle is NULL) AND ((tags->'bicycle') in ('designated','official','lane','bycicleway','primary')  OR (tags->'cycleway') in ('lane', 'track', 'segregated', 'cyclestreet', 'path'));
UPDATE network.roads SET bicycle=NULL WHERE bicycle = False AND ((tags->'bicycle') in ('yes','y')  OR (tags->'cycleway') in ('opposite', 'opposite_lane', 'shared', 'shared_lane', 'opposite_track')  OR (tags->'route')='bicycle');
UPDATE network.roads SET pedestrian=True WHERE (pedestrian =False OR pedestrian is NULL) AND  ((tags->'route')='walking' OR (tags->'foot') in ('yes', 'designated')  OR (tags->'footway') in ('yes','sidewalk'));
UPDATE network.roads SET pedestrian=NULL WHERE pedestrian = False AND (tags->'foot') in ('permissive', 'destination', 'private');
UPDATE network.roads SET car= True WHERE (car = False OR car IS NULL) AND  ((tags->'motorcar') in ('yes', 'designated') OR (tags->'motor_vehicle') in ('yes','designated'));
UPDATE network.roads SET car= NULL WHERE car = False AND ((tags->'motorcar') in ('permissive', 'destination', 'private')  OR (tags->'motor_vehicle') in ('permissive', 'destination', 'private'));

UPDATE network.roads SET car=False, pedestrian=False, bicycle=False WHERE road_type='service' AND open_access in ('private','no','forestry','agricultural');

-- redo primal graph
DROP TABLE graph.roads_primal CASCADE;
CREATE TABLE graph.roads_primal AS SELECT sid link_id, start_id source, end_id target, ST_MakeLine(startpoint,endpoint) the_geom, x1, y1, x2, y2, randstad, randstad_code,
 length, cumul_angle, delta_angle, cont_angle, axial_topo, axialv2_topo, cont_topo, contv2_topo, contv3_topo, segment_topo, time_dist, car, pedestrian, bicycle FROM network.roads;
INSERT INTO graph.roads_primal SELECT road_sid, start_id, end_id, the_geom, x1, y1, x2, y2, randstad, randstad_code, length, 0, 0, 0, 0, 0, 0, 0, 0,  segment_topo, time_dist, False, True, True FROM network.areas;  
DELETE FROM graph.roads_primal WHERE source IS NULL OR target IS NULL;
ALTER TABLE graph.roads_primal ADD COLUMN sid serial NOT NULL;
ALTER TABLE graph.roads_primal ADD CONSTRAINT roads_primal_pk PRIMARY KEY(sid);
CREATE INDEX roads_primal_geom_idx ON graph.roads_primal USING GIST(the_geom);
CREATE INDEX roads_primal_idx ON graph.roads_primal (sid);
CREATE INDEX roads_primal_source_idx ON graph.roads_primal (source);
CREATE INDEX roads_primal_target_idx ON graph.roads_primal (target);

-- update dual graph
ALTER TABLE graph.roads_dual DROP COLUMN car;
ALTER TABLE graph.roads_dual DROP COLUMN bicycle;
ALTER TABLE graph.roads_dual DROP COLUMN pedestrian;
ALTER TABLE graph.roads_dual ADD COLUMN car boolean;
ALTER TABLE graph.roads_dual ADD COLUMN bicycle boolean;
ALTER TABLE graph.roads_dual ADD COLUMN pedestrian boolean;
CREATE TEMP TABLE temp_filter AS SELECT sid FROM network.roads WHERE car=False;
UPDATE graph.roads_dual SET car=False WHERE source IN (SELECT sid FROM temp_filter) OR target IN (SELECT sid FROM temp_filter);
UPDATE graph.roads_dual SET car=False WHERE source IN (SELECT road_sid FROM network.areas) OR target IN (SELECT road_sid FROM network.areas);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT sid FROM network.roads WHERE car=True;
UPDATE graph.roads_dual SET car=True WHERE source IN (SELECT sid FROM temp_filter) AND target IN (SELECT sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT sid FROM network.roads WHERE pedestrian=False;
UPDATE graph.roads_dual as gr SET pedestrian=False WHERE source IN (SELECT sid FROM temp_filter) OR target IN (SELECT sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT sid FROM network.roads WHERE pedestrian=True;
UPDATE graph.roads_dual as gr SET pedestrian=True WHERE source IN (SELECT sid FROM temp_filter) AND target IN (SELECT sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT sid FROM network.roads WHERE bicycle=False;
UPDATE graph.roads_dual as gr SET bicycle=False WHERE source IN (SELECT sid FROM temp_filter) OR target IN (SELECT sid FROM temp_filter);
DELETE FROM temp_filter;
INSERT INTO temp_filter SELECT sid FROM network.roads WHERE bicycle=True;
UPDATE graph.roads_dual as gr SET bicycle=True WHERE source IN (SELECT sid FROM temp_filter) AND target IN (SELECT sid FROM temp_filter);
UPDATE graph.roads_dual as gr SET pedestrian=True, bicycle=True FROM network.areas as rd1, network.areas as rd2  WHERE gr.source=rd1.road_sid OR gr.target=rd2.road_sid;
UPDATE graph.roads_dual SET transfer=1.0 WHERE coalesce(pedestrian,True) <> coalesce(bicycle,True) OR coalesce(pedestrian,True) <> coalesce(car,True) OR coalesce(car,True) <> coalesce(bicycle,True); 

--redo multimodal graph


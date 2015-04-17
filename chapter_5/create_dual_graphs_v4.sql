-- links between normal segments
CREATE TABLE graph.roads_dual AS SELECT b.sid source, c.sid target, abs((b.azimuth_start-180)-c.azimuth_end) angular  FROM network.roads AS b, network.roads AS c  WHERE b.start_id IS NOT NULL AND b.start_id=c.end_id AND b.sid<>c.sid;  
INSERT INTO graph.roads_dual SELECT b.sid source, c.sid target, abs((b.azimuth_start-180)-c.azimuth_start) angular FROM network.roads AS b, network.roads AS c  WHERE b.start_id IS NOT NULL AND b.start_id=c.start_id AND b.sid<>c.sid;
INSERT INTO graph.roads_dual SELECT b.sid source, c.sid target, abs((b.azimuth_end-180)-c.azimuth_end) angular FROM network.roads AS b, network.roads AS c  WHERE b.end_id IS NOT NULL AND b.end_id=c.end_id AND b.sid<>c.sid;
INSERT INTO graph.roads_dual SELECT b.sid source, c.sid target, abs((b.azimuth_end-180)-c.azimuth_start) angular FROM network.roads AS b, network.roads AS c  WHERE b.end_id IS NOT NULL AND b.end_id=c.start_id AND b.sid<>c.sid;
--Add the geometry column for normal links:
ALTER TABLE graph.roads_dual ADD COLUMN the_geom geometry;
UPDATE graph.roads_dual as g SET the_geom = ST_MakeLine(a.the_point, b.the_point) FROM network.roads as a, network.roads as b WHERE a.sid=g.source AND b.sid=g.target;

-- Create links between pedestrian areas and road segments:
INSERT INTO graph.roads_dual SELECT b.sid source, c.road_sid target, abs((b.azimuth_end-180)-c.azimuth_start) angular FROM network.roads AS b, network.areas AS c  WHERE b.end_id IS NOT NULL AND b.end_id=c.start_id;
INSERT INTO graph.roads_dual SELECT b.sid source, c.road_sid target, abs((b.azimuth_start-180)-c.azimuth_start) angular FROM network.roads AS b, network.areas AS c  WHERE b.start_id IS NOT NULL AND b.start_id=c.start_id;
INSERT INTO graph.roads_dual SELECT b.sid source, c.road_sid target, abs((b.azimuth_end-180)-c.azimuth_end) angular FROM network.roads AS b, network.areas AS c  WHERE b.end_id IS NOT NULL AND b.end_id=c.end_id;
INSERT INTO graph.roads_dual SELECT b.sid source, c.road_sid target, abs((b.azimuth_start-180)-c.azimuth_end) angular FROM network.roads AS b, network.areas AS c  WHERE b.start_id IS NOT NULL AND b.start_id=c.end_id;
--Add the geometry for pedestrian areas. This geometry is just for visualisation:
UPDATE graph.roads_dual as g SET the_geom=ST_MakeLine(a.the_point,b.the_point) FROM network.roads as a, network.areas as b WHERE g.the_geom IS NULL AND a.sid=g.source AND b.road_sid=g.target;

--I need to make sure that all angles are within a reasonable range and that there are no negative values
UPDATE graph.roads_dual SET angular=abs(360-angular) WHERE angular>180;
UPDATE graph.roads_dual SET angular=abs(angular) WHERE angular<0;
CREATE INDEX roads_dual_source_idx ON graph.roads_dual (source);
CREATE INDEX roads_dual_target_idx ON graph.roads_dual (target);

--If for some reason I update the attributes of the segments and need to recalculate the angle this is the query:
--UPDATE graph.roads_dual as dua SET angular=abs((b.azimuth_start-180)-c.azimuth_end)  FROM network.roads as b, network.roads as c WHERE dua.angular IS NULL AND dua.start_id=b.sid AND dua.end_id=c.sid;

--Add new columns for remaining cost attributes:
ALTER TABLE graph.roads_dual ADD COLUMN sid serial NOT NULL;
ALTER TABLE graph.roads_dual ADD COLUMN metric double precision;
ALTER TABLE graph.roads_dual ADD COLUMN segment integer;
ALTER TABLE graph.roads_dual ADD COLUMN cumangular double precision;
ALTER TABLE graph.roads_dual ADD COLUMN axial double precision;
ALTER TABLE graph.roads_dual ADD COLUMN axial_v2 double precision;
ALTER TABLE graph.roads_dual ADD COLUMN continuity double precision;
ALTER TABLE graph.roads_dual ADD COLUMN continuity_v2 double precision;
ALTER TABLE graph.roads_dual ADD COLUMN continuity_v3 double precision;

--Add the important primary key and indices:
ALTER TABLE graph.roads_dual ADD CONSTRAINT roads_dual_pk PRIMARY KEY(sid);
CREATE INDEX roads_dual_idx ON graph.roads_dual (sid);
CREATE INDEX roads_dual_geom_idx ON graph.roads_dual USING GIST (the_geom);

--Make it an undirected graph:
--SELECT _phd_makeundirected('graph.roads_dual','start_id', 'end_id');
CREATE TABLE temp.roads_dual_final AS SELECT DISTINCT ON (the_geom) * FROM graph.roads_dual;
DELETE FROM graph.roads_dual WHERE sid NOT IN (SELECT sid FROM temp.roads_dual_final);
DROP TABLE temp.roads_dual_final CASCADE;

--Calculate the distance weights, for the normal segments:
UPDATE graph.roads_dual as g SET metric=(a.length/2)+(b.length/2), segment=(a.segment_topo/2)+(b.segment_topo/2), cumangular=angular+(a.cumul_angle/2)+(b.cumul_angle/2), axial =  (a.axial_topo/2) + (b.axial_topo/2), continuity = (a.cont_topo/2) + (b.cont_topo/2), continuity_v2 = (a.contv2_topo/2) + (b.contv2_topo/2) 
	FROM network.roads as a, network.roads as b WHERE a.sid=g.source AND b.sid=g.target;
UPDATE graph.roads_dual as g SET axial_v2 = (a.axialv2_topo/2) + (b.axialv2_topo/2), continuity_v3 = (a.contv3_topo/2) + (b.contv3_topo/2) 
	FROM network.roads as a, network.roads as b WHERE a.sid=g.source AND b.sid=g.target;
--UPDATE graph.roads_dual as g SET axial_v2 = (coalesce(a.axialv2_topo,0.0)/2) + (coalesce(b.axialv2_topo,0.0)/2), continuity_v3 = (coalesce(a.contv3_topo,0.0)/2) + (coalesce(b.contv3_topo,0.0)/2) FROM network.roads as a, network.roads as b WHERE a.sid=g.source AND b.sid=g.target;
--And for the pedestrian area segments:
UPDATE graph.roads_dual as g SET metric=(a.length/2)+(b.length/2), segment=(a.segment_topo/2)+(b.segment_topo/2), cumangular=angular+(a.cumul_angle/2), axial= (a.axial_topo/2), continuity = (a.cont_topo/2), continuity_v2 = (a.contv2_topo/2) 
	FROM network.roads as a, network.areas as b WHERE a.sid=g.source AND b.road_sid=g.target;
UPDATE graph.roads_dual as g SET axial_v2= (a.axialv2_topo/2), continuity_v3 = (a.contv3_topo/2) 
	FROM network.roads as a, network.areas as b WHERE a.sid=g.source AND b.road_sid=g.target;
--UPDATE graph.roads_dual as g SET axial_v2= (coalesce(a.axialv2_topo,0.0)/2), continuity_v3 = (coalesce(a.contv3_topo,0.0)/2) FROM network.roads as a, network.areas as b WHERE a.sid=g.source AND b.road_sid=g.target;

--Finalise distance weights:
UPDATE graph.roads_dual SET axial= axial+1.0 WHERE angular>15;
UPDATE graph.roads_dual SET continuity=continuity+1.0, continuity_v3= continuity_v3+1.0 WHERE angular>30.0;
UPDATE graph.roads_dual SET continuity_v2= continuity_v2+1.0 WHERE angular>45.0;
UPDATE graph.roads_dual SET axial_v2= axial_v2+1.0 WHERE angular>5.0;

-- add modes and additional columns
ALTER TABLE graph.roads_dual ADD COLUMN car boolean;
ALTER TABLE graph.roads_dual ADD COLUMN pedestrian boolean;
ALTER TABLE graph.roads_dual ADD COLUMN bicycle boolean;
ALTER TABLE graph.roads_dual ADD COLUMN service boolean;
ALTER TABLE graph.roads_dual ADD COLUMN transfer double precision;

UPDATE graph.roads_dual as gr SET car=False FROM network.roads as rd1, network.roads as rd2
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.car='no' OR rd2.car='no');
UPDATE graph.roads_dual as gr SET car=False FROM network.areas as rd1, network.areas as rd2
WHERE gr.source=rd1.road_sid OR gr.target=rd2.road_sid;
UPDATE graph.roads_dual as gr SET car=True FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.car='yes' OR rd2.car='yes');

UPDATE graph.roads_dual as gr SET pedestrian=False FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.pedestrian='no' OR rd2.pedestrian='no');
UPDATE graph.roads_dual as gr SET pedestrian=True FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.pedestrian='yes' OR rd2.pedestrian='yes');

UPDATE graph.roads_dual as gr SET bicycle=False FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.bicycle='no' OR rd2.bicycle='no');
UPDATE graph.roads_dual as gr SET bicycle=True FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.bicycle='yes' OR rd2.bicycle='yes'); 

UPDATE graph.roads_dual as gr SET service=True FROM network.roads as rd1, network.roads as rd2 
WHERE gr.source=rd1.sid AND gr.target=rd2.sid AND (rd1.road_type='service' OR rd2.road_type='service');

UPDATE graph.roads_dual SET transfer=1.0 WHERE coalesce(pedestrian,True) <> coalesce(bicycle,True) OR coalesce(pedestrian,True) <> coalesce(car,True) OR coalesce(car,True) <> coalesce(bicycle,True);

CREATE INDEX roads_dual_car_idx ON graph.roads_dual (car);
CREATE INDEX roads_dual_pedestrian_idx ON graph.roads_dual (pedestrian);
CREATE INDEX roads_dual_bicycle_idx ON graph.roads_dual (bicycle);
CREATE INDEX roads_dual_service_idx ON graph.roads_dual (service);

UPDATE graph.roads_dual SET car=NULL, pedestrian=NULL, bicycle=NULL WHERE service=True;
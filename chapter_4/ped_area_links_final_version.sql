-- identify inner crossings
CREATE TABLE temp.roads_cross_areas AS SELECT road.*, area.sid as area_id 
FROM network.roads as road, urbanform.pedestrian_areas as area 
WHERE ST_Crosses(road.the_geom,area.the_geom) OR (ST_Touches(road.the_geom,area.the_geom) 
AND NOT ST_Contains(area.the_geom,road.the_geom));

CREATE TABLE temp.roads_crossings_internal_areas AS SELECT cros.*, area.sid as area_id 
FROM network.roads_nodes as cros, urbanform.pedestrian_areas as area 
WHERE ST_Intersects(cros.the_geom, area.the_geom) AND (cros.count<>2 OR (cros.count=2 AND cros.modes>1)) AND 
(cros.sid IN (SELECT start_id FROM temp.roads_cross_areas) OR cros.sid IN (SELECT end_id FROM temp.roads_cross_areas));

-- identify outer crossings
--DROP TABLE temp.roads_links_outer_areas CASCADE;
CREATE TABLE temp.roads_links_outer_areas AS 
SELECT area.sid area_id, cros.sid node_id, ST_ShortestLine(area.the_geom, cros.the_geom) the_geom 
FROM urbanform.pedestrian_areas AS area, network.roads_nodes as cros 
WHERE (cros.count<>2 OR (cros.count=2 AND cros.modes>1))  AND NOT ST_Intersects(area.the_geom,cros.the_geom) 
AND ST_DWithin(area.the_geom,cros.the_geom,25);

ALTER TABLE temp.roads_links_outer_areas ADD COLUMN sid serial NOT NULL;
CREATE INDEX roads_links_outer_areas_gist ON temp.roads_links_outer_areas USING gist (the_geom);

CREATE TABLE temp.roads_links_outer_areas_false AS SELECT link.* 
FROM temp.roads_links_outer_areas as link, urbanform.buildings as bld 
WHERE ST_Crosses(link.the_geom, bld.the_geom);
DELETE FROM temp.roads_links_outer_areas WHERE sid IN (SELECT sid FROM temp.roads_links_outer_areas_false);

DROP TABLE temp.roads_links_outer_areas_false CASCADE;
CREATE TABLE temp.roads_links_outer_areas_false AS SELECT link.* 
FROM temp.roads_links_outer_areas as link, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat 
WHERE ST_Crosses(link.the_geom, wat.the_geom);
DELETE FROM temp.roads_links_outer_areas WHERE sid IN (SELECT sid FROM temp.roads_links_outer_areas_false);

CREATE TABLE temp.roads_intersect_areas AS SELECT road.*, area.sid area_id 
FROM network.roads as road, urbanform.pedestrian_areas as area WHERE ST_Intersects(road.the_geom,area.the_geom);

DROP TABLE temp.roads_links_outer_areas_false CASCADE;
CREATE TABLE temp.roads_links_outer_areas_false AS SELECT link.* 
FROM temp.roads_links_outer_areas as link, network.roads as road 
WHERE ST_Crosses(link.the_geom, road.the_geom) 
AND link.area_id||'_'||road.sid NOT IN  (SELECT area_id||'_'||sid FROM temp.roads_intersect_areas);
DELETE FROM temp.roads_links_outer_areas WHERE sid IN (SELECT sid FROM temp.roads_links_outer_areas_false);

DROP TABLE temp.roads_links_outer_areas_false CASCADE;
CREATE TABLE temp.roads_links_outer_areas_false AS SELECT link.* F
ROM temp.roads_links_outer_areas as link, temp.roads_crossings_internal_areas as cros 
WHERE link.area_id=cros.area_id AND link.node_id<>cros.sid 
AND (link.node_id||'_'||cros.sid IN (SELECT start_id||'_'||end_id FROM network.roads) 
OR cros.sid||'_'||link.node_id IN (SELECT start_id||'_'||end_id FROM network.roads));
DELETE FROM temp.roads_links_outer_areas WHERE sid IN (SELECT sid FROM temp.roads_links_outer_areas_false);

CREATE TABLE temp.roads_crossings_outer_areas AS SELECT cros.*, link.area_id 
FROM network.roads_nodes as cros, temp.roads_links_outer_areas as link WHERE cros.sid=link.node_id;

-- prepare all crossings to link
DROP TABLE temp.roads_crossings_areas_to_link CASCADE;
CREATE TABLE temp.roads_crossings_areas_to_link AS SELECT * FROM temp.roads_crossings_internal_areas;
INSERT INTO temp.roads_crossings_areas_to_link SELECT * FROM temp.roads_crossings_outer_areas;

-- create all links between inner and outer crossings
DROP TABLE temp.pedestrian_areas_links CASCADE;
SELECT _phd_link_all_points_by_id('temp.roads_crossings_areas_to_link', 'the_geom', 'sid', 'area_id', 'temp.pedestrian_areas_links');
CREATE INDEX pedestrian_areas_links_geom_idx ON temp.pedestrian_areas_links USING GIST (the_geom);

-- eliminate invalid links
DROP TABLE temp.links_areas_false CASCADE;
CREATE TABLE temp.links_areas_false AS SELECT link.* 
FROM temp.pedestrian_areas_links as link, urbanform.buildings as bld 
WHERE (link.group_id||'_'||link.start_id IN (SELECT area_id||'_'||sid FROM temp.roads_crossings_outer_areas) 
OR link.group_id||'_'||link.end_id IN (SELECT area_id||'_'||sid FROM temp.roads_crossings_outer_areas) ) 
AND  ST_Crosses(link.the_geom, bld.the_geom);
DELETE FROM temp.pedestrian_areas_links WHERE sid IN (SELECT sid FROM temp.links_areas_false); 

DROP TABLE temp.links_areas_false CASCADE;
CREATE TABLE temp.links_areas_false AS SELECT link.* 
FROM temp.pedestrian_areas_links as link, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat 
WHERE (link.group_id||'_'||link.start_id IN (SELECT area_id||'_'||sid FROM temp.roads_crossings_outer_areas) 
OR link.group_id||'_'||link.end_id IN (SELECT area_id||'_'||sid FROM temp.roads_crossings_outer_areas) ) 
AND ST_Crosses(link.the_geom, wat.the_geom);
DELETE FROM temp.pedestrian_areas_links WHERE sid IN (SELECT sid FROM temp.links_areas_false); 

DROP TABLE temp.links_areas_false CASCADE;
CREATE TABLE temp.links_areas_false AS SELECT link.* FROM temp.pedestrian_areas_links as link, network.roads as road 
WHERE ST_Crosses(link.the_geom, road.the_geom) 
AND link.group_id||'_'||road.sid NOT IN  (SELECT area_id||'_'||sid FROM temp.roads_intersect_areas);
DELETE FROM temp.pedestrian_areas_links WHERE sid IN (SELECT sid FROM temp.links_areas_false); 

DROP TABLE temp.links_areas_false CASCADE;
CREATE TABLE temp.links_areas_false AS SELECT link.* FROM temp.pedestrian_areas_links as link, urbanform.pedestrian_areas as area 
WHERE link.group_id=area.sid AND (NOT ST_Crosses(link.the_geom, area.the_geom) 
AND NOT ST_Within(link.the_geom, area.the_geom));
DELETE FROM temp.pedestrian_areas_links WHERE sid IN (SELECT sid FROM temp.links_areas_false); 

CREATE INDEX roads_start_idx ON network.roads (start_id);
CREATE INDEX roads_end_idx ON network.roads (end_id);

DROP TABLE temp.links_areas_false CASCADE;
CREATE TABLE temp.links_areas_false AS SELECT link.* FROM temp.pedestrian_areas_links as link, network.roads as road 
WHERE (link.start_id=road.start_id AND link.end_id=road.end_id) 
OR (link.start_id=road.end_id AND link.end_id=road.start_id);
DELETE FROM temp.pedestrian_areas_links WHERE sid IN (SELECT sid FROM temp.links_areas_false); 

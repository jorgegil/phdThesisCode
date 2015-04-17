-- FIX stops that only connect to the motorway network
DROP TABLE temp.fix_stops_ped_interface CASCADE;
CREATE TABLE temp.fix_stops_ped_interface AS SELECT * FROM network.transit_stops WHERE sid IN 
(SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NOT NULL AND road_id IN 
(SELECT sid FROM network.roads WHERE motorway=TRUE)) AND sid NOT IN
(SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NOT NULL AND road_id IN 
(SELECT sid FROM network.roads WHERE pedestrian=TRUE or pedestrian IS NULL or bicycle=TRUE or bicycle IS NULL));

--
DROP TABLE temp.transit_roads_interfaces_new CASCADE;
DROP TABLE temp.transit_stops_missing CASCADE;

-- (car=True or car IS NULL) OR (bicycle=True or bicycle IS NULL) OR (pedestrian=True or pedestrian)
CREATE TEMP TABLE temp_roads_access AS SELECT * FROM network.roads
WHERE (pedestrian=True or pedestrian IS NULL OR bicycle=True or bicycle IS NULL);
CREATE INDEX temp_roads_acess_idx ON temp_roads_access USING GIST (the_geom);

--1. 	Link all stops to roads within 50 m
CREATE TABLE temp.transit_roads_interfaces_new AS 
--INSERT INTO temp.transit_roads_interfaces_new  
SELECT stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.fix_stops_ped_interface AS stp, temp_roads_access AS rd 
WHERE ST_DWithin(stp.the_geom, rd.the_geom,50);
ALTER TABLE temp.transit_roads_interfaces_new ADD COLUMN sid serial NOT NULL;
CREATE INDEX transit_roads_interfaces_new_idx ON temp.transit_roads_interfaces_new USING GIST (the_geom);
--2.	Remove links crossing buildings, waterways and joining endpoints
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, urbanform.buildings as bld WHERE ST_Intersects(tmp.the_geom,bld.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat WHERE ST_Intersects(tmp.the_geom,wat.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, temp_roads_access as road WHERE tmp.road_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));
--3.	Identify stops without link
INSERT INTO network.transit_roads_interfaces SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
CREATE TABLE temp.transit_stops_missing AS SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);
--INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);


--4.	Link remaining stops to roads within 50 m, relax buildings
INSERT INTO temp.transit_roads_interfaces_new 
SELECT stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.transit_stops_missing AS stp, temp_roads_access AS rd 
WHERE ST_DWithin(stp.the_geom, rd.the_geom,50);
DELETE FROM temp.transit_stops_missing;
--5.	Remove links crossing waterways and joining endpoints
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat WHERE ST_Intersects(tmp.the_geom,wat.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, temp_roads_access as road WHERE tmp.road_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));
--6.	Identify stops without link
INSERT INTO network.transit_roads_interfaces SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);


--7. 	Link all stops to roads within 100 m relax nothing
INSERT INTO temp.transit_roads_interfaces_new  
SELECT stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.transit_stops_missing AS stp, temp_roads_access AS rd 
WHERE ST_DWithin(stp.the_geom, rd.the_geom,100);
DELETE FROM temp.transit_stops_missing;
--8.	Remove links crossing buildings, waterways and joining endpoints
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, urbanform.buildings as bld WHERE ST_Intersects(tmp.the_geom,bld.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat WHERE ST_Intersects(tmp.the_geom,wat.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, temp_roads_access as road WHERE tmp.road_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));
--9.	Identify stops without link
INSERT INTO network.transit_roads_interfaces SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);


--10.	Link remaining stops to roads within 50 m, relax water
INSERT INTO temp.transit_roads_interfaces_new 
SELECT stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.transit_stops_missing AS stp, temp_roads_access AS rd 
WHERE ST_DWithin(stp.the_geom, rd.the_geom,50);
DELETE FROM temp.transit_stops_missing;
--11.	Remove links to endpoints of lines
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, temp_roads_access as road WHERE tmp.road_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));
--12.	Identify stops without link
INSERT INTO network.transit_roads_interfaces SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);


--13.	Link remaining stops to roads within 50 m, relax segment endpoints
INSERT INTO temp.transit_roads_interfaces_new 
SELECT stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.transit_stops_missing AS stp, temp_roads_access AS rd 
WHERE ST_DWithin(stp.the_geom, rd.the_geom,50);
DELETE FROM temp.transit_stops_missing;
--14.	Remove links crossing buildings and waterways
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, urbanform.buildings as bld WHERE ST_Intersects(tmp.the_geom,bld.the_geom));
DELETE FROM temp.transit_roads_interfaces_new WHERE sid IN ( SELECT DISTINCT tmp.sid FROM temp.transit_roads_interfaces_new as tmp, (SELECT * FROM urbanform.water WHERE circulation IS NULL) as wat WHERE ST_Intersects(tmp.the_geom,wat.the_geom));
--16.	Identify stops without link
INSERT INTO network.transit_roads_interfaces SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);


--17.	Link remaining stops to single nearest segment, relax all
INSERT INTO temp.transit_roads_interfaces_new 
SELECT DISTINCT ON (stp.sid) stp.sid stop_id, rd.sid road_id, ST_ShortestLine(stp.the_geom, rd.the_geom) the_geom 
FROM temp.transit_stops_missing AS stp, temp_roads_access AS rd  
WHERE ST_DWithin(stp.the_geom,rd.the_geom,200) 
ORDER BY stop_id, ST_Distance(stp.the_geom, rd.the_geom) ASC;
DELETE FROM temp.transit_stops_missing;
--18.	Identify stops without link
INSERT INTO network.transit_roads_interfaces (stop_id, road_id, the_geom) SELECT stop_id, road_id, the_geom FROM temp.transit_roads_interfaces_new;
DELETE FROM temp.transit_roads_interfaces_new;
INSERT INTO temp.transit_stops_missing SELECT * FROM temp.fix_stops_ped_interface WHERE sid NOT IN (SELECT stop_id FROM network.transit_roads_interfaces WHERE multimodal_id IS NULL);

--Done as part of building the multimodal graph
UPDATE network.transit_roads_interfaces as lnk SET multimodal_id=stp.multimodal_sid 
FROM network.transit_stops as stp WHERE lnk.multimodal_id IS NULL AND lnk.stop_id=stp.sid;  

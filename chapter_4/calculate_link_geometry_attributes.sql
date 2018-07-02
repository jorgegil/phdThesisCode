-- NATIONAL MODEL
-- calculate road segment link geometric attributes

ALTER TABLE network.roads ADD COLUMN length double precision;
UPDATE network.roads SET length = ST_Length(the_geom);

-- Time, given in minutes. In the code below speed is in metres/minute, converted from km/h using m/m=(x/60)*1000
ALTER TABLE network.roads ADD COLUMN time_dist double precision;
ALTER TABLE network.roads ADD COLUMN time_ped double precision;
ALTER TABLE network.roads ADD COLUMN time_bike double precision;
UPDATE network.roads SET time_dist = length/1000::float WHERE car = ‘yes’;
UPDATE network.roads SET time_dist = length/250::float WHERE bicycle = ‘yes’;
UPDATE network.roads SET time_dist = length/83::float WHERE pedestrian = ‘yes’;
UPDATE network.roads SET time_dist = length/666::float WHERE time_dist IS NULL;
UPDATE network.roads SET time_ped = length/83.0;
UPDATE network.roads SET time_bike = CASE WHEN pedestrian=True THEN length/125.0 ELSE length/250.0 END;

-- Segment topology
ALTER TABLE network.roads ADD COLUMN segment_topo integer;
UPDATE network.roads SET segment_topo=0 WHERE length<=5.0;
UPDATE network.roads SET segment_topo=1 WHERE length>5.0;

-- Azimuth
ALTER TABLE network.roads ADD COLUMN azimuth_start double precision;
UPDATE network.roads SET azimuth_start = degrees(ST_Azimuth( ST_StartPoint(the_geom) , ST_PointN(the_geom,2)));
-- Some road segment lines have coincident end points or start points and the azimuth result is null. The update command needs to be repeated for these moving back in the list of points.
UPDATE network.roads SET azimuth_start =  degrees(ST_Azimuth( ST_StartPoint(the_geom) , ST_PointN(the_geom,3))) WHERE azimuth_start IS NULL AND ST_Equals(ST_StartPoint(the_geom) , ST_PointN(the_geom,2));
-- The same is done for end points
ALTER TABLE network.roads ADD COLUMN azimuth_end double precision;
UPDATE network.roads SET azimuth_end =  degrees(ST_Azimuth( ST_EndPoint(the_geom) , ST_PointN(the_geom , ST_Npoints(the_geom)-1)));
UPDATE network.roads SET azimuth_end =  degrees(ST_Azimuth( ST_EndPoint(the_geom) , ST_PointN(the_geom , ST_Npoints(the_geom)-2))) where azimuth_end IS NULL AND ST_Equals(ST_EndPoint(the_geom) , ST_PointN(the_geom , ST_Npoints(the_geom)-1)); 
UPDATE network.roads SET azimuth_end =  degrees(ST_Azimuth( ST_EndPoint(the_geom) , ST_PointN(the_geom , ST_Npoints(the_geom)-3))) where azimuth_end IS NULL AND ST_Equals(ST_EndPoint(the_geom) , ST_PointN(the_geom , ST_Npoints(the_geom)-2)); 

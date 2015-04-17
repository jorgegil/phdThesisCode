ALTER TABLE network.transit_links ADD COLUMN temporal double precision;
ALTER TABLE network.transit_roads_interfaces ADD COLUMN temporal double precision;
ALTER TABLE network.transit_areas_interfaces ADD COLUMN temporal double precision;
ALTER TABLE network.transit_interfaces ADD COLUMN temporal double precision;

UPDATE network.transit_links SET temporal = length/1333::float WHERE network='rail';
UPDATE network.transit_links SET temporal = length/416::float WHERE network='tram';
UPDATE network.transit_links SET temporal = length/500::float WHERE network='metro';
UPDATE network.transit_links SET temporal = length/500::float WHERE network='bus';
UPDATE network.transit_links SET temporal = length/500::float WHERE network='ferry';

UPDATE network.transit_roads_interfaces SET temporal = 3 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='rail');
UPDATE network.transit_roads_interfaces SET temporal = 0.5 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='tram');
UPDATE network.transit_roads_interfaces SET temporal = 3 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='metro');
UPDATE network.transit_roads_interfaces SET temporal = 0.5 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='bus');
UPDATE network.transit_roads_interfaces SET temporal = 1 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='ferry');

UPDATE network.transit_areas_interfaces SET temporal = 3 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='rail');
UPDATE network.transit_areas_interfaces SET temporal = 0.5 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='tram');
UPDATE network.transit_areas_interfaces SET temporal = 3 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='metro');
UPDATE network.transit_areas_interfaces SET temporal = 0.5 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='bus');
UPDATE network.transit_areas_interfaces SET temporal = 1 WHERE stop_id in (SELECT sid FROM network.transit_stops WHERE network='ferry');

UPDATE network.transit_interfaces SET temporal = 5;

-- this would have percolated to the graphs if it had been done earlier
ALTER TABLE graph.transit_multimodal ADD COLUMN temporal double precision;
UPDATE graph.transit_multimodal SET temporal = length/1333::float WHERE rail = True AND transfer = 0;
UPDATE graph.transit_multimodal SET temporal = length/416::float WHERE tram = True AND transfer = 0;
UPDATE graph.transit_multimodal SET temporal = length/500::float WHERE metro = True AND transfer = 0;
UPDATE graph.transit_multimodal SET temporal = length/500::float WHERE bus = True AND transfer = 0;
UPDATE graph.transit_multimodal SET temporal = length/500::float WHERE ferry = True AND transfer = 0;
UPDATE graph.transit_multimodal SET temporal = 5 WHERE transfer > 0;

ALTER TABLE graph.transit_multimodal_randstad ADD COLUMN temporal double precision;
UPDATE graph.transit_multimodal_randstad SET temporal = length/1333::float WHERE rail = True AND transfer = 0;
UPDATE graph.transit_multimodal_randstad SET temporal = length/416::float WHERE tram = True AND transfer = 0;
UPDATE graph.transit_multimodal_randstad SET temporal = length/500::float WHERE metro = True AND transfer = 0;
UPDATE graph.transit_multimodal_randstad SET temporal = length/500::float WHERE bus = True AND transfer = 0;
UPDATE graph.transit_multimodal_randstad SET temporal = length/500::float WHERE ferry = True AND transfer = 0;
UPDATE graph.transit_multimodal_randstad SET temporal = 5 WHERE transfer > 0;

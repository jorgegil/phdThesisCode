ALTER TABLE network.roads ADD COLUMN main_access boolean;

WITH non_main_links AS(
SELECT * FROM graph.roads_dual WHERE target IN (SELECT sid FROM network.roads WHERE main IS NULL) OR source IN (SELECT sid FROM network.roads WHERE main IS NULL)
)
UPDATE network.roads SET main_access=TRUE WHERE main=TRUE AND (sid IN (SELECT source FROM non_main_links) OR sid IN (SELECT target FROM non_main_links));

ALTER TABLE network.roads_nodes ADD COLUMN motorway_access boolean;
ALTER TABLE network.roads_nodes ADD COLUMN main_access boolean;

UPDATE network.roads_nodes SET motorway_access=TRUE WHERE (sid IN (SELECT start_id FROM network.roads WHERE motorway_access = TRUE) OR sid IN (SELECT end_id FROM network.roads WHERE motorway_access=TRUE)) AND (sid IN (SELECT start_id FROM network.roads WHERE motorway IS NULL) OR sid IN (SELECT end_id FROM network.roads WHERE motorway IS NULL));

UPDATE network.roads_nodes SET main_access=TRUE WHERE (sid IN (SELECT start_id FROM network.roads WHERE main_access = TRUE) OR sid IN (SELECT end_id FROM network.roads WHERE main_access=TRUE)) AND (sid IN (SELECT start_id FROM network.roads WHERE main IS NULL) OR sid IN (SELECT end_id FROM network.roads WHERE main IS NULL));

ALTER TABLE network.roads_randstad ADD COLUMN main_access boolean;
ALTER TABLE network.roads_nodes_randstad ADD COLUMN motorway_access boolean;
ALTER TABLE network.roads_nodes_randstad ADD COLUMN main_access boolean;

UPDATE network.roads_randstad rnd SET main_access=TRUE WHERE sid IN (SELECT sid FROM network.roads WHERE main_access=TRUE);
UPDATE network.roads_nodes_randstad rnd SET motorway_access=TRUE WHERE sid IN (SELECT sid FROM network.roads_nodes WHERE motorway_access=TRUE);
UPDATE network.roads_nodes_randstad rnd SET main_access=TRUE WHERE sid IN (SELECT sid FROM network.roads_nodes WHERE main_access=TRUE);
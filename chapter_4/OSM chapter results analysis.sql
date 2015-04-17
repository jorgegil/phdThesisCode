-- analyse route and service area results for Geoinformation and Cartography book chapter

-- comparing shortest route length: pedestrian vs pedestrian_basic
-- DROP TABLE analysis.route_comparison CASCADE;
CREATE TABLE analysis.route_comparison AS SELECT (od||'_'||modality) route_id, sum(dist) route_length FROM geoinfo.routes_primal GROUP BY od, modality ORDER BY route_id;
SELECT (od||'_'||modality) route_id, sum(dist) route_length FROM geoinfo.routes GROUP BY od, modality;

-- comparing service area: pedestrian vs pedestrian_basic
-- DROP TABLE analysis.service_area_comparison CASCADE;
CREATE TABLE analysis.service_area_comparison AS SELECT (origin||'_'||modality||'_'||max_dist) service_id, sum(dist) area_size FROM geoinfo.service_areas_primal GROUP BY origin, modality, max_dist;
INSERT INTO analysis.service_area_comparison SELECT (origin||'_'||modality) service_id, sum(dist) area_size FROM geoinfo.service_areas GROUP BY origin, modality;

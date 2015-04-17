CREATE OR REPLACE FUNCTION _phd_service_test(cost text, graph text, origin text, distance text)
  RETURNS boolean AS
$BODY$
DECLARE
	command text;

BEGIN

	command = 'SELECT sid AS id,source::int4,target::int4,'||$1||'::float8 AS cost FROM temp_'||$2||'_graph';
	EXECUTE format(
		'WITH this_service AS (SELECT  seq, id1 AS node_id, cost FROM pgr_drivingDistance(%L, 
		(SELECT entrance FROM geoinfo.sources WHERE nme=%L)::integer,
		'||$4||'::double precision, false, false))
		INSERT INTO geoinfo.service_areas (node_id,dist,origin,modality) SELECT node_id,cost,%L,%L FROM this_service',
		command, $3, $3, $2);
	
	RETURN True;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_service_test(text, text, text, text)
  OWNER TO postgres;


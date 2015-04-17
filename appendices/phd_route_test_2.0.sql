CREATE OR REPLACE FUNCTION _phd_route_test(cost text, graph text, origin text, destination text)
  RETURNS boolean AS
$BODY$
DECLARE
	command text;
	od text;

BEGIN

	command = 'SELECT sid AS id,source::int4,target::int4,'||$1||'::float8 AS cost FROM temp_'||$2||'_graph';
	od = $3||'-'||$4;
	EXECUTE format(
		'WITH this_route AS (SELECT seq, id1 AS node_id, id2 AS edge_id, cost FROM pgr_dijkstra(%L, 
		(SELECT entrance FROM geoinfo.sources WHERE nme=%L)::integer,
		(SELECT entrance FROM geoinfo.sources WHERE nme=%L)::integer, false, false))
		INSERT INTO geoinfo.routes (node_id,link_id,dist,od,modality) SELECT node_id,edge_id,cost,%L,%L FROM this_route',
		command, $3, $4, od, $2);
	
	RETURN True;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_route_test(text, text, text, text)
  OWNER TO postgres;


-- Function: _phd_link_objects_pll(text, text, text, integer, integer, text, text, text, text, text, text)

-- DROP FUNCTION _phd_link_objects_pll(text, text, text, integer, integer, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION _phd_link_objects_pll(objects text, obj_geom text, obj_id text, start_id integer, count_id integer, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text)
  RETURNS text AS
$BODY$

DECLARE
	count_rec integer;
	obj_to_link text;
	obj_links text;
	link_pass smallint;
	to_link integer;
	link_dist double precision;
	dist_pass smallint;

BEGIN
	link_pass:= 0;
	to_link:= 0;
	link_dist:= 0.0;
	dist_pass := 0;
	
	obj_to_link := 'temp_objects_to_link_'||start_id;
	obj_links := 'temp_objects_links_'||start_id;
	
	--EXECUTE 'SELECT count(*) FROM '||objects INTO count_rec;
	
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name = outputtable) THEN
		EXECUTE 'CREATE TABLE '||outputtable||' (the_geom geometry, object_id integer, target_id integer)';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_objects_without_interface') THEN
		CREATE TEMP TABLE temp_objects_without_interface (id integer, the_geom geometry, the_point geometry);
	END IF;
		
	--IF count_rec > start_id THEN
		EXECUTE 'CREATE TEMP TABLE '||obj_to_link||' AS SELECT '||obj_id||' id,'||obj_geom||' the_geom, ST_PointOnSurface('||obj_geom||') the_point 
			FROM '||objects||' ORDER BY '||obj_id||' ASC'||' LIMIT '||count_id||' OFFSET '||start_id;
		EXECUTE 'SELECT count(*) FROM '||obj_to_link INTO to_link;
	
		--RAISE NOTICE 'Creating interfaces % to %, of %',start_id,start_id+(to_link-1),count_rec;
	--END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = obj_links) THEN
		EXECUTE 'DROP TABLE '||obj_links||' CASCADE';
	END IF;
	EXECUTE 'CREATE TEMP TABLE '||obj_links||' (object_id integer, target_id integer, the_geom geometry, sid serial NOT NULL)';
	
	-- loop to find links doing many checks
	FOR link_pass IN 1..4 LOOP
		CASE link_pass
			WHEN 1 THEN
				-- all lines from centroid of buildings;
				EXECUTE'INSERT INTO '||obj_links||' (object_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||', 
						ST_ShortestLine(bld.the_point, rd.'||tgt_geom||')
						FROM '||obj_to_link||' AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||',50)';
			WHEN 2 THEN
				-- shortest line from centroid of buildings;
				EXECUTE'INSERT INTO '||obj_links||' (object_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
					ST_ShortestLine(bld.the_point, rd.'||tgt_geom||') the_geom
					FROM '||obj_to_link||' AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,50) 
					ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
			WHEN 3 THEN
				-- all lines from perimeter of the building
				EXECUTE'INSERT INTO '||obj_links||' (object_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||',
					ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
					FROM '||obj_to_link||' AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||',50)';
			WHEN 4 THEN
				-- shortest line from perimeter of the building
				EXECUTE'INSERT INTO '||obj_links||' (object_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
					ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
					FROM '||obj_to_link||' AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,50) 
					ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
		END CASE;
		
		-- delete interfaces that cross other buildings (later replace by obstacles table!)
		EXECUTE 'DELETE FROM '||obj_links||' WHERE sid IN 
			(SELECT DISTINCT tmp.sid FROM '||obj_links||' as tmp, urbanform.buildings as bld
			WHERE ST_Crosses(tmp.the_geom,bld.the_geom) AND tmp.object_id<>bld.sid)';

		-- delete interfaces that cross water (later replace by obstacles table!)
		EXECUTE 'DELETE FROM '||obj_links||' WHERE sid IN 
			(SELECT DISTINCT tmp.sid FROM '||obj_links||' as tmp, temp.noncross_water as wat 
			WHERE ST_Crosses(tmp.the_geom,wat.the_geom))';

		IF link_pass = 1 OR link_pass = 3 THEN
			-- delete interfaces to endpoints of lines
			EXECUTE 'DELETE FROM '||obj_links||' WHERE sid IN
				(SELECT DISTINCT tmp.sid FROM '||obj_links||' as tmp, network.roads as road 
				WHERE tmp.target_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom))';				
		END IF;
			
		EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, object_id, target_id FROM '||obj_links;
		-- identify objects that did not get a street assigned
		EXECUTE 'DELETE FROM '||obj_to_link||' WHERE id IN (SELECT object_id FROM '||obj_links||')';
		EXECUTE 'DELETE FROM '|| obj_links;
		
		EXECUTE 'SELECT count(*) FROM '||obj_to_link INTO to_link;
		EXIT WHEN to_link = 0;
	END LOOP;

	-- If still buildings remaining do the single shortest line without checks
	IF to_link>0 THEN
		FOR dist_pass IN 1..2 LOOP
			CASE dist_pass
				WHEN 1 THEN link_dist:= 200.0;
				WHEN 2 THEN link_dist:= 2000.0;
			END CASE;

			RAISE NOTICE 'Distance - %: % buildings',link_dist,to_link;
			EXECUTE'INSERT INTO '||obj_links||' (object_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
				ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
				FROM '||obj_to_link||' AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,'||link_dist||')
				ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
				
			EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, object_id, target_id FROM '||obj_links;
			-- identify objects that did not get a street assigned
			EXECUTE 'DELETE FROM '||obj_to_link||' WHERE id IN (SELECT object_id FROM '||obj_links||')';
			EXECUTE 'DELETE FROM '||obj_links;
			
			EXECUTE 'SELECT count(*) FROM '||obj_to_link INTO to_link;
			EXIT WHEN to_link = 0;
		END LOOP;

		-- store remaining buildings
		IF to_link>0 THEN
			EXECUTE 'INSERT INTO temp_objects_without_interface SELECT * FROM '||obj_to_link;
			RAISE NOTICE 'Final: % objects remaining',to_link;
			EXECUTE 'DELETE FROM '||obj_to_link;
		END IF;
	END IF;

	EXECUTE 'DROP TABLE '||obj_to_link||' CASCADE';
	EXECUTE 'DROP TABLE '||obj_links||' CASCADE';

	RETURN 'OK';
END

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_link_objects_pll(text, text, text, integer, integer, text, text, text, text, text, text)
  OWNER TO postgres;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.1.4
-- Dumped by pg_dump version 9.1.4
-- Started on 2013-10-02 08:32:55 BST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- TOC entry 611 (class 1255 OID 29737)
-- Dependencies: 11
-- Name: _final_median(numeric[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _final_median(numeric[]) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
   SELECT AVG(val)
   FROM (
     SELECT val
     FROM unnest($1) val
     ORDER BY 1
     LIMIT  2 - MOD(array_upper($1, 1), 2)
     OFFSET CEIL(array_upper($1, 1) / 2.0) - 1
   ) sub;
$_$;


ALTER FUNCTION public._final_median(numeric[]) OWNER TO postgres;

--
-- TOC entry 1488 (class 1255 OID 203785)
-- Dependencies: 11
-- Name: _final_median(anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _final_median(anyarray) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$ 
  WITH q AS
  (
     SELECT val
     FROM unnest($1) val
     WHERE VAL IS NOT NULL
     ORDER BY 1
  ),
  cnt AS
  (
    SELECT COUNT(*) AS c FROM q
  )
  SELECT AVG(val)::float8
  FROM 
  (
    SELECT val FROM q
    LIMIT  2 - MOD((SELECT c FROM cnt), 2)
    OFFSET GREATEST(CEIL((SELECT c FROM cnt) / 2.0) - 1,0)  
  ) q2;
$_$;


ALTER FUNCTION public._final_median(anyarray) OWNER TO postgres;

--
-- TOC entry 612 (class 1255 OID 29738)
-- Dependencies: 11
-- Name: _final_mode(anyarray); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _final_mode(anyarray) RETURNS anyelement
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT a
    FROM unnest($1) a
    GROUP BY 1 
    ORDER BY COUNT(1) DESC, 1
    LIMIT 1;
$_$;


ALTER FUNCTION public._final_mode(anyarray) OWNER TO postgres;

--
-- TOC entry 613 (class 1255 OID 29739)
-- Dependencies: 11
-- Name: _final_range(numeric[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _final_range(numeric[]) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
   SELECT MAX(val) - MIN(val)
   FROM unnest($1) val;
$_$;


ALTER FUNCTION public._final_range(numeric[]) OWNER TO postgres;

--
-- TOC entry 1485 (class 1255 OID 196352)
-- Dependencies: 11 2584
-- Name: _phd_accessibility(text, text, text, text, text, text, double precision, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_accessibility(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, decay text, results_table text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	results_area text;
	results_count text;
	links_table text;
	target_table text;

BEGIN
	
	results_count := target_type||'_'||target_alias||'_count';
	results_area := target_type||'_'||target_alias||'_area';

	-- set tables to use depending on type of target
	IF target_type = 'building' THEN
		links_table := 'temp_roads_interfaces_incatch';
		target_table := 'temp_buildings_incatch';
	ELSEIF target_type = 'land' THEN
		links_table := '';
		target_table := '';
	ELSEIF target_type = 'water' THEN
		links_table := '';
		target_table := '';
	END IF;

	-- check if required tables are there
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = catch_table) THEN
		RETURN 'Prepare the network and target within a catchment area first.';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_accessibility_results') THEN
		DELETE FROM temp_accessibility_results;
	ELSE
		CREATE TEMP TABLE temp_accessibility_results (id integer, count integer, area double precision, cost double precision);
	END IF;

	IF target_type = 'building' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_accessibility_results SELECT target.sid as id, min(target.'||target_alias||'),
			min(target.'||target_alias||'_area), min(catch.cost) 
			FROM (SELECT * FROM '||catch_table||' WHERE cost <= '||radius||') as catch 
			JOIN temp_roads_interfaces_incatch as link ON (catch.vertex_id = link.target_id) 
			JOIN temp_buildings_incatch as target ON (link.building_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		-- and include pedestrian areas, that can provide closer access
		EXECUTE 'INSERT INTO temp_accessibility_results SELECT target.sid as id, min(target.'||target_alias||'),
			min(target.'||target_alias||'_area), min(catch.cost) 
			FROM (SELECT * FROM '||catch_table||' WHERE cost <= '||radius||') as catch 
			JOIN temp_areas_incatch as link1 ON (catch.vertex_id = link1.road_sid) 
			JOIN temp_areas_interfaces_incatch as link2 ON (link1.group_id = link2.area_id) 
			JOIN temp_buildings_incatch as target ON (link2.building_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
			
	ELSEIF target_type = 'land' THEN
	ELSEIF target_type = 'water' THEN
	END IF;
		
	-- update results table
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_count) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_count||' integer';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_area) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_area||' double precision';
	END IF;
	
	EXECUTE 'UPDATE '||results_table||' as access SET '||results_count||'=temp.count, '||results_area||'=round(temp.area)
		FROM (SELECT sum(count*('||decay||')) as count, sum(area*('||decay||')) as area 
		FROM (SELECT id, min(count) as count, min(area) as area, min(cost) as cost FROM temp_accessibility_results GROUP BY id) as agg) as temp
		WHERE access.'||this_type||'='||quote_literal(this_code);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_accessibility(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, decay text, results_table text) OWNER TO postgres;

--
-- TOC entry 1499 (class 1255 OID 169795)
-- Dependencies: 11 2584
-- Name: _phd_analyse_location(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_analyse_location(this_code text, this_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	result text;
	count integer;

BEGIN
	RAISE NOTICE 'analysing % %', this_type, this_code;

	-- create output tables
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = 'analysis.'||this_type||'_proximity') THEN
		EXECUTE 'CREATE TABLE analysis.'||this_type||'_proximity (sid serial NOT NULL, '||this_type||' character varying, the_geom geometry)';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = 'analysis.'||this_type||'_density') THEN
		EXECUTE 'CREATE TABLE analysis.'||this_type||'_density (sid serial NOT NULL, '||this_type||' character varying, the_geom geometry)';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = 'analysis.'||this_type||'_local_accessibility') THEN
		EXECUTE 'CREATE TABLE analysis.'||this_type||'_local_accessibility (sid serial NOT NULL, '||this_type||' character varying, the_geom geometry)';
	END IF;
	--IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = 'analysis.'||this_type||'_regional_accessibility') THEN
	--	EXECUTE 'CREATE TABLE analysis.'||this_type||'_regional_accessibility ('||this_type||' character varying)';
	--END IF;
	--IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = 'analysis.'||this_type||'_centrality') THEN
	--	EXECUTE 'CREATE TABLE analysis.'||this_type||'_centrality ('||this_type||' character varying)';
	--END IF;

	-- insert new row if needed
	EXECUTE 'SELECT * FROM analysis.'||this_type||'_proximity WHERE '||this_type||' = '||quote_literal(this_code) INTO count;
	IF count IS NULL THEN
		EXECUTE 'INSERT INTO analysis.'||this_type||'_proximity ('||this_type||') VALUES ('||quote_literal(this_code)||')';
	END IF;
	EXECUTE 'SELECT * FROM analysis.'||this_type||'_density WHERE '||this_type||' = '||quote_literal(this_code) INTO count;
	IF count IS NULL THEN
		EXECUTE 'INSERT INTO analysis.'||this_type||'_density ('||this_type||') VALUES ('||quote_literal(this_code)||')';
	END IF;

	EXECUTE 'SELECT * FROM analysis.'||this_type||'_local_accessibility WHERE '||this_type||' = '||quote_literal(this_code) INTO count;
	IF count IS NULL THEN
		EXECUTE 'INSERT INTO analysis.'||this_type||'_local_accessibility ('||this_type||') VALUES ('||quote_literal(this_code)||')';
	END IF;


	-- prepare all auxiliary temporary tables
	SELECT _phd_prepare_location(this_code, this_type) into result;
	
	RAISE NOTICE 'analysing % % proximity', this_type, this_code;
	-- analyse proximity
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'pedestrian = True', 'road', 'pedestrian', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'bicycle = True', 'road', 'bicycle', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_car_catch', 'motorway = True', 'road', 'motorway', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_car_catch', 'main = True', 'road', 'main', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'network = ''rail''', 'stop', 'rail', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'network = ''bus''', 'stop', 'bus', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'network = ''tram''', 'stop', 'tram', 'analysis.'||this_type||'_proximity');
	PERFORM _phd_proximity(this_code, this_type, 'temp_nonmotor_catch', 'network = ''metro''', 'stop', 'metro', 'analysis.'||this_type||'_proximity');

	RAISE NOTICE 'analysing % % density', this_type, this_code;
	-- analyse density
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'pedestrian = True', 'road', 'pedroutes', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'pedestrian = True OR pedestrian IS NULL', 'road', 'ped', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count = 3', 'crossing', 'tcross', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count > 3', 'crossing', 'xcross', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'pedestrian = True', 'road', 'pedroutes', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'pedestrian = True OR pedestrian IS NULL', 'road', 'ped', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count = 3', 'crossing', 'tcross', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count > 3', 'crossing', 'xcross', 800, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'bicycle = True', 'road', 'bicycleroutes', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'bicycle = True OR bicycle IS NULL', 'road', 'bicycle', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count = 3', 'crossing', 'tcross', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count > 3', 'crossing', 'xcross', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'bicycle = True', 'road', 'bicycleroutes', 3600, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'bicycle = True OR bicycle IS NULL', 'road', 'bicycle', 3600, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count = 3', 'crossing', 'tcross', 3600, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'count > 3', 'crossing', 'xcross', 3600, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'motorway = True', 'road', 'carroutes', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'main = True', 'road', 'carmain', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'car = True OR car IS NULL', 'road', 'car', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count = 3', 'crossing', 'tcarcross', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count > 3', 'crossing', 'xcarcross', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'motorway = True', 'road', 'carroutes', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'main = True', 'road', 'carmain', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'car = True OR car IS NULL', 'road', 'car', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count = 3', 'crossing', 'tcarcross', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count > 3', 'crossing', 'xcarcross', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'motorway = True', 'road', 'carroutes', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'main = True', 'road', 'carmain', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'car = True OR car IS NULL', 'road', 'car', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count = 3', 'crossing', 'tcarcross', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count > 3', 'crossing', 'xcarcross', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'motorway = True', 'road', 'carroutes', 3200, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'main = True', 'road', 'carmain', 3200, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'car = True OR car IS NULL', 'road', 'car', 3200, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count = 3', 'crossing', 'tcarcross', 3200, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_car_catch', 'count > 3', 'crossing', 'xcarcross', 3200, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''bus''', 'stop', 'bus', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''bus''', 'stop', 'bus', 800, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''tram''', 'stop', 'walktram', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''tram''', 'stop', 'walktram', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''tram''', 'stop', 'cycletram', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''tram''', 'stop', 'cycletram', 3600, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''metro''', 'stop', 'walkmetro', 400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''metro''', 'stop', 'walkmetro', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''metro''', 'stop', 'cyclemetro', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''metro''', 'stop', 'cyclemetro', 3600, 'analysis.'||this_type||'_density');
	
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''rail''', 'stop', 'walkrail', 800, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''rail''', 'stop', 'walkrail', 1600, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''rail''', 'stop', 'cyclerail', 2400, 'analysis.'||this_type||'_density');
	PERFORM _phd_density(this_code, this_type, 'temp_nonmotor_catch', 'network = ''rail''', 'stop', 'cyclerail', 3600, 'analysis.'||this_type||'_density');
	
	RAISE NOTICE 'analysing % % local accessibility', this_type, this_code;
	-- analyse local accessibility
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'residential > 0', 'building', 'residential', 400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'retail > 0', 'building', 'retail', 400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'education > 0', 'building', 'education', 400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'assembly > 0', 'building', 'assembly', 400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'office > 0', 'building', 'office', 400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'residential > 0', 'building', 'residential', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'retail > 0', 'building', 'retail', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'education > 0', 'building', 'education', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'assembly > 0', 'building', 'assembly', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'office > 0', 'building', 'office', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'industry > 0', 'building', 'industry', 800, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'residential > 0', 'building', 'residential', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'retail > 0', 'building', 'retail', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'education > 0', 'building', 'education', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'assembly > 0', 'building', 'assembly', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'office > 0', 'building', 'office', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'industry > 0', 'building', 'industry', 1200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'assembly > 0', 'building', 'assembly', 1600, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'office > 0', 'building', 'office', 2400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'industry > 0', 'building', 'industry', 2400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'retail > 0', 'building', 'retail', 2400, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'education > 0', 'building', 'education', 3600, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'assembly > 0', 'building', 'assembly', 5000, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'office > 0', 'building', 'office', 7500, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_nonmotor_catch', 'industry > 0', 'building', 'industry', 7500, '1', 'analysis.'||this_type||'_local_accessibility');

	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_car_catch', 'retail > 0', 'building', 'retail', 3200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_car_catch', 'education > 0', 'building', 'education', 3200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_car_catch', 'assembly > 0', 'building', 'assembly', 3200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_car_catch', 'office > 0', 'building', 'office', 3200, '1', 'analysis.'||this_type||'_local_accessibility');
	PERFORM _phd_local_accessibility(this_code, this_type, 'temp_car_catch', 'industry > 0', 'building', 'industry', 3200, '1', 'analysis.'||this_type||'_local_accessibility');

	-- analyse regional accessibility
	-- analyse centrality
	
	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_analyse_location(this_code text, this_type text) OWNER TO postgres;

--
-- TOC entry 1482 (class 1255 OID 67623)
-- Dependencies: 11 2584 1842
-- Name: _phd_axialazimuth(geometry, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_axialazimuth(obj geometry, tolerance double precision) RETURNS double precision
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;
	cumulazimuth double precision;
	axialazimuth double precision;

BEGIN

	axialazimuth:=0.0;
	cumulazimuth:=0.0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			deltazimuth:=ABS(azimutha - azimuthb);
			--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, deltazimuth;
			IF deltazimuth >180 THEN
				deltazimuth:=360-deltazimuth;
			END IF;
			IF deltazimuth > tolerance THEN
				axialazimuth:=axialazimuth + deltazimuth;
				cumulazimuth:= 0.0;
			ELSE
				cumulazimuth:=cumulazimuth + (azimutha - azimuthb);
				IF ABS(cumulazimuth) > 180 THEN
					cumulazimuth:=360-ABS(cumulazimuth);
				END IF;
				--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, cumulazimuth;
			END IF; 

			IF ABS(cumulazimuth) > tolerance THEN
				axialazimuth:=axialazimuth + ABS(cumulazimuth);
				cumulazimuth:= 0.0;
			END IF;
		END LOOP;
	END IF;

	RETURN axialazimuth;

END

$$;


ALTER FUNCTION public._phd_axialazimuth(obj geometry, tolerance double precision) OWNER TO postgres;

--
-- TOC entry 1481 (class 1255 OID 67625)
-- Dependencies: 11 2584 1842
-- Name: _phd_axialsteps(geometry, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_axialsteps(obj geometry, tolerance double precision) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;
	cumulazimuth double precision;
	axialsteps integer;

BEGIN

	axialsteps:=0;
	cumulazimuth:=0.0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, ABS(azimutha - azimuthb);
			deltazimuth:=ABS(azimutha - azimuthb);
			IF deltazimuth >180 THEN
				deltazimuth:=360-deltazimuth;
			END IF;
			IF deltazimuth > tolerance THEN
				axialsteps:=axialsteps + 1;
				cumulazimuth:= 0.0;
			ELSE
				cumulazimuth:=cumulazimuth + (azimutha - azimuthb);
				IF ABS(cumulazimuth) > 180 THEN
					cumulazimuth:=360-ABS(cumulazimuth);
				END IF;
			END IF; 
			IF ABS(cumulazimuth) > tolerance THEN
				axialsteps:=axialsteps + 1;
				cumulazimuth:= 0.0;
			END IF;
		END LOOP;
	END IF;

	RETURN axialsteps;

END

$$;


ALTER FUNCTION public._phd_axialsteps(obj geometry, tolerance double precision) OWNER TO postgres;

--
-- TOC entry 1484 (class 1255 OID 116780)
-- Dependencies: 11 2584
-- Name: _phd_buildings_interfaces(text, text, text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_buildings_interfaces(buildings text, bld_geom text, bld_id text, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	count_rec integer;
	current_rec integer;
	step integer;
	link_pass smallint;
	to_link integer;
	link_dist double precision;
	dist_pass smallint;
BEGIN
	step:= 100000;
	link_pass:= 0;
	to_link:= 0;
	link_dist:= 25.0;
	
	EXECUTE 'SELECT count(*) FROM '||buildings INTO count_rec;
	current_rec:=0;

	CREATE TABLE temp.buildings_to_link (id integer, the_geom geometry, the_point geometry);
	CREATE INDEX buildings_to_link_idx ON temp.buildings_to_link (id);	
	CREATE INDEX buildings_to_link_geom_idx ON temp.buildings_to_link USING GIST (the_geom);
	CREATE INDEX buildings_to_link_point_idx ON temp.buildings_to_link USING GIST (the_point);

	CREATE TABLE temp.buildings_interfaces (building_id integer, target_id integer, the_geom geometry, sid serial NOT NULL);
	CREATE INDEX buildings_interfaces_idx ON temp.buildings_interfaces (sid);	
	CREATE INDEX buildings_interfaces_building_idx ON temp.buildings_interfaces (building_id);
	CREATE INDEX buildings_interfaces_geom_idx ON temp.buildings_interfaces USING GIST (the_geom);
	
	EXECUTE 'CREATE TABLE '||outputtable||' (the_geom geometry, building_id integer, target_id integer)';
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'buildings_without_interface') THEN
		DROP TABLE temp.buildings_without_interface CASCADE;
	END IF;
	CREATE TABLE temp.buildings_without_interface (id integer, the_geom geometry, the_point geometry);
	
	-- main loop to go through large table
	FOR current_rec IN 0..count_rec BY step LOOP
		RAISE NOTICE 'Creating interfaces % to %, of %',current_rec,current_rec+step,count_rec;
		EXECUTE 'INSERT INTO temp.buildings_to_link SELECT '||bld_id||','||bld_geom||', the_point 
			FROM '||buildings||' ORDER BY '||bld_id||' ASC'||' LIMIT '||step||' OFFSET '||current_rec;
		SELECT Count(*) FROM temp.buildings_to_link INTO to_link;

		-- loop to find links at increasing distances
		FOR dist_pass IN 1..2 LOOP
			CASE dist_pass
				WHEN 1 THEN link_dist:= 25.0;
				WHEN 2 ThEN link_dist:= 50.0;
				-- WHEN 3 THEN link_dist:=100.0;
			END CASE;

			-- loop to find links doing many checks
			FOR link_pass IN 1..4 LOOP
				RAISE NOTICE 'Distance - %, step %: % buildings',link_dist, link_pass,to_link;
				CASE link_pass
					WHEN 1 THEN
						-- all lines from centroid of buildings;
						EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||', 
							ST_ShortestLine(bld.the_point, rd.'||tgt_geom||')
							FROM temp.buildings_to_link AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||','||link_dist||')';
					WHEN 2 THEN
						-- shortest line from centroid of buildings;
						EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
							ST_ShortestLine(bld.the_point, rd.'||tgt_geom||') the_geom
							FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,'||link_dist||')
							ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
					WHEN 3 THEN
						-- all lines from perimeter of the building
						EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||',
							ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
							FROM temp.buildings_to_link AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||','||link_dist||')';
					WHEN 4 THEN
						-- shortest line from perimeter of the building
						EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
							ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
							FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,'||link_dist||')
							ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
				END CASE;
				
				-- delete interfaces that cross other buildings (later replace by obstacles table!)
				DELETE FROM temp.buildings_interfaces WHERE sid IN 
				(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, urbanform.buildings as bld
				WHERE ST_Crosses(tmp.the_geom,bld.the_geom) AND tmp.building_id<>bld.sid);
		
				-- delete interfaces that cross water (later replace by obstacles table!)
				DELETE FROM temp.buildings_interfaces WHERE sid IN 
				(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, temp.noncross_water as wat 
				WHERE ST_Crosses(tmp.the_geom,wat.the_geom));

				IF link_pass<>2 AND link_pass<>4 THEN
					-- delete interfaces to endpoints of lines
					DELETE FROM temp.buildings_interfaces WHERE sid IN
					(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, network.roads as road 
					WHERE tmp.target_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));				
				END IF;
				
				EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, building_id, target_id FROM temp.buildings_interfaces';
				-- identify buildings that did not get a street assigned
				DELETE FROM temp.buildings_to_link WHERE id IN (SELECT building_id FROM temp.buildings_interfaces);
				DELETE FROM temp.buildings_interfaces;
				
				SELECT count(*) FROM temp.buildings_to_link INTO to_link;
				EXIT WHEN to_link = 0;
			END LOOP;

		END LOOP;

		-- If still buildings remaining do the single shortest line without checks
		IF to_link>0 THEN
			FOR dist_pass IN 1..5 LOOP
				CASE dist_pass
					WHEN 1 THEN link_dist:= 50.0;
					WHEN 2 THEN link_dist:= 200.0;
					WHEN 3 THEN link_dist:= 200.0;
					WHEN 4 THEN link_dist:= 500.0;
					WHEN 5 THEN link_dist:= 2000.0;
				END CASE;

				RAISE NOTICE 'Distance - %: % buildings',link_dist,to_link;
				EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
					ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
					FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,'||link_dist||')
					ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
					
				IF link_dist < 3 THEN
					-- delete interfaces that cross water (later replace by obstacles table!)
					DELETE FROM temp.buildings_interfaces WHERE sid IN 
					(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, temp.noncross_water as wat 
					WHERE ST_Crosses(tmp.the_geom,wat.the_geom));
				END IF;
				
				EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, building_id, target_id FROM temp.buildings_interfaces';
				-- identify buildings that did not get a street assigned
				DELETE FROM temp.buildings_to_link WHERE id IN (SELECT building_id FROM temp.buildings_interfaces);
				DELETE FROM temp.buildings_interfaces;
				
				SELECT count(*) FROM temp.buildings_to_link INTO to_link;
				EXIT WHEN to_link = 0;
			END LOOP;

			-- store remaining buildings
			IF to_link>0 THEN
				INSERT INTO temp.buildings_without_interface SELECT * FROM temp.buildings_to_link;
				RAISE NOTICE 'Final: % buildings remaining',to_link;
				DELETE FROM temp.buildings_to_link;
			END IF;
		END IF;	
	END LOOP;

	DROP TABLE temp.buildings_to_link CASCADE;
	DROP TABLE temp.buildings_interfaces CASCADE;

	EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';
	ALTER TABLE temp.buildings_without_interface ADD CONSTRAINT temp_buildings_noint_pk PRIMARY KEY (id);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_buildings_interfaces(buildings text, bld_geom text, bld_id text, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) OWNER TO postgres;

--
-- TOC entry 1486 (class 1255 OID 196375)
-- Dependencies: 11 2584
-- Name: _phd_buildings_interfaces_strict(text, text, text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_buildings_interfaces_strict(buildings text, bld_geom text, bld_id text, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	count_rec integer;
	current_rec integer;
	step integer;
	link_pass smallint;
	to_link integer;
	link_dist double precision;
	dist_pass smallint;

BEGIN
	step:= 100000;
	link_pass:= 0;
	to_link:= 0;
	link_dist:= 25.0;
	dist_pass := 0;
	
	EXECUTE 'SELECT count(*) FROM '||buildings INTO count_rec;
	current_rec:=0;

	CREATE TABLE temp.buildings_to_link (id integer, the_geom geometry, the_point geometry);
	CREATE INDEX buildings_to_link_idx ON temp.buildings_to_link (id);	
	CREATE INDEX buildings_to_link_geom_idx ON temp.buildings_to_link USING GIST (the_geom);
	CREATE INDEX buildings_to_link_point_idx ON temp.buildings_to_link USING GIST (the_point);

	CREATE TABLE temp.buildings_interfaces (building_id integer, target_id integer, the_geom geometry, sid serial NOT NULL);
	CREATE INDEX buildings_interfaces_idx ON temp.buildings_interfaces (sid);	
	CREATE INDEX buildings_interfaces_building_idx ON temp.buildings_interfaces (building_id);
	CREATE INDEX buildings_interfaces_geom_idx ON temp.buildings_interfaces USING GIST (the_geom);
	
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name = outputtable) THEN
		EXECUTE 'CREATE TABLE '||outputtable||' (the_geom geometry, building_id integer, target_id integer)';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_buildings_without_interface') THEN
		DROP TABLE temp_buildings_without_interface CASCADE;
	END IF;
	CREATE TEMP TABLE temp_buildings_without_interface (id integer, the_geom geometry, the_point geometry);
	
	-- main loop to go through large table
	FOR current_rec IN 0..count_rec BY step LOOP
		RAISE NOTICE 'Creating interfaces % to %, of %',current_rec,current_rec+step,count_rec;
		EXECUTE 'INSERT INTO temp.buildings_to_link SELECT '||bld_id||','||bld_geom||', the_point 
			FROM '||buildings||' ORDER BY '||bld_id||' ASC'||' LIMIT '||step||' OFFSET '||current_rec;
		SELECT Count(*) FROM temp.buildings_to_link INTO to_link;

		-- loop to find links doing many checks
		FOR link_pass IN 1..4 LOOP
			CASE link_pass
				WHEN 1 THEN
					-- all lines from centroid of buildings;
					EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||', 
						ST_ShortestLine(bld.the_point, rd.'||tgt_geom||')
						FROM temp.buildings_to_link AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||',50)';
				WHEN 2 THEN
					-- shortest line from centroid of buildings;
					EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
						ST_ShortestLine(bld.the_point, rd.'||tgt_geom||') the_geom
						FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,50) 
						ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
				WHEN 3 THEN
					-- all lines from perimeter of the building
					EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT bld.id, rd.'||tgt_id||',
						ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
						FROM temp.buildings_to_link AS bld, '||target ||' AS rd WHERE ST_DWithin(bld.the_geom,rd.'||tgt_geom||',50)';
				WHEN 4 THEN
					-- shortest line from perimeter of the building
					EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
						ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
						FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,50) 
						ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
			END CASE;
			
			-- delete interfaces that cross other buildings (later replace by obstacles table!)
			DELETE FROM temp.buildings_interfaces WHERE sid IN 
				(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, urbanform.buildings as bld
				WHERE ST_Crosses(tmp.the_geom,bld.the_geom) AND tmp.building_id<>bld.sid);
	
			-- delete interfaces that cross water (later replace by obstacles table!)
			DELETE FROM temp.buildings_interfaces WHERE sid IN 
				(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, temp.noncross_water as wat 
				WHERE ST_Crosses(tmp.the_geom,wat.the_geom));

			IF link_pass = 1 OR link_pass = 3 THEN
				-- delete interfaces to endpoints of lines
				DELETE FROM temp.buildings_interfaces WHERE sid IN
				(SELECT DISTINCT tmp.sid FROM temp.buildings_interfaces as tmp, network.roads as road 
				WHERE tmp.target_id=road.sid AND ST_Touches(tmp.the_geom,road.the_geom));				
			END IF;
			
			EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, building_id, target_id FROM temp.buildings_interfaces';
			-- identify buildings that did not get a street assigned
			DELETE FROM temp.buildings_to_link WHERE id IN (SELECT building_id FROM temp.buildings_interfaces);
			DELETE FROM temp.buildings_interfaces;
			
			SELECT count(*) FROM temp.buildings_to_link INTO to_link;
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
				EXECUTE'INSERT INTO temp.buildings_interfaces (building_id, target_id, the_geom) SELECT DISTINCT ON (bld.id) bld.id, rd.'||tgt_id||',
					ST_ShortestLine(bld.the_geom, rd.'||tgt_geom||') the_geom
					FROM temp.buildings_to_link AS bld, '||target||' AS rd WHERE ST_DWithin(bld.the_geom,rd.the_geom,'||link_dist||')
					ORDER BY bld.id, ST_Distance(bld.the_geom, rd.'||tgt_geom||')';
									
				EXECUTE 'INSERT INTO '||outputtable||' SELECT the_geom, building_id, target_id FROM temp.buildings_interfaces';
				-- identify buildings that did not get a street assigned
				DELETE FROM temp.buildings_to_link WHERE id IN (SELECT building_id FROM temp.buildings_interfaces);
				DELETE FROM temp.buildings_interfaces;
				
				SELECT count(*) FROM temp.buildings_to_link INTO to_link;
				EXIT WHEN to_link = 0;
			END LOOP;

			-- store remaining buildings
			IF to_link>0 THEN
				INSERT INTO temp_buildings_without_interface SELECT * FROM temp.buildings_to_link;
				RAISE NOTICE 'Final: % buildings remaining',to_link;
				DELETE FROM temp.buildings_to_link;
			END IF;
		END IF;	

	END LOOP;

	DROP TABLE temp.buildings_to_link CASCADE;
	DROP TABLE temp.buildings_interfaces CASCADE;

	--EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';
	--ALTER TABLE temp_buildings_without_interface ADD CONSTRAINT temp_buildings_noint_pk PRIMARY KEY (id);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_buildings_interfaces_strict(buildings text, bld_geom text, bld_id text, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) OWNER TO postgres;

--
-- TOC entry 614 (class 1255 OID 29740)
-- Dependencies: 11 2584
-- Name: _phd_calc_gini(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_calc_gini(text, text, text) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$

DECLARE
-- like _phd_calc_gini ('survey.socio_economic_pcode','sid','household_income')
    rec RECORD;
    n int;
    gini double precision;
    T double precision;
    S double precision;

BEGIN

--Gini = 1 - (2 / T * S +1) / n
--T = sum(indicator)
--n = count rows
--S = select sum(cumul) from gini_table where rowid<rowid;

--verify that temp schema exists
	IF NOT EXISTS (select * from information_schema.schemata where information_schema.schemata.schema_name = 'temp') THEN
		EXECUTE 'CREATE SCHEMA temp';
	END IF;

--verify if a previous table exists
	IF EXISTS (select * from  INFORMATION_SCHEMA.tables where table_name = 'ginivalues') THEN
		DROP TABLE temp.ginivalues cascade;
	END IF;

--create temporary table with values required for gini coeficient calculation
    EXECUTE 'CREATE TABLE temp.ginivalues as SELECT '||$2||' sid,'||$3||' indicator FROM '||$1||' ORDER BY '||$3||' ASC';
    EXECUTE 'DELETE FROM temp.ginivalues WHERE indicator IS NULL';
    ALTER TABLE temp.ginivalues ADD COLUMN cumul double precision;

--calculate cumulative values and gini coefficient

	--define T (sumof all values)
	EXECUTE 'SELECT sum(indicator) FROM temp.ginivalues' into T;

    IF T IS NULL OR T = 0 THEN
    	gini := NULL;
    ELSE
    	n := 1;
		--define S
		FOR rec IN SELECT * FROM temp.ginivalues LOOP
			EXECUTE 'UPDATE temp.ginivalues as gini SET cumul = foo.sum 
			FROM (SELECT sum(bar.indicator) sum FROM (SELECT indicator 
			FROM temp.ginivalues ORDER BY indicator ASC LIMIT '||n||')as bar) as foo 
			WHERE gini.sid = '||rec.sid;
			n := n + 1;
		END LOOP;

		EXECUTE 'SELECT sum(cumul) FROM temp.ginivalues' into S;
		S := S-T;

		gini := 1 - (((2 / T) * S) +1) / n;

	END IF;

--eliminate temporary table
   DROP TABLE temp.ginivalues CASCADE;

   RETURN gini;

END;

$_$;


ALTER FUNCTION public._phd_calc_gini(text, text, text) OWNER TO postgres;

--
-- TOC entry 1479 (class 1255 OID 67624)
-- Dependencies: 11 2584 1842
-- Name: _phd_continuityazimuth(geometry, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_continuityazimuth(obj geometry, tolerance double precision) RETURNS double precision
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;
	continuityazimuth double precision;

BEGIN

	continuityazimuth:=0.0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, ABS(azimutha - azimuthb);
			deltazimuth:=ABS(azimutha - azimuthb);
			IF deltazimuth >180 THEN
				deltazimuth:=360-deltazimuth;
			END IF;
			IF deltazimuth > tolerance THEN
				continuityazimuth:=continuityazimuth + deltazimuth;
			END IF;
		END LOOP;
	END IF;
	RETURN continuityazimuth;

END

$$;


ALTER FUNCTION public._phd_continuityazimuth(obj geometry, tolerance double precision) OWNER TO postgres;

--
-- TOC entry 1480 (class 1255 OID 67626)
-- Dependencies: 11 2584 1842
-- Name: _phd_continuitysteps(geometry, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_continuitysteps(obj geometry, tolerance double precision) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;
	continuitysteps integer;

BEGIN

	continuitysteps:=0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			deltazimuth:=ABS(azimutha - azimuthb);
			--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, deltazimuth;
			IF deltazimuth >180 THEN
				deltazimuth:=360-deltazimuth;
			END IF;
			IF deltazimuth > tolerance THEN
				continuitysteps:=continuitysteps + 1;
			END IF;
		END LOOP;
	END IF;

	RETURN continuitysteps;

END

$$;


ALTER FUNCTION public._phd_continuitysteps(obj geometry, tolerance double precision) OWNER TO postgres;

--
-- TOC entry 615 (class 1255 OID 29741)
-- Dependencies: 11 2584
-- Name: _phd_copytable(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_copytable(source character varying, destination character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  
BEGIN
  
	Execute 'CREATE TABLE '|| destination ||' (LIKE '||source||' INCLUDING ALL)';
	Execute 'INSERT INTO '||destination ||' SELECT * from '||source;  
   
END
$$;


ALTER FUNCTION public._phd_copytable(source character varying, destination character varying) OWNER TO postgres;

--
-- TOC entry 1478 (class 1255 OID 29742)
-- Dependencies: 11 2584 1842
-- Name: _phd_cumulazimuth(geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_cumulazimuth(obj geometry) RETURNS double precision
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;
	cumulazimuth double precision;

BEGIN

	cumulazimuth:=0.0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			deltazimuth:=ABS(azimutha - azimuthb);
			--RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, deltazimuth;

			IF deltazimuth >180 THEN
				deltazimuth:=360-deltazimuth;
			END IF;
			cumulazimuth:=cumulazimuth + deltazimuth;
		END LOOP;
	END IF;

	RETURN cumulazimuth;

END

$$;


ALTER FUNCTION public._phd_cumulazimuth(obj geometry) OWNER TO postgres;

--
-- TOC entry 1477 (class 1255 OID 29743)
-- Dependencies: 11 2584 1842
-- Name: _phd_deltazimuth(geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_deltazimuth(obj geometry) RETURNS double precision
    LANGUAGE plpgsql
    AS $$

DECLARE
	npoints smallint;
	currpoint smallint;
	azimutha double precision;
	azimuthb double precision;
	deltazimuth double precision;

BEGIN

	deltazimuth:=0.0;
	SELECT ST_NPoints(obj) INTO npoints;

	IF npoints > 2 THEN
		FOR currpoint IN 2..npoints-1 LOOP
			SELECT degrees(ST_Azimuth(ST_PointN(obj,(currpoint-1)),ST_PointN(obj,currpoint))) INTO azimutha;
			SELECT degrees(ST_Azimuth(ST_PointN(obj,currpoint),ST_PointN(obj,(currpoint+1)))) INTO azimuthb;
			deltazimuth:= deltazimuth + (azimutha - azimuthb);
			IF ABS(deltazimuth) > 180 THEN
				deltazimuth:=360-ABS(deltazimuth);
			END IF;
			-- RAISE NOTICE '% - %,% = %', currpoint, azimutha, azimuthb, deltazimuth;
		END LOOP;
	END IF;

	RETURN ABS(deltazimuth);

END

$$;


ALTER FUNCTION public._phd_deltazimuth(obj geometry) OWNER TO postgres;

--
-- TOC entry 1493 (class 1255 OID 192608)
-- Dependencies: 11 2584
-- Name: _phd_density(text, text, text, text, text, text, double precision, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_density(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, results_table text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	results_cost text;
	results_count text;
	links_table text;
	target_table text;
	counter integer;

BEGIN
	results_count := target_type||'_'||target_alias||'_'||radius||'_count';
	results_cost := target_type||'_'||target_alias||'_'||radius||'_sum';

	-- set tables to use depending on type of target
	IF target_type = 'building' THEN
		links_table := 'temp_roads_interfaces_incatch';
		target_table := 'temp_buildings_incatch';
	ELSEIF target_type = 'stop' THEN
		links_table := 'temp_transit_roads_incatch';
		target_table := 'temp_transit_incatch';
	ELSEIF target_type = 'road' THEN
		links_table := 'temp_roads_incatch';
		target_table := 'temp_areas_incatch';
	ELSEIF target_type = 'crossing' THEN
		links_table := 'temp_roads_incatch';
		target_table := 'temp_nodes_incatch';
	END IF;

	-- check if required tables are there
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = catch_table) OR 
		NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = target_table) OR 
		NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = links_table) THEN
		RETURN 'Prepare the network and target within a catchment area first.';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_density_results') THEN
		DELETE FROM temp_density_results;
	ELSE
		CREATE TEMP TABLE temp_density_results (id integer, cost double precision);
	END IF;
 
	IF target_type = 'building' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(target.area)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_roads_interfaces_incatch as link ON (catch.vertex_id = link.target_id) 
			JOIN temp_buildings_incatch as target ON (link.building_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		-- and include pedestrian areas, that can provide closer access
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(target.area)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_areas_incatch as link1 ON (catch.vertex_id = link1.road_id) 
			JOIN temp_areas_interfaces_incatch as link2 ON (link1.group_id = link2.area_id) 
			JOIN temp_buildings_incatch as target ON (link2.building_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
			
	ELSEIF target_type = 'stop' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN network.transit_roads_interfaces as link ON (catch.vertex_id = link.road_id) 
			JOIN network.transit_stops as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		-- redo this to include pedestrian areas, that provide closer access
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN network.transit_areas_interfaces as link ON (catch.vertex_id = link.road_id) 
			JOIN network.transit_stops as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
			
	ELSEIF target_type = 'road' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(target.length)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_roads_incatch as target ON (catch.vertex_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';	
		-- redo this to include pedestrian areas, that provide closer access and in themselves can be targets
		EXECUTE 'INSERT INTO temp_density_results SELECT target.road_sid as id, min(target.length)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch
			JOIN temp_areas_incatch as target ON (catch.vertex_id = target.road_sid) GROUP BY target.road_sid';
			
	ELSEIF target_type = 'crossing' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_roads_incatch as link ON (catch.vertex_id = link.sid) 
			JOIN temp_nodes_incatch as target ON (link.start_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_roads_incatch as link ON (catch.vertex_id = link.sid) 
			JOIN temp_nodes_incatch as target ON (link.end_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		-- redo this to include pedestrian areas, that provide closer access
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_areas_incatch as link ON (catch.vertex_id = link.road_sid) 
			JOIN temp_nodes_incatch as target ON (link.start_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';		
		EXECUTE 'INSERT INTO temp_density_results SELECT target.sid as id, min(catch.metric)
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_areas_incatch as link ON (catch.vertex_id = link.road_sid) 
			JOIN temp_nodes_incatch as target ON (link.end_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';		
	END IF;

	-- update results table
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_count) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_count||' integer';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_cost) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_cost||' double precision';
	END IF;
	
	EXECUTE 'UPDATE '||results_table||' as dens SET '||results_count||'=temp.count, '||results_cost||'=round(temp.cost)
		FROM (SELECT count(*) as count, sum(cost) as cost 
		FROM (SELECT id, min(cost) as cost FROM temp_density_results GROUP BY id) as agg) as temp
		WHERE dens.'||this_type||'='||quote_literal(this_code);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_density(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, results_table text) OWNER TO postgres;

--
-- TOC entry 1474 (class 1255 OID 67245)
-- Dependencies: 11 2584
-- Name: _phd_eliminate_duplicates(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_eliminate_duplicates(sourcetable text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE

BEGIN
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'no_dups') THEN
		DROP TABLE no_dups CASCADE;
	END IF;
	EXECUTE 'CREATE TABLE no_dups AS SELECT DISTINCT * FROM '|| sourcetable;
	
	EXECUTE 'DELETE FROM '||sourcetable;
	
	EXECUTE 'INSERT INTO '||sourcetable||' SELECT * FROM no_dups';
	
	DROP TABLE no_dups CASCADE;
	
	RETURN 'OK';
	
END

$$;


ALTER FUNCTION public._phd_eliminate_duplicates(sourcetable text) OWNER TO postgres;

--
-- TOC entry 1476 (class 1255 OID 67246)
-- Dependencies: 11 2584
-- Name: _phd_link_all_points_by_id(text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_link_all_points_by_id(pointsdata text, pointgeometry text, pointid text, groupid text, outputtable text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	count_points bigint;
	count_fix bigint;
	linkgroup text;
	startid text;
	endid text;
BEGIN
	EXECUTE 'CREATE TABLE temp.all_points_to_link AS SELECT * FROM '|| pointsdata;
	
	EXECUTE 'CREATE TABLE '||outputtable||' (the_geom geometry, start_id integer, end_id integer, group_id integer)';
	
	FOR linkgroup IN EXECUTE 'SELECT DISTINCT '||groupid||' FROM temp.all_points_to_link' LOOP
		-- RAISE NOTICE '%', linkgroup;
		EXECUTE 'CREATE OR REPLACE VIEW temp.vu_points_to_link_now AS SELECT * FROM temp.all_points_to_link WHERE '||groupid||' = '||quote_literal(linkgroup);
		SELECT count(*) FROM temp.vu_points_to_link_now INTO count_points;
		RAISE NOTICE '% points to link in group %', count_points, linkgroup;
		
		-- LOOP THIS PROCESS UNTIL NO LINKS TO MERGE
		WHILE count_points > 0 LOOP
			EXECUTE 'SELECT '||pointid||' FROM temp.vu_points_to_link_now LIMIT 1' INTO startid;

			FOR endid IN EXECUTE 'SELECT '||pointid||' FROM temp.vu_points_to_link_now WHERE '||pointid||'<>'||quote_literal(startid) LOOP
				EXECUTE 'INSERT INTO '||outputtable||' VALUES( ST_Makeline
					((SELECT '||pointgeometry||' FROM temp.vu_points_to_link_now WHERE '||pointid||'='||quote_literal(startid)||'),
					(SELECT '||pointgeometry||' FROM temp.vu_points_to_link_now WHERE '||pointid||'='||quote_literal(endid)||')),'
					||quote_literal(startid)||','||quote_literal(endid)||','||quote_literal(linkgroup)||')';
			END LOOP;

			EXECUTE 'DELETE FROM temp.all_points_to_link WHERE '||pointid||'='||quote_literal(startid)||' AND '||groupid||'='||quote_literal(linkgroup);
			SELECT count(*) FROM temp.vu_points_to_link_now INTO count_points;
			-- RAISE NOTICE '% points to link', count_points;
		END LOOP;
	END LOOP;

	EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';

	DROP TABLE temp.all_points_to_link CASCADE;

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_link_all_points_by_id(pointsdata text, pointgeometry text, pointid text, groupid text, outputtable text) OWNER TO postgres;

--
-- TOC entry 1487 (class 1255 OID 198361)
-- Dependencies: 11 2584
-- Name: _phd_link_objects_pll(text, text, text, integer, integer, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_link_objects_pll(objects text, obj_geom text, obj_id text, start_id integer, count_id integer, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) RETURNS text
    LANGUAGE plpgsql
    AS $$

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

$$;


ALTER FUNCTION public._phd_link_objects_pll(objects text, obj_geom text, obj_id text, start_id integer, count_id integer, target text, tgt_geom text, tgt_id text, obstacles text, obs_geom text, outputtable text) OWNER TO postgres;

--
-- TOC entry 1500 (class 1255 OID 216282)
-- Dependencies: 11 2584
-- Name: _phd_local_accessibility(text, text, text, text, text, text, double precision, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_local_accessibility(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, decay text, results_table text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	results_area text;
	results_count text;
	links_table text;
	target_table text;

BEGIN
	
	results_count := target_type||'_'||target_alias||'_'||radius||'_count';
	results_area := target_type||'_'||target_alias||'_'||radius||'_area';

	-- set tables to use depending on type of target
	IF target_type = 'building' THEN
		links_table := 'temp_roads_interfaces_incatch';
		target_table := 'temp_buildings_incatch';
	ELSEIF target_type = 'land' THEN
		links_table := '';
		target_table := '';
	ELSEIF target_type = 'water' THEN
		links_table := '';
		target_table := '';
	END IF;

	-- check if required tables are there
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = catch_table) THEN
		RETURN 'Prepare the network and target within a catchment area first.';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_accessibility_results') THEN
		DELETE FROM temp_accessibility_results;
	ELSE
		CREATE TEMP TABLE temp_accessibility_results (id integer, count integer, area double precision, cost double precision);
	END IF;

	IF target_type = 'building' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_accessibility_results SELECT target.sid as id, min(target.'||target_alias||'),
			min(target.'||target_alias||'_area), min(catch.metric) 
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_roads_interfaces_incatch as link ON (catch.vertex_id = link.target_id) 
			JOIN temp_buildings_incatch as target ON (link.object_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
		-- and include pedestrian areas, that can provide closer access
		EXECUTE 'INSERT INTO temp_accessibility_results SELECT target.sid as id, min(target.'||target_alias||'),
			min(target.'||target_alias||'_area), min(catch.metric) 
			FROM (SELECT * FROM '||catch_table||' WHERE metric <= '||radius||') as catch 
			JOIN temp_areas_incatch as link1 ON (catch.vertex_id = link1.road_sid) 
			JOIN temp_areas_interfaces_incatch as link2 ON (link1.group_id = link2.target_id) 
			JOIN temp_buildings_incatch as target ON (link2.object_id = target.sid) 
			WHERE target.'||target||' GROUP BY target.sid';
			
	ELSEIF target_type = 'land' THEN
	ELSEIF target_type = 'water' THEN
	END IF;
		
	-- update results table
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_count) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_count||' integer';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_area) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_area||' double precision';
	END IF;
	
	EXECUTE 'UPDATE '||results_table||' as access SET '||results_count||'=temp.count, '||results_area||'=round(temp.area)
		FROM (SELECT sum(count*('||decay||')) as count, sum(area*('||decay||')) as area 
		FROM (SELECT id, min(count) as count, min(area) as area, min(cost) as cost FROM temp_accessibility_results GROUP BY id) as agg) as temp
		WHERE access.'||this_type||'='||quote_literal(this_code);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_local_accessibility(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, radius double precision, decay text, results_table text) OWNER TO postgres;

--
-- TOC entry 616 (class 1255 OID 29744)
-- Dependencies: 11 2584
-- Name: _phd_makeundirected(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_makeundirected(source character varying, origin character varying, destination character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  current_rec bigint;
  count_rec bigint;
  link record;
BEGIN
  
  EXECUTE 'SELECT Count(*) FROM '||source INTO count_rec;
  current_rec:=0;

  WHILE current_rec < count_rec LOOP
	EXECUTE 'SELECT '||origin||' AS f1, '||destination||' AS f2 FROM '||source||' LIMIT 1 OFFSET '||current_rec INTO link;
	EXECUTE 'DELETE FROM '||source||' WHERE '||destination||'='||quote_literal(link.f1)||' AND '||origin||'='||quote_literal(link.f2);
	current_rec:=current_rec+1;
	EXECUTE 'SELECT Count(*) FROM '||source INTO count_rec;
  END LOOP;

  RETURN count_rec;
	
END
$$;


ALTER FUNCTION public._phd_makeundirected(source character varying, origin character varying, destination character varying) OWNER TO postgres;

--
-- TOC entry 617 (class 1255 OID 29745)
-- Dependencies: 11 2584
-- Name: _phd_merge_lines_at_points(text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_merge_lines_at_points(linedata text, lineid text, linegeom text, sharedpoints text, pointid text, pointgeom text, outputtable text) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE

	count_rec bigint;

	prev_count bigint;

BEGIN

	-- preparatory steps creating required tables
	EXECUTE 'CREATE TABLE temp.roads_to_merge_now AS SELECT '||lineid||' id,'||linegeom||' the_geom FROM '||linedata;
	EXECUTE 'SELECT Count(*) FROM temp.roads_to_merge_now' INTO count_rec;
	RAISE NOTICE 'Merging % segments...',count_rec;
	prev_count := 0;

	EXECUTE 'CREATE TABLE '||outputtable||' (line_id integer, the_geom geometry)';

	-- LOOP THIS PROCESS UNTIL NO ROADS TO MERGE
	WHILE count_rec > 0 LOOP

		EXECUTE 'ALTER TABLE temp.roads_to_merge_now ADD COLUMN node_1 bigint';
		EXECUTE 'ALTER TABLE temp.roads_to_merge_now ADD COLUMN node_2 bigint';
		EXECUTE 'CREATE INDEX roads_to_merge_now_idx ON temp.roads_to_merge_now USING gist (the_geom)';
		EXECUTE 'UPDATE temp.roads_to_merge_now AS tmn SET node_1=nod.'||pointid||' FROM '||sharedpoints||' AS nod
			WHERE ST_Intersects(ST_StartPoint(tmn.the_geom),nod.'||pointgeom||')';
		EXECUTE 'UPDATE temp.roads_to_merge_now AS tmn SET node_2=nod.'||pointid||' FROM '||sharedpoints||' AS nod
			WHERE ST_Intersects(ST_EndPoint(tmn.the_geom),nod.'||pointgeom||')';
		EXECUTE 'UPDATE temp.roads_to_merge_now SET node_1=node_2 WHERE node_1 IS NULL AND node_2 IS NOT NULL';
		-- EXECUTE 'UPDATE temp.roads_to_merge_now SET node_2=node_1 WHERE node_2 IS NULL AND node_1 IS NOT NULL';

		EXECUTE 'CREATE TABLE temp.roads_newly_merged_a AS SELECT id, node_1, (st_dump(merged_geom)).geom the_geom
			FROM (SELECT node_1, min(id) id, ST_Linemerge(ST_Collect(the_geom)) AS merged_geom
			FROM temp.roads_to_merge_now GROUP BY node_1) AS subq';

		DROP TABLE temp.roads_to_merge_now CASCADE;

		EXECUTE 'CREATE TABLE temp.roads_to_merge_now AS SELECT road.id, road.the_geom 
			FROM temp.roads_newly_merged_a AS road, '||sharedpoints||' AS cro WHERE ST_Touches(road.the_geom,cro.'||pointgeom||') 
			GROUP BY road.id, road.the_geom';
		EXECUTE 'INSERT INTO '||outputtable||' SELECT id, the_geom FROM temp.roads_newly_merged_a 
			WHERE id NOT IN (SELECT id FROM temp.roads_to_merge_now)';
		EXECUTE 'SELECT Count(*) FROM temp.roads_to_merge_now' INTO count_rec;
		RAISE NOTICE 'Merging % lines...',count_rec;

		DROP TABLE temp.roads_newly_merged_a CASCADE;

		IF count_rec = prev_count THEN
			EXIT;
		ELSE
			prev_count := count_rec;
		END IF;

	END LOOP;

	EXECUTE 'CREATE TABLE '||outputtable||'_not AS SELECT id, the_geom FROM temp.roads_to_merge_now';
	EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';

	-- Clean up
	DROP TABLE temp.roads_to_merge_now CASCADE;

	RETURN 1;

END

$$;


ALTER FUNCTION public._phd_merge_lines_at_points(linedata text, lineid text, linegeom text, sharedpoints text, pointid text, pointgeom text, outputtable text) OWNER TO postgres;

--
-- TOC entry 1475 (class 1255 OID 67247)
-- Dependencies: 11 2584
-- Name: _phd_merge_openov_links(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_merge_openov_links() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	count_links bigint;
	count_fix bigint;
	fixpoint text;
	fixlink record;
	newlink record;
	newstart text;
	newend text;
	count_dups integer;
BEGIN

	FOR fixpoint IN SELECT ownercode||stopcode FROM temp.vu_openov_stops_false LOOP
		-- RAISE NOTICE '%', fixpoint;
		EXECUTE 'CREATE OR REPLACE VIEW temp.vu_links_to_fix_now AS SELECT * FROM temp.openov_links_to_merge 
			WHERE stopcode_start= '||quote_literal(fixpoint)||' OR stopcode_end= '||quote_literal(fixpoint);
		SELECT count(*) FROM temp.vu_links_to_fix_now INTO count_links;
		RAISE NOTICE '% links to fix on point %', count_links, fixpoint;
		
		-- LOOP THIS PROCESS UNTIL NO LINKS TO MERGE
		WHILE count_links > 0 LOOP
			SELECT * FROM temp.vu_links_to_fix_now LIMIT 1 INTO fixlink;
			IF fixlink.stopcode_start<>fixpoint THEN
				newstart:=fixlink.stopcode_start;
			ELSEIF fixlink.stopcode_end<>fixpoint THEN
				newstart:=fixlink.stopcode_end;
			END IF;

			FOR newlink IN SELECT * FROM temp.vu_links_to_fix_now WHERE sid<>fixlink.sid AND ownercode||lineid=fixlink.ownercode||fixlink.lineid LOOP
				IF newlink.stopcode_start<>fixpoint THEN
					newend:=newlink.stopcode_start;
				ELSEIF newlink.stopcode_end<>fixpoint THEN
					newend:=newlink.stopcode_end;
				END IF;
				IF newend<>newstart THEN
					-- This check is essential to avoid adding duplicates to the links to merge list
					-- they can easily occur when there are intensely used false stops in the middle of long
					-- chains of other false stops. Without this it got to a stop having 6000+ links, when
					-- when they shouldn't have more than 100
					SELECT count(*) FROM temp.openov_links_to_merge WHERE ownercode=fixlink.ownercode AND 
					lineid=fixlink.lineid AND stopcode_start=newstart AND stopcode_end=newend INTO count_dups;
					IF count_dups = 0 THEN
						INSERT INTO temp.openov_links_to_merge (ownercode,lineid, stopcode_start, stopcode_end) VALUES(fixlink.ownercode,fixlink.lineid, newstart, newend);
					END IF;
				END IF;
			END LOOP;

			DELETE FROM temp.openov_links_to_merge WHERE sid=fixlink.sid;
			SELECT count(*) FROM temp.vu_links_to_fix_now INTO count_links;
			-- RAISE NOTICE '% links to fix', count_links;
		END LOOP;
	END LOOP;

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_merge_openov_links() OWNER TO postgres;

--
-- TOC entry 1489 (class 1255 OID 201960)
-- Dependencies: 11 2584
-- Name: _phd_multisource_road_subgraph(text, text, text, double precision, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_multisource_road_subgraph(sources_list text, sources_id text, mode text, radius double precision, output text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	catch_table text;
	graph_table text;
	segment integer;
	links_cost text;
	segment_id text;
	counter integer;

BEGIN
	
	-- prepare output tables
	catch_table := output||'_subcatch';
	graph_table := output||'_subgraph';
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name = catch_table) THEN
		RETURN 'Output table already exists!';
	ELSE
		EXECUTE 'CREATE TABLE '||catch_table||' (vertex_id integer, metric double precision, topological integer,
			angular double precision, axial double precision, continuity double precision)';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name  = graph_table) THEN
		RETURN 'Output table already exists!';
	ELSE
		EXECUTE 'CREATE TABLE '||graph_table||' (LIKE graph.roads_dual)';
	END IF;
	
	-- prepare or clean temporary tables
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_segments_list') THEN
		DELETE FROM temp_segments_list;
	ELSE
		CREATE TEMP TABLE temp_segments_list (id integer); 
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_buffer_graph') THEN
		DELETE FROM temp_buffer_graph;
	ELSE
		CREATE TEMP TABLE temp_buffer_graph (LIKE graph.roads_dual); 
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_all_catch') THEN
		DELETE FROM temp_all_catch;
	ELSE
		CREATE TEMP TABLE temp_all_catch (vertex_id integer, edge_id integer, cost double precision); 
	END IF;

	-- get all segments within distance to reduce initial graph size
	EXECUTE 'INSERT INTO temp_segments_list SELECT '||sources_id||' FROM '||sources_list;
	EXECUTE 'INSERT INTO temp_buffer_graph SELECT * FROM graph.roads_dual 
		WHERE ST_DWithin(the_geom,(SELECT ST_Collect(the_geom) FROM '||sources_list||'),'||radius||')';
	
	-- get driving distance
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, metric AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	
	-- find the shortest metric distance to any of the segs
	EXECUTE 'INSERT INTO '||catch_table||' (vertex_id, metric) SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id';
	
	-- get all links from the graph that connect nodes within catchment
	EXECUTE 'INSERT INTO '||graph_table||' SELECT * FROM temp_buffer_graph WHERE source IN (SELECT vertex_id FROM '||catch_table||') AND target IN (SELECT vertex_id FROM '||catch_table||')';


	-- calculate the angular distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, cumangular AS cost FROM '||graph_table||' WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest angular distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET angular=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
	
	-- calculate the topological distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, 1.0::float8 AS cost FROM '||graph_table||' WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest topological distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET topological=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the axial distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, axial AS cost FROM '||graph_table||' WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET axial=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the continuity distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, continuity_v2 AS cost FROM '||graph_table||' WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest continuity distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET continuity=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
		
	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_multisource_road_subgraph(sources_list text, sources_id text, mode text, radius double precision, output text) OWNER TO postgres;

--
-- TOC entry 1490 (class 1255 OID 203809)
-- Dependencies: 11 2584
-- Name: _phd_multisource_road_subgraph_pll(text, text, text, double precision, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_multisource_road_subgraph_pll(sources_list text, sources_id text, mode text, radius double precision, output text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	catch_table text;
	graph_table text;
	segment integer;
	links_cost text;
	segment_id text;
	counter integer;

BEGIN
	
	-- prepare output tables
	catch_table := output||'_subcatch';
	graph_table := output||'_subgraph';
	
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name = catch_table) THEN
		EXECUTE 'CREATE TABLE '||catch_table||' (vertex_id integer, metric double precision, topological integer,
			angular double precision, axial double precision, continuity double precision)';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_schema||'.'||table_name  = graph_table) THEN
		EXECUTE 'CREATE TABLE '||graph_table||' (LIKE graph.roads_dual)';
	END IF;
	
	-- prepare or clean temporary tables
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_segments_list') THEN
		DELETE FROM temp_segments_list;
	ELSE
		CREATE TEMP TABLE temp_segments_list (id integer); 
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_buffer_graph') THEN
		DELETE FROM temp_buffer_graph;
	ELSE
		CREATE TEMP TABLE temp_buffer_graph (LIKE graph.roads_dual); 
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_all_catch') THEN
		DELETE FROM temp_all_catch;
	ELSE
		CREATE TEMP TABLE temp_all_catch (vertex_id integer, edge_id integer, cost double precision); 
	END IF;

	-- get all segments within distance to reduce initial graph size
	EXECUTE 'INSERT INTO temp_segments_list SELECT '||sources_id||' FROM '||sources_list;
	EXECUTE 'INSERT INTO temp_buffer_graph SELECT * FROM graph.roads_dual 
		WHERE ST_DWithin(the_geom,(SELECT ST_Collect(the_geom) FROM '||sources_list||'),'||radius||')';
	
	-- get metric driving distance
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, metric AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	
	-- add the shortest metric distance to any of the segs
	EXECUTE 'INSERT INTO '||catch_table||' (vertex_id, metric) SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id';
	
	-- get all links from the graph that connect nodes within catchment
	EXECUTE 'INSERT INTO '||graph_table||' SELECT * FROM temp_buffer_graph WHERE source IN (SELECT vertex_id FROM '||catch_table||') AND target IN (SELECT vertex_id FROM '||catch_table||')';


	-- calculate the angular distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, cumangular AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest angular distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET angular=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
	
	-- calculate the segment topological distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, segment::float8 AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest topological distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET topological=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the axial distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, axial AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET axial=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the continuity distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, continuity_v2 AS cost FROM temp_buffer_graph WHERE ('||mode||'=True OR '||mode||' IS NULL) AND service IS NULL'', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest continuity distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET continuity=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
		
	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_multisource_road_subgraph_pll(sources_list text, sources_id text, mode text, radius double precision, output text) OWNER TO postgres;

--
-- TOC entry 1498 (class 1255 OID 169807)
-- Dependencies: 11 2584
-- Name: _phd_node_graph(text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_node_graph(mode text, distance text, target text, target_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_node_graph(mode text, distance text, target text, target_type text) OWNER TO postgres;

--
-- TOC entry 1492 (class 1255 OID 169806)
-- Dependencies: 11 2584
-- Name: _phd_node_radius(text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_node_radius(mode text, distance text, target text, target_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_node_radius(mode text, distance text, target text, target_type text) OWNER TO postgres;

--
-- TOC entry 1491 (class 1255 OID 192606)
-- Dependencies: 11 2584
-- Name: _phd_prepare_activity(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_prepare_activity(this_code text, this_type text, radius double precision) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	source_table text;
	source_id text;
	source_geom text;
	
BEGIN
	
	-- set tables to use depending on type of origin
	IF this_type = 'pcode' THEN
		source_table:= 'survey.sampling_points';
		source_id := 'pcode';
		source_geom := 'building_geom';
	ELSEIF this_type = 'building' THEN
		source_table:= 'urbanform.buildings_randstad';
		source_id := 'building_id';
		source_geom := 'the_point';
	ELSEIF this_type = 'stop' THEN
		source_table:= 'network.transit_stops';
		source_id := 'stop_id';
		source_geom := 'the_geom';
	ELSEIF this_type = 'road' THEN
		source_table:= 'network.roads_randstad';
		source_id := 'sid';
		source_geom := 'the_point';
	END IF;

	-- create set of temporary urban form layers
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_roads_interfaces_incatch') THEN
		DELETE FROM temp_roads_interfaces_incatch;
		EXECUTE 'INSERT INTO temp_roads_interfaces_incatch SELECT * FROM urbanform.buildings_roads_interfaces_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_roads_interfaces_incatch AS SELECT * FROM urbanform.buildings_roads_interfaces_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_areas_interfaces_incatch') THEN
		DELETE FROM temp_areas_interfaces_incatch;
		EXECUTE 'INSERT INTO temp_areas_interfaces_incatch SELECT * FROM urbanform.buildings_areas_interfaces_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_areas_interfaces_incatch AS SELECT * FROM urbanform.buildings_areas_interfaces_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_buildings_incatch') THEN
		DELETE FROM temp_buildings_incatch;
		EXECUTE 'INSERT INTO temp_buildings_incatch SELECT * FROM urbanform.buildings_randstad WHERE units IS NOT NULL AND ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_buildings_incatch AS SELECT * FROM urbanform.buildings_randstad WHERE units IS NOT NULL AND ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_prepare_activity(this_code text, this_type text, radius double precision) OWNER TO postgres;

--
-- TOC entry 1495 (class 1255 OID 192603)
-- Dependencies: 11 2584
-- Name: _phd_prepare_location(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_prepare_location(this_code text, this_type text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	result text;
	
BEGIN
	--RAISE NOTICE 'preparing % %', this_type, this_code;

	RAISE NOTICE 'preparing subgraphs';
	-- create subgraphs for each private transport mode
	PERFORM _phd_prepare_subgraph(this_code, this_type, 'nonmotor', 7500);
	PERFORM _phd_prepare_subgraph(this_code, this_type, 'car', 4000);

	RAISE NOTICE 'preparing urban form';
	-- create sets of urban form layers
	PERFORM _phd_prepare_network(this_code, this_type, 7500);
	PERFORM _phd_prepare_activity(this_code, this_type, 7500);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_prepare_location(this_code text, this_type text) OWNER TO postgres;

--
-- TOC entry 1496 (class 1255 OID 192605)
-- Dependencies: 11 2584
-- Name: _phd_prepare_network(text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_prepare_network(this_code text, this_type text, radius double precision) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	source_table text;
	source_id text;
	source_geom text;

BEGIN
	-- set tables to use depending on type of origin
	IF this_type = 'pcode' THEN
		source_table:= 'survey.sampling_points';
		source_id := 'pcode';
		source_geom := 'building_geom';
	ELSEIF this_type = 'building' THEN
		source_table:= 'urbanform.buildings_randstad';
		source_id := 'building_id';
		source_geom := 'the_point';
	ELSEIF this_type = 'stop' THEN
		source_table:= 'network.transit_stops';
		source_id := 'stop_id';
		source_geom := 'the_geom';
	ELSEIF this_type = 'road' THEN
		source_table:= 'network.roads_randstad';
		source_id := 'sid';
		source_geom := 'the_point';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_roads_incatch') THEN
		DELETE FROM temp_roads_incatch;
		EXECUTE 'INSERT INTO temp_roads_incatch SELECT * FROM network.roads_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_roads_incatch AS SELECT * FROM network.roads_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_nodes_incatch') THEN
		DELETE FROM temp_nodes_incatch;
		EXECUTE 'INSERT INTO temp_nodes_incatch SELECT * FROM network.roads_nodes_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_nodes_incatch AS SELECT * FROM network.roads_nodes_randstad WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_areas_incatch') THEN
		DELETE FROM temp_areas_incatch;
		EXECUTE 'INSERT INTO temp_areas_incatch SELECT * FROM network.areas WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_areas_incatch AS SELECT * FROM network.areas WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	-- public transport networks
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_transit_roads_incatch') THEN
		DELETE FROM temp_transit_roads_incatch;
		EXECUTE 'INSERT INTO temp_transit_roads_incatch SELECT * FROM network.transit_roads_interfaces WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_transit_roads_incatch AS SELECT * FROM network.transit_roads_interfaces WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_transit_areas_incatch') THEN
		DELETE FROM temp_transit_areas_incatch;
		EXECUTE 'INSERT INTO temp_transit_areas_incatch SELECT * FROM network.transit_areas_interfaces WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_transit_areas_incatch AS SELECT * FROM network.transit_areas_interfaces WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;
	
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_transit_incatch') THEN
		DELETE FROM temp_transit_incatch;
		EXECUTE 'INSERT INTO temp_transit_incatch SELECT * FROM network.transit_stops WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_transit_incatch AS SELECT * FROM network.transit_stops WHERE ST_DWithin(the_geom,
			(SELECT '||source_geom||' FROM '||source_table||' WHERE '||source_id||'='||quote_literal(this_code)||'),'||quote_literal(radius)||')';
	END IF;

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_prepare_network(this_code text, this_type text, radius double precision) OWNER TO postgres;

--
-- TOC entry 1494 (class 1255 OID 216281)
-- Dependencies: 11 2584
-- Name: _phd_prepare_subgraph(text, text, text, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_prepare_subgraph(this_code text, this_type text, mode text, radius double precision) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	catch_table text;
	graph_table text;
	segment integer;
	links_table text;
	links_id text;
	links_cost double precision;
	segment_id text;
	counter integer;
	mode_filter text;

BEGIN
	catch_table := 'temp_'||mode||'_catch';
	graph_table := 'temp_'||mode||'_graph';
	--counter:=0;
	IF mode='nonmotor' THEN
		mode_filter := '(coalesce(pedestrian,True)=True OR coalesce(bicycle,True)=True)';
	ELSEIF mode='car' THEN
		mode_filter := 'coalesce(car,True)=True';
	END IF;

	-- set tables to use depending on type of origin
	IF this_type = 'pcode' THEN
		links_table:= 'survey.sampling_roads_interfaces';
		links_id := 'pcode';
		segment_id := 'target_id';
	ELSEIF this_type = 'building' THEN
		links_table:= 'urbanform.buildings_roads_interfaces_randstad';
		links_id := 'building_id';
		segment_id := 'target_id';
	ELSEIF this_type = 'stop' THEN
		links_table:= 'network.transit_roads_interfaces';
		links_id := 'stop_id';
		segment_id := 'road_id';
	ELSEIF this_type = 'road' THEN
		links_table:= 'network.roads_randstad';
		links_id := 'sid';
		segment_id := links_id;
	END IF;

	-- prepare or clean temporary tables
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = catch_table) THEN
		EXECUTE 'DELETE FROM '||catch_table;
	ELSE
		EXECUTE 'CREATE TEMP TABLE '||catch_table||' (vertex_id integer, metric double precision, axial double precision,
			angular double precision, continuity double precision, segment double precision)';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = graph_table) THEN
		EXECUTE 'DELETE FROM '||graph_table;
	ELSE
		EXECUTE 'CREATE TEMP TABLE '||graph_table||' (LIKE graph.roads_dual)';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_all_catch') THEN
		DELETE FROM temp_all_catch;
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_all_catch (vertex_id integer, edge_id integer, cost double precision)'; 
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_segments_list') THEN
		DELETE FROM temp_segments_list;
	ELSE
		EXECUTE 'CREATE TEMP TABLE temp_segments_list (id integer)'; 
	END IF;


	-- get driving distance to all segments linked to a origin code
	EXECUTE 'INSERT INTO temp_segments_list SELECT '||segment_id||' FROM '||links_table||' WHERE '||links_id||' = '||quote_literal(this_code);

-- 	SELECT count(*) FROM temp_segments_list INTO counter;
-- 	RAISE NOTICE 'segs %',counter;
	
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'SELECT * FROM graph.roads_dual_randstad WHERE '||mode_filter||' AND (source='||quote_literal(segment)||' OR target='||quote_literal(segment)||')' INTO counter;
		IF counter > 0 THEN
			EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
			(''SELECT sid AS id, source, target, metric AS cost FROM graph.roads_dual_randstad WHERE '||mode_filter||''', '||segment||','||radius||',false,false)'; 
		ELSE
			DELETE FROM temp_segments_list WHERE id=segment;
		END IF;
	END LOOP;
	
	-- find the shortest metric distance to any of the segs
	EXECUTE 'INSERT INTO '||catch_table||' (vertex_id, metric) SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id';
	
	-- get all links from the graph that connect nodes within catchment
	EXECUTE 'INSERT INTO '||graph_table||' SELECT * FROM graph.roads_dual_randstad WHERE source IN (SELECT vertex_id FROM '||catch_table||') AND target IN (SELECT vertex_id FROM '||catch_table||')';

	-- calculate the axial distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, axial AS cost FROM '||graph_table||' WHERE '||mode_filter||''', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET axial=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
/*	
	-- calculate the angular distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, cumangular AS cost FROM '||graph_table||' WHERE '||mode_filter||''', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET angular=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the segment distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, segment::double precision AS cost FROM '||graph_table||' WHERE '||mode_filter||''', '||segment||','||radius||',false,false)'; 
	END LOOP;
		-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET segment=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';

	-- calculate the continuity distance to all segments
	DELETE FROM temp_all_catch;
	FOR segment IN SELECT id FROM temp_segments_list LOOP
		EXECUTE 'INSERT INTO temp_all_catch SELECT * FROM driving_distance 
		(''SELECT sid AS id, source, target, continuity_v2 AS cost FROM '||graph_table||' WHERE '||mode_filter||''', '||segment||','||radius||',false,false)'; 
	END LOOP;
	-- find the shortest axial distance to any of the segs
	EXECUTE 'UPDATE '||catch_table||' as catch SET continuity=temp.cost FROM (SELECT vertex_id, min(cost) as cost FROM temp_all_catch GROUP BY vertex_id) as temp WHERE catch.vertex_id=temp.vertex_id';
*/
	RETURN 'Tables '||catch_table||' and '||graph_table||' are ready.';
END

$$;


ALTER FUNCTION public._phd_prepare_subgraph(this_code text, this_type text, mode text, radius double precision) OWNER TO postgres;

--
-- TOC entry 1497 (class 1255 OID 192857)
-- Dependencies: 11 2584
-- Name: _phd_proximity(text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_proximity(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, results_table text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
	results_metric text;
	results_axial text;
	results_mid text;
	results_aid text;
	links_table text;
	target_table text;
	counter integer;

BEGIN
	
	results_metric := target_type||'_'||target_alias||'_dist';
	results_axial := target_type||'_'||target_alias||'_ax';
	results_mid := target_type||'_'||target_alias||'_mid';
	results_aid := target_type||'_'||target_alias||'_axid';

	-- set tables to use depending on type of target
	IF target_type = 'building' THEN
		links_table := 'temp_roads_interfaces_incatch';
		target_table := 'temp_buildings_incatch';
	ELSEIF target_type = 'stop' THEN
		links_table := 'temp_transit_roads_incatch';
		target_table := 'temp_transit_incatch';
	ELSEIF target_type = 'road' THEN
		links_table := 'temp_roads_incatch';
		target_table := 'temp_areas_incatch';
	END IF;

	-- check if required tables are there
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = catch_table) OR 
		NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = target_table) OR 
		NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = links_table) THEN
		RETURN 'Prepare the network and target within a catchment area first.';
	END IF;
	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.tables WHERE table_name = 'temp_proximity_results') THEN
		DELETE FROM temp_proximity_results;
	ELSE
		CREATE TEMP TABLE temp_proximity_results (id integer, cost double precision);
	END IF;
 
	IF target_type = 'building' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_roads_interfaces_incatch as link ON (catch.vertex_id = link.target_id) 
			JOIN temp_buildings_incatch as target ON (link.building_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.metric ASC LIMIT 1';
		-- and include pedestrian areas, that can provide closer access
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_areas_incatch as link1 ON (catch.vertex_id = link1.road_id) 
			JOIN temp_areas_interfaces_incatch as link2 ON (link1.group_id = link2.area_id) 
			JOIN temp_buildings_incatch as target ON (link2.building_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch..metric ASC LIMIT 1';
			
	ELSEIF target_type = 'stop' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_transit_roads_incatch as link ON (catch.vertex_id = link.road_id) 
			JOIN temp_transit_incatch as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.metric ASC LIMIT 1';
		-- redo this to include pedestrian areas, that provide closer access
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_transit_areas_incatch as link ON (catch.vertex_id = link.road_id) 
			JOIN temp_transit_incatch as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.metric ASC LIMIT 1';
			
	ELSEIF target_type = 'road' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_roads_incatch as target ON (catch.vertex_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.metric ASC LIMIT 1';	
		-- redo this to include pedestrian areas, that provide closer access and in themselves can be targets
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.road_sid as id, catch.metric
			FROM '||catch_table||' as catch 
			JOIN temp_areas_incatch as target ON (catch.vertex_id = target.road_sid) 
			ORDER BY catch.metric ASC LIMIT 1';
	END IF;

	-- update results table
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_mid) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_mid||' integer';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_metric) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_metric||' double precision';
	END IF;
	
	EXECUTE 'UPDATE '||results_table||' as prox SET '||results_mid||'=temp.id, '||results_metric||'=round(temp.cost) 
		FROM (SELECT * FROM temp_proximity_results ORDER BY cost ASC LIMIT 1) as temp 
		WHERE prox.'||this_type||'='||quote_literal(this_code);
		
	-- repeat for axial
	DELETE FROM temp_proximity_results;
	IF target_type = 'building' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_roads_interfaces_incatch as link ON (catch.vertex_id = link.target_id) 
			JOIN temp_buildings_incatch as target ON (link.building_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.cost ASC LIMIT 1';
		-- and include pedestrian areas, that can provide closer access
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_areas_incatch as link1 ON (catch.vertex_id = link1.road_id) 
			JOIN temp_areas_interfaces_incatch as link2 ON (link1.group_id = link2.area_id) 
			JOIN temp_buildings_incatch as target ON (link2.building_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.cost ASC LIMIT 1';
			
	ELSEIF target_type = 'stop' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_transit_roads_incatch as link ON (catch.vertex_id = link.road_id) 
			JOIN temp_transit_incatch as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.axial ASC LIMIT 1';
		-- redo this to include pedestrian areas, that provide closer access
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_transit_areas_incatch as link ON (catch.vertex_id = link.road_id) 
			JOIN temp_transit_incatch as target ON (link.stop_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.axial ASC LIMIT 1';
			
	ELSEIF target_type = 'road' THEN
		-- retrieve results from catchment table
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_roads_incatch as target ON (catch.vertex_id = target.sid) 
			WHERE target.'||target||' ORDER BY catch.axial ASC LIMIT 1';	
		-- redo this to include pedestrian areas, that provide closer access and in themselves can be targets
		EXECUTE 'INSERT INTO temp_proximity_results SELECT target.road_sid as id, catch.axial
			FROM '||catch_table||' as catch 
			JOIN temp_areas_incatch as target ON (catch.vertex_id = target.road_sid) 
			ORDER BY catch.axial ASC LIMIT 1';
	END IF;
		
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_aid) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_aid||' double precision';
	END IF;
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.columns WHERE table_schema||'.'||table_name = results_table AND column_name = results_axial) THEN
		EXECUTE 'ALTER TABLE '||results_table||' ADD COLUMN '||results_axial||' double precision';
	END IF;

	EXECUTE 'UPDATE '||results_table||' as prox SET '||results_aid||'=temp.id, '||results_axial||'=round(temp.cost)
		FROM (SELECT * FROM temp_proximity_results ORDER BY cost ASC LIMIT 1) as temp 
		WHERE prox.'||this_type||'='||quote_literal(this_code);

	RETURN 'OK';
END

$$;


ALTER FUNCTION public._phd_proximity(this_code text, this_type text, catch_table text, target text, target_type text, target_alias text, results_table text) OWNER TO postgres;

--
-- TOC entry 1483 (class 1255 OID 67659)
-- Dependencies: 11 2584 1842
-- Name: _phd_split_lines(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_split_lines(lineq text, pointq text, OUT lineid integer, OUT line geometry) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE
	linerec record;
	pointrec record;
	linepos float;
	start_ float;
	end_ float;
	loopqry text;
BEGIN
	EXECUTE 'CREATE TEMP TABLE line_tmp as '|| lineq;
	EXECUTE 'CREATE TEMP TABLE point_tmp as '|| pointq;

	FOR linerec in EXECUTE 'SELECT * FROM line_tmp ORDER BY sid' LOOP
		start_ := 0;
		/*loopqry := 'SELECT *, line_locate_point('||linerec.the_geom||',the_geom) as frac from
			point_tmp where intersects(the_geom,'||linerec.the_geom||
			')ORDER BY line_locate_point('||linerec.the_geom||',the_geom)';
		*/
		FOR pointrec IN SELECT *,line_locate_point(linerec.the_geom, the_geom) as
			frac FROM point_tmp where intersects(the_geom,linerec.the_geom) ORDER BY
			line_locate_point(linerec.the_geom, the_geom) LOOP
		--FOR pointrec in EXECUTE loopqry LOOP
			end_ := pointrec.frac;
			lineid := linerec.sid;
			--RAISE NOTICE 'start=%,end=%',start_, end_;
			line := line_substring(linerec.the_geom, start_, end_);
			start_:= end_;
			RETURN NEXT;
		END LOOP;
		line:= line_substring(linerec.the_geom, end_,1.0);
		RETURN NEXT;
	END LOOP;
	
	DROP TABLE line_tmp;
	DROP TABLE point_tmp;
 RETURN;
END;
$$;


ALTER FUNCTION public._phd_split_lines(lineq text, pointq text, OUT lineid integer, OUT line geometry) OWNER TO postgres;

--
-- TOC entry 618 (class 1255 OID 29746)
-- Dependencies: 11 2584
-- Name: _phd_updatecolumns(character varying, character varying, integer, integer, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION _phd_updatecolumns(schema_name character varying, update_table character varying, from_col integer, to_col integer, expression_s character varying, expression_m character varying, expression_e character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$

DECLARE
	i integer;
	colname text;

BEGIN

	FOR i IN from_col..to_col LOOP

		Execute'SELECT column_name FROM INFORMATION_SCHEMA.columns WHERE table_schema = '||quote_literal(schema_name)||' AND table_name = '||quote_literal(update_table)||' AND ordinal_position = '||i into colname;		
		RAISE NOTICE 'execute inputs: % ',colname;

		IF expression_s IS NOT NULL AND expression_m IS NULL AND expression_e IS NULL THEN
			Execute 'UPDATE '||schema_name||'.'||update_table||' as foo SET '||colname||'='||expression_s;
		ELSEIF expression_s IS NOT NULL AND expression_m IS NULL AND expression_e IS NOT NULL THEN
			Execute 'UPDATE '||schema_name||'.'||update_table||' as foo SET '||colname||'='||expression_s||colname||expression_e;
		ELSEIF expression_s IS NOT NULL AND expression_m IS NOT NULL AND expression_e IS NOT NULL THEN
			Execute 'UPDATE '||schema_name||'.'||update_table||' as foo SET '||colname||'='||expression_s||colname||expression_m||colname||expression_e;
		END IF;

	END LOOP;

	RETURN i;   

END

$$;


ALTER FUNCTION public._phd_updatecolumns(schema_name character varying, update_table character varying, from_col integer, to_col integer, expression_s character varying, expression_m character varying, expression_e character varying) OWNER TO postgres;


-- TOC entry 754 (class 1255 OID 29902)
-- Dependencies: 11 2584 1822
-- Name: find_extent(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION find_extent(text, text) RETURNS box2d
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE
	tablename alias for $1;
	columnname alias for $2;
	myrec RECORD;

BEGIN
	FOR myrec IN EXECUTE 'SELECT extent("' || columnname || '") FROM "' || tablename || '"' LOOP
		return myrec.extent;
	END LOOP;
END;
$_$;


ALTER FUNCTION public.find_extent(text, text) OWNER TO postgres;

--
-- TOC entry 755 (class 1255 OID 29903)
-- Dependencies: 11 2584 1822
-- Name: find_extent(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION find_extent(text, text, text) RETURNS box2d
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $_$
DECLARE
	schemaname alias for $1;
	tablename alias for $2;
	columnname alias for $3;
	myrec RECORD;

BEGIN
	FOR myrec IN EXECUTE 'SELECT extent("' || columnname || '") FROM "' || schemaname || '"."' || tablename || '"' LOOP
		return myrec.extent;
	END LOOP;
END;
$_$;


ALTER FUNCTION public.find_extent(text, text, text) OWNER TO postgres;

--
-- TOC entry 778 (class 1255 OID 29904)
-- Dependencies: 11 2584
-- Name: find_nearest_link_within_distance(character varying, double precision, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION find_nearest_link_within_distance(point character varying, distance double precision, tbl character varying) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    row record;
    x float8;
    y float8;
    
    srid integer;
    
BEGIN

    FOR row IN EXECUTE 'select getsrid(the_geom) as srid from '||tbl||' where gid = (select min(gid) from '||tbl||')' LOOP
    END LOOP;
	srid:= row.srid;
    
    -- Getting x and y of the point
    FOR row in EXECUTE 'select x(GeometryFromText('''||point||''', '||srid||')) as x' LOOP
    END LOOP;
	x:=row.x;

    FOR row in EXECUTE 'select y(GeometryFromText('''||point||''', '||srid||')) as y' LOOP
    END LOOP;
	y:=row.y;

    -- Searching for a link within the distance
    FOR row in EXECUTE 'select gid, distance(the_geom, GeometryFromText('''||point||''', '||srid||')) as dist from '||tbl||
			    ' where setsrid(''BOX3D('||x-distance||' '||y-distance||', '||x+distance||' '||y+distance||')''::BOX3D, '||srid||')&&the_geom order by dist asc limit 1'
    LOOP
    END LOOP;

    IF row.gid IS NULL THEN
	    --RAISE EXCEPTION 'Data cannot be matched';
	    RETURN NULL;
    END IF;

    RETURN row.gid;

END;
$$;


ALTER FUNCTION public.find_nearest_link_within_distance(point character varying, distance double precision, tbl character varying) OWNER TO postgres;

--
-- TOC entry 779 (class 1255 OID 29905)
-- Dependencies: 11 2584
-- Name: find_nearest_node_within_distance(character varying, double precision, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION find_nearest_node_within_distance(point character varying, distance double precision, tbl character varying) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    row record;
    x float8;
    y float8;
    d1 double precision;
    d2 double precision;
    d  double precision;
    field varchar;

    node integer;
    source integer;
    target integer;
    
    srid integer;
    
BEGIN

    FOR row IN EXECUTE 'select getsrid(the_geom) as srid from '||tbl||' where gid = (select min(gid) from '||tbl||')' LOOP
    END LOOP;
	srid:= row.srid;

    -- Getting x and y of the point

    FOR row in EXECUTE 'select x(GeometryFromText('''||point||''', '||srid||')) as x' LOOP
    END LOOP;
	x:=row.x;

    FOR row in EXECUTE 'select y(GeometryFromText('''||point||''', '||srid||')) as y' LOOP
    END LOOP;
	y:=row.y;

    -- Getting nearest source

    FOR row in EXECUTE 'select source, distance(StartPoint(the_geom), GeometryFromText('''||point||''', '||srid||')) as dist from '||tbl||
			    ' where setsrid(''BOX3D('||x-distance||' '||y-distance||', '||x+distance||' '||y+distance||')''::BOX3D, '||srid||')&&the_geom order by dist asc limit 1'
    LOOP
    END LOOP;
    
    d1:=row.dist;
    source:=row.source;

    -- Getting nearest target

    FOR row in EXECUTE 'select target, distance(EndPoint(the_geom), GeometryFromText('''||point||''', '||srid||')) as dist from '||tbl||
			    ' where setsrid(''BOX3D('||x-distance||' '||y-distance||', '||x+distance||' '||y+distance||')''::BOX3D, '||srid||')&&the_geom order by dist asc limit 1'
    LOOP
    END LOOP;

    -- Checking what is nearer - source or target
    
    d2:=row.dist;
    target:=row.target;
    IF d1<d2 THEN
	node:=source;
        d:=d1;
    ELSE
	node:=target;
        d:=d2;
    END IF;

    IF d=NULL OR d>distance THEN
        node:=NULL;
    END IF;

    RETURN node;

END;
$$;


ALTER FUNCTION public.find_nearest_node_within_distance(point character varying, distance double precision, tbl character varying) OWNER TO postgres;

--
-- TOC entry 780 (class 1255 OID 29906)
-- Dependencies: 11 2584 1867
-- Name: find_node_by_nearest_link_within_distance(character varying, double precision, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION find_node_by_nearest_link_within_distance(point character varying, distance double precision, tbl character varying) RETURNS link_point
    LANGUAGE plpgsql STRICT
    AS $$
DECLARE
    row record;
    link integer;
    d1 double precision;
    d2 double precision;
    field varchar;
    res link_point;
    
    srid integer;
BEGIN

    FOR row IN EXECUTE 'select getsrid(the_geom) as srid from '||tbl||' where gid = (select min(gid) from '||tbl||')' LOOP
    END LOOP;
	srid:= row.srid;


    -- Searching for a nearest link
    
    FOR row in EXECUTE 'select id from find_nearest_link_within_distance('''||point||''', '||distance||', '''||tbl||''') as id'
    LOOP
    END LOOP;
    IF row.id is null THEN
        res.id = -1;
        RETURN res;
    END IF;
    link:=row.id;

    -- Check what is nearer - source or target
    
    FOR row in EXECUTE 'select distance((select StartPoint(the_geom) from '||tbl||' where gid='||link||'), GeometryFromText('''||point||''', '||srid||')) as dist'
    LOOP
    END LOOP;
    d1:=row.dist;

    FOR row in EXECUTE 'select distance((select EndPoint(the_geom) from '||tbl||' where gid='||link||'), GeometryFromText('''||point||''', '||srid||')) as dist'
    LOOP
    END LOOP;
    d2:=row.dist;

    IF d1<d2 THEN
	field:='source';
    ELSE
	field:='target';
    END IF;
    
    FOR row in EXECUTE 'select '||field||' as id, '''||field||''' as f from '||tbl||' where gid='||link
    LOOP
    END LOOP;
        
    res.id:=row.id;
    res.name:=row.f;
    
    RETURN res;


END;
$$;


ALTER FUNCTION public.find_node_by_nearest_link_within_distance(point character varying, distance double precision, tbl character varying) OWNER TO postgres;

--
-- TOC entry 2591 (class 1255 OID 30660)
-- Dependencies: 11 611
-- Name: median(numeric); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE median(numeric) (
    SFUNC = array_append,
    STYPE = numeric[],
    INITCOND = '{}',
    FINALFUNC = public._final_median
);


ALTER AGGREGATE public.median(numeric) OWNER TO postgres;

--
-- TOC entry 2606 (class 1255 OID 203786)
-- Dependencies: 11 1488
-- Name: median(anyelement); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE median(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}',
    FINALFUNC = public._final_median
);


ALTER AGGREGATE public.median(anyelement) OWNER TO postgres;

--
-- TOC entry 2594 (class 1255 OID 30663)
-- Dependencies: 11 612
-- Name: mode(anyelement); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE mode(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}',
    FINALFUNC = _final_mode
);


ALTER AGGREGATE public.mode(anyelement) OWNER TO postgres;

--
-- TOC entry 2596 (class 1255 OID 30665)
-- Dependencies: 11 613
-- Name: range(numeric); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE range(numeric) (
    SFUNC = array_append,
    STYPE = numeric[],
    INITCOND = '{}',
    FINALFUNC = _final_range
);


ALTER AGGREGATE public.range(numeric) OWNER TO postgres;


-- Completed on 2013-10-02 08:32:56 BST

--
-- PostgreSQL database dump complete
--
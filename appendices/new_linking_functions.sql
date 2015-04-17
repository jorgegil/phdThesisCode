-- Function: _phd_eliminate_duplicates(text)

-- DROP FUNCTION _phd_eliminate_duplicates(text);

CREATE OR REPLACE FUNCTION _phd_eliminate_duplicates(sourcetable text)
  RETURNS text AS
$BODY$
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

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_eliminate_duplicates(text)
  OWNER TO postgres;

-- Function: _phd_link_all_points_by_id(text, text, text, text, text)

-- DROP FUNCTION _phd_link_all_points_by_id(text, text, text, text, text);

CREATE OR REPLACE FUNCTION _phd_link_all_points_by_id(pointsdata text, pointgeometry text, pointid text, groupid text, outputtable text)
  RETURNS text AS
$BODY$
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

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_link_all_points_by_id(text, text, text, text, text)
  OWNER TO postgres;

-- Function: _phd_merge_openov_links()

-- DROP FUNCTION _phd_merge_openov_links();

CREATE OR REPLACE FUNCTION _phd_merge_openov_links()
  RETURNS text AS
$BODY$
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

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_merge_openov_links()
  OWNER TO postgres;

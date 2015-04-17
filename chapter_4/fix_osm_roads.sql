-- TO FIX PROBLEM B / D2
-- THESE ARE JUST SOME TEST COMMANDS
--SELECT ST_ContainsProperly('LINESTRING(0 0, 1 1, 0 2)'::geometry, 'POINT(0 0)'::geometry);

-- DROP TABLE extracts.split_test_a cascade;
-- DROP TABLE extracts.to_split_a cascade;
-- DROP TABLE extracts.split_test_b cascade;
-- DROP TABLE extracts.to_split_b cascade;

CREATE TABLE extracts.split_test_a AS
SELECT rd.id, (ST_Dump(ST_Split(rd.the_geom,cr.the_geom))).geom the_geom, rd.tags, rd.road_type, rd.road_number,
rd.road_class, rd.road_number_int, rd.moped, rd.bicycle, rd.unlink, rd.layer
FROM extracts.to_segment as rd, extracts.roads_new_crossings as cr 
WHERE ST_Intersects(rd.the_geom,cr.the_geom);

ALTER TABLE extracts.split_test_a ADD COLUMN sid serial NOT NULL;
ALTER TABLE extracts.split_test_a ADD CONSTRAINT split_test_a_pk PRIMARY KEY (sid);

CREATE TABLE extracts.to_split_a AS
SELECT * FROM extracts.split_test_a WHERE sid IN
(SELECT rd.sid FROM extracts.split_test_a as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom) GROUP BY rd.sid);

DELETE FROM extracts.split_test_a WHERE sid IN
(SELECT rd.sid FROM extracts.split_test_a as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom) GROUP BY rd.sid);

CREATE TABLE extracts.split_test_b AS
SELECT rd.id, (ST_Dump(ST_Split(rd.the_geom,cr.the_geom))).geom the_geom, rd.tags, rd.road_type, rd.road_number,
rd.road_class, rd.road_number_int, rd.moped, rd.bicycle, rd.unlink, rd.layer
FROM extracts.to_split_a as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom);

ALTER TABLE extracts.split_test_b ADD COLUMN sid serial NOT NULL;
ALTER TABLE extracts.split_test_b ADD CONSTRAINT split_test_b_pk PRIMARY KEY (sid);

CREATE TABLE extracts.to_split_b AS
SELECT * FROM extracts.split_test_a WHERE sid IN
(SELECT rd.sid FROM extracts.split_test_b as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom) GROUP BY rd.sid);

DELETE FROM extracts.split_test_b WHERE sid IN
(SELECT rd.sid FROM extracts.split_test_b as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom) GROUP BY rd.sid);


DROP TABLE extracts.split_test_merge CASCADE;
CREATE TABLE extracts.split_test_merge AS SELECT *, 'A'::text pass FROM extracts.split_test_a;
INSERT INTO extracts.split_test_merge SELECT *, 'B'::text FROM extracts.split_test_b;

DROP TABLE extracts.split_test_clean CASCADE;
CREATE TABLE extracts.split_test_clean AS SELECT id, the_geom FROM extracts.split_test_merge GROUP BY the_geom, id;

------------------------------------------
-- TESTING WITH A COMPLETE DATA SET, COULDN'T HANDLE SO MUCH DATA...

-- START OF FIRST PASS
-- DROP TABLE extracts.roads_new_split CASCADE;

CREATE TABLE extracts.roads_new_split AS
SELECT rd.id, (ST_Dump(ST_Split(rd.the_geom,cr.the_geom))).geom the_geom
FROM extracts.roads_to_segment as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom);

ALTER TABLE extracts.roads_new_split ADD COLUMN sid serial NOT NULL;
ALTER TABLE extracts.roads_new_split ADD CONSTRAINT roads_new_split_pk PRIMARY KEY (sid);
CREATE INDEX roads_new_split_idx ON extracts.roads_new_split USING gist(the_geom);

CREATE TABLE extracts.roads_to_refine AS
SELECT * FROM extracts.roads_new_split WHERE sid IN
(SELECT rd.sid FROM extracts.roads_new_split as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom) GROUP BY rd.sid);
CREATE INDEX roads_to_refine_idx ON extracts.roads_to_refine USING gist(the_geom);

DELETE FROM extracts.roads_new_split WHERE sid IN (SELECT sid FROM extracts.roads_to_refine);

CREATE TABLE extracts.roads_new_split_merge AS SELECT *, '01'::text pass FROM extracts.roads_new_split;

-- START OF SECOND AND FOLLOWING PASSES
DROP TABLE extracts.roads_new_split CASCADE;
CREATE TABLE extracts.roads_new_split AS
SELECT rd.id, (ST_Dump(ST_Split(rd.the_geom,cr.the_geom))).geom the_geom
FROM extracts.roads_to_refine as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom);

ALTER TABLE extracts.roads_new_split ADD COLUMN sid serial NOT NULL;
ALTER TABLE extracts.roads_new_split ADD CONSTRAINT roads_new_split_pk PRIMARY KEY (sid);
CREATE INDEX roads_new_split_idx ON extracts.roads_new_split USING gist(the_geom);

DROP TABLE extracts.roads_to_refine CASCADE;

CREATE TABLE extracts.roads_to_refine AS
SELECT rd.* FROM extracts.roads_new_split as rd, extracts.roads_new_crossings as cr 
WHERE ST_ContainsProperly(rd.the_geom,cr.the_geom);
CREATE INDEX roads_to_refine_idx ON extracts.roads_to_refine USING gist(the_geom);

DELETE FROM extracts.roads_new_split WHERE sid IN (SELECT sid FROM extracts.roads_to_refine);

INSERT INTO extracts.roads_new_split_merge SELECT *, '02' FROM extracts.roads_new_split;

-- RUN AFTER INSERT RETURNS 0
CREATE TABLE extracts.roads_new_split_clean AS SELECT id, the_geom FROM extracts.split_test_merge GROUP BY the_geom, id;

-- END OF TESTING COMMANDS
------------------------------



-- Function: _phd_split_line_at_points(text, text, text, text, text)

-- DROP FUNCTION _phd_split_line_at_points(text, text, text, text, text);

CREATE OR REPLACE FUNCTION _phd_split_line_at_points(linedata text, idcolumn text, geomcolumn text, bladepoints text, outputtable text)
  RETURNS integer AS
$BODY$
DECLARE
	count_rec bigint;
	current_rec bigint;
	step smallint;
	new_lines smallint;
	test_count smallint;
BEGIN
  
	step:=1000;
    
	new_lines:= 2; --step;
	EXECUTE 'SELECT Count(*) FROM '||linedata INTO count_rec;
	current_rec:=0;

	-- preparatory steps creating required tables
	EXECUTE 'CREATE TABLE lines_to_split (id integer, the_geom geometry)';
	EXECUTE 'CREATE INDEX lines_to_split_idx ON lines_to_split USING GIST (the_geom)';
	EXECUTE 'CREATE TABLE points_to_split (id integer, the_geom geometry)';
	EXECUTE 'CREATE INDEX points_to_split_idx ON points_to_split USING GIST (the_geom)';
	
	EXECUTE 'CREATE TABLE split_lines_all (id integer, the_geom geometry, sid serial NOT NULL)';
	EXECUTE 'CREATE INDEX split_lines_all_idx ON split_lines_all USING GIST (the_geom)';
	EXECUTE 'CREATE TABLE split_lines_to_refine (id integer, the_geom geometry)';
	EXECUTE 'CREATE INDEX split_lines_to_refine_idx ON split_lines_to_refine USING GIST (the_geom)';
	EXECUTE 'CREATE TABLE points_to_refine (id integer, the_geom geometry)';
	EXECUTE 'CREATE INDEX points_to_refine_idx ON split_lines_to_refine USING GIST (the_geom)';
	EXECUTE 'CREATE TABLE split_lines_done (id integer, the_geom geometry)';
	EXECUTE 'CREATE INDEX split_lines_done_idx ON split_lines_done USING GIST (the_geom)';
	
	EXECUTE 'CREATE TABLE '||outputtable||' (line_id integer, the_geom geometry)';
	
	-- main loop to go through large table
	FOR current_rec IN 0..count_rec BY step LOOP
		RAISE NOTICE 'Splitting lines % to %, of %',current_rec,current_rec+step,count_rec;
		
		EXECUTE 'INSERT INTO lines_to_split SELECT '||idcolumn||','||geomcolumn||' 
			FROM '||linedata||' ORDER BY '||idcolumn||' ASC'||' LIMIT '||step||' OFFSET '||current_rec;
		EXECUTE 'INSERT INTO points_to_split SELECT poi.'||idcolumn||',poi.'||geomcolumn||' FROM '||bladepoints||' AS poi, lines_to_split AS lin 
			WHERE ST_Contains(lin.the_geom,poi.'||geomcolumn||') GROUP BY poi.'||idcolumn||',poi.'||geomcolumn;

		-- do a first split operation, following will be refine operations
		EXECUTE 'DELETE FROM split_lines_all';			
		EXECUTE 'INSERT INTO split_lines_all SELECT lin.id, (ST_Dump(ST_Split(lin.the_geom,poi.the_geom))).geom the_geom
			FROM lines_to_split AS lin, points_to_split AS poi WHERE ST_Contains(lin.the_geom,poi.the_geom)';
			
		EXECUTE 'DELETE FROM split_lines_all WHERE sid IN (SELECT sid FROM split_lines_all AS lin, points_to_split AS poi WHERE
			ST_Contains(lin.the_geom,poi.the_geom))';
		-- loop for recursive splitting of selected lines
		WHILE new_lines > 0 LOOP
			EXECUTE 'INSERT INTO split_lines_done SELECT id, the_geom FROM split_lines_all';		
			EXECUTE 'SELECT Count(*) FROM split_lines_all' INTO new_lines;
			-- RAISE NOTICE '--- % new line segments have been created...',new_lines;

			EXECUTE 'DELETE FROM split_lines_to_refine';		
			EXECUTE 'INSERT INTO split_lines_to_refine SELECT lin.id, (ST_Dump(ST_Difference(lin.the_geom,done.the_geom))).geom
				FROM lines_to_split AS lin, 
				(SELECT id, ST_Multi(ST_Collect(the_geom)) the_geom FROM split_lines_done GROUP BY id) AS done
				WHERE lin.id=done.id';
			
			EXECUTE 'DELETE FROM points_to_refine';
			EXECUTE 'INSERT INTO points_to_refine SELECT poi.id, poi.the_geom FROM points_to_split AS poi, split_lines_to_refine AS lin 
				WHERE ST_Contains(lin.the_geom,poi.the_geom) GROUP BY poi.id,poi.the_geom';

			EXECUTE 'DELETE FROM split_lines_all';			
			EXECUTE 'INSERT INTO split_lines_all SELECT lin.id, (ST_Dump(ST_Split(lin.the_geom,poi.the_geom))).geom the_geom
				FROM split_lines_to_refine AS lin, points_to_refine AS poi WHERE ST_Contains(lin.the_geom,poi.the_geom)';
			EXECUTE 'DELETE FROM split_lines_all WHERE sid IN (SELECT sid FROM split_lines_all AS lin, points_to_refine AS poi WHERE
				ST_Contains(lin.the_geom,poi.the_geom))';
		END LOOP;

		-- Need to add this in the end, not sure why...
		EXECUTE 'INSERT INTO split_lines_done SELECT id, the_geom FROM split_lines_to_refine';
		
		-- conclude operation
		EXECUTE 'INSERT INTO '||outputtable||' SELECT id, the_geom FROM split_lines_done GROUP BY the_geom, id';

		-- prepare next run
		EXECUTE 'DELETE FROM lines_to_split';
		EXECUTE 'DELETE FROM points_to_split';
		EXECUTE 'DELETE FROM split_lines_done';
		new_lines:=step;
	END LOOP;
	
	EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';
	-- EXECUTE 'ALTER TABLE '||outputtable||' ADD CONSTRAINT split_lines_output_pk PRIMARY KEY (sid)';

	-- Clean up
	DROP TABLE lines_to_split CASCADE;
	DROP TABLE points_to_split CASCADE;
	DROP TABLE split_lines_all CASCADE;
	DROP TABLE split_lines_to_refine CASCADE;
	DROP TABLE points_to_refine CASCADE;
	DROP TABLE split_lines_done CASCADE;
			
	RETURN 1;
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_split_line_at_points(text, text, text, text, text)
  OWNER TO postgres;


------------
-- TEST COMMAND

drop table extracts.test_split_roads cascade;
select _phd_split_line_at_points('extracts.test_to_explode', 'id', 'the_geom','extracts.test_crossings_to_explode','extracts.test_split_roads');

-- In the end I had to run several times because the process was taking longer and longer. Took one hour to split 240,000 lines
CREATE TABLE extracts.split_roads (line_id integer, the_geom geometry);

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 0;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 20000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 40000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 60000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 80000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 100000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 120000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 140000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 160000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 180000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 200000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

create or replace view extracts.vu_roads_to_explode AS SELECT * FROM extracts.roads_to_explode ORDER BY sid LIMIT 20000 OFFSET 220000;
select _phd_split_line_at_points('extracts.vu_roads_to_explode', 'id', 'the_geom','extracts.roads_crossings_to_explode','extracts.split_roads');

-------------------------------------------
-- ************************************* --
-------------------------------------------

-- TO FIX PROBLEM D1

-- THESE ARE JUST SOME TEST COMMANDS
drop table temp.to_merge_now cascade;
--drop table temp.merged_final cascade;
create table temp.to_merge_now as select * from temp.to_merge_p1;


drop table temp.merged_p1a cascade;
create table temp.merged_p1a as
SELECT id, node_1, road_type, (st_dump(merged_geom)).geom the_geom
FROM (  SELECT node_1, road_type, max(id) id, ST_Linemerge(ST_Collect(the_geom)) AS merged_geom
        FROM temp.to_merge_now
        GROUP BY node_1, road_type
) AS subq;

alter table temp.merged_p1a add column node_2 bigint;
update temp.merged_p1a as p1a set node_2=p1b.node_2 from temp.to_merge_now as p1b where p1a.node_1=p1b.node_1;
update temp.merged_p1a as p1a set node_2=p1b.node_2 from temp.to_merge_now as p1b where p1a.node_1=p1b.node_1 and p1a.node_1<>p1b.node_2;

drop table temp.merged_p1b cascade;
create table temp.merged_p1b as
SELECT id, node_2, road_type, (st_dump(merged_geom)).geom the_geom
FROM (  SELECT node_2, road_type, max(id) id, ST_Linemerge(ST_Collect(the_geom)) AS merged_geom
        FROM temp.merged_p1a
        GROUP BY node_2, road_type
) AS subq;

drop table temp.to_merge_now;
create table temp.to_merge_now as select * from temp.merged_p1b;

alter table temp.to_merge_now add column node_1 bigint;
update temp.to_merge_now as tmn set node_1=NULL, node_2=NULL;
create index to_merge_now_idx on temp.to_merge_now using gist (the_geom);

update temp.to_merge_now as tmn set node_1=nod.node_id from extracts.roads_new_nocross as nod
where ST_Intersects(ST_StartPoint(tmn.the_geom),nod.the_geom);

update temp.to_merge_now as tmn set node_2=nod.node_id from extracts.roads_new_nocross as nod
where ST_Intersects(ST_EndPoint(tmn.the_geom),nod.the_geom);

update temp.to_merge_now set node_1=node_2 where node_1 IS NULL and node_2 IS NOT NULL;
update temp.to_merge_now set node_2=node_1 where node_2 IS NULL and node_1 IS NOT NULL;

create table temp.merged_final as select * FROM temp.to_merge_now where node_1 IS NULL and node_2 IS NULL;
delete FROM temp.to_merge_now where node_1 IS NULL and node_2 IS NULL;

insert into temp.merged_final select * FROM temp.to_merge_now where node_1 IS NULL and node_2 IS NULL;
delete FROM temp.to_merge_now where node_1 IS NULL and node_2 IS NULL;

-- END OF TESTING COMMANDS
------------------------------
CREATE TABLE temp.roads_to_merge_now AS SELECT * FROM extracts.roads_to_merge;

-- LOOP THIS PROCESS UNTIL NO ROADS TO MERGE
CREATE TABLE temp.roads_newly_merged_a AS
SELECT id, node_1, (st_dump(merged_geom)).geom the_geom
FROM (  SELECT node_1, max(id) id, ST_Linemerge(ST_Collect(the_geom)) AS merged_geom
        FROM temp.roads_to_merge_now
        GROUP BY node_1
) AS subq;

ALTER TABLE temp.roads_newly_merged_a ADD COLUMN node_2 bigint;
UPDATE temp.roads_newly_merged_a as p1a SET node_2=p1b.node_2 FROM temp.roads_to_merge_now as p1b WHERE p1a.node_1=p1b.node_1;
-- UPDATE temp.roads_newly_merged_a as p1a SET node_2=p1b.node_2 FROM temp.to_merge_now as p1b WHERE p1a.node_1=p1b.node_1 and p1a.node_1<>p1b.node_2;

CREATE TABLE temp.roads_newly_merged_b AS
SELECT id, node_2, (st_dump(merged_geom)).geom the_geom
FROM (  SELECT node_2, max(id) id, ST_Linemerge(ST_Collect(the_geom)) AS merged_geom
        FROM temp.roads_newly_merged_a
        GROUP BY node_2
) AS subq;

DROP TABLE temp.roads_to_merge_now CASCADE;
CREATE TABLE temp.roads_to_merge_now AS SELECT * FROM temp.roads_newly_merged_b;

ALTER TABLE temp.roads_to_merge_now ADD COLUMN node_1 bigint;
UPDATE temp.roads_to_merge_now SET node_1=NULL, node_2=NULL;
CREATE INDEX roads_to_merge_now_idx ON temp.roads_to_merge_now USING gist (the_geom);

UPDATE temp.roads_to_merge_now AS tmn SET node_1=nod.node_id FROM temp.no_cross as nod
where ST_Intersects(ST_StartPoint(tmn.the_geom),nod.the_geom);

UPDATE temp.roads_to_merge_now AS tmn SET node_2=nod.node_id FROM temp.no_cross as nod
where ST_Intersects(ST_EndPoint(tmn.the_geom),nod.the_geom);

UPDATE temp.roads_to_merge_now SET node_1=node_2 WHERE node_1 IS NULL AND node_2 IS NOT NULL;
UPDATE temp.roads_to_merge_now SET node_2=node_1 WHERE node_2 IS NULL AND node_1 IS NOT NULL;

DROP TABLE temp.roads_newly_merged_a CASCADE;
DROP TABLE temp.roads_newly_merged_b CASCADE;

-- END


-- Function: _phd_merge_lines_at_points(text, text, text, text, text, text, text)

-- DROP FUNCTION _phd_merge_lines_at_points(text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION _phd_merge_lines_at_points(linedata text, lineid text, linegeom text, 
		sharedpoints text, pointid text, pointgeom text, outputtable text)
  RETURNS integer AS
$BODY$
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
	EXECUTE 'CREATE TABLE '||outputtable||'_not SELECT id, the_geom FROM temp.roads_to_merge_now';
	EXECUTE 'ALTER TABLE '||outputtable||' ADD COLUMN sid serial NOT NULL';

	-- Clean up
	DROP TABLE temp.roads_to_merge_now CASCADE;
			
	RETURN 1;
	
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_merge_lines_at_points(text, text, text, text, text, text, text)
  OWNER TO postgres;

------------
-- TEST COMMAND

drop table extracts.merged_roads cascade;
select _phd_merge_lines_at_points('extracts.roads_to_merge', 'sid', 'the_geom','temp.no_cross','sid','the_geom','extracts.merged_roads');

-- Function: _phd_copytable(character varying, character varying)
-- Description: 
-- DROP FUNCTION _phd_copytable(character varying, character varying);

CREATE OR REPLACE FUNCTION _phd_copytable(source character varying, destination character varying)
  RETURNS void AS
$BODY$
DECLARE
  
BEGIN
  
	Execute 'CREATE TABLE '|| destination ||' (LIKE '||source||' INCLUDING ALL)';
	Execute 'INSERT INTO '||destination ||' SELECT * from '||source;  
   
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_copytable(character varying, character varying)
  OWNER TO postgres;

-- Function: _phd_makeundirected(character varying, character varying, character varying)
-- Description:
-- DROP FUNCTION _phd_makeundirected(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION _phd_makeundirected(source character varying, origin character varying, destination character varying)
  RETURNS integer AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_makeundirected(character varying, character varying, character varying)
  OWNER TO postgres;

-- Function: _phd_updatecolumns(character varying,character varying,integer, integer, character varying, character varying, character varying)
-- Description:
-- DROP FUNCTION _phd_updatecolumns(character varying,character varying,integer, integer, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION _phd_updatecolumns(schema_name character varying,update_table character varying,from_col integer,to_col integer,expression_s character varying,expression_m character varying,expression_e character varying)
  RETURNS integer AS
$BODY$
DECLARE
	i integer;
	colname text;
  
BEGIN
	FOR i IN from_col..to_col LOOP
		Execute'SELECT column_name FROM INFORMATION_SCHEMA.columns WHERE table_schema = '||quote_literal(schema_name)||' AND table_name = '||quote_literal(update_table)||' AND ordinal_position = '||i into colname;		
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_updatecolumns(character varying,character varying,integer, integer, character varying, character varying, character varying)
  OWNER TO postgres;
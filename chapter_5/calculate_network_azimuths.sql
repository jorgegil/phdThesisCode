-- Function: _phd_cumulazimuth(geometry)

-- DROP FUNCTION _phd_cumulazimuth(geometry);

CREATE OR REPLACE FUNCTION _phd_cumulazimuth(obj geometry)
  RETURNS double precision AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_cumulazimuth(obj geometry)
  OWNER TO postgres;



-- Function: _phd_deltazimuth(geometry)

-- DROP FUNCTION _phd_deltazimuth(geometry);

CREATE OR REPLACE FUNCTION _phd_deltazimuth(obj geometry)
  RETURNS double precision AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_deltazimuth(geometry)
  OWNER TO postgres;
  
  


-- Function: _phd_axialazimuth(geometry, double precision)

-- DROP FUNCTION _phd_axialazimuth(geometry, double precision);

CREATE OR REPLACE FUNCTION _phd_axialazimuth(obj geometry, tolerance double precision)
  RETURNS double precision AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_axialazimuth(obj geometry, tolerance double precision)
  OWNER TO postgres;




-- Function: _phd_continuityazimuth(geometry, double precision)

-- DROP FUNCTION _phd_continuityazimuth(geometry, double precision);

CREATE OR REPLACE FUNCTION _phd_continuityazimuth(obj geometry, tolerance double precision)
  RETURNS double precision AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_continuityazimuth(obj geometry, tolerance double precision)
  OWNER TO postgres;
  
  
-- Function: _phd_axialsteps(geometry, double precision)

-- DROP FUNCTION _phd_axialsteps(geometry, double precision);

CREATE OR REPLACE FUNCTION _phd_axialsteps(obj geometry, tolerance double precision)
  RETURNS integer AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_axialsteps(obj geometry, tolerance double precision)
  OWNER TO postgres;




-- Function: _phd_continuitysteps(geometry, double precision)

-- DROP FUNCTION _phd_continuitysteps(geometry, double precision);

CREATE OR REPLACE FUNCTION _phd_continuitysteps(obj geometry, tolerance double precision)
  RETURNS integer AS
$BODY$
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION _phd_continuitysteps(obj geometry, tolerance double precision)
  OWNER TO postgres;
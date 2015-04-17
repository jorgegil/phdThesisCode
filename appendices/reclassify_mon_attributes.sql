update survey.mobility_journeys set mode_main=hv;

update survey.mobility_journeys set mode_leg=vv;

update survey.mobility_journeys set mode_main= CASE
WHEN hv = '9' THEN '2'
WHEN hv = '10' or hv = '11' THEN '9'
WHEN hv = '12' THEN '10'
WHEN hv = '14' or hv = '15' or hv = '18' or hv = '19' or hv = '26' THEN '13'
WHEN hv = '16' or hv = '17' THEN '11'
WHEN hv = '20' or hv = '21' THEN '1'
WHEN hv = '22' THEN '12'
ELSE mode_main END;

update survey.mobility_journeys set mode_leg= CASE
WHEN vv = '9' THEN '2'
WHEN vv = '10' or vv = '11' THEN '9'
WHEN vv = '12' THEN '10'
WHEN vv = '14' or vv = '15' or vv = '18' or vv = '19' or vv = '26' THEN '13' 
WHEN vv = '16' or vv = '17' THEN '11'
WHEN vv = '20' or vv = '21' THEN '1'
WHEN vv = '22' THEN '12'
ELSE mode_leg END;

update survey.mobility_journeys set distance= CASE
WHEN afstv <= 5 THEN 1
WHEN afstv > 5 and afstv <= 10 THEN 2
WHEN afstv > 10 and afstv <= 15 THEN 3
WHEN afstv > 15 and afstv <= 30 THEN 4
WHEN afstv > 30 and afstv <= 50 THEN 5
WHEN afstv > 50 and afstv <= 75 THEN 6
WHEN afstv > 75 and afstv <= 100 THEN 7
WHEN afstv > 100 and afstv <= 150 THEN 8
WHEN afstv > 150 and afstv <= 200 THEN 9
WHEN afstv > 200 and afstv <= 250 THEN 10
WHEN afstv > 250 and afstv <= 300 THEN 11
WHEN afstv > 300 and afstv <= 350 THEN 12
WHEN afstv > 350 and afstv <= 400 THEN 13
WHEN afstv > 400 and afstv <= 450 THEN 14
WHEN afstv > 450 and afstv <= 500 THEN 15
WHEN afstv > 500 and afstv <= 600 THEN 16
WHEN afstv > 600 and afstv <= 700 THEN 17
WHEN afstv > 700 and afstv <= 800 THEN 18
WHEN afstv > 800 and afstv <= 900 THEN 19
WHEN afstv > 900 and afstv <= 1000 THEN 20
ELSE 21 END;

update survey.mobility_journeys set distance_leg= CASE
WHEN afstr <= 5 THEN 1
WHEN afstr > 5 and afstr <= 10 THEN 2
WHEN afstr > 10 and afstr <= 15 THEN 3
WHEN afstr > 15 and afstr <= 30 THEN 4
WHEN afstr > 30 and afstr <= 50 THEN 5
WHEN afstr > 50 and afstr <= 75 THEN 6
WHEN afstr > 75 and afstr <= 100 THEN 7
WHEN afstr > 100 and afstr <= 150 THEN 8
WHEN afstr > 150 and afstr <= 200 THEN 9
WHEN afstr > 200 and afstr <= 250 THEN 10
WHEN afstr > 250 and afstr <= 300 THEN 11
WHEN afstr > 300 and afstr <= 350 THEN 12
WHEN afstr > 350 and afstr <= 400 THEN 13
WHEN afstr > 400 and afstr <= 450 THEN 14
WHEN afstr > 450 and afstr <= 500 THEN 15
WHEN afstr > 500 and afstr <= 600 THEN 16
WHEN afstr > 600 and afstr <= 700 THEN 17
WHEN afstr > 700 and afstr <= 800 THEN 18
WHEN afstr > 800 and afstr <= 900 THEN 19
WHEN afstr > 900 and afstr <= 1000 THEN 20
ELSE 21 END;

update survey.mobility_journeys set duration= CASE
WHEN rsdduur <= 5 THEN 1
WHEN rsdduur > 5 and rsdduur <= 10 THEN 2
WHEN rsdduur > 10 and rsdduur <= 15 THEN 3
WHEN rsdduur > 15 and rsdduur <= 20 THEN 4
WHEN rsdduur > 20 and rsdduur <= 25 THEN 5
WHEN rsdduur > 25 and rsdduur <= 30 THEN 6
WHEN rsdduur > 30 and rsdduur <= 35 THEN 7
WHEN rsdduur > 35 and rsdduur <= 40 THEN 8
WHEN rsdduur > 40 and rsdduur <= 45 THEN 9
WHEN rsdduur > 45 and rsdduur <= 50 THEN 10
WHEN rsdduur > 50 and rsdduur <= 55 THEN 11
WHEN rsdduur > 55 and rsdduur <= 60 THEN 12
WHEN rsdduur > 60 and rsdduur <= 65 THEN 13
WHEN rsdduur > 65 and rsdduur <= 70 THEN 14
WHEN rsdduur > 70 and rsdduur <= 75 THEN 15
WHEN rsdduur > 75 and rsdduur <= 80 THEN 16
WHEN rsdduur > 80 and rsdduur <= 85 THEN 17
WHEN rsdduur > 85 and rsdduur <= 90 THEN 18
WHEN rsdduur > 90 and rsdduur <= 95 THEN 19
WHEN rsdduur > 95 and rsdduur <= 100 THEN 20
WHEN rsdduur > 100 and rsdduur <= 105 THEN 21
WHEN rsdduur > 105 and rsdduur <= 110 THEN 22
WHEN rsdduur > 110 and rsdduur <= 115 THEN 23
WHEN rsdduur > 115 and rsdduur <= 120 THEN 24
ELSE 25 END;

update survey.mobility_journeys set duration_nb= CASE
WHEN rsdduur <= 7 THEN 1
WHEN rsdduur > 7 and rsdduur <= 12 THEN 2
WHEN rsdduur > 12 and rsdduur <= 17 THEN 3
WHEN rsdduur > 17 and rsdduur <= 22 THEN 4
WHEN rsdduur > 22 and rsdduur <= 27 THEN 5
WHEN rsdduur > 27 and rsdduur <= 32 THEN 6
WHEN rsdduur > 32 and rsdduur <= 37 THEN 7
WHEN rsdduur > 37 and rsdduur <= 42 THEN 8
WHEN rsdduur > 42 and rsdduur <= 47 THEN 9
WHEN rsdduur > 47 and rsdduur <= 52 THEN 10
WHEN rsdduur > 52 and rsdduur <= 57 THEN 11
WHEN rsdduur > 57 and rsdduur <= 62 THEN 12
WHEN rsdduur > 62 and rsdduur <= 67 THEN 13
WHEN rsdduur > 67 and rsdduur <= 72 THEN 14
WHEN rsdduur > 72 and rsdduur <= 77 THEN 15
WHEN rsdduur > 77 and rsdduur <= 82 THEN 16
WHEN rsdduur > 82 and rsdduur <= 87 THEN 17
WHEN rsdduur > 87 and rsdduur <= 92 THEN 18
WHEN rsdduur > 92 and rsdduur <= 97 THEN 19
WHEN rsdduur > 97 and rsdduur <= 102 THEN 20
WHEN rsdduur > 102 and rsdduur <= 107 THEN 21
WHEN rsdduur > 107 and rsdduur <= 112 THEN 22
WHEN rsdduur > 112 and rsdduur <= 117 THEN 23
WHEN rsdduur > 117 and rsdduur <= 122 THEN 24
ELSE 25 END;

UPDATE survey.mobility_journeys SET duration_leg= CASE
WHEN rrrsdduur <= 5 THEN 1
WHEN rrsdduur > 5 and rrsdduur <= 10 THEN 2 
WHEN rrsdduur > 10 and rrsdduur <= 15 THEN 3 
WHEN rrsdduur > 15 and rrsdduur <= 20 THEN 4 
WHEN rrsdduur > 20 and rrsdduur <= 25 THEN 5 
WHEN rrsdduur > 25 and rrsdduur <= 30 THEN 6 
WHEN rrsdduur > 30 and rrsdduur <= 35 THEN 7 
WHEN rrsdduur > 35 and rrsdduur <= 40 THEN 8 
WHEN rrsdduur > 40 and rrsdduur <= 45 THEN 9 
WHEN rrsdduur > 45 and rrsdduur <= 50 THEN 10 
WHEN rrsdduur > 50 and rrsdduur <= 55 THEN 11 
WHEN rrsdduur > 55 and rrsdduur <= 60 THEN 12 
WHEN rrsdduur > 60 and rrsdduur <= 65 THEN 13 
WHEN rrsdduur > 65 and rrsdduur <= 70 THEN 14 
WHEN rrsdduur > 70 and rrsdduur <= 75 THEN 15 
WHEN rrsdduur > 75 and rrsdduur <= 80 THEN 16 
WHEN rrsdduur > 80 and rrsdduur <= 85 THEN 17 
WHEN rrsdduur > 85 and rrsdduur <= 90 THEN 18 
WHEN rrsdduur > 90 and rrsdduur <= 95 THEN 19 
WHEN rrsdduur > 95 and rrsdduur <= 100 THEN 20 
WHEN rrsdduur > 100 and rrsdduur <= 105 THEN 21 
WHEN rrsdduur > 105 and rrsdduur <= 110 THEN 22 
WHEN rrsdduur > 110 and rrsdduur <= 115 THEN 23 
WHEN rrsdduur > 115 and rrsdduur <= 120 THEN 24 
ELSE 25 END; 

update survey.mobility_journeys set duration_leg_nb= CASE 
WHEN rrsdduur <= 7 THEN 1 
WHEN rrsdduur > 7 and rrsdduur <= 12 THEN 2 
WHEN rrsdduur > 12 and rrsdduur <= 17 THEN 3 
WHEN rrsdduur > 17 and rrsdduur <= 22 THEN 4 
WHEN rrsdduur > 22 and rrsdduur <= 27 THEN 5 
WHEN rrsdduur > 27 and rrsdduur <= 32 THEN 6 
WHEN rrsdduur > 32 and rrsdduur <= 37 THEN 7 
WHEN rrsdduur > 37 and rrsdduur <= 42 THEN 8 
WHEN rrsdduur > 42 and rrsdduur <= 47 THEN 9 
WHEN rrsdduur > 47 and rrsdduur <= 52 THEN 10 
WHEN rrsdduur > 52 and rrsdduur <= 57 THEN 11 
WHEN rrsdduur > 57 and rrsdduur <= 62 THEN 12 
WHEN rrsdduur > 62 and rrsdduur <= 67 THEN 13 
WHEN rrsdduur > 67 and rrsdduur <= 72 THEN 14 
WHEN rrsdduur > 72 and rrsdduur <= 77 THEN 15 
WHEN rrsdduur > 77 and rrsdduur <= 82 THEN 16 
WHEN rrsdduur > 82 and rrsdduur <= 87 THEN 17 
WHEN rrsdduur > 87 and rrsdduur <= 92 THEN 18 
WHEN rrsdduur > 92 and rrsdduur <= 97 THEN 19 
WHEN rrsdduur > 97 and rrsdduur <= 102 THEN 20 
WHEN rrsdduur > 102 and rrsdduur <= 107 THEN 21 
WHEN rrsdduur > 107 and rrsdduur <= 112 THEN 22 
WHEN rrsdduur > 112 and rrsdduur <= 117 THEN 23 
WHEN rrsdduur > 117 and rrsdduur <= 122 THEN 24 
ELSE 25 END;

SELECT home_pcode pcode, persid FROM survey.randstad_journeys WHERE home_pcode = '3234' AND agg_pcode = home_pcode GROUP BY home_pcode, persid ORDER BY persid;

SELECT persid, count(*) count FROM survey.randstad_journeys WHERE home_pcode='3234'AND agg_pcode = home_pcode GROUP BY persid;
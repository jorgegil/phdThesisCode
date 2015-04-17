--DROP TABLE  source.openov_stop CASCADE;
CREATE TABLE source.openov_stop (recordtype text, versionnr smallint, im_explicit text, ownercode text, stopcode text, tpointcode text,
getin text, getout text, deprec text, stopname text, townname text, stoparea text, stopside text, equipowner text, equipnumber integer,
stoptime integer, stoplength integer, description text, stoptype text);
--DROP TABLE  source.openov_point CASCADE;
CREATE TABLE source.openov_point (recordtype text, versionnr smallint, im_explicit text, ownercode text, pointcode text, validfrom text,
pointtype text, coordsys text, loc_x integer, loc_y integer, loc_z integer, description text);
--DROP TABLE  source.openov_link CASCADE;
CREATE TABLE source.openov_link (recordtype text, versionnr smallint, im_explicit text, ownercode text, stopcode_start text,
stopcode_end text, validfrom text, distance integer, description text, linemode text);
--DROP TABLE  source.openov_line CASCADE;
CREATE TABLE source.openov_line (recordtype text, versionnr smallint, im_explicit text, ownercode text, lineid text,
linecode text, linename text, linenumber integer, description text, linemode text);
--DROP TABLE  source.openov_jourplan CASCADE;
CREATE TABLE source.openov_jourplan (recordtype text, versionnr smallint, im_explicit text, ownercode text, lineid text,
jourcode text, linkorder text, stopcode_start text, stopcode_end text, finance text, destcode text, deprec text, istiming text, linecode text, producttype text);
--DROP TABLE  source.openov_pool CASCADE;
CREATE TABLE source.openov_pool (recordtype text, versionnr smallint, im_explicit text, ownercode text, stopcode_start text,
stopcode_end text, validfrom text, pointowner text, pointcode text, diststart smallint, segspeed smallint, description text, linemode text);

COPY source.openov_stop FROM '/Users/Shared/openov/arr_br_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/arr_br_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/arr_br_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/arr_br_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/arr_br_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/arr_br_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/arr_dr_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/arr_dr_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/arr_dr_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/arr_dr_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/arr_dr_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/arr_dr_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/arr_gr_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/arr_gr_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/arr_gr_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/arr_gr_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/arr_gr_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/arr_gr_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/arr_hk_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/arr_hk_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/arr_hk_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/arr_hk_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/arr_hk_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/arr_hk_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/arr_rl_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/arr_rl_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/arr_rl_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/arr_rl_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/arr_rl_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/arr_rl_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/cxx_USRSTOP.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/cxx_POINT.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/cxx_LINK.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/cxx_LINE.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/cxx_JOPATILI.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/cxx_POOL.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/ebs_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/ebs_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/ebs_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/ebs_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/ebs_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/ebs_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/gvb_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/gvb_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/gvb_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/gvb_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/gvb_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/gvb_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/htm_USRSTOP.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/htm_POINT.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/htm_LINK.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/htm_LINE.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/htm_JOPATILI.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/htm_POOL.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/qbuzz_gr_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/qbuzz_gr_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/qbuzz_gr_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/qbuzz_gr_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/qbuzz_gr_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/qbuzz_gr_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/qbuzz_rt_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/qbuzz_rt_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/qbuzz_rt_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/qbuzz_rt_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/qbuzz_rt_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/qbuzz_rt_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/syntus_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/syntus_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/syntus_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/syntus_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/syntus_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/syntus_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brbr1_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brbr1_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brbr1_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brbr1_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brbr1_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brbr1_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brbr2_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brbr2_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brbr2_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brbr2_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brbr2_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brbr2_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brbu_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brbu_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brbu_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brbu_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brbu_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brbu_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brhg_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brhg_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brhg_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brhg_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brhg_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brhg_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_broh_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_broh_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_broh_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_broh_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_broh_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_broh_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brti_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brti_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brti_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brti_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brti_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brti_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brwa_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brwa_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brwa_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brwa_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brwa_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brwa_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brze_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brze_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brze_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brze_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brze_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brze_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

COPY source.openov_stop FROM '/Users/Shared/openov/vtn_brzo_USRSTOPXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_point FROM '/Users/Shared/openov/vtn_brzo_POINTXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_link FROM '/Users/Shared/openov/vtn_brzo_LINKXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_line FROM '/Users/Shared/openov/vtn_brzo_LINEXXXXXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_jourplan FROM '/Users/Shared/openov/vtn_brzo_JOPATILIXX.TMI' WITH (DELIMITER '|', NULL '');
COPY source.openov_pool FROM '/Users/Shared/openov/vtn_brzo_POOLXXXXXX.TMI' WITH (DELIMITER '|', NULL '');

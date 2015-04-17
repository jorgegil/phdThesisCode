-- DROP TABLE graph.transit_multimodal CASCADE;
CREATE TABLE graph.transit_multimodal AS SELECT sid link_id, multimodal_start source, multimodal_end target, the_geom, length, temporal, randstad, randstad_code FROM network.transit_links;
ALTER TABLE graph.transit_multimodal ADD COLUMN transfer double precision;
UPDATE graph.transit_multimodal SET transfer=0;

INSERT INTO graph.transit_multimodal SELECT sid, multimodal_start, multimodal_end, the_geom, ST_Length(the_geom), temporal, randstad, randstad_code, 2.0 FROM network.transit_interfaces;
ALTER TABLE graph.transit_multimodal ADD COLUMN sid serial NOT NULL PRIMARY KEY;

ALTER TABLE graph.transit_multimodal ADD COLUMN bus boolean;
ALTER TABLE graph.transit_multimodal ADD COLUMN rail boolean;
ALTER TABLE graph.transit_multimodal ADD COLUMN tram boolean;
ALTER TABLE graph.transit_multimodal ADD COLUMN metro boolean;
ALTER TABLE graph.transit_multimodal ADD COLUMN ferry boolean;

UPDATE graph.transit_multimodal as gr SET bus=True FROM network.transit_links as lnk WHERE gr.transfer=0 AND lnk.sid=gr.link_id AND lnk.network='bus';
UPDATE graph.transit_multimodal as gr SET bus=True FROM network.transit_interfaces as lnk WHERE gr.transfer>0 AND lnk.sid=gr.link_id AND (lnk.start_network='bus' OR lnk.end_network='bus');
UPDATE graph.transit_multimodal as gr SET rail=True FROM network.transit_links as lnk WHERE gr.transfer=0 AND lnk.sid=gr.link_id AND lnk.network='rail';
UPDATE graph.transit_multimodal as gr SET rail=True FROM network.transit_interfaces as lnk WHERE gr.transfer>0 AND lnk.sid=gr.link_id AND (lnk.start_network='rail' OR lnk.end_network='rail');
UPDATE graph.transit_multimodal as gr SET tram=True FROM network.transit_links as lnk WHERE gr.transfer=0 AND lnk.sid=gr.link_id AND lnk.network='tram';
UPDATE graph.transit_multimodal as gr SET tram=True FROM network.transit_interfaces as lnk WHERE gr.transfer>0 AND lnk.sid=gr.link_id AND (lnk.start_network='tram' OR lnk.end_network='tram');
UPDATE graph.transit_multimodal as gr SET metro=True FROM network.transit_links as lnk WHERE gr.transfer=0 AND lnk.sid=gr.link_id AND lnk.network='metro';
UPDATE graph.transit_multimodal as gr SET metro=True FROM network.transit_interfaces as lnk WHERE gr.transfer>0 AND lnk.sid=gr.link_id AND (lnk.start_network='metro' OR lnk.end_network='metro');
UPDATE graph.transit_multimodal as gr SET ferry=True FROM network.transit_links as lnk WHERE gr.transfer=0 AND lnk.sid=gr.link_id AND lnk.network='ferry';
UPDATE graph.transit_multimodal as gr SET ferry=True FROM network.transit_interfaces as lnk WHERE gr.transfer>0 AND lnk.sid=gr.link_id AND (lnk.start_network='ferry' OR lnk.end_network='ferry');

--COMPOSITE DISTANCE IMPEDANCES FOR MULTIMODAL ANALYSIS
-- the naming order is: local/motorway/transit/building

--Cognitive angular segment:angular/angular/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_angular_seg double precision;
--Cognitive angular temporal:angular/angular/temporal/temporal
ALTER TABLE graph.multimodal ADD COLUMN cogn_angular_temp double precision;
--Cognitive angular mix segment:angular/segment/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_angular_mix_seg double precision;
--Cognitive angular mix temporal:angular/temporal/temporal/temporal
ALTER TABLE graph.multimodal ADD COLUMN cogn_angular_mix_temp double precision;
--Cognitive angular mix:angular/temporal/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_angular_mix double precision;

--Cognitive axial segment:axial/axial/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_axial_seg double precision;
--Cognitive axial temporal:axial/axial/temporal/temporal
ALTER TABLE graph.multimodal ADD COLUMN cogn_axial_temp double precision;
--Cognitive axial mix segment:axial/segment/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_axial_mix_seg double precision;
--Cognitive axial mix temporal:axial/temporal/temporal/temporal
ALTER TABLE graph.multimodal ADD COLUMN cogn_axial_mix_temp double precision;
--Cognitive axial mix:angular/temporal/segment/segment
ALTER TABLE graph.multimodal ADD COLUMN cogn_axial_mix double precision;


UPDATE graph.multimodal SET cogn_angular_seg = (cumangular/90.0::float), cogn_angular_temp = (cumangular/90.0::float), cogn_angular_mix_seg = (cumangular/90.0::float), cogn_angular_mix_temp = (cumangular/90.0::float), cogn_angular_mix = (cumangular/90.0::float), cogn_axial_seg = axial, cogn_axial_temp = axial, cogn_axial_mix_seg = axial, cogn_axial_mix_temp = axial, cogn_axial_mix = (cumangular/90.0::float) WHERE mobility='private' AND (car IS NULL OR car = False);

UPDATE graph.multimodal SET cogn_angular_seg = (cumangular/90.0::float), cogn_angular_temp = (cumangular/90.0::float), cogn_angular_mix_seg = segment, cogn_angular_mix_temp = temporal, cogn_angular_mix = temporal, cogn_axial_seg = axial, cogn_axial_temp = axial, cogn_axial_mix_seg = segment, cogn_axial_mix_temp = temporal, cogn_axial_mix = temporal WHERE mobility = 'private' AND car = True;

UPDATE graph.multimodal SET cogn_angular_seg = (segment+transfer), cogn_angular_temp = temporal, cogn_angular_mix_seg = (segment+transfer), cogn_angular_mix_temp = temporal, cogn_angular_mix = (segment+transfer), cogn_axial_seg = (segment+transfer), cogn_axial_temp = temporal, cogn_axial_mix_seg = (segment+transfer), cogn_axial_mix_temp = temporal, cogn_axial_mix = (segment+transfer) WHERE mobility = 'public';

UPDATE graph.multimodal SET cogn_angular_seg = segment, cogn_angular_temp = temporal, cogn_angular_mix_seg = segment, cogn_angular_mix_temp = temporal, cogn_angular_mix = segment, cogn_axial_seg = segment, cogn_axial_temp = temporal, cogn_axial_mix_seg = segment, cogn_axial_mix_temp = temporal, cogn_axial_mix = segment  WHERE mobility = 'building';


-- in public transport metric can be 0 and in private transport axial and segment can be 0, leading to 0 in several metrics
-- this is added to simplify the funcion calls, can be removed at any time if necessary.
update graph.multimodal set cogn_angular_mix_seg=cogn_angular_mix_seg+0.000001, cogn_axial_seg=cogn_axial_seg+0.000001, cogn_axial_mix_seg=cogn_axial_mix_seg+0.000001, cogn_axial_mix=cogn_axial_mix+0.000001,cogn_axial_temp=cogn_axial_temp+0.000001, cogn_axial_mix_temp=cogn_axial_mix_temp+0.000001,cogn_angular_mix_temp=cogn_angular_mix_temp+0.000001,metric=metric+0.00001, segment=segment+0.000001;
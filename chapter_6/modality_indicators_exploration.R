# modality indicators exploration: reduce from possible to meaningful

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc") 
library("sm") 
library("cluster") 
library("pvclust")
library("fpc")
library("RColorBrewer")
library("classInt")

def.par <- par(no.readonly = TRUE)

#connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

#get mobility and indicator data
mon<- dbGetQuery(con,"SELECT pcode, journeys, legs, persons, distance, duration, distance_legs, duration_legs, 
                    walk, cycle, car, bus, tram, train, transit, avg_dist, avg_journeys_pers, avg_dist_pers, 
                    car_dist, transit_dist, car_dur, transit_dur, short_walk, short_cycle, short_car, 
                    medium_cycle, medium_car, medium_transit, far_car, far_transit 
                    FROM survey.mobility_patterns_home_od WHERE journeys IS NOT NULL AND journeys > 60 
                    AND pcode IN (SELECT pcode FROM survey.sampling_points)")

#network proximity
proximity <- dbGetQuery(con,"CREATE TEMP TABLE temp_proximity AS SELECT * FROM analysis.pcode_local_proximity;
                ALTER TABLE temp_proximity DROP COLUMN the_geom;
                SELECT * FROM temp_proximity;")
dbSendQuery(con,"DROP TABLE temp_proximity")

#network density
ndensity1 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_density;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
ndensity2<- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_density_temporal;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")

#activity density
adensity1 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_car;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
adensity2 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_nonmotor;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
adensity3 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_nonmotor_temporal_bike;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
adensity4 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_nonmotor_temporal_ped;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
adensity5 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_localtransit;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")
adensity6 <- dbGetQuery(con,"CREATE TEMP TABLE temp_density AS SELECT * FROM analysis.pcode_local_accessibility_transit;
                ALTER TABLE temp_density DROP COLUMN the_geom;
                SELECT * FROM temp_density;")
dbSendQuery(con,"DROP TABLE temp_density")

#activity closeness
accessibility <- dbGetQuery(con,"CREATE TEMP TABLE temp_accessibility AS SELECT * FROM analysis.pcode_accessibility;
                ALTER TABLE temp_accessibility DROP COLUMN the_geom;
                SELECT * FROM temp_accessibility;")
dbSendQuery(con,"DROP TABLE temp_accessibility")
#get maximum value for each postcode. already done in the database.
#accessibility <- aggregate(.~pcode, data = data.frame(accessibility[,2:31]), max)

#network centrality (route and place hierarchy)
centrality1 <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.pcode_centrality_car WHERE pcode IS NOT NULL;
                ALTER TABLE temp_centrality DROP COLUMN the_geom;
                SELECT * FROM temp_centrality;")
dbSendQuery(con,"DROP TABLE temp_centrality")
centrality2 <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.pcode_centrality_nonmotor WHERE pcode IS NOT NULL;
                ALTER TABLE temp_centrality DROP COLUMN the_geom;
                SELECT * FROM temp_centrality;")
dbSendQuery(con,"DROP TABLE temp_centrality")
centrality3 <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.pcode_centrality_transit WHERE pcode IS NOT NULL;
                ALTER TABLE temp_centrality DROP COLUMN the_geom;
                SELECT * FROM temp_centrality;")
dbSendQuery(con,"DROP TABLE temp_centrality")


# some constants
margins <- c(0.25,0.25,0.25,0.25)
bins <- pretty(range(c(0, 100)), n=21)
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)


######
# 1. Correlation within group ######

## network proximity ######
# get the data without the id column
proximity_data <- data.frame(proximity[,seq(3,ncol(proximity)-1,2)])
proximity_data <- subset(proximity, proximity$pcode %in% mon$pcode)[,2:ncol(proximity)]

# remove NA
proximity_data <- na.omit(proximity_data)

# correlation
proximity_rmatrix <- round(rcorr(as.matrix(proximity_data))$r,digits=3)
proximity_r2matrix <- round((rcorr(as.matrix(proximity_data))$r)^2,digits=3)
proximity_pmatrix <- round(rcorr(as.matrix(proximity_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(proximity_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=proximity_pmatrix, sig.level=0.001)
corrplot(proximity_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=proximity_pmatrix, insig = "p-value", sig.level=-1)


####
## network density ######
# get the data for column
ndensity_metric_data <- ndensity1[,c(1,seq(3,31,2),seq(32,100,2),seq(103,131,2))]
ndensity_axial_data <- ndensity1[,c(1,seq(133,161,2),seq(162,230,2),seq(233,261,2))]
ndensity_angular_data <- ndensity1[,c(1,seq(263,291,2),seq(292,360,2),seq(363,391,2))]
ndensity_temporal_data <- ndensity2[,c(1,seq(3,37,2),seq(38,120,2),seq(123,157,2))]

density_data <- ndensity_metric_data[,2:ncol(ndensity_metric_data)]
density_data <- ndensity_angular_data[,2:ncol(ndensity_angular_data)]
density_data <- ndensity_axial_data[,2:ncol(ndensity_axial_data)]
density_data <- merge(ndensity_metric_data,ndensity_temporal_data,by = "pcode")
density_data <- merge(ndensity_metric_data,ndensity_axial_data,by = "pcode")
density_data <- merge(ndensity_metric_data,ndensity_angular_data,by = "pcode")
density_data <- merge(ndensity_angular_data,ndensity_axial_data,by = "pcode")
density_data <- density_data[,2:ncol(density_data)]

# remove NA
density_data <- na.omit(density_data)

# correlation
density_rmatrix <- round(rcorr(as.matrix(density_data))$r,digits=3)
density_r2matrix <- round((rcorr(as.matrix(density_data))$r)^2,digits=3)
density_pmatrix <- round(rcorr(as.matrix(density_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(density_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=density_pmatrix, sig.level=0.001)
corrplot(density_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=density_pmatrix, insig = "p-value", sig.level=-1)


####
## activity density ######
# get the data for column
adensity_carmetric_data <- adensity1[,c(1,seq(3,61,2))]
adensity_caraxial_data <- adensity1[,c(1,seq(63,121,2))]
adensity_carangular_data <- adensity1[,c(1,seq(123,181,2))]
adensity_metric_data <- adensity2[,c(1,seq(3,61,2))]
adensity_axial_data <- adensity2[,c(1,seq(63,121,2))]
adensity_angular_data <- adensity2[,c(1,seq(123,181,2))]
adensity_temporalped_data <- adensity4[,c(1,seq(3,ncol(adensity4)-1,2))]
adensity_temporalbike_data <- adensity3[,c(1,seq(3,ncol(adensity4)-1,2))]
adensity_temporalped_data <- adensity4[,c(1,seq(75,ncol(adensity4)-1,2))]
adensity_cartemporal_data <- adensity1[,c(1,seq(181,ncol(adensity1)-1,2))]
adensity_localtransit_data <- adensity5[,c(1,seq(3,ncol(adensity5)-1,2))]
adensity_transit_data <- adensity6[,c(1,seq(3,ncol(adensity6)-1,2))]

density_data <- adensity_temporalped_data[,2:ncol(adensity_temporalped_data)]
density_data <- adensity_metric_data[,2:ncol(adensity_metric_data)]
density_data <- adensity_angular_data[,2:ncol(adensity_angular_data)]
density_data <- adensity_axial_data[,2:ncol(adensity_axial_data)]
density_data <- adensity_carmetric_data[,2:ncol(adensity_carmetric_data)]
density_data <- adensity_carangular_data[,2:ncol(adensity_carangular_data)]
density_data <- adensity_caraxial_data[,2:ncol(adensity_caraxial_data)]

density_data <- merge(adensity_metric_data,adensity_carmetric_data,by = "pcode")
density_data <- merge(adensity_metric_data,adensity_temporalped_data,by = "pcode")
density_data <- merge(adensity_metric_data,adensity_angular_data,by = "pcode")
density_data <- merge(adensity_angular_data,adensity_axial_data,by = "pcode")

density_data <- merge(adensity_temporalped_data,adensity_cartemporal_data,by = "pcode")
density_data <- merge(density_data,adensity_localtransit_data,by = "pcode")
density_data <- merge(density_data,adensity_transit_data,by = "pcode")

density_data <- density_data[,2:ncol(density_data)]

# remove NA
density_data <- na.omit(density_data)

# correlation
density_rmatrix <- round(rcorr(as.matrix(density_data))$r,digits=3)
density_r2matrix <- round((rcorr(as.matrix(density_data))$r)^2,digits=3)
density_pmatrix <- round(rcorr(as.matrix(density_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(density_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=density_pmatrix, sig.level=0.001)
corrplot(density_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=density_pmatrix, insig = "p-value", sig.level=-1)

#cor(adensity2$retail_2400_count ,adensity4$retail_30_count)


####
## activity closeness ######
# get the data for column
accessibility_data <- accessibility[,3:ncol(accessibility)-1]

# remove NA
accessibility_data <- na.omit(accessibility_data)

# correlation
accessibility_rmatrix <- round(rcorr(as.matrix(accessibility_data))$r,digits=3)
accessibility_r2matrix <- round((rcorr(as.matrix(accessibility_data))$r)^2,digits=3)
accessibility_pmatrix <- round(rcorr(as.matrix(accessibility_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(accessibility_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=accessibility_pmatrix, sig.level=0.001)
corrplot(accessibility_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=accessibility_pmatrix, insig = "p-value", sig.level=-1)


## network centrality
# get the centrality data for the spot value
centrality_spot_data <- centrality1[,c(ncol(centrality_raw),4,14,16)]
#get maximum value for each postcode
centrality_spot_data <- aggregate(.~pcode, data = centrality_spot_data, max)

colnames(centrality1)
centrality1_data <- centrality1[,c(1:3,8:9,12:13,18:19,22:23,28:29,32:33,38:39,42:44,51:53,57:59,66:68,72:74,81:83,87:89,
                                   96:98,102:103,106:107,110:111,114:115,118:120,124:126,130:132,136:138)]
centrality2_data <- centrality2[,c(1:5,8:11,14:17,20:23,26:29,32:35,38:41,44:47,50:51,56:59,64:67,72:75,80:85,93:100,
                                   108:115,123:130,138:141)]
centrality3_data <- centrality3[,c(1,34:65,98:133,148:161,176:193)]

# remove NA
#This identifies columns with NA values. 
colSums(is.na(centrality1_data))
colSums(is.na(centrality2_data))
colSums(is.na(centrality3_data))
#Some columns have lots of NA, these indicators do not apply so should be excluded.
#Here I exclude those with lots and keep some, removing those postcodes instead
centrality1_data <- centrality1_data[,colSums(is.na(centrality1_data))<31]
centrality2_data <- centrality2_data[,colSums(is.na(centrality2_data))<61]
centrality3_data <- centrality3_data[,colSums(is.na(centrality3_data))<150]#good for local transit
centrality3_data <- centrality3_data[,colSums(is.na(centrality3_data))<750]#includes rail for 1600m

centrality1_data <- na.omit(centrality1_data)
centrality2_data <- na.omit(centrality2_data)
centrality3_data <- na.omit(centrality3_data)

#Or I could replace NA by 0 to keep all columns, as we're talking about shares and mean and max. although that is not absolutely correct...
centrality1_data[is.na(centrality1_data)] <- 0
centrality2_data[is.na(centrality2_data)] <- 0
centrality3_data[is.na(centrality3_data)] <- 0

#can merge valid columns
centrality_data <- merge(centrality1_data,centrality2_data,by = "pcode")
centrality_data <- merge(centrality_data,centrality3_data,by = "pcode")
centrality_data <- centrality_data[,2:ncol(centrality_data)]

# remove NA
centrality_data <- na.omit(centrality_data)

# correlation
centrality_rmatrix <- round(rcorr(as.matrix(centrality_data))$r,digits=3)
centrality_r2matrix <- round((rcorr(as.matrix(centrality_data))$r)^2,digits=3)
centrality_pmatrix <- round(rcorr(as.matrix(centrality_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(centrality_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=centrality_pmatrix, sig.level=0.01)
corrplot(centrality_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=centrality_pmatrix, insig = "p-value", sig.level=-1)

# correlation
centrality1_rmatrix <- round(rcorr(as.matrix(centrality1_data))$r,digits=3)
centrality1_r2matrix <- round((rcorr(as.matrix(centrality1_data))$r)^2,digits=3)
centrality1_pmatrix <- round(rcorr(as.matrix(centrality1_data))$P,digits=5)
centrality2_rmatrix <- round(rcorr(as.matrix(centrality2_data))$r,digits=3)
centrality2_r2matrix <- round((rcorr(as.matrix(centrality2_data))$r)^2,digits=3)
centrality2_pmatrix <- round(rcorr(as.matrix(centrality2_data))$P,digits=5)
centrality3_rmatrix <- round(rcorr(as.matrix(centrality3_data))$r,digits=3)
centrality3_r2matrix <- round((rcorr(as.matrix(centrality3_data))$r)^2,digits=3)
centrality3_pmatrix <- round(rcorr(as.matrix(centrality3_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(centrality1_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=centrality1_pmatrix, sig.level=0.01)
corrplot(centrality1_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=centrality1_pmatrix, insig = "p-value", sig.level=-1)
corrplot(centrality2_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=centrality2_pmatrix, sig.level=0.01)
corrplot(centrality2_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=centrality2_pmatrix, insig = "p-value", sig.level=-1)
corrplot(centrality3_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=centrality3_pmatrix, sig.level=0.01)
corrplot(centrality3_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=centrality3_pmatrix, insig = "p-value", sig.level=-1)



# 2. Compile selected indicators ######
#proximity
modality_indicators_set <- proximity[,c("pcode","bicycle_metric_dist","main_metric_dist","motorway_metric_dist","bus_metric_dist",
        "rail_metric_dist","bicycle_cumangular_dist","main_cumangular_dist","motorway_cumangular_dist","bus_cumangular_dist","rail_cumangular_dist")]
modality_indicators_set$localtransit_metric_dist <- apply(proximity[,c("bus_metric_dist","metro_metric_dist","tram_metric_dist")], 1, function(row) min(row))
modality_indicators_set$localtransit_angular_dist <- apply(proximity[,c("bus_cumangular_dist","metro_cumangular_dist","tram_cumangular_dist")], 1, function(row) min(row))
is.na(modality_indicators_set) <- do.call(cbind,lapply(modality_indicators_set, is.infinite))

#network density
modality_indicators_add <- ndensity1[,c("pcode","bicycle_800_size","nonmotor_800_size","main_800_size","car_800_size","bus_800_count",
        "bicycle_1600_size","nonmotor_1600_size","main_1600_size","car_1600_size","bus_1600_count",
        "motorway_1600_size","culdesac_1600_count","rail_1600_count")]
modality_indicators_add$crossings_800_count <- apply(ndensity1[,c("xcross_800_count","tcross_800_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add$crossings_1600_count <- apply(ndensity1[,c("xcross_1600_count","tcross_1600_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add$localtransit_800_count <- apply(ndensity1[,c("metro_800_count","tram_800_count","bus_800_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add$localtransit_1600_count <- apply(ndensity1[,c("metro_1600_count","tram_1600_count","bus_1600_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")

#network reach
modality_indicators_add <- ndensity1[,c("pcode","culdesac_180_count","nonmotor_180_size","car_180_size")]
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")

#activity density - local metric
modality_indicators_add <- adensity2[,c("pcode","residential_800_area","active_800_area","work_800_area","sports_800_area","industry_800_area",
                                        "education_800_area","office_800_area","assembly_800_area","retail_800_area","residential_1600_area",
                                        "active_1600_area","work_1600_area","sports_1600_area","industry_1600_area","education_1600_area",
                                        "office_1600_area","assembly_1600_area","retail_1600_area")]
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")
#activity density - modal temporal
modality_indicators_set$activity_bike_10min_area <- adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$retail_10_area+adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$assembly_10_area+adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$sports_10_area
modality_indicators_set$activity_car_10min_area <- adensity1[match(modality_indicators_add$pcode,adensity1$pcode),]$active_t10_area
modality_indicators_set$activity_pedtransit_10min_area <- adensity6[match(modality_indicators_add$pcode,adensity6$pcode),]$active_10_ped_area
modality_indicators_set$activity_biketransit_10min_area <- adensity6[match(modality_indicators_add$pcode,adensity6$pcode),]$active_10_bike_area
modality_indicators_set$work_bike_20min_area <- adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$retail_20_area+adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$assembly_20_area+adensity3[match(modality_indicators_add$pcode,adensity3$pcode),]$sports_20_area
modality_indicators_set$work_car_20min_area <- adensity1[match(modality_indicators_add$pcode,adensity1$pcode),]$work_t20_area
modality_indicators_set$work_pedtransit_20min_area <- adensity6[match(modality_indicators_add$pcode,adensity6$pcode),]$work_20_ped_area
modality_indicators_set$work_biketransit_20min_area <- adensity6[match(modality_indicators_add$pcode,adensity6$pcode),]$work_20_bike_area

#network centrality
#car
modality_indicators_add <- centrality1[,c("pcode","private_angular_close_800_mean","main_private_angular_betw_800","car_private_angular_betw_800",
                                       "private_angular_close_1600_mean","main_private_angular_betw_1600","car_private_angular_betw_1600","motorway_private_angular_betw_1600")]
colnames(modality_indicators_add) <- c("pcode","car_angular_close_800_mean","main_angular_betw_800","car_angular_betw_800",
                                       "car_angular_close_1600_mean","main_angular_betw_1600","car_angular_betw_1600","motorway_angular_betw_1600")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")
#nonmotor
modality_indicators_add <- centrality2[,c("pcode","private_angular_close_800_mean","nonmotor_cogn_angular_seg_close_800_mean",
                                          "bicycle_private_angular_betw_800","bicycle_nonmotor_cogn_angular_seg_betw_800",
                                          "nonmotor_private_angular_betw_800","nonmotor_nonmotor_cogn_angular_seg_betw_800",
                                          "private_angular_close_1600_mean","nonmotor_cogn_angular_seg_close_1600_mean",
                                          "bicycle_private_angular_betw_1600","bicycle_nonmotor_cogn_angular_seg_betw_1600",
                                          "nonmotor_private_angular_betw_1600","nonmotor_nonmotor_cogn_angular_seg_betw_1600")]
colnames(modality_indicators_add) <- c("pcode","nonmotor_angular_close_800_mean","nonmotor_angular_seg_close_800_mean",
                                       "bicycle_angular_betw_800","bicycle_angular_seg_betw_800",
                                       "nonmotor_angular_betw_800","nonmotor_angular_seg_betw_800",
                                       "nonmotor_angular_close_1600_mean","nonmotor_angular_seg_close_1600_mean",
                                       "bicycle_angular_betw_1600","bicycle_angular_seg_betw_1600",
                                       "nonmotor_angular_betw_1600","nonmotor_angular_seg_betw_1600")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")
#transit
modality_indicators_add <- centrality3[,c("pcode","nonmotor_cogn_angular_seg_close_800_transit_mean","nonmotor_cogn_angular_seg_close_800_rail_mean",
                                          "nonmotor_cogn_angular_seg_close_1600_transit_mean","nonmotor_cogn_angular_seg_close_1600_rail_mean")]
colnames(modality_indicators_add) <- c("pcode","transit_angular_seg_close_800_mean","rail_angular_seg_close_800_mean",
                                        "transit_angular_seg_close_1600_mean","rail_angular_seg_close_1600_mean")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")

#activity accessibility
modality_indicators_add <- accessibility[,c("pcode","residential_local_access_800m","education_local_access_800m","activity_local_access_800m","work_local_access_800m","car_activity_temp","transit_activity_tempbike","car_work_temp","transit_work_tempbike")]
modality_indicators_set <- merge(modality_indicators_set,modality_indicators_add,by="pcode")

if(dbExistsTable(con,c("analysis","modality_indicators_possible"))){
    dbRemoveTable(con,c("analysis","modality_indicators_possible"))
}
dbWriteTable(con,c("analysis","modality_indicators_possible"),modality_indicators_set)

modality_indicators_set <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_possible")
modality_indicators_set <- modality_indicators_set[,2:ncol(modality_indicators_set)]


# 3. Explore selected set ######
modality_indicators_data <- modality_indicators_set[,2:ncol(modality_indicators_set)]

#descriptive statistics of indicators
descriptive_modality <- as.data.frame(round(psych::describe(modality_indicators_data),digits=2))
descriptive_modality$gini <- round(apply(modality_indicators_data,2,Gini),digits=4)
#to get the values without the 0 as for the histogram
descriptive_modality$gini_nozero <- 0
for (i in 1:ncol(modality_indicators_data)){
    descriptive_modality$gini_nozero[i]<-round(Gini(subset(modality_indicators_data,modality_indicators_data[,i]>0)[,i]),digits=4)
}
View(descriptive_modality)

#histograms
par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 1:ncol(modality_indicators_data)){
    hist(modality_indicators_data[,i],col=colour,main=colnames(modality_indicators_data)[i],xlab="",ylab="")
}

# ignoring places with 0 values
par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 1:ncol(modality_indicators_data)){
    hist(subset(modality_indicators_data,modality_indicators_data[,i]>0)[,i],col=colour,main=colnames(modality_indicators_data)[i],xlab="",ylab="")
}

# ignoring places with 0 values and transforming the variables with log
par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 1:ncol(modality_indicators_data)){
    hist(log(subset(modality_indicators_data,modality_indicators_data[,i]>0)[,i]),col=colour,main=colnames(modality_indicators_data)[i],xlab="",ylab="")
}

#transform non-normal variables
normal_modality_indicators <- modality_indicators_set
for (i in 2:ncol(normal_modality_indicators)){
    normal_modality_indicators[,i] <- ifelse(normal_modality_indicators[,i]>0,log(normal_modality_indicators[,i]),0)
}
par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 2:ncol(normal_modality_indicators)){
    hist(normal_modality_indicators[,i],col=colour,main=colnames(normal_modality_indicators)[i],xlab="",ylab="")
}

#keep these from original set
normal_modality_indicators$nonmotor_800_size <- modality_indicators_set$nonmotor_800_size
normal_modality_indicators$car_800_size <- modality_indicators_set$car_800_size
normal_modality_indicators$nonmotor_1600_size <- modality_indicators_set$nonmotor_1600_size
normal_modality_indicators$car_1600_size <- modality_indicators_set$car_1600_size
normal_modality_indicators$work_car_20min_area <- modality_indicators_set$work_car_20min_area
normal_modality_indicators$car_angular_close_800_mean <- modality_indicators_set$car_angular_close_800_mean
normal_modality_indicators$car_angular_close_1600_mean <- modality_indicators_set$car_angular_close_1600_mean
normal_modality_indicators$nonmotor_angular_close_800_mean <- modality_indicators_set$car_angular_close_1600_mean
normal_modality_indicators$bicycle_angular_seg_betw_800 <- modality_indicators_set$bicycle_angular_seg_betw_800
normal_modality_indicators$nonmotor_angular_close_1600_mean <- modality_indicators_set$nonmotor_angular_close_1600_mean
normal_modality_indicators$bicycle_angular_seg_betw_1600 <- modality_indicators_set$bicycle_angular_seg_betw_1600
normal_modality_indicators$transit_angular_seg_close_800_mean <- modality_indicators_set$transit_angular_seg_close_800_mean
normal_modality_indicators$rail_angular_seg_close_800_mean <- modality_indicators_set$rail_angular_seg_close_800_mean
normal_modality_indicators$transit_angular_seg_close_1600_mean <- modality_indicators_set$transit_angular_seg_close_1600_mean
normal_modality_indicators$rail_angular_seg_close_1600_mean <- modality_indicators_set$rail_angular_seg_close_1600_mean

normal_modality_indicators$rail_1600_count <- modality_indicators_set$rail_1600_count
normal_modality_indicators$culdesac_180_count <- modality_indicators_set$culdesac_180_count
normal_modality_indicators$main_angular_betw_800 <- modality_indicators_set$main_angular_betw_800
normal_modality_indicators$main_angular_betw_1600 <- modality_indicators_set$main_angular_betw_1600
normal_modality_indicators$nonmotor_angular_seg_close_800_mean <- modality_indicators_set$nonmotor_angular_seg_close_800_mean
normal_modality_indicators$nonmotor_angular_seg_close_1600_mean <- modality_indicators_set$nonmotor_angular_seg_close_1600_mean

#correlate across groups
# remove NA
modality_indicators_data <- na.omit(normal_modality_indicators[,2:ncol(normal_modality_indicators)])
#prepare data for correlation
modality_rmatrix <- round(rcorr(as.matrix(modality_indicators_data))$r,digits=3)
modality_r2matrix <- round((rcorr(as.matrix(modality_indicators_data))$r)^2,digits=3)
modality_pmatrix <- round(rcorr(as.matrix(modality_indicators_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(modality_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=modality_pmatrix, sig.level=0.01)
corrplot(modality_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=modality_pmatrix, insig = "p-value", sig.level=-1)


#simply rank all the variables
ranked_modality_indicators <- modality_indicators_set
for (i in 2:ncol(ranked_modality_indicators)){
    ranked_modality_indicators[,i] <- ifelse(ranked_modality_indicators[,i]>0,rank(ranked_modality_indicators[,i],na.last="keep",ties="average"),0)
}
#using ranked values
ranked_modality_indicators<- na.omit(ranked_modality_indicators)
rank_modality_rmatrix <- round(rcorr(as.matrix(ranked_modality_indicators[2:ncol(ranked_modality_indicators)]))$r,digits=3)
rank_modality_r2matrix <- round((rcorr(as.matrix(ranked_modality_indicators[2:ncol(ranked_modality_indicators)]))$r)^2,digits=3)
rank_modality_pmatrix <- round(rcorr(as.matrix(ranked_modality_indicators[2:ncol(ranked_modality_indicators)]))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(rank_modality_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=rank_modality_pmatrix, sig.level=0.01)
corrplot(rank_modality_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=rank_modality_pmatrix, insig = "p-value", sig.level=-1)



# 4. correlate with mobility ######
#normalise mobility data
mon_data <- mon[9:ncol(mon)]
par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 1:ncol(mon_data)){
    hist(log(subset(mon_data,mon_data[,i]>0)[,i]),col=colour,main=colnames(mon_data)[i],xlab="",ylab="")
}
normal_mon_data <- mon[,c(1,9:ncol(mon))]
for (i in 2:ncol(normal_mon_data)){
    normal_mon_data[,i] <- ifelse(normal_mon_data[,i]>0,log(normal_mon_data[,i]),0)
}
normal_mon_data<- na.omit(normal_mon_data)

#against normal modality data
modality_mobility_data <- merge(normal_mon_data,normal_modality_indicators,by="pcode")
# remove NA
modality_mobility_data <- na.omit(modality_mobility_data[,2:ncol(modality_mobility_data)])
#correlation matrices
modality_mobility_rmatrix <- round(rcorr(as.matrix(modality_mobility_data))$r,digits=3)
modality_mobility_r2matrix <- round((rcorr(as.matrix(modality_mobility_data))$r)^2,digits=3)
modality_mobility_pmatrix <- round(rcorr(as.matrix(modality_mobility_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(modality_mobility_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=modality_mobility_pmatrix, sig.level=0.01)
corrplot(modality_mobility_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=modality_mobility_pmatrix, insig = "p-value", sig.level=-1)

#with ranked variables
ranked_mon_data <- mon[,c(1,9:ncol(mon))]
for (i in 2:ncol(ranked_mon_data)){
    ranked_mon_data[,i] <- ifelse(ranked_mon_data[,i]>0,rank(ranked_mon_data[,i],na.last="keep",ties="average"),0)
}
ranked_mon_data<- na.omit(ranked_mon_data)

#against ranked  modality data
ranked_modality_mobility_data<- merge(ranked_mon_data,ranked_modality_indicators,by="pcode")
# remove NA
ranked_modality_mobility_data <- na.omit(ranked_modality_mobility_data[,2:ncol(ranked_modality_mobility_data)])
#correlation matrices
rank_modality_mobility_rmatrix <- round(rcorr(as.matrix(ranked_modality_mobility_data))$r,digits=3)
rank_modality_mobility_r2matrix <- round((rcorr(as.matrix(ranked_modality_mobility_data))$r)^2,digits=3)
rank_modality_mobility_pmatrix <- round(rcorr(as.matrix(ranked_modality_mobility_data))$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(rank_modality_mobility_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=rank_modality_mobility_pmatrix, sig.level=0.01)
corrplot(rank_modality_mobility_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=rank_modality_mobility_pmatrix, insig = "p-value", sig.level=-1)



# 5. make a reduced meaningful set ######

#proximity
modality_indicators_reducedset <- proximity[,c("pcode","bicycle_metric_dist","main_metric_dist","motorway_metric_dist","rail_metric_dist")]
modality_indicators_reducedset$localtransit_metric_dist <- apply(proximity[,c("bus_metric_dist","metro_metric_dist","tram_metric_dist")], 1, function(row) min(row))
is.na(modality_indicators_reducedset) <- do.call(cbind,lapply(modality_indicators_reducedset, is.infinite))

#network density
modality_indicators_add <- ndensity1[,c("pcode","pedestrian_800_size","bicycle_800_size","car_800_size","main_800_size","culdesac_800_count",
                                        "motorway_1600_size","rail_1600_count")]
modality_indicators_add$crossings_800_count <- apply(ndensity1[,c("xcross_800_count","tcross_800_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add$localtransit_800_count <- apply(ndensity1[,c("metro_800_count","tram_800_count","bus_800_count")], 1, function(row) sum(row,na.rm=TRUE))
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#network reach
modality_indicators_add <- ndensity1[,c("pcode","nonmotor_180_size","car_180_size")]
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#activity density - local metric
modality_indicators_add <- modality_indicators_set[,c("pcode","residential_800_area","active_800_area","work_800_area","education_800_area")]
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#network centrality
#car
modality_indicators_add <- centrality1[,c("pcode","private_angular_close_800_mean","car_private_angular_betw_800","main_private_angular_betw_800","motorway_private_angular_betw_1600")]
colnames(modality_indicators_add) <- c("pcode","car_angular_close_800_mean","car_angular_betw_800","main_angular_betw_800","motorway_angular_betw_1600")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#nonmotor
modality_indicators_add <- centrality2[,c("pcode","nonmotor_cogn_angular_seg_close_800_mean","bicycle_private_angular_betw_800")]
colnames(modality_indicators_add) <- c("pcode","nonmotor_angular_seg_close_800_mean","bicycle_angular_betw_800")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#transit
modality_indicators_add <- centrality3[,c("pcode","nonmotor_cogn_angular_seg_close_800_transit_mean","nonmotor_cogn_angular_seg_close_1600_rail_mean")]
colnames(modality_indicators_add) <- c("pcode","transit_angular_seg_close_800_mean","rail_angular_seg_close_1600_mean")
modality_indicators_add[is.na(modality_indicators_add)] <- 0
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")

#activity accessibility
modality_indicators_add <- accessibility[,c("pcode","residential_local_access_800m","education_local_access_800m","activity_local_access_800m","work_local_access_800m","car_activity_temp","transit_activity_tempbike","car_work_temp","transit_work_tempbike")]
colnames(modality_indicators_add)[2:ncol(modality_indicators_add)] <- c("nonmotor_residential_localaccess","nonmotor_education_localaccess","nonmotor_activity_localaccess","nonmotor_work_localaccess","car_activity_access","transit_activity_access","car_work_access","transit_work_access")
modality_indicators_add$activity_access_diff <- modality_indicators_add$transit_activity_access-car_activity_access
modality_indicators_add$work_access_diff <- modality_indicators_add$transit_work_access-car_work_access
modality_indicators_reducedset <- merge(modality_indicators_reducedset,modality_indicators_add,by="pcode")


if(dbExistsTable(con,c("analysis","modality_indicators_meaningful"))){
    dbRemoveTable(con,c("analysis","modality_indicators_meaningful"))
}
dbWriteTable(con,c("analysis","modality_indicators_meaningful"),modality_indicators_reducedset)

modality_indicators_reducedset <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful")
modality_data <- modality_indicators_reducedset[,2:ncol(modality_indicators_reducedset)]
modality_data <- na.omit(modality_data)

# reanalyse this reduced set with the previous, and new methods
#histograms
par(mfrow=c(6,3),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 2:ncol(modality_data)){
    h<-hist(modality_data[,i],breaks=10,col=colour,main=colnames(modality_data)[i],xlab="",ylab="")
}

#transform non-normal variables, where 0 remains 0
normal_modality_data <- modality_data
for (i in 2:ncol(normal_modality_data)){
    normal_modality_data[,i] <- ifelse(normal_modality_data[,i]>0,log(normal_modality_data[,i]+1),0)
}
#keep these from original set
normal_modality_data$car_800_size <- modality_data$car_800_size
normal_modality_data$rail_1600_count <- modality_data$rail_1600_count
#normal_modality_data$car_angular_close_800_mean <- modality_data$car_angular_close_800_mean
#normal_modality_data$main_angular_betw_800 <- modality_data$main_angular_betw_800
#normal_modality_data$motorway_angular_betw_1600 <- modality_data$motorway_angular_betw_1600
#normal_modality_data$nonmotor_angular_seg_close_800_mean <- modality_data$nonmotor_angular_seg_close_800_mean
normal_modality_data$activity_access_diff <- log(modality_data$activity_access_diff+190000000)
normal_modality_data$work_access_diff <- log(modality_data$work_access_diff+560000000)

#or simply rank them
ranked_modality_data <- modality_indicators_reducedset
for (i in 2:ncol(ranked_modality_data)){
    ranked_modality_data[,i] <- ifelse(ranked_modality_data[,i]>0,rank(ranked_modality_data[,i],na.last="keep",ties="average"),0)
}

#histograms with normal plot
par(mfrow=c(5,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 2:ncol(normal_modality_data)){
    h<-hist(normal_modality_data[,i],col=colour,main=colnames(normal_modality_data)[i],xlab="",ylab="")
    xfit<-seq(min(normal_modality_data[,i]),max(normal_modality_data[,i]),length=40) 
    yfit<-dnorm(xfit,mean=mean(normal_modality_data[,i]),sd=sd(normal_modality_data[,i]))
    yfit <- yfit*diff(h$mids[1:2])*length(normal_modality_data[,i]) 
    lines(xfit, yfit, col="blue", lwd=2)
}

# "plain" density plots
par(mfrow=c(5,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 2:ncol(normal_modality_data)){
    plot(density(normal_modality_data[,i],adjust=0.5),col=colour,xlab="",main=colnames(normal_modality_data)[i])
}

# classify the variables with natural breaks using hierarchichal clustering
# and make density plots
par(mfrow=c(5,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 2:ncol(normal_modality_data)){
    n <- 5
    if (i %in% c(13)) n <- 3
    breaks <- classIntervals(normal_modality_data[,i],n=n,style="hclust")$brks
    modality_data$new <- cut(normal_modality_data[,i],breaks,right=FALSE,include.lowest=TRUE,labels=c(1:n))
    colnames(modality_data)[ncol(modality_data)] <- paste("h",colnames(modality_data)[i],sep="_")
    plot(density(normal_modality_data[,i],adjust=0.5),col=colour,xlab="",main=colnames(normal_modality_data)[i])
    abline(v=breaks)
}

#boxplot
scaled_modality_data <- data.frame(scale(normal_modality_data[,2:ncol(normal_modality_data)]))
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(2.5,0.25,0.25,0.25), ps=10, cex=1.1)
boxdata <- boxplot(scaled_modality_data,ylim=c(-5,5),lwd=1, cex=0.25, frame.plot=TRUE,las=2,main="Modality indicators variation in the Randstad")
abline(h=0,col="black",lty=3)


# 6. correlation between mobility and select results of the reduced set ######

#review again correlation of indicators before clustering
#correlate again including normal mobility data
modality_mobility_data <- merge(normal_mon_data,normal_modality_data,by="pcode")
modality_mobility_data <- modality_mobility_data[,2:ncol(modality_mobility_data)]
# remove NA
#modality_mobility_data <- na.omit(modality_mobility_data[,2:ncol(modality_mobility_data)])
#correlation matrices
modality_mobility_rmatrix <- round(rcorr(as.matrix(modality_mobility_data),type="spearman")$r,digits=3)
modality_mobility_r2matrix <- round((rcorr(as.matrix(modality_mobility_data),type="spearman")$r)^2,digits=3)
modality_mobility_pmatrix <- round(rcorr(as.matrix(modality_mobility_data),type="spearman")$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(modality_mobility_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=modality_mobility_pmatrix, sig.level=0.01)
corrplot(modality_mobility_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=modality_mobility_pmatrix, insig = "p-value", sig.level=-1)

#this shows the impact of 0 values in the correlation results
cor(subset(normal_modality_data,normal_modality_data$motorway_1600_size>0)$motorway_angular_betw_1600,subset(normal_modality_data,normal_modality_data$motorway_1600_size>0)$motorway_1600_size)
cor(normal_modality_data[,"motorway_angular_betw_1600"],normal_modality_data[,"motorway_1600_size"])

#I'll use spearman from now because it's more robust
modality_mobility_rmatrix1 <- round(cor(as.matrix(modality_mobility_data),use="pairwise.complete.obs"),digits=3)
modality_mobility_rmatrix2 <- round(cor(as.matrix(modality_mobility_data),use="pairwise.complete.obs",method="kendall"),digits=3)
modality_mobility_rmatrix3 <- round(cor(as.matrix(modality_mobility_data),use="pairwise.complete.obs",method="spearman"),digits=3)

##
#the correlation with mobility must be done pairwise removing the zeros as well. If I make them NA this is automatic.
normal_modality_data_nozero <- normal_modality_data[,c(1,7:ncol(normal_modality_data))]
normal_modality_data_nozero[normal_modality_data_nozero==0]<-NA
normal_modality_data_nozero <- merge(normal_modality_data[,1:6],normal_modality_data_nozero,by="pcode")

modality_mobility_data <- merge(normal_mon_data,normal_modality_data_nozero,by="pcode")
modality_mobility_data <- modality_mobility_data[,2:ncol(modality_mobility_data)]
#correlation matrices
modality_mobility_rmatrix <- round(rcorr(as.matrix(modality_mobility_data),type="spearman")$r,digits=3)
modality_mobility_r2matrix <- round((rcorr(as.matrix(modality_mobility_data),type="spearman")$r)^2,digits=3)
modality_mobility_pmatrix <- round(rcorr(as.matrix(modality_mobility_data),type="spearman")$P,digits=5)
# correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(modality_mobility_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=modality_mobility_pmatrix, sig.level=0.01)
corrplot(modality_mobility_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=modality_mobility_pmatrix, insig = "p-value", sig.level=-1)


# scatterplots of relevant pairs and correlations



# 7. Classification of modality based on infrastructure ######
attach(modality_indicators_reducedset)

#composite accessibility index
modality_indicators_reducedset$activity_access_diff <- transit_activity_access - car_activity_access
modality_indicators_reducedset$work_access_diff <- transit_work_access - car_work_access
    
L <- (rail_1600_count > 0 & localtransit_800_count>0)
L <- (rail_1600_count > 0 & localtransit_800_count==0)
L <- (rail_1600_count > 0 & localtransit_800_count==0)
modality_indicators_reducedset[L,"rail_1600_count"]

#transit
modality_indicators_reducedset$transit_class <- NA
modality_indicators_reducedset[rail_1600_count > 0,"transit_class"] <- 2 #rail
modality_indicators_reducedset[(rail_1600_count == 0 & localtransit_800_count > 0),"transit_class"] <- 1 #local transit
modality_indicators_reducedset[(rail_1600_count == 0 & localtransit_800_count == 0),"transit_class"] <- 0 #no transit

#car
modality_indicators_reducedset$car_class <- NA
modality_indicators_reducedset[(main_800_size > 0 & motorway_1600_size == 0),"car_class"] <- 1 #main road
modality_indicators_reducedset[(main_800_size == 0 & motorway_1600_size > 0),"car_class"] <- 2 #motorway
modality_indicators_reducedset[(main_800_size > 0 & motorway_1600_size > 0),"car_class"] <- 3 #car
modality_indicators_reducedset[(main_800_size == 0 & motorway_1600_size == 0),"car_class"] <- 0 #no car

#nonmotor
modality_indicators_reducedset$nomotor_class <- NA
modality_indicators_reducedset[(pedestrian_800_size > 0 & bicycle_800_size == 0),"nomotor_class"] <- 1 #pedestrian
modality_indicators_reducedset[(pedestrian_800_size == 0 & bicycle_800_size > 0),"nomotor_class"] <- 2 #bicycle
modality_indicators_reducedset[(pedestrian_800_size > 0 & bicycle_800_size > 0),"nomotor_class"] <- 3 #nonmotorised
modality_indicators_reducedset[(pedestrian_800_size == 0 & bicycle_800_size == 0),"nomotor_class"] <- 0 #no nonmotorised

#codes
modality_indicators_reducedset$tri_class <- do.call(paste,c(modality_indicators_reducedset[c("transit_class","car_class","nomotor_class")], sep = ""))
modality_indicators_reducedset$duo_class <- do.call(paste,c(modality_indicators_reducedset[c("transit_class","car_class")],sep=""))

#using the base class aggregate
aggregate(modality_indicators_reducedset$"duo_class", by=list(modality_indicators_reducedset$"duo_class"), FUN=length)
#or sql expressions
library(sqldf)
sqldf(dbname="phd_work", port="5432", user="postgres","Select tri_class, count(*) as count from modality_indicators_reducedset group by tri_class order by tri_class asc")
sqldf(dbname="phd_work", port="5432", user="postgres","Select duo_class, count(*) as count from modality_indicators_reducedset group by duo_class order by duo_class asc")

detach(modality_indicators_reducedset)

if(dbExistsTable(con,c("analysis","modality_indicators_meaningful_clusters"))){
    dbRemoveTable(con,c("analysis","modality_indicators_meaningful_clusters"))
}
dbWriteTable(con,c("analysis","modality_indicators_meaningful_clusters"),modality_indicators_reducedset[,2:ncol(modality_indicators_reducedset)])

modality_indicators_reducedset <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful_clusters")
modality_data <- modality_indicators_reducedset[,2:ncol(modality_indicators_reducedset)]


# 8. Clustering of urban form typologies ######

#scale, remove NAs or invalid values
scaled_modality_data <- na.omit(data.frame(pcode=modality_data$pcode, scale(modality_data[,2:39])))
scaled_normal_modality_data <- na.omit(data.frame(pcode=normal_modality_data$pcode, scale(normal_modality_data[,2:39])))

#only keep non-correlated columns
modality_character_v1 <- scaled_modality_data[,c(2:8,11,13:22,26,28,29,38,39)]
modality_character_v2 <- scaled_modality_data[,c(2:8,11,13:22,26,28,29,38,39)]
modality_character <- scaled_modality_data[,c(2:8,11,13:22,26,28,29,38,39)]
normal_modality_character <- scaled_normal_modality_data[,c(2:8,11,13:22,26,28,29,38,39)]

#scree plot
screeplot<-c(1:23)
for (i in 1:25) screeplot[i] <- sum(kmeans(modality_character, centers=i)$withinss)
#scree plot
par(mfrow=c(1,1),mai=c(1.1,1,0.5,0.5), omi=c(0.5,0.5,0.5,0.5), ps=12)
plot(1:25, screeplot, type="l",col="blue", xlab="Number of Clusters", ylab="Within groups sum of squares",main="Scree plot",xaxs="i",xaxt="n")
axis(1, at=1:25, labels=seq(1,25))

screeplot<-c(1:23)
for (i in 1:25) screeplot[i] <- sum(kmeans(normal_modality_character, centers=i)$withinss)
#scree plot
par(mfrow=c(1,1),mai=c(1.1,1,0.5,0.5), omi=c(0.5,0.5,0.5,0.5), ps=12)
plot(1:25, screeplot, type="l",col="blue", xlab="Number of Clusters", ylab="Within groups sum of squares",main="Scree plot",xaxs="i",xaxt="n")
axis(1, at=1:25, labels=seq(1,25))


# calculate selected cluster solutions
modality_clusters <- data.frame(pcode=modality_data$pcode)
modality_medoids <- matrix(NA,0,2+ncol(modality_character))
for (i in 2:25){
    solution <- paste("k",i,sep="_")
    modality_fit <- pam(modality_character, i, stand=TRUE)
    modality_medoids <- rbind(modality_medoids,data.frame("solution"=solution,"cluster"=c(1:i),pcode=modality_data[row.names(modality_fit$medoids),"pcode"],modality_data[row.names(modality_fit$medoids),colnames(modality_character)]))
    modality_clusters$new <- modality_fit$clustering
    colnames(modality_clusters)[ncol(modality_clusters)] <- solution
}

normal_modality_clusters <- data.frame(pcode=modality_data$pcode)
normal_modality_medoids <- matrix(NA,0,2+ncol(normal_modality_character))
for (i in 2:25){
    solution <- paste("k",i,sep="_")
    modality_fit <- pam(normal_modality_character, i, stand=TRUE)
    normal_modality_medoids <- rbind(normal_modality_medoids,data.frame("solution"=solution,"cluster"=c(1:i),pcode=modality_data[row.names(modality_fit$medoids),"pcode"],modality_fit$medoids))
    normal_modality_clusters$new <- modality_fit$clustering
    colnames(normal_modality_clusters)[ncol(normal_modality_clusters)] <- solution
}

#description of cluster solutions - per cluster ######
modality_cluster_summary <- matrix(NA,0,9)
d1 <- dist(modality_character, method="euclidean")
colnames(modality_cluster_summary) <- c("clusters","number","size","diameter","widest gap","avg_distance","silo_width","separation","avg_toother")
for (j in 2:ncol(modality_clusters)){
    modality_stats <- cluster.stats(d=d1, modality_clusters[,j])
    modality_temp_summary <- matrix(NA,modality_stats$cluster.number,9)
    
    for (i in 1:modality_stats$cluster.number){
        modality_temp_summary[i,1] <- colnames(modality_clusters)[j]
        modality_temp_summary[i,2] <- i
        modality_temp_summary[i,3] <- round(modality_stats$cluster.size[i])
        # diameter is the maximum within cluster distance
        modality_temp_summary[i,4] <- round(modality_stats$diameter[i],4)
        # list of the widest gap within each cluster: might be identical to diameter?
        modality_temp_summary[i,5] <- round(modality_stats$cwidegap[i],4)
        # average within cluster distance
        modality_temp_summary[i,6] <- round(modality_stats$average.distance[i],4)
        # aveage cluster silhouette widhts
        modality_temp_summary[i,7] <- round(modality_stats$clus.avg.silwidths[i],4)
        # separation is the minimum between cluster distance
        modality_temp_summary[i,8] <- round(modality_stats$separation[i],4)
        # aveage between cluster distances
        modality_temp_summary[i,9] <- round(modality_stats$average.toother[i],4)
    }
    modality_cluster_summary <- rbind(modality_cluster_summary,modality_temp_summary)
}

normal_modality_cluster_summary <- matrix(NA,0,9)
d1 <- dist(normal_modality_character, method="euclidean")
colnames(normal_modality_cluster_summary) <- c("clusters","number","size","diameter","widest gap","avg_distance","silo_width","separation","avg_toother")
for (j in 2:ncol(normal_modality_clusters)){
    modality_stats <- cluster.stats(d=d1, normal_modality_clusters[,j])
    modality_temp_summary <- matrix(NA,modality_stats$cluster.number,9)
    
    for (i in 1:modality_stats$cluster.number){
        modality_temp_summary[i,1] <- colnames(normal_modality_clusters)[j]
        modality_temp_summary[i,2] <- i
        modality_temp_summary[i,3] <- round(modality_stats$cluster.size[i])
        # diameter is the maximum within cluster distance
        modality_temp_summary[i,4] <- round(modality_stats$diameter[i],4)
        # list of the widest gap within each cluster: might be identical to diameter?
        modality_temp_summary[i,5] <- round(modality_stats$cwidegap[i],4)
        # average within cluster distance
        modality_temp_summary[i,6] <- round(modality_stats$average.distance[i],4)
        # aveage cluster silhouette widhts
        modality_temp_summary[i,7] <- round(modality_stats$clus.avg.silwidths[i],4)
        # separation is the minimum between cluster distance
        modality_temp_summary[i,8] <- round(modality_stats$separation[i],4)
        # aveage between cluster distances
        modality_temp_summary[i,9] <- round(modality_stats$average.toother[i],4)
    }
    normal_modality_cluster_summary <- rbind(normal_modality_cluster_summary,modality_temp_summary)
}

#description of cluster solutions ######
#quality of solutions indices
modality_cluster_quality <- matrix(NA,(ncol(modality_clusters)-1),14)
colnames(modality_cluster_quality) <- c("clusters","number","within_ss","avg_within","avg_between","wb_ratio","avg_silhouette","widest_gap","g3","dunn","dunn2","ch","entropy","sep_index")

for (i in 2:ncol(modality_clusters)){
    modality_stats <- cluster.stats(d=d1, modality_clusters[,i],wgap=TRUE,G3 = TRUE, sepindex=TRUE, sepprob=1)
    #,G2 = TRUE this is too slow
    r <- i-1
    modality_cluster_quality[r,1] <- colnames(modality_clusters)[i]
    #description - global
    modality_cluster_quality[r,2] <- modality_stats$cluster.number
    modality_cluster_quality[r,3] <- round(modality_stats$within.cluster.ss,digits=4)
    modality_cluster_quality[r,4] <- round(modality_stats$average.within,digits=4)
    modality_cluster_quality[r,5] <- round(modality_stats$average.between,digits=4)
    #ratio of within/between
    modality_cluster_quality[r,6] <- round(modality_stats$wb.ratio,digits=4)
    # calculates the average width of the silhouette of all observations. 0 is between clusters, 1 is well placed.
    modality_cluster_quality[r,7] <- round(modality_stats$avg.silwidth,digits=4)
    # The widest within cluster gap
    modality_cluster_quality[r,8] <- round(modality_stats$widestgap,digits=4)
    
    #quality tests
    #Goodman Kruskal -1 (inversion) 0 (no relation) 1 (agreement)
    modality_cluster_quality[r,9] <- round(modality_stats$g3,digits=4)
    #Dunn's validity index - the higher the better
    modality_cluster_quality[r,10] <- round(modality_stats$dunn,digits=4)
    # Another version of Dunn's index
    modality_cluster_quality[r,11] <- round(modality_stats$dunn2,digits=4)
    # Calinksy Harabasz index - the higher the better
    modality_cluster_quality[r,12] <- round(modality_stats$ch,digits=4)
    # distribution of memberships Meila - the higher the better
    modality_cluster_quality[r,13] <- round(modality_stats$entropy,digits=4)
    # Hennig - formalise separation between clusters, good for selecting number of clusters
    modality_cluster_quality[r,14] <- round(modality_stats$sindex,digits=4)
}

#line charts of the various indices
par(mfrow=c(3,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 3:14){
    plot(modality_cluster_quality[,i],type="l",col="red",ylab="index value",xlab="k",main=colnames(modality_cluster_quality)[i], xaxs="i",xaxt="n")
    axis(1, at=c(1:ncol(modality_clusters)-1), labels=modality_cluster_quality[,2])
}


normal_modality_cluster_quality <- matrix(NA,(ncol(normal_modality_clusters)-1),14)
colnames(normal_modality_cluster_quality) <- c("clusters","number","within_ss","avg_within","avg_between","wb_ratio","avg_silhouette","widest_gap","g3","dunn","dunn2","ch","entropy","sep_index")

for (i in 2:ncol(normal_modality_clusters)){
    modality_stats <- cluster.stats(d=d1, normal_modality_clusters[,i],wgap=TRUE,G3 = TRUE, sepindex=TRUE, sepprob=1)
    #,G2 = TRUE this is too slow
    r <- i-1
    normal_modality_cluster_quality[r,1] <- colnames(normal_modality_clusters)[i]
    #description - global
    normal_modality_cluster_quality[r,2] <- modality_stats$cluster.number
    normal_modality_cluster_quality[r,3] <- round(modality_stats$within.cluster.ss,digits=4)
    normal_modality_cluster_quality[r,4] <- round(modality_stats$average.within,digits=4)
    normal_modality_cluster_quality[r,5] <- round(modality_stats$average.between,digits=4)
    #ratio of within/between
    normal_modality_cluster_quality[r,6] <- round(modality_stats$wb.ratio,digits=4)
    # calculates the average width of the silhouette of all observations. 0 is between clusters, 1 is well placed.
    normal_modality_cluster_quality[r,7] <- round(modality_stats$avg.silwidth,digits=4)
    # The widest within cluster gap
    normal_modality_cluster_quality[r,8] <- round(modality_stats$widestgap,digits=4)
    
    #quality tests
    #Goodman Kruskal -1 (inversion) 0 (no relation) 1 (agreement)
    normal_modality_cluster_quality[r,9] <- round(modality_stats$g3,digits=4)
    #Dunn's validity index - the higher the better
    normal_modality_cluster_quality[r,10] <- round(modality_stats$dunn,digits=4)
    # Another version of Dunn's index
    normal_modality_cluster_quality[r,11] <- round(modality_stats$dunn2,digits=4)
    # Calinksy Harabasz index - the higher the better
    normal_modality_cluster_quality[r,12] <- round(modality_stats$ch,digits=4)
    # distribution of memberships Meila - the higher the better
    normal_modality_cluster_quality[r,13] <- round(modality_stats$entropy,digits=4)
    # Hennig - formalise separation between clusters, good for selecting number of clusters
    normal_modality_cluster_quality[r,14] <- round(modality_stats$sindex,digits=4)
}

#line charts of the various indices
par(mfrow=c(3,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 3:14){
    plot(normal_modality_cluster_quality[,i],type="l",col="red",ylab="index value",xlab="k",main=colnames(normal_modality_cluster_quality)[i], xaxs="i",xaxt="n")
    axis(1, at=c(1:(ncol(normal_modality_clusters)-1)), labels=normal_modality_cluster_quality[,2])
}

# 9. Produce thematic maps for expert inspection ######

# add selected cluster solutions
modality_data$k_5 <- modality_clusters$k_5
modality_data$k_11 <- modality_clusters$k_11
modality_data$k_15 <- modality_clusters$k_15
modality_data$k_19 <- modality_clusters$k_19

# add selected cluster solutions, these actually look crap
modality_data$nk_5 <- normal_modality_clusters$k_5
modality_data$nk_9 <- normal_modality_clusters$k_9
modality_data$nk_10 <- normal_modality_clusters$k_10
modality_data$nk_11 <- normal_modality_clusters$k_11
modality_data$nk_12 <- normal_modality_clusters$k_12
modality_data$nk_13 <- normal_modality_clusters$k_13
modality_data$nk_15 <- normal_modality_clusters$k_15
modality_data$nk_19 <- normal_modality_clusters$k_19

#write results to postgresql for mapping
output<-"modality_indicators_meaningful_clusters"
if(dbExistsTable(con,c("analysis",output))){
    dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),modality_data) 

modality_indicators_reducedset <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful_clusters")
modality_data <- modality_indicators_reducedset[,2:ncol(modality_indicators_reducedset)]


# 10. Statistical description of modality types ######

#k-medoid details of selected k=5, k=11, k=15, k=19
sel_k <- c(5,11,15,19)

#mean values of clusters
agg_data <- modality_data[,c(2:8,11,13:22,26,28,29,34:39,45:48)]

modality_clusters_mean <- as.data.frame(matrix(data=NA,sum(sel_k)+1,ncol(agg_data)-1,byrow=FALSE))
colnames(modality_clusters_mean) <- c("solution","clusters","count",colnames(agg_data)[1:(ncol(agg_data)-4)])

#add the Randstad mean values
modality_clusters_mean[1,] <- c("Randstad","",nrow(modality_data),round(colMeans(agg_data[,1:17]),digits=0),round(colMeans(agg_data[,18:21]),digits=6),round(colMeans(agg_data[,22:(ncol(agg_data)-length(sel_k))]),digits=0))

curr_row <- 1
for (i in 1:length(sel_k)){
    #descriptive statistics of clusters
    solution <- paste("k_",sel_k[i],sep="")
    result <- aggregate(agg_data[,1:(ncol(agg_data)-length(sel_k))],by=list(agg_data[,solution]),FUN=mean) 
    for (j in 1:sel_k[i]){
        elements <- nrow(subset(agg_data,agg_data[,solution] == j))
        modality_clusters_mean[curr_row+j,] <- c(solution,j,elements,round(result[j,2:18],digits=0),round(result[j,19:22],digits=6),round(result[j,23:(ncol(agg_data)-length(sel_k)+1)],digits=0))        
    }
    curr_row <- curr_row+sel_k[i]
}

#max values of clusters
agg_data <- modality_data[,c(2:8,11,13:22,26,28,29,34:39,45:48)]

modality_clusters_max <- as.data.frame(matrix(data=NA,sum(sel_k)+1,ncol(agg_data)-1,byrow=FALSE))
colnames(modality_clusters_max) <- c("solution","clusters","count",colnames(agg_data)[1:(ncol(agg_data)-4)])

#add the Randstad mean values
modality_clusters_max[1,] <- c("Randstad","",nrow(modality_data),round(apply(agg_data[,1:17],2,max),digits=0),round(apply(agg_data[,18:21],2,max),digits=6),round(apply(agg_data[,22:(ncol(agg_data)-length(sel_k))],2,max),digits=0))

curr_row <- 1
for (i in 1:length(sel_k)){
    #descriptive statistics of clusters
    solution <- paste("k_",sel_k[i],sep="")
    result <- aggregate(agg_data[,1:(ncol(agg_data)-length(sel_k))],by=list(agg_data[,solution]),FUN=max) 
    for (j in 1:sel_k[i]){
        elements <- nrow(subset(agg_data,agg_data[,solution] == j))
        modality_clusters_max[curr_row+j,] <- c(solution,j,elements,round(result[j,2:18],digits=0),round(result[j,19:22],digits=6),round(result[j,23:(ncol(agg_data)-length(sel_k)+1)],digits=0))        
    }
    curr_row <- curr_row+sel_k[i]
}

#min values of clusters
agg_data <- modality_data[,c(2:8,11,13:22,26,28,29,34:39,45:48)]

modality_clusters_min <- as.data.frame(matrix(data=NA,sum(sel_k)+1,ncol(agg_data)-1,byrow=FALSE))
colnames(modality_clusters_min) <- c("solution","clusters","count",colnames(agg_data)[1:(ncol(agg_data)-4)])

#add the Randstad mean values
modality_clusters_min[1,] <- c("Randstad","",nrow(modality_data),round(apply(agg_data[,1:17],2,min),digits=0),round(apply(agg_data[,18:21],2,min),digits=6),round(apply(agg_data[,22:(ncol(agg_data)-length(sel_k))],2,min),digits=0))

curr_row <- 1
for (i in 1:length(sel_k)){
    #descriptive statistics of clusters
    solution <- paste("k_",sel_k[i],sep="")
    result <- aggregate(agg_data[,1:(ncol(agg_data)-length(sel_k))],by=list(agg_data[,solution]),FUN=min) 
    for (j in 1:sel_k[i]){
        elements <- nrow(subset(agg_data,agg_data[,solution] == j))
        modality_clusters_min[curr_row+j,] <- c(solution,j,elements,round(result[j,2:18],digits=0),round(result[j,19:22],digits=6),round(result[j,23:(ncol(agg_data)-length(sel_k)+1)],digits=0))        
    }
    curr_row <- curr_row+sel_k[i]
}

#medoid value of clusters
med <- paste("k_",sel_k[1],sep="")
for (i in 2:length(sel_k)){
    med <- append(med,paste("k_",sel_k[i],sep=""))
}
#medoid data of clusters
modality_clusters_medoid <- subset(modality_medoids, modality_medoids$solution %in% med)


#scaled values for paralell plots and box plots
smodality_data  <- data.frame(scaled_modality_data, modality_data[,45:48])
#this is the best scaling solution, goes between -1 and 1 retaining the centre at 0. range is not maxed like in most parallel plots.
smodality_data1 <- data.frame(pcode=modality_data$pcode,apply(scaled_modality_data[2:ncol(scaled_modality_data)],2,function(x)round(x*(1/max(abs(max(x)),abs(min(x)))),4)), modality_data[,45:48])
snormal_modality_data <- data.frame(pcode=modality_data$pcode,apply(scaled_normal_modality_data[2:ncol(scaled_normal_modality_data)],2,function(x)round(x*(1/max(abs(max(x)),abs(min(x)))),4)), modality_data[,45:48])

#add the selected cluster solutions
smodality_data$k_5 <- modality_clusters$k_5
smodality_data$k_11 <- modality_clusters$k_11
smodality_data$k_15 <- modality_clusters$k_15
smodality_data$k_19 <- modality_clusters$k_19

#scaled mean values of clusters
agg_data <- smodality_data1[,c(2:8,11,13:22,26,28,29,34:43)]

modality_clusters_smean <- as.data.frame(matrix(data=NA,sum(sel_k)+1,ncol(agg_data)-1,byrow=FALSE))
colnames(modality_clusters_smean) <- c("solution","clusters","count",colnames(agg_data)[1:(ncol(agg_data)-4)])

#add the Randstad mean values
modality_clusters_smean[1,] <- c("Randstad","",nrow(modality_data),round(colMeans(agg_data[,1:17]),digits=4),round(colMeans(agg_data[,18:21]),digits=6),round(colMeans(agg_data[,22:(ncol(agg_data)-length(sel_k))]),digits=4))

curr_row <- 1
for (i in 1:length(sel_k)){
    #descriptive statistics of clusters
    solution <- paste("k_",sel_k[i],sep="")
    result <- aggregate(agg_data[,1:(ncol(agg_data)-length(sel_k))],by=list(agg_data[,solution]),FUN=mean) 
    for (j in 1:sel_k[i]){
        elements <- nrow(subset(agg_data,agg_data[,solution] == j))
        modality_clusters_smean[curr_row+j,] <- c(solution,j,elements,round(result[j,2:18],digits=4),round(result[j,19:22],digits=6),round(result[j,23:(ncol(agg_data)-length(sel_k)+1)],digits=4))        
    }
    curr_row <- curr_row+sel_k[i]
}

# scaled medoid value of clusters
modality_clusters_smedoid <- as.data.frame(matrix(NA,0,ncol(modality_character)+3))
colnames(modality_clusters_smedoid) <- c("solution","cluster","pcode",colnames(modality_character))
agg_data <- smodality_data1[,c(1:8,11,13:22,26,28,29,38,39)]
agg_data$pcode <- as.character(agg_data$pcode)

for (i in 1:length(sel_k)){
    s <- paste("k_",sel_k[i],sep="")
    #medoid data of clusters
    med <- subset(modality_medoids, modality_medoids$solution == s)[1:3]
    result <- data.frame(med[,1:2],subset(agg_data, agg_data$pcode %in% med$pcode))
    modality_clusters_smedoid <- rbind(modality_clusters_smedoid,result)
}


# 11. Visualisation of modality types ######

#my chosen colour palette (equivalent to colours used in QGIS)
clusterpal <- c("red1","green1","dodgerblue3","orange1","green4","wheat1","purple1","deepskyblue1","magenta","cyan1","yellow1","brown","mediumpurple","plum1","grey30","black","black","black","black")

#parallel plots of the results
agg_data <- smodality_data1[,c(2:8,11,13:22,26,28,29,38:43)]

for (i in 1:length(sel_k)){
    par(mfrow=c(ceiling(sel_k[i]/2),2),mai=c(0.25,0.25,0.25,0.25), omi=c(1,0.25,0.25,0.25), ps=12)
    solution <- paste("k_",sel_k[i],sep="")
    for (j in 1:sel_k[i]){
        plot_data <- subset(agg_data,agg_data[,solution] == j)[,c(1:(ncol(agg_data)-length(sel_k)))]
        plot(as.numeric(plot_data[1,]),type="l",ylim=c(-1,1),main=paste("Cluster ",j,sep=""),lwd=0.03, col=clusterpal[j], axes=FALSE, frame.plot=TRUE)
        abline(h=0,col="black",lty=3)
        for (k in 2:nrow(plot_data))  lines(as.numeric(plot_data[k,]),col=clusterpal[j],lwd=0.03)
        if (j <= sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=FALSE)
        if (j > sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=colnames(plot_data),las=2)
        axis(side=2, labels=TRUE)
        coord <- par("usr")
    }
    title(paste("Distribution of modality indicators in each cluster: ",solution," solution",sep=""),outer=TRUE)
}

#boxplots for the clusters with the mean overlaid.
for (i in 1:length(sel_k)){
    par(mfrow=c(ceiling(sel_k[i]/2),2),mai=c(0.25,0.25,0.25,0.25), omi=c(1,0.25,0.25,0.25), ps=12)
    s <- paste("k_",sel_k[i],sep="")
    for (j in 1:sel_k[i]){
        plot_data <- subset(agg_data,agg_data[,s] == j)[,c(1:(ncol(agg_data)-length(sel_k)))]
        boxplot(plot_data, ylim=c(-1,1),main=paste("Cluster ",j,sep=""),lwd=0.5, frame.plot=TRUE, axes=FALSE)
        abline(h=0,col="black",lty=3)
        line_data <- subset(modality_clusters_smean,modality_clusters_smean$solution == s)[,c(4:24,29,30)]
        lines(as.numeric(line_data[j,1:ncol(line_data)]),type="l",col=clusterpal[j],lwd=1)
        if (j <= sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=FALSE)
        if (j > sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=colnames(plot_data),las=2)
        axis(side=2, labels=TRUE)
        coord <- par("usr")
    }
    title(paste("Variation of modality indicators in each cluster: ",s," solution",sep=""),outer=TRUE)
}

#boxplots for the clusters, for each variable.
for (i in 1:length(sel_k)){
    par(mfrow=c(ceiling(sel_k[i]/2),2),mai=c(0.25,0.25,0.25,0.25), omi=c(1,0.25,0.25,0.25), ps=12)
    s <- paste("k_",sel_k[i],sep="")
    for (j in 1:sel_k[i]){
        plot_data <- subset(agg_data,agg_data[,s] == j)[,c(1:(ncol(agg_data)-length(sel_k)))]
        boxplot(plot_data, ylim=c(-1,1),main=paste("Cluster ",j,sep=""),lwd=0.5, frame.plot=TRUE, axes=FALSE)
        abline(h=0,col="black",lty=3)
        line_data <- subset(modality_clusters_smean,modality_clusters_smean$solution == s)[,c(4:24,29,30)]
        lines(as.numeric(line_data[j,1:ncol(line_data)]),type="l",col=clusterpal[j],lwd=1)
        if (j <= sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=FALSE)
        if (j > sel_k[i]-2) axis(side=1,at=c(1:ncol(plot_data)),labels=colnames(plot_data),las=2)
        axis(side=2, labels=TRUE)
        coord <- par("usr")
    }
    title(paste("Variation of modality indicators in each cluster: ",s," solution",sep=""),outer=TRUE)
}

# mean values plot
for (i in 1:length(sel_k)){
    par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25), ps=10)
    s <- paste("k_",sel_k[i],sep="")
    plot_data <- subset(modality_clusters_smean,modality_clusters_smean$solution == s)[,c(2,4:ncol(modality_clusters_smean))]
    plot(as.numeric(plot_data[1,2:ncol(plot_data)]),type="l",ylim=c(-1,1),col=clusterpal[1],lwd=3,xaxt="n")
    abline(h=0,col="black",lty=3)
    for (j in 2:sel_k[i]) lines(as.numeric(plot_data[j,2:ncol(plot_data)]),type="l",col=clusterpal[j],lwd=3)
    axis(1,at=1:(ncol(plot_data)-1),labels=colnames(plot_data[,2:ncol(plot_data)]),cex.axis=0.85, las=2)
    legend(x="top",legend=plot_data[,"clusters"],ncol=5,cex=1,bty="n",col=clusterpal,lty=1,lwd=3,xpd=TRUE)
    title(paste("Mean values of clusters: ",s," solution",sep=""),outer=TRUE)
}

# medoid values plot
for (i in 1:length(sel_k)){
    par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25), ps=10)
    s <- paste("k_",sel_k[i],sep="")
    plot_data <- subset(modality_clusters_smedoid,modality_clusters_smedoid$solution == s)[,c(2,4:ncol(modality_clusters_smedoid))]
    plot(as.numeric(plot_data[1,2:ncol(plot_data)]),type="l",ylim=c(-1,1),col=clusterpal[1],lwd=3,xaxt="n")
    abline(h=0,col="black",lty=3)
    for (j in 2:sel_k[i]) lines(as.numeric(plot_data[j,2:ncol(plot_data)]),type="l",col=clusterpal[j],lwd=3)
    axis(1,at=1:(ncol(plot_data)-1),labels=colnames(plot_data[,2:ncol(plot_data)]),cex.axis=0.85, las=2)
    legend(x="top",legend=plot_data[,"cluster"],ncol=5,cex=1,bty="n",col=clusterpal,lty=1,lwd=3,xpd=TRUE)
    title(paste("Medoid values of clusters: ",s," solution",sep=""),outer=TRUE)
}

#mosaic plots of select cluster solutions, using pre-classified attribute data with 5 levels (top,high,medium,low,bottom)
agg_data <- modality_data[,c(45:55,58,60:69,73,75,76,81:86)]
for (i in 1:length(sel_k)){
    par(mfrow=c(14,2),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=15)
    s <- paste("k_",sel_k[i],sep="")
    for (j in 5:ncol(agg_data)){
        x <- table(agg_data[,c(i,j)])
        mosaicplot(x,shade=T,main=colnames(agg_data)[j],xlab="",ylab="")
    }
}

library("vcd")
for (i in 1:length(sel_k)){
    par(mfrow=c(13,2),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=12)
    s <- paste("k_",sel_k[i],sep="")
    for (j in 5:ncol(agg_data)){
        x <- table(agg_data[,c(i,j)])
        mp <- mosaic(x,shade=T,main=colnames(agg_data)[j],xlab="",ylab="",newpage=F)
    }
}
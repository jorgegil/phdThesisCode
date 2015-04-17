#Randstad urban form and travel statistical analysis

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc")
library("RColorBrewer")
library("classInt")

# some constants
def.par <- par(no.readonly = TRUE)
margins <- c(0.25,0.25,0.25,0.25)
bins <- pretty(range(c(0, 100)), n=21)
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)

#connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

##### 1. load data sets ####
urbanform<- dbGetQuery(con,"SELECT pcode, municipality, dist_1b_5b_full, dist_1b_dus, size_2a_pop, size_2b_pop, 
  mix_3b_hh, mix_3c_divers_retail, mix_3c_divers_work, mix_3c_divers_leisure, dens_4b_hh, dens_4c_jobs, local_5a_facilities,
  prox_6a_rail, prox_6b_road, street_8a_length, street_8c_tcross, street_8c_xcross, type_9a_urb, type_9a_dus, type_9b_myear, type_9b_named
  FROM analysis.classic_urbanform_indicators") 
#reclassify urban form named areas
urbanform$type_9b_newname <- "Other"
urbanform[which(urbanform$type_9b_named == "VINEX"),"type_9b_newname"] <- "TOD"
urbanform[which(urbanform$type_9b_named == "TOD"),"type_9b_newname"] <- "TOD" 
urbanform[which(urbanform$type_9b_named == "Reference"),"type_9b_newname"] <- "Reference"
urbanform[which(urbanform$type_9b_named == "Other"),"type_9b_newname"] <- "Reference"
urbanform[which(urbanform$type_9b_named == "Traditional"),"type_9b_newname"] <- "Traditional" 

mobility <- dbGetQuery(con,"SELECT pcode, journeys, legs, persons, distance, duration, distance_legs, duration_legs, 
  walk, cycle, car, bus, tram, train, transit, avg_dist, avg_journeys_pers, avg_dist_pers, 
  car_dist, transit_dist, car_dur, transit_dur, short_walk, short_cycle, short_car, 
  medium_cycle, medium_car, medium_transit, far_car, far_transit 
  FROM survey.mobility_patterns_home_od WHERE journeys IS NOT NULL AND journeys>=60") 

socioeconomic <- dbGetQuery(con,"SELECT pcode, age_15_24, age_25_44, age_45_64, age_65_74, age_75_more, oneperson_hh,
  nochildren_hh, withchildren_hh, low_income, high_income, cars_hh, own_car, primary_edu, middle_edu, secondary_edu, higher_edu 
  FROM survey.socio_economic_individuals_pcode WHERE individuals > 0")
sociocluster <- dbGetQuery(con,"SELECT pcode, k_8 FROM analysis.socio_economic_individuals_pcode_clusters")

modality <- dbGetQuery(con,"SELECT pcode, bicycle_metric_dist, main_metric_dist,
            motorway_metric_dist, rail_metric_dist, localtransit_metric_dist,
            pedestrian_800_size, bicycle_800_size, car_800_size, main_800_size,
            culdesac_800_count, motorway_1600_size, rail_1600_count, crossings_800_count,
            localtransit_800_count, nonmotor_180_size, car_180_size, residential_800_area,
            active_800_area, work_800_area, education_800_area, car_angular_close_800_mean,
            car_angular_betw_800, main_angular_betw_800, motorway_angular_betw_1600,
            nonmotor_angular_seg_close_800_mean, bicycle_angular_betw_800, transit_angular_seg_close_800_mean,
            rail_angular_seg_close_1600_mean FROM analysis.modality_indicators_meaningful")

#merge the three data sets
travelpatterns <- mobility
travelpatterns <- merge(travelpatterns, urbanform, by = "pcode")
travelpatterns <- merge(travelpatterns, socioeconomic, by = "pcode")
travelpatterns <- merge(travelpatterns, sociocluster, by = "pcode")
travelpatterns <- merge(travelpatterns, modality, by = "pcode")

#extract only the relevant data columns from the three data sets
data_to_scale <- mobility[which(mobility$pcode %in% travelpatterns$pcode),]
mobility_data <- data.frame(pcode=data_to_scale[,1],scale(data_to_scale[,9:ncol(data_to_scale)]))
travelpatterns_data <- mobility_data

data_to_scale <- urbanform[which(urbanform$pcode %in% travelpatterns$pcode),]
urbanform_data <- data.frame(pcode=data_to_scale[,1],scale(data_to_scale[,3:(ncol(data_to_scale)-5)]))
travelpatterns_data <- merge(travelpatterns_data, urbanform_data, by = "pcode")

data_to_scale <- socioeconomic[which(socioeconomic$pcode %in% travelpatterns$pcode),]
socioeconomic_data <- data.frame(pcode=data_to_scale[,1],scale(data_to_scale[,2:ncol(data_to_scale)]))
travelpatterns_data<- merge(travelpatterns_data, socioeconomic_data, by = "pcode")
travelpatterns_data <- merge(travelpatterns_data, sociocluster, by = "pcode")

data_to_scale <- modality[which(modality$pcode %in% travelpatterns$pcode),]
modality_data <- data.frame(pcode=data_to_scale[,1],scale(data_to_scale[,2:ncol(data_to_scale)]))
travelpatterns_data<- merge(travelpatterns_data, modality_data, by = "pcode")

##### 2. correlation matrix and correlograms ####
travelpatterns_rmatrix <- round(rcorr(as.matrix(travelpatterns_data))$r,digits=3)
travelpatterns_r2matrix <- round((rcorr(as.matrix(travelpatterns_data))$r)^2,digits=3)
travelpatterns_pmatrix <- round(rcorr(as.matrix(travelpatterns_data))$P,digits=5)

par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(travelpatterns_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=travelpatterns_pmatrix, sig.level=0.001)
corrplot(travelpatterns_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=travelpatterns_pmatrix, insig = "p-value", sig.level=-1)

#trying to do a non simetrical matrix was not too successful
test_rmatrix <- travelpatterns_rmatrix[24:53,2:23]
test_pmatrix <- travelpatterns_pmatrix[24:53,2:23]
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(test_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=test_pmatrix, sig.level=0.001)
corrplot(test_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=test_pmatrix, insig = "p-value", sig.level=-1)

#and trying to make a new type of heatmap is too much work. something for later
pal <- rainbow(20,start=0,end=4/6)
breaks <- seq(-1,1,0.1)
layout(matrix(data=c(1,2),nrow=1,ncol=2),widths=c(8,1),heights=c(1,1))
par(mar=c(3,7,12,2),oma=c(0.2,0.2,0.2,0.2),mex=0.5)
image(x=1:nrow(test_rmatrix),y=1:ncol(test_rmatrix),z=test_rmatrix,zlim=c(-1,1),breaks=breaks,col=pal)
text(x=1:nrow(test_rmatrix)+0.75,y=par("usr")[4]+1.25,srt=45,adj=1,labels=rownames(test_rmatrix),xpd=TRUE)
axis(2,at=1:ncol(test_rmatrix),labels=colnames(test_rmatrix),las=1,col="white")


##### 3. charts based on neighbourhood types ####
mobilitypatterns <- mobility_data
#invert direction of car variables to make indicators
mobilitypatterns$car <- -mobilitypatterns$car
mobilitypatterns$short_car <- -mobilitypatterns$short_car
mobilitypatterns$medium_car <- -mobilitypatterns$medium_car
mobilitypatterns$far_car <- -mobilitypatterns$far_car
mobilitypatterns$car_dist <- -mobilitypatterns$car_dist
mobilitypatterns$car_dur <- -mobilitypatterns$car_dur
mobilitypatterns$avg_dist <- -mobilitypatterns$avg_dist
mobilitypatterns$avg_journeys_pers <- -mobilitypatterns$avg_journeys_pers
mobilitypatterns$avg_dist_pers <- -mobilitypatterns$avg_dist_pers

#join urban form types
mobilitypatterns <- merge(mobilitypatterns, data.frame(urbanform[1],urbanform[(ncol(urbanform)-3):ncol(urbanform)]), by = "pcode")
mobility_dus <- aggregate(mobilitypatterns[2:23], list(neighbourhood_type = mobilitypatterns$type_9a_dus), mean,na.action = na.omit)[c(1,4,2,3),]
mobility_myear <- aggregate(mobilitypatterns[2:23], list(neighbourhood_type = mobilitypatterns$type_9b_myear), mean,na.action = na.omit)[c(4,1,2,3),]
mobility_named <- aggregate(mobilitypatterns[2:23], list(neighbourhood_type = mobilitypatterns$type_9b_newname), mean,na.action = na.omit)[c(4,2,3,1),]

#aggregate values per type (mean)
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(1.5,0.25,0.25,0.25), ps=10, cex=1.1)
barplot(as.matrix(mobility_dus[1:3,2:ncol(mobility_dus)]),beside=TRUE,space=c(0,1),legend.text=unlist(mobility_dus[1:3,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(3,"Set1"), main="Sustainable Mobility by Neighbourhood Type: DUS",ylim=c(-1.2,1.2), las=2)
barplot(as.matrix(mobility_myear[2:ncol(mobility_myear)]),beside=TRUE,space=c(0,1),legend.text=unlist(mobility_myear[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Sustainable Mobility by Neighbourhood Type: period",ylim=c(-1,3), las=2)
barplot(as.matrix(mobility_named[2:ncol(mobility_named)]),beside=TRUE,space=c(0,1),legend.text=unlist(mobility_named[1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Sustainable Mobility by Neighbourhood Type: reference",ylim=c(-1,3), las=2)

# make charts for urban form variables
urbanformpatterns <- urbanform_data

#join urban form types
urbanformpatterns <- merge(urbanformpatterns, data.frame(urbanform[1],urbanform[(ncol(urbanform)-3):ncol(urbanform)]), by = "pcode")
urbanform_dus <- aggregate(urbanformpatterns[2:17], list(neighbourhood_type = urbanformpatterns$type_9a_dus), mean,na.action = na.omit)[c(1,4,2,3),]
urbanform_myear <- aggregate(urbanformpatterns[2:17], list(neighbourhood_type = urbanformpatterns$type_9b_myear), mean,na.action = na.omit)[c(4,1,2,3),]
urbanform_named <- aggregate(urbanformpatterns[2:17], list(neighbourhood_type = urbanformpatterns$type_9b_newname), mean,na.action = na.omit)[c(4,2,3,1),]

par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(1.5,0.25,0.25,0.25), ps=10, cex=1.1)
barplot(as.matrix(urbanform_dus[1:3,2:ncol(urbanform_dus)]),beside=TRUE,space=c(0,1),legend.text=unlist(urbanform_dus[1:3,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(3,"Set1"), main="Urban Form by Neighbourhood Type: DUS",ylim=c(-1,2), las=2)
barplot(as.matrix(urbanform_myear[2:ncol(urbanform_myear)]),beside=TRUE,space=c(0,1),legend.text=unlist(urbanform_myear[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Urban Form by Neighbourhood Type: period",ylim=c(-2,4), las=2)
barplot(as.matrix(urbanform_named[2:ncol(urbanform_named)]),beside=TRUE,space=c(0,1),legend.text=unlist(urbanform_named[1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Urban Form by Neighbourhood Type: reference",ylim=c(-2,4), las=2)

# make charts for socio-economic variables
sociopatterns <- socioeconomic_data

#join urban form types
sociopatterns <- merge(sociopatterns, data.frame(urbanform[1],urbanform[(ncol(urbanform)-3):ncol(urbanform)]), by = "pcode")
socio_dus <- aggregate(sociopatterns[2:17], list(neighbourhood_type = sociopatterns$type_9a_dus), mean,na.action = na.omit)[c(1,4,2,3),]
socio_myear <- aggregate(sociopatterns[2:17], list(neighbourhood_type = sociopatterns$type_9b_myear), mean,na.action = na.omit)[c(4,1,2,3),]
socio_named <- aggregate(sociopatterns[2:17], list(neighbourhood_type = sociopatterns$type_9b_newname), mean,na.action = na.omit)[c(4,2,3,1),]

par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(1.5,0.25,0.25,0.25), ps=10, cex=1.1)
barplot(as.matrix(socio_dus[1:3,2:ncol(socio_dus)]),beside=TRUE,space=c(0,1),legend.text=unlist(socio_dus[1:3,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(3,"Set1"), main="Socio-economic character by Neighbourhood Type: DUS",ylim=c(-1,2), las=2)
barplot(as.matrix(socio_myear[2:ncol(socio_myear)]),beside=TRUE,space=c(0,1),legend.text=unlist(socio_myear[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Socio-economic character by Neighbourhood Type: period",ylim=c(-2,4), las=2)
barplot(as.matrix(socio_named[2:ncol(socio_named)]),beside=TRUE,space=c(0,1),legend.text=unlist(socio_named[1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Socio-economic character by Neighbourhood Type: reference",ylim=c(-2,4), las=2)


##### 4. correlation with modality ####
# (instead of urban form)

#descriptive statistics of indicators
descriptive_modality <- as.data.frame(round(psych::describe(modality[,2:ncol(modality)]),digits=2))
descriptive_modality$gini <- round(apply(modality[,2:ncol(modality)],2,Gini),digits=4)
View(descriptive_modality)

#correlogram
travelpatterns_rmatrix <- round(rcorr(as.matrix(travelpatterns_data[,c(2:23,56:83)]))$r,digits=3)
travelpatterns_r2matrix <- round((rcorr(as.matrix(travelpatterns_data[,c(2:23,56:83)]))$r)^2,digits=3)
travelpatterns_pmatrix <- round(rcorr(as.matrix(travelpatterns_data[,c(2:23,56:83)]))$P,digits=5)

par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(travelpatterns_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=travelpatterns_pmatrix, sig.level=0.01)
corrplot(travelpatterns_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=travelpatterns_pmatrix, insig = "p-value", sig.level=-1)

#same charts as above of urban form
modalitypatterns <- modality_data
#join urban form types
modalitypatterns <- merge(modalitypatterns, data.frame(urbanform[1],urbanform[,(ncol(urbanform)-3):ncol(urbanform)]), by = "pcode")
modality_dus <- aggregate(modalitypatterns[2:29], list(neighbourhood_type = modalitypatterns$type_9a_dus), mean,na.action = na.omit)[c(1,4,2,3),]
modality_myear <- aggregate(modalitypatterns[2:29], list(neighbourhood_type = modalitypatterns$type_9b_myear), mean,na.action = na.omit)[c(4,1,2,3),]
modality_named <- aggregate(modalitypatterns[2:29], list(neighbourhood_type = modalitypatterns$type_9b_newname), mean,na.action = na.omit)[c(4,2,3,1),]

par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(3,0.5,0.25,0.25), ps=10, cex=1.1)
barplot(as.matrix(modality_dus[1:3,2:ncol(modality_dus)]),beside=TRUE,space=c(0,1),legend.text=unlist(modality_dus[1:3,1]),args.legend=list(bty="n",horiz=TRUE,cex=0.7),
        col=brewer.pal(3,"Set1"), main="Modality by Neighbourhood Type: DUS",ylim=c(-1,2), las=2)
barplot(as.matrix(modality_myear[2:ncol(modality_myear)]),beside=TRUE,space=c(0,1),legend.text=unlist(modality_myear[,1]),args.legend=list(bty="n",horiz=TRUE,cex=0.7),
        col=brewer.pal(4,"Set1"), main="Modality by Neighbourhood Type: period",ylim=c(-2,4), las=2)
barplot(as.matrix(modality_named[2:ncol(modality_named)]),beside=TRUE,space=c(0,1),legend.text=unlist(modality_named[1]),args.legend=list(bty="n",horiz=TRUE,cex=0.7),
        col=brewer.pal(4,"Set1"), main="Modality by Neighbourhood Type: reference",ylim=c(-2,4), las=2)


##### 5. Visualise relevant scatterplot shapes from correlation ####

# verify triangle in rail centrality vs share plot. it IS confirmed... ufff! EXPLORE
tt<-subset(travelpatterns,rail_1600_count>0)
with(tt,plot(rail_angular_seg_close_1600_mean,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Rail station centrality"))
with(tt,smoothScatter(rail_angular_seg_close_1600_mean,train,ylab="Rail journeys %",xlab="Rail station centrality"))

#rail travel and distance to station
with(tt,plot(rail_metric_dist,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Network distance to rail station"))
with(travelpatterns,plot(rail_metric_dist,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Network distance to rail station"))
tt<-subset(travelpatterns,rail_metric_dist<10000)
with(tt,plot(rail_metric_dist,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Network distance to rail station"))
tt<-subset(travelpatterns,rail_metric_dist<2000)
with(tt,plot(rail_metric_dist,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Network distance to rail station"))
tt<-subset(travelpatterns,rail_metric_dist>=2000 & rail_metric_dist<10000)
with(tt,plot(rail_metric_dist,train,pch=19,cex=0.5,ylab="Rail journeys %",xlab="Network distance to rail station"))

#rail travel and number of stations
with(travelpatterns,plot(rail_1600_count,train,pch=19,cex=0.5))

#the same for local transit - EXPLORE
plot_data<-subset(travelpatterns,localtransit_800_count>0)
with(plot_data,plot(transit_angular_seg_close_800_mean,tram+bus,pch=19,cex=0.5,ylab="Local transit journeys %",xlab="Local transit stop centrality"))

#somehow transit is related to cycle path length...
plot_data <- subset(travelpatterns,travelpatterns$bicycle_800_size>0)
with(plot_data,plot(bicycle_800_size,cycle,pch=19,cex=0.5,ylab="Bike journeys %",xlab="Length of bike lanes within 800m"))
with(plot_data,plot(log(bicycle_800_size),transit,pch=19,cex=0.5))
with(plot_data,plot(bicycle_angular_betw_800,cycle,pch=19,cex=0.5))
#but nothing here
plot_data <- subset(travelpatterns,travelpatterns$bicycle_angular_betw_800>0)
with(plot_data,plot(bicycle_angular_betw_800,cycle,pch=19,cex=0.5))
with(plot_data,plot(bicycle_angular_betw_800,short_car,pch=19,cex=0.5))

#nothing here
plot_data <- subset(travelpatterns,travelpatterns$car_angular_betw_800>0)
plot(plot_data$car_angular_betw_800,plot_data$cycle)
plot(plot_data$car_angular_betw_800,plot_data$short_car)
plot(plot_data$car_angular_betw_800,plot_data$medium_car)
plot(plot_data$car_angular_betw_800,plot_data$far_car)
plot(plot_data$car_angular_betw_800,plot_data$car)

#nor here
plot_data <- subset(travelpatterns,travelpatterns$main_angular_betw_800>0)
plot(plot_data$main_angular_betw_800,plot_data$cycle)
plot(plot_data$main_angular_betw_800,plot_data$short_car)
plot(plot_data$main_angular_betw_800,plot_data$medium_car)
plot(plot_data$main_angular_betw_800,plot_data$far_car)
plot(plot_data$main_angular_betw_800,plot_data$car)


##### 7. Exploration of mobility and modality types ####

travelpatterns <- travelpatterns_data[,1:69]

# classify the variables with natural breaks using hierarchichal clustering
for (i in 1:22){
    if (i %in% c(3:11,15:20)) n <- 4
    if (i %in% c(1,2,12:14,21)) n <- 5
    breaks <- classIntervals(travelpatterns[,i+8],n=n,style="hclust")$brks
    travelpatterns$new <- cut(travelpatterns[,i+8],breaks,right=FALSE,include.lowest=TRUE,labels=c(1:n))
    colnames(travelpatterns)[ncol(travelpatterns)] <- paste("h",colnames(travelpatterns)[i+8],sep="_")
}

#load modality data
modality_data <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful_clusters")
modality_data <- modality_data[,1:86]

#join mobility and modality data
travelform_data <- merge(travelpatterns,modality_data,by="pcode")

#add complete data to database
output<-"travelform_patterns_data"
if(dbExistsTable(con,c("analysis",output))){
    dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),travelform_data) 

travelform_data  <- dbGetQuery(con,"SELECT * FROM analysis.travelform_patterns_data")


# Mosaic plots of modality per mobility attribute
agg_data <- travelform_data[,c(70:91,135)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
agg_data <- agg_data[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
# make plot for each mobility characteristic
par(mfrow=c(11,2),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=15)
for (j in 1:(ncol(agg_data)-1)){
    x <- table(agg_data[,c(ncol(agg_data),j)])
    mosaicplot(x,shade=T,main=colnames(agg_data)[j],xlab="",ylab="")
}
# make plot for each modality type
par(mfrow=c(8,2),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=15)
for (j in 1:15){
    sub_data <- subset(agg_data, agg_data[,ncol(agg_data)]==j)
    x <- table(stack(sub_data, select =-21)[,c(2,1)])
    mosaicplot(x,shade=T,main=paste("modality type ",j),xlab="",ylab="")
}

# boxplots of modality per mobility attribute
agg_data <- travelform_data[,c(70:91,135)]
#agg_data <- data.frame(apply(mobility[,4:23],2,scale01))
#agg_data$modal_k15 <- mobility$modal_k15
par(mfrow=c(5,4),mai=c(0.25,0.25,0.25,0.25), omi=margins)
for (i in 1:(ncol(agg_data)-1)){
    boxplot(agg_data[,i]~agg_data$modal_k15,col=modalitypal,main=colnames(agg_data)[i],ylim=c(0,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
    abline(h=0,col="black",lty=3)
    if (i <= 16) axis(side=1,at=c(1:15),labels=FALSE)
    if (i > 16) axis(side=1,at=c(1:15))
    axis(side=2, labels=TRUE)
}
title("Position of modality types in each mobility variable",outer=TRUE)

# plots of neighbourhoods per mobility attribute, coloured by modality type
travelform_data <- travelpatterns
plot_data <- travelform_data[,c(9:30,135)]
#re-order columns for better visualisation
plot_data$transit <- as.numeric(plot_data$bus)+as.numeric(plot_data$tram)
plot_data <- plot_data[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
mobil <- colnames(plot_data)[1:20]
for (i in 1:length(mobil)){
    png(paste0(output_folder,"randstad_mobility_",mobil[i],".png"), width = 1024, height = 600)
    par(mfrow=c(1,1),mai=c(1,1,1,1), omi=margins, cex=1.2)
    data <- plot_data[order(-plot_data[i]),]
    plot(data[,i], pch=16, cex=0.5, ylab=mobil[i],col=modalitypal[data[,21]], main="Randstad neighbourhoods")
    dev.off()    
}
# now showing each modality at a time!
for (i in 1:length(mobil)){
    for (j in 1:15){
        png(paste0(output_folder,"randstad_",mobil[i],"_modality_",j,".png"), width = 1024, height = 600)
        par(mfrow=c(1,1),mai=c(1,1,1,1), omi=margins)
        data <- plot_data[order(-plot_data[i]),]
        colours <- rep (alphacol("grey",30),15)
        colours[j] <- modalitypal[j]
        plot(data[,i], pch=16, cex=1.5, ylab=mobil[i],col=colours[data[,21]], main=paste0("Randstad type ",j," neighbourhoods"))
        dev.off()
    }
}

# descriptive stats of mobility per modality
agg_data <- travelform_data[,c(9:30,135)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
agg_data$transit <- as.numeric(agg_data$bus)+as.numeric(agg_data$tram)
agg_data <- agg_data[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]

#first version, repeat code, limited stats
modality_mobility <- as.data.frame(matrix(data=NA,16*4,ncol(agg_data)+1,byrow=FALSE))
colnames(modality_mobility) <- c("type","stat",colnames(agg_data)[1:(ncol(agg_data)-1)])
#add the mean values, then the same for median, min and max
curr_row <- 1
modality_mobility[curr_row,] <- c("Randstad","mean",round(apply(agg_data[,1:(ncol(agg_data)-1)],2,mean),digits=2))
result <- aggregate(agg_data[,1:(ncol(agg_data)-1)],by=list(agg_data[,"modal_k15"]),FUN=mean)
for (j in 1:15) modality_mobility[curr_row+j,] <- c(paste("type_",j,sep=""),"mean",round(result[j,2:ncol(agg_data)],digits=2))
curr_row <- curr_row+j

#iterative code:
#another option was to use the fivenum function
#or use full descriptive stats functions
#but some stats return no values and the thing can get too complicated again
result_rand <- Hmisc::describe(agg_data[,1:(ncol(agg_data)-1)])
result_mod <- aggregate(agg_data[,1:(ncol(agg_data)-1)],by=list(agg_data[,"modal_k15"]),FUN=Hmisc::describe)
stats <- c("mean","min","max",names(result_rand[[1]]$counts[5:11]))

#or a custum function based on quantiles
dstats <- function(x){
    mean <- mean(x)
    min <- min(x)
    median <- median(x)
    max <- max(x)
    q <- quantile(x, probs = c(5,10,25,75,90,95)/100, type=8)
    return (c(mean=mean, min=min, median=median, max=max, q[1], q[2], q[3], q[4], q[5], q[6]))  
}

result_rand <- apply(agg_data[,1:(ncol(agg_data)-1)],2,dstats)
result_mod <- aggregate(agg_data[,1:(ncol(agg_data)-1)], by=list(agg_data[,"modal_k15"]),FUN=dstats)
stats <- rownames(result_rand)

modality_mobility <- as.data.frame(matrix(data=NA,16*length(stats),ncol(agg_data)+1,byrow=FALSE))
colnames(modality_mobility) <- c("type","stat",colnames(agg_data)[1:(ncol(agg_data)-1)])

#add the values
for (i in 1:length(stats)){
    for (j in 1:16){
        currow <- j+(16*(i-1))
        if (j==1){
            modality_mobility[currow,] <- c("Randstad",stats[i],round(result_rand[i,],2))
        }else{
            modality_mobility[currow,1] <- paste("type_",j-1,sep="")
            modality_mobility[currow,2] <- stats[i]
            for (k in 2:(ncol(agg_data))) modality_mobility[currow,k+1] <- as.numeric(round(result_mod[j-1,k][i],2))
        }
    }
}

# output file with all the data for exploration in Excel
write.table(modality_mobility, "~/Copy/PhD/Thesis_work/analysis/modality_mobility_descriptive.txt", sep="\t")

# descriptive stats of mobility per modality only for socio-economic group 2
#mean values of clusters
agg_data <- subset(travelform_data, travelform_data$socio_k8==2)[,c(9:30,135)]
agg_data$transit <- as.numeric(agg_data$bus)+as.numeric(agg_data$tram)
agg_data <- agg_data[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]

result_rand <- apply(agg_data[,1:(ncol(agg_data)-1)],2,dstats)
result_mod <- aggregate(agg_data[,1:(ncol(agg_data)-1)], by=list(agg_data[,"modal_k15"]),FUN=dstats)
stats <- rownames(result_rand)
mods <- nrow(result_mod)+1

modality_mobility_t2 <- as.data.frame(matrix(data=NA,mods*length(stats),ncol(agg_data)+1,byrow=FALSE))
colnames(modality_mobility_t2) <- c("type","stat",colnames(agg_data)[1:(ncol(agg_data)-1)])

#add the values
for (i in 1:length(stats)){
    for (j in 1:mods){
        currow <- j+(mods*(i-1))
        if (j==1){
            modality_mobility_t2[currow,] <- c("Randstad",stats[i],round(result_rand[i,],2))
        }else{
            modality_mobility_t2[currow,1] <- paste("type_",result_mod[[1]][j-1],sep="")
            modality_mobility_t2[currow,2] <- stats[i]
            for (k in 2:(ncol(agg_data))) modality_mobility_t2[currow,k+1] <- round(result_mod[j-1,k][i],2)
        }
    }
}

# output file with all the data for exploration in Excel
write.table(modality_mobility_t2, "~/Copy/PhD/Thesis_work/analysis/modality_mobility_t2_descriptive.txt", sep="\t")


##### 8. Visualising the descriptive stats ####
# in mobility potential charts 
# one chart for each modality type (excluding outlier types)

#function to add alpha value to standard R colours
alphacol <- function(colour,a){rgb(col2rgb(colour)[1],col2rgb(colour)[2],col2rgb(colour)[3],alpha=a,max=255)}

#my chosen palettes
#for mobility is a colour for each variable group:
mobilitypal <- list(mode=c("Walk","Bicycle","Car","Local transit","Rail","All"),
                    line=c("blue1","orange1","black","green1","red1","yellow1"), 
                    fill=c(alphacol("blue",50),alphacol("orange",50),alphacol("black",50),alphacol("green",50),alphacol("red",50),alphacol("yellow",50)))
mobvarspalalpha <- c(rep(alphacol("blue",90),2),rep(alphacol("orange",90),3),rep(alphacol("black",90),6),rep(alphacol("green",90),2),rep(alphacol("red",90),4),rep(alphacol("yellow",90),3))
mobvarspal <- c(rep("blue1",2),rep("orange1",3),rep("darkgrey",6),rep("green1",2),rep("red1",4),rep("yellow1",3))
modalitypal <- c("red1","green1","dodgerblue3","orange1","green4","wheat2","purple1","deepskyblue1","magenta","cyan1","yellow1","brown","mediumpurple","plum1","grey30","black","black","black","black")
randstadpal <- c("gray30","gray70","gray90")
randstadpal_light <- c("gray60","gray70",alphacol("gray70",50))
socio2pal <- c("red1","red2",alphacol("red2",50))

#for the charts the values must be plotted between 0 - 100%, and 0 - 7 for journeys
plotdata_rand <- subset(modality_mobility, modality_mobility$type=="Randstad")[,3:22]
plotdata_rand <- apply(plotdata_rand,2,as.numeric)
plotdata_rand[,20] <- plotdata_rand[,20]*14.28

#randastad mobility ranges/culture. base plot for other charts
randstad_baseplot <- function(title,pal,limits,avg,lines){
    par(mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
    plot(plotdata_rand[1,],type="l",ylim=c(0,100),main=title,axes=F,xlab="",ylab="% Share / Distance km",lwd=0)
    polygon(c(1:20,20:1),c(plotdata_rand[limits[2],1:20],plotdata_rand[limits[1],20:1]),col=pal[3],border=pal[2])
    axis(side=1, at=c(1:ncol(plotdata_rand)),labels=colnames(plotdata_rand),las=2)
    axis(side=2, labels=TRUE)
    #
    coord <- par("usr")
    rect(coord[1],coord[3],2.5,coord[4],border=mobilitypal$line[1],lwd=1)
    rect(2.5,coord[3],5.5,coord[4],border=mobilitypal$line[2],lwd=1)
    rect(5.5,coord[3],11.5,coord[4],border=mobilitypal$line[3],lwd=1)
    rect(11.5,coord[3],13.5,coord[4],border=mobilitypal$line[4],lwd=1)
    rect(13.5,coord[3],17.5,coord[4],border=mobilitypal$line[5],lwd=1)
    rect(17.5,coord[3],coord[2],coord[4],border=mobilitypal$line[6],lwd=1)
    #
    lines(plotdata_rand[avg,],lwd=2,col=pal[1])
    mtext(side=4,at=plotdata_rand[avg,20],text=stats[avg],col=pal[1],las=2)
    if (length(lines) > 0){
        for (i in lines){
            lines(plotdata_rand[i,],lwd=1,col=pal[2])
            mtext(side=4,at=plotdata_rand[i,20],text=stats[i],col=pal[1],las=2)
        }
    }
    grid(nx=NA,ny=NULL)
    mtext(side=4,at=plotdata_rand[limits[1],20],text=stats[limits[1]],col=pal[1],las=2)
    mtext(side=4,at=plotdata_rand[limits[2],20],text=stats[limits[2]],col=pal[1],las=2)
}
randstad_baseplot("Randstad mobility range",randstadpal,c(4,2),1,c())

# now add the filter of socio-economic type 2: young middle class families with children and cars
plotdata_t2 <- subset(modality_mobility_t2, modality_mobility_t2$type=="Randstad")[,3:22]
plotdata_t2 <- apply(plotdata_t2,2,as.numeric)
plotdata_t2[,20] <- plotdata_t2[,20]*14.28

randstad_baseplot("Randstad mobility with socio-economic type 2 overlay",randstadpal,randstadpal,c(10,5),1,c(2,4))
polygon(c(1:20,20:1),c(plotdata_t2[8,1:20],plotdata_t2[3,20:1]),col=socio2pal[3],border=socio2pal[2])
lines(plotdata_t2[1,],lwd=2,col=socio2pal[1])
for (i in c(2,9)) lines(plotdata_t2[i,],lwd=1,col=socio2pal[2])
legend("topright",legend=c("Randstad","Socio T2"),lty=1,lwd=2,col=c(randstadpal[1],socio2pal[1]),horiz=T,bty="n",cex=0.8)

#the same can be done for every modality environment type
for (i in 1:15){
    plotdata <- subset(modality_mobility, modality_mobility$type==paste("type_",i,sep=""))[,3:22]
    plotdata <- apply(plotdata,2,as.numeric)
    plotdata[,20] <- plotdata[,20]*14.28
    
    #chart settings
    limits <- c(10,5) #use 5% and 95% for solid band
    med <- 1 #use mean as central line
    lines <- c(2,4) #use min and max as other lines
    randstad_baseplot(paste("Randstad mobility with modality type ",i," overlay",sep=""),randstadpal_light,limits,med,lines)
    #randstad_baseplot(paste("Randstad mobility with modality type ",i," overlay",sep=""),randstadpal_light,c(4,2),1,c())
    polygon(c(1:20,20:1),c(plotdata[limits[1],1:20],plotdata[limits[2],20:1]),col=alphacol(modalitypal[i],50),border=modalitypal[i])
    lines(plotdata[med,],lwd=2,col=modalitypal[i])
    for (j in lines) lines(plotdata[j,],lwd=0.7,col=modalitypal[i])
    legend("topright",legend=c("Randstad",paste("Modality T",i,sep="")),lty=1,lwd=2,col=c(randstadpal_light[1],modalitypal[i]),horiz=T,bty="n",cex=0.8)
}

###
#now visualise the individual modality environments in relation to the randstad range
#data can be scaled between -1 and 1 and centered on the Randstad mean in the 0 position,
#the range is not maxed like in most parallel plots.
splotdata <- data.frame(pcode=mon_data$pcode,scale(mon_data[2:ncol(mon_data)],center=TRUE,scale=FALSE))
splotdata <- data.frame(pcode=smon_data$pcode,apply(smon_data[2:ncol(mon_data)],2,function(x)round(x*(1/max(abs(max(x)),abs(min(x)))),4)))

#But it's not necessarily relevant to keep the Randstad baseline reference, 
#can simply scale between 0 and 1 thus removing the Randstad 'signature'.
#The goal is to distinguish the mobility fingerprint of modality types, setting bounds for potential mobility
#this is an alternative, goes between 0 and 1, with the Randstad mean shifting. There is always a max and min for every variable.
modality_mobility[,3:22] <- apply(modality_mobility[,3:22],2,as.numeric)
smodality_mobility <- data.frame(type=modality_mobility$type,stat=modality_mobility$stat,apply(modality_mobility[,3:22],2,function(x)round((x-min(x))/(max(x)-min(x)),4)))

#now some experiments with radial plots
grouplabels <- c("","walk","","cycle","","","","","car","","","transit","","","train","","","mean dist","mean dist/pers","journeys/pers")

#This gives small identifying "finger prints"
plotdata <- subset(smodality_mobility, smodality_mobility$stat=="mean")[2:16,3:22]
stars(plotdata,scale=T,draw.segments=T,labels=c(1:15),col.segments=mobvarspal,main="Modality types: mean mobility profile",key.loc=c(12,2),key.labels=grouplabels)
stars(plotdata,scale=T,draw.segments=T,labels=c(1:15),col.segments=mobvarspal,main="Modality types: mean mobility profile",key.loc=c(12,2))
stars(plotdata,scale=T,draw.segments=T,labels=c(1:15),col.segments=mobvarspalalpha,main="Modality types: mean mobility profile",key.loc=c(12,2),key.labels=grouplabels)
stars(plotdata,scale=T,labels=c(1:15),col.stars=modalitypal,main="Modality types: mean mobility profile",key.loc=c(12,2),key.labels=grouplabels)
stars(plotdata,scale=T,labels=c(1:15),col.stars=modalitypal,main="Modality types: mean mobility profile",key.loc=c(12,2))

#This gives a more detailed mobility potential for a given modality type
#on this one can overlay a TOD mobility profile to evaluate performance
for (i in 1:15){
    plotdata <- subset(modality_mobility, modality_mobility$type==paste("type_",i,sep=""))[,3:22]
    plotdata <- apply(plotdata,2,as.numeric)
    plotdata[,20] <- plotdata[,20]*14.28
    
    #chart settings
    limits <- c(10,5) #use 5% and 95% for solid band
    med <- 1 #use mean as central line
    lines <- c(2,4) #use min and max as other lines
    randstad_baseplot(paste("Randstad mobility with modality type ",i," overlay",sep=""),randstadpal_light,limits,med,lines)
    #randstad_baseplot(paste("Randstad mobility with modality type ",i," overlay",sep=""),randstadpal_light,c(4,2),1,c())
    polygon(c(1:20,20:1),c(plotdata[limits[1],1:20],plotdata[limits[2],20:1]),col=alphacol(modalitypal[i],50),border=modalitypal[i])
    lines(plotdata[med,],lwd=2,col=modalitypal[i])
    for (j in lines) lines(plotdata[j,],lwd=0.7,col=modalitypal[i])
    legend("topright",legend=c("Randstad",paste("Modality T",i,sep="")),lty=1,lwd=2,col=c(randstadpal_light[1],modalitypal[i]),horiz=T,bty="n",cex=0.8)
}

typedata <- subset(smodality_mobility, smodality_mobility$type=="type_1")[,1:22]
plotdata <- subset(typedata, typedata$stat=="max")[,3:22]
stars(plotdata,scale=F,labels=c(rep("",15)),draw.segments=T,col.segments=c(rep("white",20)))
plotdata <- subset(typedata, typedata$stat=="95%")[,3:22]
stars(plotdata,scale=F,add=T,draw.segments=T,labels=c(rep("",15)),col.segments=mobvarspalalpha)
plotdata <- subset(typedata, typedata$stat=="75%")[,3:22]
stars(plotdata,scale=F,add=T,draw.segments=T,labels=c(rep("",15)),col.segments=mobvarspalalpha,lwd = 1)
#plotdata <- subset(typedata, typedata$stat=="mean")[,3:22]
#stars(plotdata,scale=F,add=T,draw.segments=T,labels=c(rep("",15)),col.segments=mobvarspalalpha,lwd = 2)
plotdata <- subset(typedata, typedata$stat=="25%")[,3:22]
stars(plotdata,scale=F,add=T,labels=c(rep("",15)),draw.segments=T,col.segments=c(rep("white",20)),lwd = 1)
plotdata <- subset(typedata, typedata$stat=="25%")[,3:22]
stars(plotdata,scale=F,add=T,labels=c(rep("",15)),draw.segments=T,col.segments=mobvarspalalpha,lwd = 1)
plotdata <- subset(typedata, typedata$stat=="5%")[,3:22]
stars(plotdata,scale=F,add=T,labels=c(rep("",15)),draw.segments=T,col.segments=c(rep("white",20)))
plotdata <- subset(typedata, typedata$stat=="min")[,3:22]
stars(plotdata,scale=F,add=T,labels=c(rep("",15)),draw.segments=T,col.segments=c(rep("white",20)))

plotdata <- subset(typedata, typedata$stat=="mean")[,3:22]
stars(plotdata,scale=F,add=T,draw.segments=F,labels=c(rep("",15)),col.lines=modalitypal[1],lwd = 2)

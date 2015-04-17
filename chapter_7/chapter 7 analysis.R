#Statistical analysis of urban form and travel framework

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc")
library("RColorBrewer")

# some constants
def.par <- par(no.readonly = TRUE)
margins <- c(0.25,0.25,0.25,0.25)
bins <- pretty(range(c(0, 100)), n=21)
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)
output_folder <- "~/_TEMP/R/"
quants <- c(5,10,25,75,90,95)
coord <- par("usr")
stats <- c("mean", "min", "median", "max", "5%", "10%", "25%", "75%", "90%", "95%")

##### utility functions ####
# function to add alpha value to standard R colours
alphacol <- function(colour,a){rgb(col2rgb(colour)[1],col2rgb(colour)[2],col2rgb(colour)[3],alpha=a,max=255)}
# scale given object's values between 0 and 1
scale01 <- function(x){(x-min(x))/(max(x)-min(x))}
dstats <- function(x){
    mean <- mean(x)
    sd <- sd(x)
    min <- min(x)
    median <- median(x)
    max <- max(x)
    q <- quantile(x, probs = c(5,10,25,75,90,95)/100, type=8)
    gini <- Gini(x)
    qcd <- (d[4]-d[3])/(d[4]+d[3])
    cv <- sd/mean
    return (c(mean=mean, min=min, median=median, max=max, q[1], q[2], q[3], q[4], q[5], q[6], gini=gini, qcd=qcd, cv=cv))  
}


##### getting the data sets #####
# connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

# get full socio-economic data set
fullsocio <- dbGetQuery(con,"SELECT * FROM analysis.socio_economic_individuals_pcode_clusters")

# get full urban form data set
fullmodality <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful_clusters")

# get VINEX/TOD neighbourhoods
vinex <- dbGetQuery(con,"SELECT pcode, randstad_code, neighbourhood_type, neighbourhood_name
                  FROM survey.sampling_points WHERE neighbourhood_type='VINEX'")
tod <- dbGetQuery(con,"SELECT pcode, randstad_code, neighbourhood_type, neighbourhood_name
                  FROM survey.sampling_points WHERE neighbourhood_type='VINEX' OR neighbourhood_type='TOD'") 

# get the rest of the analysis data
travelpatterns <- dbGetQuery(con,"SELECT * FROM analysis.travelform_patterns_data;")
# geometry doesn't cause an error any more, only a warning. great!
travelpatterns_t2 <- subset(travelpatterns, socio_k8==2)

# mobility data for plots
mobility <- travelpatterns[,c(9:30,135)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
mobility$transit <- as.numeric(mobility$bus)+as.numeric(mobility$tram)
mobility <- mobility[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
mobility <- cbind(travelpatterns[,c(1,176,177)],mobility)
mobility <- cbind(mobility,travelpatterns[,c(50:52)])
# remaining data from full set
modality <- travelpatterns[,c(1,176,177,92:127,135,50:52)]
form <- travelpatterns[,c(1,176,177,32:52)]
socio <- travelpatterns[,c(1,176,177,53:69,50:52)]

journeys <- dbGetQuery(con,"SELECT (afstr*100) distance, rrsdduur duration, kmotief purpose,
aankbzh activity, mode_leg as mode, mode_main, pcode, home_pcode, agg_pcode, mm_code FROM survey.randstad_journeys WHERE agg_pcode = home_pcode AND home_pcode IN (SELECT pcode FROM survey.sampling_points)")


########
# some basic stats for console output... no patience to produce a nice data frame
quantile(subset(journeys,mode ==1)$distance, probs=c(25,30,35,40,50,75,85,90,95,99)/100, type=8)
quantile(subset(journeys,mode ==2)$distance, probs=c(25,30,35,40,50,75,85,90,95,99)/100, type=8)
quantile(subset(journeys,mode ==6)$distance, probs=c(25,30,35,40,50,75,85,90,95,99)/100, type=8)
quantile(subset(journeys,mode ==7)$distance, probs=c(5,8,10,25,30,35,40,50,75,85,90,95,99)/100, type=8)
quantile(subset(journeys,mode ==5)$distance, probs=c(5,7,10,25,30,35,40,50,55,60,65,75,85,90,95,99)/100, type=8)
quantile(subset(journeys,mode ==3)$distance, probs=c(5,7,10,25,30,35,40,50,55,60,65,75,85,90,95,99)/100, type=8)
median(subset(journeys,mode ==1)$distance)
median(subset(journeys,mode ==2)$distance)
median(subset(journeys,mode ==3)$distance)
median(subset(journeys,mode ==4)$distance)
median(subset(journeys,mode ==5)$distance)
median(subset(journeys,mode ==6)$distance)
median(subset(journeys,mode ==7)$distance)
mean(subset(journeys,mode ==7)$distance)
mean(subset(journeys,mode ==6)$distance)
mean(subset(journeys,mode ==5)$distance)
mean(subset(journeys,mode ==4)$distance)
mean(subset(journeys,mode ==3)$distance)
mean(subset(journeys,mode ==2)$distance)
mean(subset(journeys,mode ==1)$distance)

# desc stats to include:
# mean, median, standard deviation, coficient of variation, quartile coefficient of dispersion

#### Mobility overview ####
# For the Randstad and all VINEX
#
# calculate quartile coefficient of dispersion
qcd <- function(x){
    q <- quantile(x, probs = c(25,75)/100, type=8)
    qcd <- (q[2]-q[1])/(q[2]+q[1])
    return (qcd)
}
# calculate potential based on iqr
potential <- function(x){
    q <- quantile(x, probs = c(25,75)/100, type=8)
    iqr <- q[2]-q[1]
    low <- q[1]-(1.5*iqr)
    pot_low <- max(low,min(x))
    high <- q[2]+(1.5*iqr)
    pot_high <- min(high,max(x))
    return (c(pot_low=pot_low, pot_high=pot_high))
}

mobil_out <- as.data.frame(sapply(mobility[,4:23],mean, na.rm=TRUE))
colnames(mobil_out) <- ("randstad_mean")
mobil_out$vinex_mean <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23],mean, na.rm=TRUE)
mobil_out$randstad_std <- sapply(mobility[,4:23],sd)
mobil_out$vinex_std <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23],sd)
mobil_out$randstad_median <- sapply(mobility[,4:23],median)
mobil_out$vinex_median <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23],median)
mobil_out$randstad_gini <- sapply(mobility[,4:23],Gini)
mobil_out$vinex_gini <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23],Gini)
mobil_out$randstad_qcd <- sapply(mobility[,4:23],qcd)
mobil_out$vinex_qcd <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23], qcd)
potent <- sapply(mobility[,4:23],potential)
mobil_out$randstad_potlow <- potent[1,]
mobil_out$randstad_pothigh <- potent[2,]
potent <- sapply(subset(mobility,pcode %in% vinex$pcode)[,4:23], potential)
mobil_out$vinex_potlow <- potent[1,]
mobil_out$vinex_pothigh <- potent[2,]


#### Socio economic overview ####
# For the Randstad and each socio type
colnames(fullsocio)
colnames(socio) # used for clustering, no collinearity [,4:19]
socio_out <- as.data.frame(sapply(fullsocio[,5:26],mean, na.rm=TRUE))
colnames(socio_out) <- ("randstad_mean")
socio_out$vinex_mean <- sapply(subset(fullsocio,pcode %in% vinex$pcode)[,5:26],mean, na.rm=TRUE)
socio_out$randstad_median <- sapply(fullsocio[,5:26],median)
socio_out$vinex_median <- sapply(subset(fullsocio,pcode %in% vinex$pcode)[,5:26],median)
socio_out$randstad_gini <- sapply(fullsocio[,5:26],Gini)
socio_out$vinex_gini <- sapply(subset(fullsocio,pcode %in% vinex$pcode)[,5:26],Gini)
socio_out$randstad_qcd <- sapply(fullsocio[,5:26],qcd)
socio_out$vinex_qcd <- sapply(subset(fullsocio,pcode %in% vinex$pcode)[,5:26], qcd)
# socio of each socio type
for (i in 1:8)
{
    socio_out$"new" <- sapply(subset(fullsocio,k_8==i)[,5:26],median)
    colnames(socio_out)[length(socio_out)] <- paste0("socio",i,"_median")
    socio_out$"new" <- sapply(subset(fullsocio,k_8==i)[,5:26],qcd)
    colnames(socio_out)[length(socio_out)] <- paste0("socio",i,"_qcd") 
}

# mobility for each socio type
mobility$socio_k8 <- socio$socio_k8
for (i in 1:8)
{
    mobil_out$"new" <- sapply(subset(mobility,socio_k8==i)[,4:23],mean, na.rm=TRUE)
    colnames(mobil_out)[length(mobil_out)] <- paste0("socio",i,"_mean")
    mobil_out$"new" <- sapply(subset(mobility,socio_k8==i)[,4:23],median)
    colnames(mobil_out)[length(mobil_out)] <- paste0("socio",i,"_median")
    mobil_out$"new" <- sapply(subset(mobility,socio_k8==i)[,4:23],qcd)
    colnames(mobil_out)[length(mobil_out)] <- paste0("socio",i,"_qcd")
    potent <- sapply(subset(mobility,socio_k8==i)[,4:23],potential)
    mobil_out$"new" <- potent[1,]
    colnames(mobil_out)[length(mobil_out)] <- paste0("socio",i,"_potlow")
    mobil_out$"new" <- potent[2,]
    colnames(mobil_out)[length(mobil_out)] <- paste0("socio",i,"_pothigh")
}

#### Urban form and structure overview ####
colnames(fullmodality)
colnames(modality)
#re-order columns for better visualisation
sel_modality <- modality[,c(1,4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:40,44)]

modal_out <- as.data.frame(sapply(sel_modality[,2:26],mean, na.rm=TRUE))
colnames(modal_out) <- ("randstad_mean")
modal_out$vinex_mean <- sapply(subset(sel_modality,pcode %in% vinex$pcode)[,2:26],mean, na.rm=TRUE)
modal_out$randstad_median <- sapply(sel_modality[,2:26],median)
modal_out$vinex_median <- sapply(subset(sel_modality,pcode %in% vinex$pcode)[,2:26],median)
modal_out$randstad_gini <- sapply(sel_modality[,2:26],Gini)
modal_out$vinex_gini <- sapply(subset(sel_modality,pcode %in% vinex$pcode)[,2:26],Gini)
modal_out$randstad_qcd <- sapply(sel_modality[,2:26],qcd)
modal_out$vinex_qcd <- sapply(subset(sel_modality,pcode %in% vinex$pcode)[,2:26], qcd)
# modality of each type
for (i in 1:15)
{
    modal_out$"new" <- sapply(subset(sel_modality,modal_k15==i)[,2:26],median)
    colnames(modal_out)[length(modal_out)] <- paste0("modal",i,"_median")
    modal_out$"new" <- sapply(subset(sel_modality,modal_k15==i)[,2:26],qcd)
    colnames(modal_out)[length(modal_out)] <- paste0("modal",i,"_qcd")
}

# mobilty for each urban form type
for (i in 1:15)
{
    mobil_out$"new" <- sapply(subset(mobility,modal_k15==i)[,4:23],mean, na.rm=TRUE)
    colnames(mobil_out)[length(mobil_out)] <- paste0("modal",i,"_mean")
    mobil_out$"new" <- sapply(subset(mobility,modal_k15==i)[,4:23],median)
    colnames(mobil_out)[length(mobil_out)] <- paste0("modal",i,"_median")
    mobil_out$"new" <- sapply(subset(mobility,modal_k15==i)[,4:23],qcd)
    colnames(mobil_out)[length(mobil_out)] <- paste0("modal",i,"_qcd")
    potent <- sapply(subset(mobility,modal_k15==i)[,4:23],potential)
    mobil_out$"new" <- potent[1,]
    colnames(mobil_out)[length(mobil_out)] <- paste0("modal",i,"_potlow")
    mobil_out$"new" <- potent[2,]
    colnames(mobil_out)[length(mobil_out)] <- paste0("modal",i,"_pothigh")    
}

write.table(mobil_out, paste0(output_folder,"ch8_mobility_potential.txt"), sep="\t")
write.table(socio_out, paste0(output_folder,"ch8_sociotypes_descriptive_.txt"), sep="\t")
write.table(modal_out, paste0(output_folder,"ch8_modaltypes_descriptive.txt"), sep="\t")

#### Mobility potential indicators for socio type 2
types <- c(1,3,4,7,8,9,10)
potential_out <- mobil_out[,0]
for (i in types)
{
    data <- subset(mobility,modal_k15==i & socio_k8==2)[,4:23]
    potential_out$"new" <- sapply(data,mean, na.rm=TRUE)
    colnames(potential_out)[length(potential_out)] <- paste0("modal",i,"_mean")
    potential_out$"new" <- sapply(data,median)
    colnames(potential_out)[length(potential_out)] <- paste0("modal",i,"_median")
    potential_out$"new" <- sapply(data,qcd)
    colnames(potential_out)[length(potential_out)] <- paste0("modal",i,"_qcd")
    potent <- sapply(data,potential)
    potential_out$"new" <- potent[1,]
    colnames(potential_out)[length(potential_out)] <- paste0("modal",i,"_potlow")
    potential_out$"new" <- potent[2,]
    colnames(potential_out)[length(potential_out)] <- paste0("modal",i,"_pothigh")    
}

write.table(potential_out, paste0(output_folder,"ch8_todt2_potential.txt"), sep="\t")


####  Mobility performance indicators
# calculate performance based on potential
performance <- function(x, low, high){
    perform <- (x-low)/(high-low)
    return (perform)
}
adjust_performance <- function(x, low, high){
    if (x<low) x<-low
    if (x>high) x<-high
    perform <- (x-low)/(high-low)
    return (perform)
}
adjust_potential <- function(x){
    q <- quantile(x, probs = c(25,75)/100, type=8)
    iqr <- q[2]-q[1]
    low <- q[1]-iqr
    pot_low <- max(low,min(x))
    high <- q[2]+iqr
    pot_high <- min(high,max(x))
    return (c(pot_low=pot_low, pot_high=pot_high))
}


perform_out <- mobil_out[,0]
# data just for making charts outside, if I feel like it...
perform_iqr_out <- mobil_out[,0]
adjust_perform_out <- mobil_out[,0]
move_out <- mobil_out[,0]
max <- sapply(mobility[,4:23],max)
min <- sapply(mobility[,4:23],min)
for (i in types){
    context <- subset(mobility,modal_k15==i & socio_k8==2)[,c(1,4:23)]
    potent <- sapply(context[,2:21],potential)
    adjust_potent <-  sapply(context[,2:21],adjust_potential)
    for (j in subset(context,pcode %in% vinex$pcode)[,1]){
        case <- subset(context,pcode==j)[,2:21]
        perform_out$"new" <- mapply(performance,case,potent[1,],potent[2,])
        colnames(perform_out)[length(perform_out)] <- paste0(j)
        perform_iqr_out$"new" <- mapply(performance,case,adjust_potent[1,],adjust_potent[2,])
        colnames(perform_iqr_out)[length(perform_iqr_out)] <- paste0(j)
        adjust_perform_out$"new" <- mapply(adjust_performance,case,potent[1,],potent[2,])
        colnames(adjust_perform_out)[length(adjust_perform_out)] <- paste0(j)
        move_out$"new" <- mapply(performance,case,min,max)
        colnames(move_out)[length(move_out)] <- paste0(j)
    }
}
write.table(perform_out, paste0(output_folder,"ch8_todt2_performance.txt"), sep="\t")
write.table(perform_iqr_out, paste0(output_folder,"ch8_todt2_performance_iqr.txt"), sep="\t")
write.table(adjust_perform_out, paste0(output_folder,"ch8_todt2_adjusted_performance.txt"), sep="\t")
write.table(move_out, paste0(output_folder,"ch8_todt2_movement.txt"), sep="\t")




#TOD modality and mobility statistical analysis

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc")
library("RColorBrewer")
library("beeswarm")
#library("ggplot2")
#library("mvoutlier")
#library("pvclust")
#library("cluster") 
#library("fpc")
#library("classInt")

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


##### getting the data sets #####
# connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

# get full socio-economic data set
fullsocio <- dbGetQuery(con,"SELECT * FROM analysis.socio_economic_individuals_pcode_clusters")

# get full modality data set
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

# T2 mobility data for plots
mobility_t2 <- travelpatterns_t2[,c(9:30,135,178)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
mobility_t2$transit <- as.numeric(mobility_t2$bus)+as.numeric(mobility_t2$tram)
mobility_t2 <- mobility_t2[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23,24)]
mobility_t2 <- cbind(travelpatterns_t2[,c(1,176,177,51,52)],mobility_t2)

# get the descriptive stats of mobility per modality type = gives the potential range
modality_mobility <- read.table("~/Copy/PhD/Thesis_work/analysis/modality_mobility_descriptive.txt", sep="\t")
modality_mobility_t2 <- read.table("~/Copy/PhD/Thesis_work/analysis/modality_mobility_t2_descriptive.txt", sep="\t")

# only keep TOD of type 2 cluster (79%) = 48 neighbourhoods
todpatterns <- merge(tod, travelpatterns, by = "pcode")
todpatterns_t2 <- subset(todpatterns, socio_k8==2)

# TOD mobility data for plots (TOD identification missing!!!)
mobility_todt2 <- todpatterns_t2[,c(12:33,138)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
mobility_todt2$transit <- as.numeric(mobility_todt2$bus)+as.numeric(mobility_todt2$tram)
mobility_todt2 <- mobility_todt2[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
mobility_todt2 <- cbind(todpatterns_t2[,c(1,4,179,180)],mobility_todt2)

##### my chosen palettes #####
# for mobility it's a colour for each variable group:
mobilitypal <- list(mode=c("Walk","Bicycle","Car","Local transit","Rail","All"),
                    line=c("blue1","orange1","black","green1","red1","yellow1"), 
                    fill=c(alphacol("blue",50),alphacol("orange",50),alphacol("black",50),alphacol("green",50),alphacol("red",50),alphacol("yellow",50)))
mobvarspalalpha <- c(rep(alphacol("blue",90),2),rep(alphacol("orange",90),3),rep(alphacol("black",90),6),rep(alphacol("green",90),2),rep(alphacol("red",90),4),rep(alphacol("yellow",90),3))
mobvarspal <- c(rep("blue1",2),rep("orange1",3),rep("darkgrey",6),rep("green1",2),rep("red1",4),rep("yellow1",3))
modalitypal <- c("red1","green1","dodgerblue3","orange1","green4","wheat2","purple1","deepskyblue1","magenta","cyan1","yellow1","brown","mediumpurple","plum1","grey30","black","black","black","black")
randstadpal <- c("gray30","gray70","gray90")
randstadpal_light <- c("gray60","gray70",alphacol("gray70",50))
socio2pal <- c("red1","red2",alphacol("red2",50))


##### STEP 0 #####
# Revisiting the base data for the Randstad ####

# full socio-economic description (1053 postcodes)
d <- fullsocio[,c(5:26)]

desc_d <- as.data.frame(round(psych::describe(d),2))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"fullsocio_descriptive.txt"), sep="\t")
#charts
# histograms
png(paste0(output_folder,"fullsocio_histogram.png"), width = 1800, height = 1000)
par(mfrow=c(5,5),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Socio-economic variables distribution", outer=TRUE)
dev.off()

# socio-economic description
d <- data.frame(socio[,2:17])

desc_d <- as.data.frame(round(psych::describe(d),2))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"socio_descriptive.txt"), sep="\t")
#charts
# histograms
png(paste0(output_folder,"socio_histogram.png"), width = 1500, height = 800)
par(mfrow=c(4,4),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}d <- data.frame(form[,2:17])
mtext("Socio-economic variables distribution", outer=TRUE)
dev.off()
# mean barplot by area type
d <- aggregate(scale(socio[4:19]), list(neighbourhood_type = socio$type_9b_myear), mean, na.action = na.omit)[c(4,1,2,3),]
png(paste0(output_folder,"Randstad_socio_barplot_byyear.png"), width = 1500, height = 600)
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(2,0.25,0.5,0.25), ps=12, cex=1.1)
barplot(as.matrix(d[2:ncol(d)]),beside=TRUE,space=c(0,1),legend.text=unlist(d[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Socio-economic profile by Neighbourhood Type: period",ylim=c(-3,3), las=2)
dev.off()
d <- aggregate(socio[4:19], list(neighbourhood_type = socio$type_9b_myear), mean, na.action = na.omit)[c(4,1,2,3),]
png(paste0(output_folder,"Randstad_socio_barplot_byyear_noscale.png"), width = 1500, height = 600)
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(1.5,0.25,0.25,0.25), ps=12, cex=1.1)
barplot(as.matrix(d[2:ncol(d)]),beside=TRUE,space=c(0,1),legend.text=unlist(d[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Socio-economic profile by Neighbourhood Type: period",ylim=c(0,60), las=2)
dev.off()

# mobility description
d <- data.frame(mobility[,4:23])

desc_d <- as.data.frame(round(psych::describe(d),2))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"mobility_descriptive.txt"), sep="\t")
#charts
# histograms
png(paste0(output_folder,"mobility_histogram.png"), width = 1024, height = 600)
par(mfrow=c(5,4),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Mobility variables distribution", outer=TRUE)
dev.off()
# mean barplot by area type
d <- aggregate(scale(mobility[,4:23]), list(neighbourhood_type = mobility$type_9b_myear), mean, na.action = na.omit)[c(4,1,2,3),]
png(paste0(output_folder,"Randstad_mobility_barplot_byyear.png"), width = 1500, height = 600)
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(2,0.25,0.25,0.25), ps=12, cex=1.1)
barplot(as.matrix(d[2:ncol(d)]),beside=TRUE,space=c(0,1),legend.text=unlist(d[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Mobility by Neighbourhood Type: period",ylim=c(-3,3), las=2)
dev.off()

# urban form description
d <- data.frame(form[,4:19])
d[is.na(d)] <- 0
desc_d <- as.data.frame(round(psych::describe(d),2))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"form_descriptive.txt"), sep="\t")
#charts
# histograms
png(paste0(output_folder,"form_histogram.png"), width = 1024, height = 600)
par(mfrow=c(4,4),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Urban form variables distribution", outer=TRUE)
dev.off()
# mean barplot by area type
d <- aggregate(scale(form[,4:19]), list(neighbourhood_type = form$type_9b_myear), mean, na.action = na.omit)[c(4,1,2,3),]
png(paste0(output_folder,"Randstad_form_barplot_byyear.png"), width = 1500, height = 600)
par(mfrow=c(1,1),mai=c(0.25,0.25,1,0.25), omi=c(2,0.25,0.25,0.25), ps=12, cex=1.1)
barplot(as.matrix(d[2:ncol(d)]),beside=TRUE,space=c(0,1),legend.text=unlist(d[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Urban form by Neighbourhood Type: period",ylim=c(-3,3), las=2)
dev.off()

# full modality description (1049 postcodes)
d <- fullmodality[,c(2:37)]
desc_d <- as.data.frame(round(psych::describe(d),6))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),6)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"fullmodality_descriptive.txt"), sep="\t")
# histograms
png(paste0(output_folder,"fullmodality_histogram.png"), width = 1800, height = 1500)
par(mfrow=c(6,6),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Modality variables distribution", outer=TRUE)
dev.off()
# same for no-zero variables
dz <- d
dz[dz == 0] <- NA
desc_d <- as.data.frame(round(psych::describe(dz),6))
desc_d$gini <- round(apply(dz,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(dz,2,quantile,probs = c(i)/100, type=8),6)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"fullmodality_descriptive_nozero.txt"), sep="\t")
# histograms
png(paste0(output_folder,"fullmodality_histogram_nozero.png"), width = 1800, height = 1500)
par(mfrow=c(6,6),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(dz)){
    hist(dz[,i],col=colour,main=colnames(dz)[i],xlab="",ylab="")
}
mtext("Modality variables distribution", outer=TRUE)
dev.off()

# modality description
d <- data.frame(modality[,c(4:31,36:39)])
d[is.na(d)] <- 0
desc_d <- as.data.frame(round(psych::describe(d),2))
desc_d$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    desc_d[,ncol(desc_d)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(desc_d)[ncol(desc_d)] <- paste0(i,"%")
}
write.table(desc_d, paste0(output_folder,"modality_descriptive.txt"), sep="\t")
#charts
# histograms
png(paste0(output_folder,"modality_histogram.png"), width = 1024, height = 1024)
par(mfrow=c(8,4),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Modality variables distribution", outer=TRUE)
dev.off()
# mean barplot by area type
d <- aggregate(scale(modality[,c(4:31,36:39)]), list(neighbourhood_type = modality$type_9b_myear), mean, na.action = na.omit)[c(4,1,2,3),]
png(paste0(output_folder,"Randstad_modality_barplot_byyear.png"), width = 1500, height = 750)
par(mfrow=c(1,1),mai=c(0.25,0.25,0.5,0.25), omi=c(3.5,0.25,0.25,0.25), ps=12, cex=1.1)
barplot(as.matrix(d[2:ncol(d)]),beside=TRUE,space=c(0,1),legend.text=unlist(d[,1]),args.legend=list(bty="n",horiz=TRUE,cex=1.1),
        col=brewer.pal(4,"Set1"), main="Modality by Neighbourhood Type: period",ylim=c(-2,3), las=2)
dev.off()
# standard scaling
scaled_d <- data.frame(scale(d))
# beeswarm
png(paste0(output_folder,"modality_centered_scaled_beeswarm.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_d,las=2,cex=0.2,main="Modality distribution")
abline(h=0,col="black",lty=3)
dev.off()
# boxplot
png(paste0(output_folder,"modality_centered_scaled_boxplot.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_d,ylim=c(-4,4),lwd=1, frame.plot=TRUE,las=2,main="Modality distribution")
abline(h=0,col="black",lty=3)
dev.off()
# rms scaling
scaled_d <- data.frame(scale(d,center=FALSE))
# beeswarm
png(paste0(output_folder,"modality_scaled_beeswarm.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_d,las=2,cex=0.2,main="Modality variation")
abline(h=0,col="black",lty=3)
dev.off()
# boxplot
png(paste0(output_folder,"modality_scaled_boxplot.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_d,ylim=c(0,3.5),lwd=1, frame.plot=TRUE,las=2,main="Modality variation")
abline(h=0,col="black",lty=3)
dev.off()

# same for no-zero values
dz <- d
dz[dz == 0] <- NA
png(paste0(output_folder,"modality_histogram_nozero.png"), width = 1024, height = 1024)
par(mfrow=c(8,4),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(dz)){
    hist(dz[,i],col=colour,main=colnames(dz)[i],xlab="",ylab="")
}
mtext("Modality variables distribution (no zero)", outer=TRUE)
dev.off()
# standard scaling
scaled_d <- data.frame(scale(dz))
# beeswarm
png(paste0(output_folder,"modality_centered_scaled_beeswarm_nozero.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_d,las=2,cex=0.2,main="Modality distribution (no zero)")
abline(h=0,col="black",lty=3)
dev.off()
# boxplot
png(paste0(output_folder,"modality_centered_scaled_boxplot_nozero.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_d,ylim=c(-4,4),lwd=1, frame.plot=TRUE,las=2,main="Modality distribution (no zero)")
abline(h=0,col="black",lty=3)
dev.off()
# rms scaling
scaled_d <- data.frame(scale(dz,center=FALSE))
# beeswarm
png(paste0(output_folder,"modality_scaled_beeswarm_nozero.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_d,las=2,cex=0.2,main="Modality variation (no zero)")
abline(h=0,col="black",lty=3)
dev.off()
# boxplot
png(paste0(output_folder,"modality_scaled_boxplot_nozero.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_d,ylim=c(0,3.5),lwd=1, frame.plot=TRUE,las=2,main="Modality variation (no zero)")
abline(h=0,col="black",lty=3)
dev.off()


##### STEP 1 #####
# Revisiting the socio-economic base data for TOD T2

# frequency of socio-economic types in Randstad
table(travelpatterns$socio_k8)
table(travelpatterns$socio_k8)/length(travelpatterns$socio_k8)*100
# frequency of socio types in TOD
table(todpatterns$socio_k8)
table(todpatterns$socio_k8)/length(todpatterns$socio_k8)*100

# socio-economic description ####
# socio-economic T2
#descriptive stats
d <- travelpatterns_t2[,c(53:68)]
d[is.na(d)] <- 0
descsocio_t2 <- as.data.frame(round(psych::describe(d),2))
descsocio_t2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descsocio_t2[,ncol(descsocio_t2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descsocio_t2)[ncol(descsocio_t2)] <- paste0(i,"%")
}
View(descsocio_t2)
#charts

# socio-economic TOD T2
#descriptive stats
d <- todpatterns_t2[,c(56:71)]
d[is.na(d)] <- 0
descsocio_todt2 <- as.data.frame(round(psych::describe(d),2))
descsocio_todt2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descsocio_todt2[,ncol(descsocio_todt2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descsocio_todt2)[ncol(descsocio_todt2)] <- paste0(i,"%")
}
View(descsocio_todt2)
#charts

# relation between modality types and socio types ####
# frequency of modality types in Randstad
table(travelpatterns$modal_k15)
table(travelpatterns$modal_k15)/length(travelpatterns$modal_k15)*100
# frequency of modality types in socio-economic types
df <- subset(travelpatterns,socio_k8==1)
table(df$modal_k15)
table(df$modal_k15)/length(df$modal_k15)*100    
for (i in 1:8){
    df <- subset(travelpatterns,socio_k8==i)
    png(paste0(output_folder,"socio",i,"_modality_histogram.png"), width = 800, height = 400)
    par(mfrow=c(1,1),mai=c(1.1,1.1,1,1), omi=margins, las=1)
    hist(df$modal_k15, col=colour, breaks= c(0:15),xlab="Urban form types",ylim=c(1,60),
         main=paste0("Frequency of urban form for socio-economic type ",i),labels=T)#as.character(c(1:15)))
    dev.off()
}
# mosaic plot of socio types and modality types
png(paste0(output_folder,"socio_by_modality_mosaicplot.png_modality_mosaicplot.png"), width = 600, height = 600)
par(mfrow=c(1,1),mai=c(1,1,1,1), omi=margins, las=1)
x <- table(travelpatterns[,c("socio_k8","modal_k15")])
mosaicplot(x,shade=T,main="Relation between socio-economic types and urban form",xlab="Socio-economic types",ylab="Urban form types")
dev.off()

##### STEP 2 #####
# Revisiting the base data for T2 as the control variable
# T2 mobility description ####
#source stats
View(as.data.frame(round(psych::describe(travelpatterns[,c(2:4)]),2)))
View(as.data.frame(round(psych::describe(todpatterns[,c(5:7)]),2)))
#descriptive stats
descmobility_t2 <- as.data.frame(round(psych::describe(mobility_t2[,c(1:20)]),2))
descmobility_t2$gini <- round(apply(mobility_t2[,c(1:20)],2,Gini),digits=4)
for (i in quants){
    descmobility_t2[,ncol(descmobility_t2)+1] <- round(apply(mobility_t2[,1:20],2,quantile,probs = c(i)/100, type=8),2)
    colnames(descmobility_t2)[ncol(descmobility_t2)] <- paste0(i,"%")
}
View(descmobility_t2)
#charts
d <- mobility_t2[,c(6:25)]
png(paste0(output_folder,"t2_mobility_histogram.png"), width = 2000, height = 400)
par(mfrow=c(2,10),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Mobility variables distribution in socio-economic Type 2", outer=TRUE)
dev.off()
#different types of scaling, only relevant when comparing multiple variables.
#the result is the same for same variable
#data is centred on 0 and scaled by Std Dev. Shows distribution and variation within a variable
scaled_mobility_t2 <- data.frame(scale(mobility_t2[,1:20]))
png(paste0(output_folder,"t2_mobility_centered_scaled_beeswarm.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_mobility_t2,las=2,cex=0.2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()
png(paste0(output_folder,"t2_mobility_centered_scaled_boxplot.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_mobility_t2,ylim=c(-3,8),lwd=1, frame.plot=TRUE,las=2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()
###
#data is not centered, scaled by root mean square. Shows amount of variation across variables. The best for that!
scaled_mobility_t2 <- data.frame(scale(mobility_t2[,1:20],center=FALSE))
png(paste0(output_folder,"t2_mobility_scaled_beeswarm.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_mobility_t2,las=2,cex=0.2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()
png(paste0(output_folder,"t2_mobility_scaled_boxplot.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_mobility_t2,ylim=c(0,8),lwd=1, frame.plot=TRUE,las=2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()
###
#data is not centered, scaled by Std Dev. Shows distribution within and level/value across variables
scaled_mobility_t2 <- data.frame(scale(mobility_t2[,1:20],center=FALSE,scale = apply(mobility_t2[,1:20], 2, sd, na.rm = TRUE)))
png(paste0(output_folder,"t2_mobility_stdev_beeswarm.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
beeswarm(scaled_mobility_t2,las=2,cex=0.2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()
png(paste0(output_folder,"t2_mobility_stdev_boxplot.png"), width = 1024, height = 600)
par(mfrow=c(1,1),mai=c(2,0.25,0.5,0.25), omi=c(0.25,0.25,0.25,0.25), ps=12, cex=1.1)
boxplot(scaled_mobility_t2,ylim=c(0,14),lwd=1, frame.plot=TRUE,las=2,main="Mobility variation in socio-economic Type 2")
abline(h=0,col="black",lty=3)
dev.off()

# boxplots of mobility by modality type
d <- mobility_t2[,c(6:25)]
d <- data.frame(apply(d,2,scale01))
d$modal_k15 <- mobility_t2$modal_k15
png(paste0(output_folder,"t2_mobility_by_modality_boxplots.png"), width = 1500, height = 800)
par(mfrow=c(5,4),mai=c(0.25,0.25,0.25,0.25), omi=margins, ps=12)
for (i in 1:(ncol(d)-1)){
    boxplot(d[,i]~d$modal_k15,col=modalitypal[c(1,3,4:11,14)],main=colnames(d)[i],ylim=c(0,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
    abline(h=0,col="black",lty=3)
    if (i <= 16) axis(side=1,at=c(1:11),labels=FALSE)
    if (i > 16) axis(side=1,at=c(1:11),labels=c(1,3,4:11,14))
    axis(side=2, labels=TRUE)
}
title("Modality types in each mobility variable",outer=TRUE)
dev.off()

# T2 urban form description ####
#descriptive stats
d <- travelpatterns_t2[,c(32:47)]
d[is.na(d)] <- 0
descform_t2 <- as.data.frame(round(psych::describe(d),2))
descform_t2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descform_t2[,ncol(descform_t2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descform_t2)[ncol(descform_t2)] <- paste0(i,"%")
}
View(descform_t2)
#charts

# T2 modality description ####
#descriptive stats
d <- travelpatterns_t2[,c(92:119,124:127)]
#d[is.na(d)] <- 0
descmodality_t2 <- as.data.frame(round(psych::describe(d),2))
descmodality_t2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descmodality_t2[,ncol(descmodality_t2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descmodality_t2)[ncol(descmodality_t2)] <- paste0(i,"%")
}
View(descmodality_t2)
#charts

# frequency of modality types in T2 #
table(travelpatterns_t2$modal_k15)
table(travelpatterns_t2$modal_k15)/length(travelpatterns_t2$modal_k15)*100

# boxplots of modality types ####
# using final reduced modality indicators set, ordered
modality$socio_k8 <- travelpatterns[match(modality$pcode,travelpatterns$pcode),]$socio_k8
d <- modality[,c(4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:39)]
d$modal_k15 <- modality$modal_k15
d <- subset(d, d$modal_k15 != 12)
d <- data.frame(apply(d,2,scale01))
png(paste0(output_folder,"modality_by_modality_boxplots.png"), width = 1500, height = 1200)
par(mfrow=c(5,5),mai=c(0.25,0.25,0.25,0.25), omi=margins, ps=12)
for (i in 1:(ncol(d)-1)){
    boxplot(d[,i]~d$modal_k15,col=modalitypal[c(1:11,13:15)],main=colnames(d)[i],ylim=c(0,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
    abline(h=0,col="black",lty=3)
    axis(side=1, at=c(1:14), labels=c(1:11,13:15))
    axis(side=2, labels=TRUE)
}
title("Modality types in each urban form variable",outer=TRUE)
dev.off()

d <- modality[modality$socio_k8==2,c(4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:39)]
d <- data.frame(apply(d,2,scale01))
d$modal_k15 <- modality[modality$socio_k8==2,]$modal_k15
png(paste0(output_folder,"t2_modality_by_modality_boxplots.png"), width = 1500, height = 1200)
par(mfrow=c(5,5),mai=c(0.25,0.25,0.25,0.25), omi=margins, ps=12)
for (i in 1:(ncol(d)-1)){
    boxplot(d[,i]~d$modal_k15,col=modalitypal,main=colnames(d)[i],ylim=c(0,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
    abline(h=0,col="black",lty=3)
    axis(side=1, at=c(1:15), labels=c(1:15))
    axis(side=2, labels=TRUE)
}
title("Modality types in each urban form variable",outer=TRUE)
dev.off()


##### STEP 3 #####
# Revisiting the base data for TOD Type 2
# TOD mobility description ####
d <- todmobility[,c(1:20)]
# descriptive stats
descmobility_todt2 <- as.data.frame(round(psych::describe(d),2))
descmobility_todt2$gini <- round(apply(todmobility[,c(1:20)],2,Gini),digits=4)
for (i in quants){
    descmobility_todt2[,ncol(descmobility_todt2)+1] <- round(apply(todmobility[,1:20],2,quantile,probs = c(i)/100, type=8),2)
    colnames(descmobility_todt2)[ncol(descmobility_todt2)] <- paste0(i,"%")
}
View(descmobility_todt2)
#charts
png(paste0(output_folder,"todt2_mobility_histogram.png"), width = 2000, height = 400)
par(mfrow=c(2,10),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(d)){
    hist(d[,i],col=colour,main=colnames(d)[i],xlab="",ylab="")
}
mtext("Mobility variables distribution in TOD T2", outer=TRUE)
dev.off()
# boxplots of mobility by modality type
d <- data.frame(apply(d,2,scale01))
d$modal_k15 <- todmobility$modal_k15
png(paste0(output_folder,"todt2_mobility_by_modality_boxplots.png"), width = 1500, height = 800)
par(mfrow=c(5,4),mai=c(0.25,0.25,0.25,0.25), omi=margins, ps=12)
for (i in 1:(ncol(d)-1)){
    boxplot(d[,i]~d$modal_k15,col=modalitypal[c(1,3,4,7:11)],main=colnames(d)[i],ylim=c(0,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
    abline(h=0,col="black",lty=3)
    if (i <= 16) axis(side=1,at=c(1:8),labels=FALSE)
    if (i > 16) axis(side=1,at=c(1:8),labels=c(1,3,4,7:11))
    axis(side=2, labels=TRUE)
}
title("Modality types in each mobility variable",outer=TRUE)
dev.off()


# TOD urban form description ####
# descriptive stats
d <- todpatterns_t2[,c(35:50)]
d[is.na(d)] <- 0
descform_todt2 <- as.data.frame(round(psych::describe(d),2))
descform_todt2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descform_todt2[,ncol(descform_todt2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descform_todt2)[ncol(descform_todt2)] <- paste0(i,"%")
}
View(descform_todt2)
#charts

# TOD modality description ####
# descriptive stats
d <- todpatterns_t2[,c(95:122,127:130)]
#d[is.na(d)] <- 0
descmodality_todt2 <- as.data.frame(round(psych::describe(d),2))
descmodality_todt2$gini <- round(apply(d,2,Gini),digits=4)
for (i in quants){
    descmodality_todt2[,ncol(descmodality_todt2)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
    colnames(descmodality_todt2)[ncol(descmodality_todt2)] <- paste0(i,"%")
}
View(descmodality_todt2)
#charts

# frequency of modality types in TOD
table(todpatterns$modal_k15)
table(todpatterns$modal_k15)/length(todpatterns$modal_k15)*100
png(paste0(output_folder,"TOD_modality_histogram.png"), width = 800, height = 400)
par(mfrow=c(1,1),mai=c(1.1,1.1,1,1), omi=margins, las=1)
hist(todpatterns$modal_k15, col=colour, breaks= c(0:15),xlab="Urban form types",ylim=c(0,20),
     main="Frequency of urban form types of TOD",labels=T)
dev.off()
# frequency of modality types in TOD T2
table(todpatterns_t2$modal_k15)
table(todpatterns_t2$modal_k15)/length(todpatterns_t2$modal_k15)*100
png(paste0(output_folder,"TOD_t2_modality_histogram.png"), width = 800, height = 400)
par(mfrow=c(1,1),mai=c(1.1,1.1,1,1), omi=margins, las=1)
hist(todpatterns_t2$modal_k15, col=colour, breaks= c(0:15),xlab="Urban form types",ylim=c(0,20),
     main="Frequency of urban form types of TOD t2",labels=T)
dev.off()

##### STEP 4 #####
# Revisiting the correlation of individual mobility variables within TOD T2

# Correlating TOD T2 mobility ####
# correlogram of mobility against modality
todt2_indicators<- data.frame(scaled_mobility_todt2[3:23],scaled_modality_todt2)
correl <- rcorr(as.matrix(todt2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"todt2_mobility_modality_correlogram.png"), width = 2500, height = 2500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

## correlogram of mobility against urban form
todt2_indicators<- data.frame(scaled_mobility_todt2[3:23],scaled_form_todt2)
correl <- rcorr(as.matrix(todt2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"todt2_mobility_form_correlogram.png"), width = 2000, height = 2000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

## correlogram of mobility against socio-economic characteristics
todt2_indicators<- data.frame(scaled_mobility_todt2[3:23],scaled_socio_todt2)
correl <- rcorr(as.matrix(todt2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"todt2_mobility_socio_correlogram.png"), width = 2000, height = 2000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

## extract a table, manually, with highest correlations of each pair

# Correlating T2 mobility ####
# correlogram of mobility against modality
t2_indicators <- data.frame(scaled_mobility_t2,scaled_modality_t2)
correl <- rcorr(as.matrix(t2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"t2_mobility_modality_correlogram.png"), width = 2500, height = 2500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

# mosaic plots of modality and mobility
df <- travelpatterns_t2[,c(70:91,135)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
df <- df[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
png(paste0(output_folder,"t2_mobility_modality_mosaicplot.png"), width = 1500, height = 1200)
par(mfrow=c(5,4),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=15)
for (j in 1:(ncol(df)-1)){
    x <- table(df[,c(ncol(df),j)])
    mosaicplot(x,shade=T,main=colnames(df)[j],xlab="",ylab="")
}
dev.off()

## correlogram of mobility against urban form
t2_indicators<- data.frame(scaled_mobility_t2,scaled_form_t2)
correl <- rcorr(as.matrix(t2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"t2_mobility_form_correlogram.png"), width = 2000, height = 2000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

## correlogram of mobility against socio-economic characteristics
t2_indicators<- data.frame(scaled_mobility_t2,scaled_socio_t2)
correl <- rcorr(as.matrix(t2_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"t2_mobility_socio_correlogram.png"), width = 2000, height = 2000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

# Correlating ALL mobility ####
# correlogram of mobility variables
correl <- rcorr(as.matrix(mobility[,4:23]),type="spearman")
rmatrix <- round(correl$r,digits=3)
pmatrix <- round(correl$P,digits=5)
# correlogram
png(paste0(output_folder,"mobility_correlogram.png"), width = 1500, height = 1500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="shade",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="number",type="upper",col=c("white"),add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# scattermatrix
png(paste0(output_folder,"mobility_scattermatrix.png"), width = 5000, height = 5000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
pairs(mobility[,4:23],upper.panel=NULL, cex.labels=4)
dev.off()

# correlogram of mobility against modality
full_indicators <- data.frame(mobility[,4:23],modality[,c(4:31,36:39)])
correl <- rcorr(as.matrix(full_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"full_mobility_modality_correlogram.png"), width = 2500, height = 2500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# correlogram of full modality variables
correl <- rcorr(as.matrix(modality[,c(4:31,36:39)]),type="spearman")
rmatrix <- round(correl$r,digits=3)
pmatrix <- round(correl$P,digits=5)
# correlogram
png(paste0(output_folder,"full_modality_correlogram.png"), width = 2500, height = 2500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="shade",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="number",type="upper",col=c("white"),add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# scattermatrix
png(paste0(output_folder,"full_modality_scattermatrix.png"), width = 5000, height = 5000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
pairs(modality[,c(4:31,36:39)],upper.panel=NULL, cex.labels=4)
dev.off()


# correlogram of mobility against final modality
sel_modality <- modality[,c(4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:39)]
full_indicators <- data.frame(mobility[,4:23],sel_modality)
correl <- rcorr(as.matrix(full_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
pmatrix <- round(correl$P,digits=5)
# correlogram
png(paste0(output_folder,"mobility_modality_correlogram.png"), width = 5000, height = 5000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=3)
corrplot(rmatrix, method="shade",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="number",type="upper",col=c("white"),add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# scattermatrix
png(paste0(output_folder,"mobility_modality_scattermatrix.png"), width = 5000, height = 5000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
pairs(full_indicators,upper.panel=NULL, cex.labels=2)
dev.off()
# correlogram of modality variables
correl <- rcorr(as.matrix(sel_modality),type="spearman")
rmatrix <- round(correl$r,digits=3)
pmatrix <- round(correl$P,digits=5)
# correlogram
png(paste0(output_folder,"modality_correlogram.png"), width = 1500, height = 1500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="shade",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="number",type="upper",col=c("white"),add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# scattermatrix
png(paste0(output_folder,"modality_scattermatrix.png"), width = 2500, height = 2500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
pairs(sel_modality,upper.panel=NULL, cex.labels=2)
dev.off()

## correlogram of mobility against urban form
full_indicators<- data.frame(mobility[,4:23],form[,2:17])
correl <- rcorr(as.matrix(full_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"full_mobility_form_correlogram.png"), width = 2000, height = 2000)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
corrplot(rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()

## correlogram of mobility against socio-economic characteristics
full_indicators<- data.frame(mobility[,4:23],socio[,4:19])
correl <- rcorr(as.matrix(full_indicators),type="spearman")
rmatrix <- round(correl$r,digits=3)
r2matrix <- round((correl$r)^2,digits=3)
pmatrix <- round(correl$P,digits=5)
View(rmatrix)
View(pmatrix)
# correlogram
png(paste0(output_folder,"mobility_socio_correlogram.png"), width = 4500, height = 4500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=3)
corrplot(rmatrix, method="shade",type="lower",cl.pos="n",tl.col="black",addCoef.col="black",tl.pos="lt",p.mat=pmatrix, sig.level=0.05)
corrplot(rmatrix, method="number",type="upper",col=c("white"),add=TRUE, cl.pos="n",tl.pos="n",p.mat=pmatrix, insig = "p-value", sig.level=-1)
dev.off()
# scattermatrix
png(paste0(output_folder,"mobility_socio_scattermatrix.png"), width = 4500, height = 4500)
par(mfrow=c(1,1),mai=margins, omi=margins, cex=1.5)
pairs(full_indicators,upper.panel=NULL, cex.labels=2)
dev.off()



##### STEP 5 #####
# Showing the mobility potential of TOD within modality types, and the Randstad

##### Randstad range ####
# make the plot
basedata <- subset(modality_mobility[3:22], modality_mobility$type=="Randstad")
basedata[,20] <- basedata[,20]*14.28
par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
plot(t(basedata[1,]), type = "l", ylim=c(0,100), main="Mobility within Randstad with socio-economic Type 2 overlay", axes=F, xlab="", ylab="Level", lwd=1)
abline(h=100,col="black",lty=2)
abline(h=0,col="black",lty=2)
# the mobility sector rectangles
coord <- par("usr")
pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
for (i in 1:6){
    rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],col=mobilitypal$fill[i],lwd=1)
}
# the main polygons
polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col="gray80",border="gray50")
polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col="gray50",border="gray50")
polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col="gray20",border="gray20")
for (i in c(1,5,7,8,10)){  
    lines(t(basedata[i,]),lwd=1,lty=3,col="black")
    mtext(side=4,at=basedata[i,20],text=stats[i],col="black",las=2)
}
# remaining decorations
axis(side=1, at=c(1:ncol(basedata)),labels=colnames(modality_mobility)[3:22],las=2)
axis(side=2, labels=TRUE)

# overlay socio economic T2 constraint
basedata <- subset(modality_mobility_t2[3:22], modality_mobility_t2$type=="Randstad")
basedata[,20] <- basedata[,20]*14.28
# the main polygons
polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col=alphacol("lightcoral",150),border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col=alphacol("brown2",150),border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col=alphacol("red3",150),border=socio2pal[3])


##### Randstad range constraint #####
# showing type 2 range
##
# get maximum range for Randstad
min_randstad <- data.frame(subset(modality_mobility, modality_mobility$type=="Randstad" & modality_mobility$stat=="min")[,3:22])
max_randstad <- data.frame(subset(modality_mobility, modality_mobility$type=="Randstad" & modality_mobility$stat=="max")[,3:22])
# scale T2 values by Randstad range
randscale_modality_mobility_t2 <- rbind(modality_mobility_t2,cbind(type="FullRandstad",stat="min",min_randstad),cbind(type="FullRandstad",stat="max",max_randstad))
randscale_modality_mobility_t2[,3:22] <- apply(randscale_modality_mobility_t2[,3:22],2,scale01)
# make the plot
basedata <- subset(randscale_modality_mobility_t2, randscale_modality_mobility_t2$type=="Randstad")[,3:22]
par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
plot(t(basedata[1,]), type = "l", ylim=c(0,1), main="T2 mobility within Randstad", axes=F, xlab="", ylab="Level", lwd=1)
abline(h=1,col="black",lty=2)
abline(h=0,col="black",lty=2)
# the mobility sector rectangles
pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
for (i in 1:6){
    rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],col=mobilitypal$fill[i],lwd=1)
}
# the main polygons
polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col="lightcoral",border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col="brown2",border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col="red3",border=socio2pal[3])
for (i in c(1,5,7,8,10)){  
    lines(t(basedata[i,]),lwd=1,lty=3,col="black")
    mtext(side=4,at=basedata[i,20],text=stats[i],col="black",las=2)
}
# remaining decorations
axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
axis(side=2, labels=TRUE)

# parallel plot of type 2 #####
# highlighting TOD
##
# scale T2 pcodes by Randstad range
randscale_mobility_t2 <- rbind(mobility_t2,cbind(pcode="0000",min_randstad,modal_k15="0"),cbind(pcode="0000",max_randstad,modal_k15="0"))
randscale_mobility_t2[,2:21] <- apply(randscale_mobility_t2[,2:21],2,scale01)
# scale TODT2 pcodes by Randstad range
randscale_mobility_todt2 <- rbind(mobility_todt2,cbind(pcode="0000",neighbourhood_name="Randstad",min_randstad,modal_k15="0"),cbind(pcode="0000",neighbourhood_name="Randstad",max_randstad,modal_k15="0"))
randscale_mobility_todt2[,3:22] <- apply(randscale_mobility_todt2[,3:22],2,scale01)
# make the plot
par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
plot(t(scaled_mobility_t2[1,2:21]), type = "l", ylim=c(0,1), main="T2 mobility within Randstad", axes=F, xlab="", ylab="Level", lwd=1)
abline(h=1,col="black",lty=2)
abline(h=0,col="black",lty=2)
# the mobility sector rectangles
pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
for (i in 1:6){
    rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],col=mobilitypal$fill[i],lwd=1)
}
# the main lines
for (i in c(1:(nrow(randscale_mobility_t2)-2))){  
    lines(t(randscale_mobility_t2[i,2:21]),lwd=1,col=alphacol("black",80))
}
# the TOD lines
for (i in c(1:(nrow(randscale_mobility_todt2)-2))){  
    lines(t(randscale_mobility_todt2[i,3:22]),lwd=1,col=alphacol("red",80))
}
# remaining decorations
axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
axis(side=2, labels=TRUE)

##### T2 range constraint #####
# showing T2 density
##
t2scale_modality_mobility_t2 <- modality_mobility_t2
t2scale_modality_mobility_t2[,3:22] <- apply(t2scale_modality_mobility_t2[,3:22],2,scale01)
# make the plot
basedata <- subset(t2scale_modality_mobility_t2, t2scale_modality_mobility_t2$type=="Randstad")[,3:22]
par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
plot(t(basedata[1,]), type = "l", ylim=c(0,1), main="T2 mobility within T2 neighbourhoods", axes=F, xlab="", ylab="Level", lwd=1)
abline(h=1,col="black",lty=2)
abline(h=0,col="black",lty=2)
# the mobility sector rectangles
pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
for (i in 1:6){
    rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],col=mobilitypal$fill[i],lwd=1)
}
# the main polygons
polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col="lightcoral",border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col="brown2",border=socio2pal[3])
polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col="red3",border=socio2pal[3])
for (i in c(1,5,7,8,10)){  
    lines(t(basedata[i,]),lwd=1,lty=3,col="black")
    mtext(side=4,at=basedata[i,20],text=stats[i],col="black",las=2)
}
# remaining decorations
axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
axis(side=2, labels=TRUE)

# parallel plot of type 2 #####
# highlighting TOD
# get maximum range for T2
min_T2 <- data.frame(subset(modality_mobility_t2, modality_mobility_t2$type=="Randstad" & modality_mobility_t2$stat=="min")[,3:22])
max_T2 <- data.frame(subset(modality_mobility_t2, modality_mobility_t2$type=="Randstad" & modality_mobility_t2$stat=="max")[,3:22])
# scale T2 pcodes by T2 range
t2scale_mobility_t2 <- mobility_t2
t2scale_mobility_t2[,6:25] <- apply(mobility_t2[,6:25],2,scale01)
# scale TOD pcodes by T2 range
t2scale_mobility_todt2 <- rbind(mobility_todt2,cbind(pcode="0000",neighbourhood_name="T2",min_T2,modal_k15="0"),cbind(pcode="0000",neighbourhood_name="T2",max_T2,modal_k15="0"))
t2scale_mobility_todt2[,3:22] <- apply(t2scale_mobility_todt2[,3:22],2,scale01)
# make the plot
par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
plot(t(scaled_mobility_t2[1,2:21]), type = "l", ylim=c(0,1), main="T2 mobility within T2 neighbourhoods", axes=F, xlab="", ylab="Level", lwd=1)
abline(h=1,col="black",lty=2)
abline(h=0,col="black",lty=2)
# the mobility sector rectangles
pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
for (i in 1:6){
    rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],col=mobilitypal$fill[i],lwd=1)
}
# the main lines
for (i in c(1:nrow(t2scale_mobility_t2))){  
    lines(t(t2scale_mobility_t2[i,2:21]),lwd=1,col=alphacol("black",80))
}
# the TOD lines
for (i in c(1:(nrow(t2scale_mobility_todt2)-2))){  
    lines(t(t2scale_mobility_todt2[i,3:22]),lwd=1,col=alphacol("red",80))
}
# remaining decorations
axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
axis(side=2, labels=TRUE)


##### STEP 6 #####
# comparison of TOD T2 modality types #####
# constrained by type 2 range
##
modal <- sort(unique(todpatterns_t2$modal_k15))
# summary of modality types represented in each subset
table(todpatterns_t2$modal_k15)
table(todpatterns_t2$modal_k15)/nrow(todpatterns_t2)*100
table(subset(travelpatterns_t2, travelpatterns_t2$modal_k15 %in% modal)$modal_k15)
table(subset(travelpatterns_t2, travelpatterns_t2$modal_k15 %in% modal)$modal_k15)/nrow(travelpatterns_t2)*100

# descriptive stats of modality types ####
for (j in modality){
    d <- subset(modality_mobility_t2,modality_mobility_t2$type %in% paste0("type_",j))[,1:22]
    View(d)
}
desclist <- list()
for (j in modality){
    d <- subset(mobility_t2,mobility_t2$modal_k15 == j)[,2:21]
    descdata <- as.data.frame(round(psych::describe(d),2))
    descdata$gini <- round(apply(d,2,Gini),digits=4)
    for (i in quants){
        descdata[,ncol(descdata)+1] <- round(apply(d,2,quantile,probs = c(i)/100, type=8),2)
        colnames(descdata)[ncol(descdata)] <- paste0(i,"%")
    }
    desclist[[j]] <- descdata
}

# showing modality mobility p-value signature ####
agg_data <- travelpatterns_t2[,c(70:91,135)]
#re-order columns for better visualisation
agg_data <- agg_data[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23)]
#par(mfrow=c(6,2),mai=c(0.25,0.25,0.25,0.25), omi=c(0.1,0.2,0.25,0.25), ps=15)
for (j in modal){
    par(mfrow=c(1,1),mai=c(1,1,1,1), omi=c(1,1,1,1), ps=15)
    png(paste0(output_folder,"t2_modality_type",j,"_signature.png"), width = 1024, height = 400)
    d <- subset(agg_data, agg_data[,ncol(agg_data)]==j)
    x <- table(stack(d, select =-21)[,c(2,1)])
    mosaicplot(x,shade=T,main=paste("modality type ",j),xlab="",ylab="")
    dev.off()
}

# showing modality full potential ####
for (j in modality){
    basedata <- subset(t2scale_modality_mobility_t2, 
                t2scale_modality_mobility_t2$type %in% paste0("type_",j))[,3:22]
    png(paste0(output_folder,"t2_modality_type",j,"_potential.png"), width = 750, height = 500)
    # make the plot
    par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
    plot(t(basedata[1,]), type = "l", ylim=c(0,1), main=paste0("Modality Type ",j," within T2 neighbourhoods"), axes=F, xlab="", ylab="Level", lwd=1)
    abline(h=1,col="black",lty=2)
    abline(h=0,col="black",lty=2)
    # the mobility sector rectangles
    pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
    for (i in 1:6){
        rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],lwd=1)#,col=mobilitypal$fill[i])
    }
    # the main polygons
    polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col=alphacol(modalitypal[j],50),border=alphacol(modalitypal[j],50))
    polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col=alphacol(modalitypal[j],50),border=alphacol(modalitypal[j],50))
    polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col=alphacol(modalitypal[j],50),border=alphacol(modalitypal[j],50))
    for (i in c(1,5,7,8,10)){  
        lines(t(basedata[i,]),lwd=1,lty=3,col="black")
        mtext(side=4,at=basedata[i,20],text=stats[i],col="black",las=2)
    }
    # remaining decorations
    axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
    axis(side=2, labels=TRUE)
    dev.off()
}

View(subset(travelpatterns_t2,!(travelpatterns_t2$pcode %in% todpatterns_t2$pcode))[,1:79])
View(subset(travelpatterns_t2,!(travelpatterns_t2$pcode %in% todpatterns_t2$pcode))[,80:175])

# TOD in modality type ####
for (j in modality){
    toddata <- subset(t2scale_mobility_todt2, 
                       t2scale_mobility_todt2$modal_k15 == j)[,c(1,3:22)]
    basedata <- subset(t2scale_modality_mobility_t2, 
                       t2scale_modality_mobility_t2$type %in% paste0("type_",j))[,3:22]
    png(paste0(output_folder,"todt2_modality_type",j,"_performance.png"), width = 750, height = 500)
    # make the plot
    par(mfrow=c(1,1),mai=c(1,1,1,0.5),omi=c(1,0,0,0),ps=12)
    plot(t(toddata[1,2:21]), type = "l", ylim=c(0,1), col=alphacol("gray30",50), axes=F, xlab="", ylab="Level", lwd=1, 
         main=paste0("Modality type ",j," TOD performance"))
    abline(h=1,col="black",lty=2)
    abline(h=0,col="black",lty=2)
    # the mobility sector rectangles
    pos <- c(coord[1],2.5,5.5,11.5,13.5,17.5,coord[2])
    for (i in 1:6){rect(pos[i],coord[3],pos[i+1],coord[4],border=mobilitypal$line[i],lwd=1)}
    # the base polygons
    polygon(c(1:20,20:1),c(basedata[4,1:20],basedata[2,20:1]),col=alphacol("gray30",50),border=alphacol("gray30",50))
    polygon(c(1:20,20:1),c(basedata[10,1:20],basedata[5,20:1]),col=alphacol("gray30",50),border=alphacol("gray30",50))
    polygon(c(1:20,20:1),c(basedata[8,1:20],basedata[7,20:1]),col=alphacol("gray30",50),border=alphacol("gray30",50))
    for (i in c(1,5,7,8,10)){  
        lines(t(basedata[i,]),lwd=1,lty=3,col="black")
        mtext(side=4,at=basedata[i,20],text=stats[i],col="black",las=2)
    }
    # the TOD lines
    for (i in 1:nrow(toddata)){lines(t(toddata[i,2:21]),lwd=1,col=modalitypal[j])}
    # the TOD postcodes
    #for (i in 2:nrow(toddata)){mtext(side=4,at=toddata[i,20],text=toddata[i,1],col="black",las=2)}
    # remaining decorations
    axis(side=1, at=c(1:ncol(basedata)),labels=colnames(basedata),las=2)
    axis(side=2, labels=TRUE)
    dev.off()
}

#thesis appendix charts

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
clusterpal <- c("red1","green1","dodgerblue3","orange1","green4","wheat1","purple1","deepskyblue1","magenta","cyan1","yellow1","brown","mediumpurple","plum1","grey30","black","black","black","black")
filter <- 60

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
    qcd <- (q[4]-q[3])/(q[4]+q[3])
    cv <- sd/mean
    return (c(mean=mean, min=min, median=median, max=max, q[1], q[2], q[3], q[4], q[5], q[6], gini=gini, qcd=qcd, cv=cv))  
}


# connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

# get full modality-economic data set
fullmodality <- dbGetQuery(con,"SELECT * FROM analysis.modality_indicators_meaningful_clusters")
# get the rest of the analysis data
travelpatterns <- dbGetQuery(con,"SELECT * FROM analysis.travelform_patterns_data;")

# remaining data from full set
modality <- travelpatterns[,c(1,176,177,92:127,135,50:52)]
sel_modality <- modality[,c(1,4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:40)]

mon<- dbGetQuery(con,"SELECT pcode, journeys, legs, persons, distance, duration, distance_legs, duration_legs, 
                    walk, cycle, car, bus, tram, train, transit, avg_dur_pers, avg_journeys_pers, avg_dist_pers, 
                    car_dist, transit_dist, car_dur, transit_dur, short_walk, short_cycle, short_car, short_transit,
                    medium_cycle, medium_car, medium_transit, far_car, far_transit 
                    FROM survey.mobility_patterns_home_od WHERE journeys IS NOT NULL") 
#AND pcode IN (SELECT pcode FROM survey.sampling_points)")

#### Appendix E ####
submon <- subset(mon,journeys >= filter)

calculate <- c(9:11,14:31)
titles <- c("Walk %","Cycle %","Car %","Train %","Transit %","Average duration / person","Average journeys / person",
            "Average distance / person","Car distance %","Transit distance %","Car duration %","Transit duration %",
            "Short distance walk %","Short distance cycle %","Short distance car %","Short distance transit %",
            "Medium distance cycle %","Medium distance car %","Medim distance transit %","Long distance car %","Long distance transit %")
count <- 1
for (i in calculate){
    png(paste0(output_folder,"sustainable_mobility_",i,"_stats.png"), width = 1405, height = 484)
    par(mfrow=c(1,1),mai=margins, omi=c(1,7,1,0.25), yaxs="i", las=1, cex=2)
    x <- submon[,i]
    stats <- dstats(x)
    if (stats[7]!=stats[8]){
        hist(x,breaks="FD",col="grey50",main="",xlab="",ylab="")
    }else{
        hist(x,breaks="scott",col="grey50",main="",xlab="",ylab="")
    }
    mtext(titles[count],side=3,line=0,adj=0,outer=TRUE,cex=3)
    mtext(paste0("Mean: ",round(stats[1],4)),side=2,adj=1,line=6,padj=-6,outer=TRUE,cex=3)
    mtext(paste0("SD: ",round(sd(x),4)),side=2,adj=1,line=6,padj=-4,outer=TRUE,cex=3)
    mtext(paste0("Median: ",round(stats[3],4)),side=2,adj=1,line=6,padj=-2,outer=TRUE,cex=3)
    mtext(paste0("Min: ", round(stats[2],4)),side=2,adj=1,line=6,padj=0,outer=TRUE,cex=3)
    mtext(paste0("Max: ", round(stats[4],4)),side=2,adj=1,line=6,padj=2,outer=TRUE,cex=3)
    mtext(paste0("Q2: ", round(stats[7],4)),side=2,adj=1,line=6,padj=4,outer=TRUE,cex=3)
    mtext(paste0("Q3: ", round(stats[8],4)),side=2,adj=1,line=6,padj=6,outer=TRUE,cex=3)
    mtext(paste0("QCD: ", round(stats[12],4)),side=2,adj=1,line=6,padj=8,outer=TRUE,cex=3)
    dev.off()
    count <- count +1
}


#### Appendix G ####
titles <- c("Bicycle lanes proximity (m)","Main roads proximity (m)","Motorways proximity (m)","Local transit stops proximity (m)","Rail stations proximity (m)",
            "Pedestrian areas density (m)","Bicycle lanes density (m)","Motor roads density (m)","Main roads density (m)","Motorways density (m)",
            "Cul-de-sac density (n)","Crossings density (n)","Local transit stops density (n)","Rail stations density (n)","Non-motorised access reach (m)",
            "Motor roads reach (m)","Residential land use density (m2)","Active land use density (m2)","Work land use density (m2)","Education land use density (m2)",
            "Non-motorised access closeness","Motor roads closeness","Local transit stops closeness","Rail stations closeness","Bicycle lanes betweenness","Motor roads betweenness",
            "Active use car accessibility","Active use transit accessibility","Work use car accessibility","Work use transit accessibility")
short_list <- c(4:6,8,7,9,10,13,16,17,15,18:23,28,24,30,31,36:39)
long_list <- c(4:6,8,7,9:12,14,13,16,17,15,18:23,28,24,30,31,29,25,36:39)
count <- 1
for (i in long_list){
    if (i %in% c(24,28,30,31)){
        rounding <- 6        
    }else{
        rounding <- 2        
    }
    x <- modality[,i]
    stats <- dstats(x)
    png(paste0(output_folder,"modality_",count,"_stats.png"), width = 1405, height = 484)
    par(mfrow=c(1,1),mai=margins, omi=c(1,7,1,0.25), yaxs="i", las=1, cex=2)
    if (stats[7]!=stats[8]){
        hist(x,breaks="FD",col="grey50",main="",xlab="",ylab="")
    }else{
        hist(x,breaks="scott",col="grey50",main="",xlab="",ylab="")
    }
    mtext(titles[count],side=3,line=0,adj=0,outer=TRUE,cex=2.5)
    mtext(paste0("Mean: ",round(stats[1],rounding)),side=2,adj=1,line=6,padj=-6,outer=TRUE,cex=3)
    mtext(paste0("SD: ",round(sd(x),rounding)),side=2,adj=1,line=6,padj=-4,outer=TRUE,cex=3)
    mtext(paste0("Median: ",round(stats[3],rounding)),side=2,adj=1,line=6,padj=-2,outer=TRUE,cex=3)
    mtext(paste0("Min: ", round(stats[2],rounding)),side=2,adj=1,line=6,padj=0,outer=TRUE,cex=3)
    mtext(paste0("Max: ", round(stats[4],rounding)),side=2,adj=1,line=6,padj=2,outer=TRUE,cex=3)
    mtext(paste0("Q2: ", round(stats[7],rounding)),side=2,adj=1,line=6,padj=4,outer=TRUE,cex=3)
    mtext(paste0("Q3: ", round(stats[8],rounding)),side=2,adj=1,line=6,padj=6,outer=TRUE,cex=3)
    mtext(paste0("QCD: ", round(stats[12],rounding)),side=2,adj=1,line=6,padj=8,outer=TRUE,cex=3)
    dev.off()
    count <- count +1
}


#### Appendix I ####
# boxplots
plot_data <- subset(sel_modality, sel_modality$modal_k15 != 12)[,c(2:ncol(sel_modality))]
#plot_data <- data.frame(apply(plot_data,2,scale01))
png(paste0(output_folder,"modality_by_modality_boxplots_0.png"), width = 2000, height = 2000)
par(mfrow=c(3,2),mai=c(1.5,0.5,1.5,0.5), omi=c(0.5,0.5,0.5,0.5), ps=12, cex=2)
for (i in 1:(ncol(plot_data)-1)){
    if (i %% 6 == 0){
        title("Modality types in each urban form variable",outer=TRUE)
        dev.off()
        png(paste0(output_folder,"modality_by_modality_boxplots_",i%/%6,".png"), width = 2000, height = 2000)
        par(mfrow=c(3,2),mai=c(1.5,0.5,1.5,0.5), omi=c(0.5,0.5,0.5,0.5), ps=12, cex=2)
    }
    boxplot(plot_data[,i]~plot_data$modal_k15,col=modalitypal[c(1:11,13:15)],main=colnames(plot_data)[i],lwd=1, axes=FALSE, frame.plot=TRUE, outcex=1)
    #,ylim=c(0,1)
    abline(h=0,col="black",lty=3)
    axis(side=1, at=c(1:14), labels=c(1:11,13:15))
    axis(side=2, labels=TRUE)
}
title("Modality types in each urban form variable",outer=TRUE)
dev.off()

# descriptive statistics of each cluster
agg_data <- sel_modality[,c(2:27)]
result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=mean)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=min)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=max)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=median)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=quantile,0.25)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=quantile,0.75)
result[,1:17] <- round(result[,1:17],digits=0)
result[,18:25] <- round(result[,18:25],digits=6)
View(result)

qcd <- function(v){unname(diff(q<-quantile(v,c(0.25,0.75)))/sum(q))}
result <- aggregate(agg_data[,1:25],by=list(agg_data[,"modal_k15"]),FUN=qcd)
result[,1:26] <- round(result[,1:26],digits=3)
View(result)


#### Conclusion ####
# Contingency tables of urban form and socio-economic types
library(gmodels)
table_modal_socio <- CrossTable(travelpatterns$modal_k15,travelpatterns$socio_k8)
View(as.data.frame.matrix(round(table_modal_socio$prop.row*100,0)))


# Mobility potential of all urban from types, irrespective of socio-economic type

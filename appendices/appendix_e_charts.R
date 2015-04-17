# stats and charts for Appendix E

library("RPostgreSQL")
library("psych")
library("ineq")
library("Hmisc") 
library("sm") 


#connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")
mon<- dbGetQuery(con,"SELECT pcode, journeys, legs, persons, distance, duration, distance_legs, duration_legs, 
                    walk, cycle, car, bus, tram, train, transit, avg_dur_pers, avg_journeys_pers, avg_dist_pers, 
                    car_dist, transit_dist, car_dur, transit_dur, short_walk, short_cycle, short_car, short_transit,
                    medium_cycle, medium_car, medium_transit, far_car, far_transit 
                    FROM survey.mobility_patterns_home_od WHERE journeys IS NOT NULL") 
#AND pcode IN (SELECT pcode FROM survey.sampling_points)")

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

# some constants
filter <- 60
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)
def.par <- par(no.readonly = TRUE)
margins <- c(0.25,0.25,0.25,0.25)
output_folder <- "~/_TEMP/R/"
coord <- par("usr")

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
#TOD mobility performance and outliers

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc")
library("RColorBrewer")
library("beeswarm")


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

# get tod selection data
tod <- dbGetQuery(con,"SELECT pcode, randstad_code, neighbourhood_type, neighbourhood_name
                  FROM survey.sampling_points WHERE neighbourhood_type='VINEX' OR neighbourhood_type='TOD'") 

# get the rest of the analysis data
travelpatterns <- dbGetQuery(con,"SELECT * FROM analysis.travelform_patterns_data;")
# geometry doesn't cause an error any more, only a warning. great!
travelpatterns_t2 <- subset(travelpatterns, socio_k8==2)

# T2 mobility data for plots
mobility_t2 <- travelpatterns_t2[,c(9:30,135,178)]
#re-order columns for better visualisation
# walk, bicycle, car, local transit, rail, all, person
mobility_t2$transit <- as.numeric(mobility_t2$bus)+as.numeric(mobility_t2$tram)
mobility_t2 <- mobility_t2[,c(15,1,16,18,2,17,19,21,3,11,13,20,7,22,6,12,14,8,10,9,23,24)]
mobility_t2 <- cbind(travelpatterns_t2[,c(1,176,177,51,52)],mobility_t2)

# T2 modality data for plots
modality_t2 <- travelpatterns_t2[,c(1,176,177,51,52,92:94,96,95,97,98,101,104,105,103,106:111,116,112,118,119,124:127,135,178)]

# get the descriptive stats of mobility per modality type = gives the potential range
modality_mobility_t2 <- read.table("~/Copy/PhD/Thesis_work/analysis/modality_mobility_t2_descriptive.txt", sep="\t")

# only keep TOD of type 2 cluster (79%) = 48 neighbourhoods
todpatterns_t2 <- merge(tod, travelpatterns_t2, by = "pcode")

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
# scale T2 values for potential ####
# scale T2 range
t2scale_modality_mobility_t2 <- modality_mobility_t2
t2scale_modality_mobility_t2[,3:22] <- apply(t2scale_modality_mobility_t2[,3:22],2,scale01)
# get maximum range for T2
min_T2 <- data.frame(subset(modality_mobility_t2, modality_mobility_t2$type=="Randstad" & modality_mobility_t2$stat=="min")[,3:22])
max_T2 <- data.frame(subset(modality_mobility_t2, modality_mobility_t2$type=="Randstad" & modality_mobility_t2$stat=="max")[,3:22])
# scale T2 pcodes by T2 range
t2scale_mobility_t2 <- mobility_t2
t2scale_mobility_t2[,6:25] <- apply(mobility_t2[,6:25],2,scale01)
# scale TOD pcodes by T2 range
t2scale_mobility_todt2 <- rbind(mobility_todt2,cbind(pcode="0000",neighbourhood_name="T2",min_T2,modal_k15="0"),cbind(pcode="0000",neighbourhood_name="T2",max_T2,modal_k15="0"))
t2scale_mobility_todt2[,3:22] <- apply(t2scale_mobility_todt2[,3:22],2,scale01)

# scale t2 values by modality type ####
modal <- sort(unique(mobility_t2$modal_k15))
modscale_mobility <- modality_mobility_t2
#modscale_mobility_t2 <- mobility_t2[!(mobility_t2$pcode %in% todpatterns_t2$pcode) & mobility_t2$modal_k15 %in% modal]
modscale_mobility_t2 <- mobility_t2[mobility_t2$modal_k15 %in% modal,]
for (j in modal){
    modscale_mobility_t2[modscale_mobility_t2$modal_k15 == j, 6:25] <-
        apply(modscale_mobility_t2[modscale_mobility_t2$modal_k15 == j,6:25],2,scale01)    
    
    # scale mobility reference values by modality
    modscale_mobility[modscale_mobility$type == paste0("type_",j),3:22] <- 
        apply(modscale_mobility[modscale_mobility$type == paste0("type_",j),3:22],2,scale01)
}

# scale TOD T2 values by modality type ####
modscale_mobility_todt2 <- rbind(mobility_todt2,
                                 c(pcode="0000",neighbourhood_name="min",c(rep(0,20)),modal_k15=0),
                                 c(pcode="0000",neighbourhood_name="max",c(rep(1,20)),modal_k15=0))
for (j in modal){
    # get modality min/max values
    mod_max <- subset(modality_mobility_t2,modality_mobility_t2$type == paste0("type_",j) 
                      & modality_mobility_t2$stat == "max")[,3:22]
    mod_min <- subset(modality_mobility_t2,modality_mobility_t2$type == paste0("type_",j) 
                      & modality_mobility_t2$stat == "min")[,3:22]
    # insert the min and max in the data frame
    modscale_mobility_todt2[modscale_mobility_todt2$neighbourhood_name=="min",] <- c("0000","min",mod_min,j)
    modscale_mobility_todt2[modscale_mobility_todt2$neighbourhood_name=="max",] <- c("0000","max",mod_max,j)
    # make all values numeric
    modscale_mobility_todt2[,3:22] <- apply(modscale_mobility_todt2[,3:22],2,as.numeric)
    # scale values of same type based on new min/max
    modscale_mobility_todt2[modscale_mobility_todt2$modal_k15 == j,3:22] <- 
        apply(modscale_mobility_todt2[modscale_mobility_todt2$modal_k15 == j,3:22],2,scale01)
}


##### STEP 1 #####
# bar plots of T2 neighbourhoods by modality ####
# in each modality type by mobility variable
mobil <- colnames(mobility_t2[,6:25])
for (j in modal){
    cols <- c(modalitypal[j],"gray")
    plotdata <- subset(mobility_t2, mobility_t2$modal_k15 == j)
    png(paste0(output_folder,"t2_type",j,"_performance.png"), width = 2000, height = 1700)
    par(mfrow=c(5,4),mai=c(1,1,1,0.5),omi=c(0,0,1,0),ps=14)
    for (i in 1:length(mobil)){
        # order data by relevant variable
        d <- plotdata[order(-plotdata[i+5]),]
        # get orderer id of VINEX neighbourhoods
        type <- (d[,5] != "TOD")+1 #is.na(d[,4])+1
        if (i %in% c(1:9,12:15)) {
            sety <- c(0,100)
            ytxt <- "% share"
        } else {
            sety <- c(0,max(d[,i+5]))
            if (i == 20) { ytxt <- "journeys"}
            if (i %in% c(11,17)) { ytxt <- "minutes"}
            if (i %in% c(10,16,18,19)) { ytxt <- "kilometres"}
        }
        # code for individual chart
        #x <- barplot(d[,i+5],names.arg=paste0(d[,3]," ",d[,2]), las=2, axis.lty=1, col=cols[type],
        #    ylim=c(0,100), main=paste0(mobil[i]," performance in environments of type ",j))
        x <- barplot(d[,i+5], axis.lty=1, col=cols[type], ylim=sety, ylab=ytxt, main=paste0(mobil[i]," , environments type ",j))
        text(x, d[,i+5], labels = d[,1], srt = 90, pos = 4, cex = 2)
    }
    dev.off()
}

# bar plots of T2 neighbourhoods by mobility ####
# in each modality type comparing mobility variable
for (i in 1:length(mobil)){
    # order data by relevant variable
    plotdata <- mobility_t2[order(-mobility_t2[i+5]),]
    if (i %in% c(1:9,12:15)) {
        sety <- c(0,100)
        ytxt <- "% share"
    } else {
        sety <- c(0,max(plotdata[,i+5]))
        if (i == 20) { ytxt <- "journeys"}
        if (i %in% c(11,17)) { ytxt <- "minutes"}
        if (i %in% c(10,16,18,19)) { ytxt <- "kilometres"}
    }
    png(paste0(output_folder,"t2_",mobil[i],"_performance.png"), width = 2000, height = 1700)
    par(mfrow=c(4,3),mai=c(1,1,1,0.5),omi=c(0,0,1,0),ps=14)
    for (j in modal){
        cols <- c(modalitypal[j],"gray")
        # get modality type data
        d <- subset(plotdata, plotdata$modal_k15 == j)
        # get orderer id of VINEX neighbourhoods
        type <- (d[,5] != "TOD")+1 #is.na(d[,4])+1
        # code for individual chart
        x <- barplot(d[,i+5], axis.lty=1, col=cols[type], ylim=sety, ylab=ytxt, main=paste0("environments type ",j))
        text(x, d[,i+5], labels = d[,1], srt = 90, pos = 4, cex = 2)
    }
    dev.off()
}

# trying it with gg_plot, nice but would need to learn... maybe for final version of charts.
# ggplot(d, aes(x=buurt_name, y=short_walk, fill=type_9b_named)) + geom_bar(stat="identity")

grouplabels <- c("","walk","","cycle","","","","","car","","","transit","","","train","","","mean dist","mean dist/pers","journeys/pers")
# star plots of T2 individual mobility ####
# within specific modality type
for (j in modal){
    image_name <- paste0("t2_modality_type",j,"_mobility",".png")
    png(paste0(output_folder,image_name), width = 1250, height = 800)
    par(mfrow=c(1,1),mar=c(1,1,1,1),omi=c(0,0,0,0),ps=15)
    plotdata <- subset(t2scale_mobility_t2, t2scale_mobility_t2$modal_k15 == j)[,c(1,6:25)]
    stars(plotdata[,2:21],scale=F,draw.segments=T,labels=as.character(plotdata$pcode),col.segments=mobvarspal,main=paste0("Mobility of T2 with modality type ",j))        
    dev.off()
}

modal_k5 <- sort(unique(travelpatterns_t2$modal_k5))
#t2scale_mobility_t2$modal_k5 <- travelpatterns_t2[match(t2scale_mobility_t2$pcode,travelpatterns_t2$pcode),]$modal_k5
for (j in modal_k5){
    image_name <- paste0("t2_modality_k5_type",j,"_mobility",".png")
    png(paste0(output_folder,image_name), width = 1250, height = 800)
    par(mfrow=c(1,1),mar=c(1,1,1,1),omi=c(0,0,0,0),ps=15)
    plotdata <- subset(t2scale_mobility_t2, t2scale_mobility_t2$modal_k5 == j)[,c(1,6:25)]
    stars(plotdata[,2:21],scale=F,draw.segments=T,labels=plotdata$pcode,col.segments=mobvarspal,main=paste0("Mobility of T2 with modality k5 type ",j))        
    dev.off()
}

##### STEP 2 #####
# star plots of TOD T2 individual mobility performance ####
# within specific modality type
for (j in modal){
    image_name <- paste0("todt2_modality_type",j,"_mobility",".png")
    png(paste0(output_folder,image_name), width = 1250, height = 800)
    par(mfrow=c(1,1),mar=c(1,1,1,1),omi=c(0,0,0,0),ps=15)
    plotdata <- subset(t2scale_mobility_todt2, t2scale_mobility_todt2$modal_k15 == j)[,c(1,3:22)]
    if (nrow(plotdata) == 10){
        location <- abs(sqrt(nrow(plotdata)))*3.2
        stars(plotdata[,2:21],scale=F,draw.segments=T,labels=plotdata$pcode,col.segments=mobvarspal,main=paste0("Mobility of TOD with modality type ",j)
              ,key.loc=c(location,2.3),key.labels=grouplabels)
    }else{
        stars(plotdata[,2:21],scale=F,draw.segments=T,labels=plotdata$pcode,col.segments=mobvarspal,main=paste0("Mobility of TOD with modality type ",j))        
    }
    dev.off()
}

# star plot of mobility of individual TODs ####
# scaled by specific modality
for (i in modal){    
    type_data <- subset(modscale_mobility, modscale_mobility$type == paste0("type_",i))[,1:22]
    tod_data <- subset(modscale_mobility_todt2, modscale_mobility_todt2$modal_k15==i)[,1:23]
    
    for (j in 1:nrow(tod_data)){
        #some required strings for naming things
        image_name <- paste0("modality_type",i,"_",tod_data[j,1],"_",tod_data[j,2],"_performance",".png")
        png(paste0(output_folder,"mobility_performance/",image_name), width = 950, height = 800)
        par(mfrow=c(1,1),mar=c(1,1,1,1),omi=c(1.5,1,1,1),ps=15)
        # plot the base chart
        plotdata <- subset(type_data, type_data$stat=="max")[,3:22]
        stars(plotdata,scale=F,add=F,draw.segments=F,labels=NULL,col.lines="grey90",lwd = 0.3)
        stars(plotdata,scale=F,add=T,key.loc=c(2.1,2.1),key.labels=colnames(tod_data)[3:22],draw.segments=F,labels=NULL)
        #add the titles
        title(main=paste0("Mobility performance of ",tod_data[j,2]," (",tod_data[j,1],")")
              ,sub=paste0("Reference potential: modality type",i),outer=T)
        #plot the individual TOD
        plotdata <- tod_data[j,3:22]
        stars(plotdata,scale=F,add=T,draw.segments=T,col.segments=mobvarspal,lwd = 0.5,labels=NULL)
        #plot the reference lines
        plotdata <- subset(type_data, type_data$stat=="75%")[,3:22]
        stars(plotdata,scale=F,add=T,draw.segments=F,labels=NULL,col.lines=modalitypal[i],lwd = 1)
        #plotdata <- subset(type_data, type_data$stat=="mean")[,3:22]
        #stars(plotdata,scale=F,add=T,draw.segments=F,labels=NULL,col.lines=modalitypal[i],lwd = 1)
        plotdata <- subset(type_data, type_data$stat=="25%")[,3:22]
        stars(plotdata,scale=F,add=T,draw.segments=F,labels=NULL,col.lines=modalitypal[i],lwd = 1)
        dev.off()
    }
}
# these star plots are not the best for individual performance assessment.


##### STEP 3 #####
# calculate the quartile of each value ####
normalisex <- function(x, mm){
    (x - mm[2]) / (mm[1] - mm[2])
}
normalised_dat <- as.data.frame(mapply(normalisex,dat,mm))

quantx <- function(x,lev){
    quant <- 0
    if (x < lev[1]) quant <- 1
    if (x  >= lev[1] && x < lev[2]) quant <- 2
    if (x  >= lev[2] && x < lev[3]) quant <- 3
    if (x  >= lev[3]) quant <- 4
    return(quant)
}

quant_mobility_todt2 <- modscale_mobility_todt2
quant_mobility_t2 <- modscale_mobility_t2
quant_mobility_t2[is.na(quant_mobility_t2)] <- 0
for (j in modal){
    # get modality min/max values
    mod_75 <- subset(modscale_mobility,modscale_mobility$type == paste0("type_",j) 
                     & modscale_mobility$stat == "75%")
    mod_50 <- subset(modscale_mobility,modscale_mobility$type == paste0("type_",j) 
                     & modscale_mobility$stat == "mean")
    mod_25 <- subset(modscale_mobility,modscale_mobility$type == paste0("type_",j) 
                     & modscale_mobility$stat == "25%")
    
    for (i in 3:22){
        dat <- quant_mobility_todt2[quant_mobility_todt2$modal_k15 == j,i]
        quant_mobility_todt2[quant_mobility_todt2$modal_k15 == j,i] <- 
            as.data.frame(sapply(dat,quantx,c(mod_25[i],mod_50[i],mod_75[i])))
    }
    
    for (i in 2:21){
        dat <- quant_mobility_t2[quant_mobility_t2$modal_k15 == j,i]
        quant_mobility_t2[quant_mobility_t2$modal_k15 == j,i] <- 
            as.data.frame(sapply(dat,quantx,c(mod_25[i],mod_50[i],mod_75[i])))
    }    
}


##### STEP 4 #####
# individual TOD performance assessment ####
# using a simplified mobility model
# here I invert the variables according to the sustainability direction

# absolute performance charts ####
mobpal <- mobvarspal[c(1,3,12,6)]
d <- mobility_todt2
for (i in 1:nrow(d)){
    image_name <- paste0(d[i,1],"_",d[i,3],"_performance.png")
    png(paste0(output_folder,"tod_absolute_performance/",image_name), width = 500, height = 300)
    par(mfrow=c(1,1),mai=margins,omi=margins,ps=12)
    plotdata <-  matrix(data=c(d[i,6],d[i,9],(d[i,17]+d[i,19]),-d[i,13],
                               d[i,5],d[i,7],0,-d[i,10],
                               0,d[i,8],d[i,16],-d[i,11],
                               0,0,d[i,18],-d[i,12],
                               0,0,d[i,20],-d[i,14]),nrow=4,ncol=5,
                        dimnames=list(c("walk","cycle","transit","car"),
                                      c("total","short","medium","far","dist")))
    barplot(plotdata[1:3,],ylim=c(-100,100),col=mobpal[1:3],
            main=paste0("Mobility of ",d[i,3]," (",d[i,1],")"))
    barplot(plotdata[4,],add=TRUE,col=mobpal[4])
    legend(x="topright",legend=c("walk","cycle","transit","car"),fill=mobpal)
    dev.off()
}

# constrained performance charts ####
d <- modscale_mobility_t2[modscale_mobility_t2[,5]=="TOD",]
for (i in 1:nrow(d)){
    image_name <- paste("modality",d[i,26],d[i,1],d[i,2],"performance.png",sep="_")
    png(paste0(output_folder,"tod_constrained_performance/",image_name), width = 500, height = 300)
    par(mfrow=c(1,1),mai=margins+c(0,0,0,1),omi=margins,ps=12,xpd=NA)
    plotdata <-  matrix(data=c(d[i,7],d[i,10],d[i,18],-d[i,14],
                               d[i,6],d[i,8],0,-d[i,11],
                               0,d[i,9],d[i,17],-d[i,12],
                               0,0,d[i,19],-d[i,13],
                               0,0,d[i,21],-d[i,15]),nrow=4,ncol=5,
                        dimnames=list(c("walk","cycle","transit","car"),
                                      c("total","short","medium","far","dist")))
    barplot(plotdata[1:4,],ylim=c(-1,1),col=mobpal[1:4],beside=T,legend=F,
            main=paste0("Performance of ",d[i,2]," (",d[i,1],")"))
    #barplot(plotdata[4,],add=TRUE,col=mobpal[4])
    legend(27,1,legend=c("walk","cycle","transit","car"),fill=mobpal,inset=0)
    dev.off()
}


##### STEP 5 #####
# identifying outliers ####
# can use different detection methods
# 1 ESD (3 sigma), known to be unreliable, but pretty standard
# 2 Hampel identifier based on the median and MAD, can be too aggressive
# 3 boxplot 1.5 IQR rule above or below the quartiles. similar to above

# Moreover, outliers are identified even for “clean” data, 
# or at least no distinction is made between outliers and extremes of a distribution.

# I don't want multi-variate outlier detection, such as this. 
# this would be useful before clustering
out <- uni.plot(mobility_t2[,6:15])
mobility_t2[out$outliers,]$pcode

# Per mobility variable, within T2 ####
# above or below, and modality

# Get the overall mobility outliers as results lists
# 1 ESD
esd_outliers <- list()
for (i in 1:length(mobil)){
    # calculate range
    top_cut <- descmobility_t2[i,]$mean + (3* descmobility_t2[i,]$sd)
    bottom_cut <- descmobility_t2[i,]$mean - (3* descmobility_t2[i,]$sd)
    # get top and bottom outliers
    top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut)$pcode)
    bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut)$pcode)
    # store in outliers list
    esd_outliers[[i]] <- list(mobil[i],top,bottom)
}

# 2 HAMPEL
hampel_outliers <- list()
for (i in 1:length(mobil)){
    # calculate range
    top_cut <- descmobility_t2[i,]$median + (3* descmobility_t2[i,]$mad)
    bottom_cut <- descmobility_t2[i,]$median - (3* descmobility_t2[i,]$mad)
    # get top and bottom outliers
    top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut)$pcode)
    bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut)$pcode)
    # store in outliers list
    hampel_outliers[[i]] <- list(mobil[i],top,bottom)
}

# 3 Boxplot
box_outliers <- list()
for (i in 1:length(mobil)){
    # calculate range
    IQR <- (descmobility_t2[i,]$"75%") - (descmobility_t2[i,]$"25%")
    top_cut <- descmobility_t2[i,]$"75%" + (1.5* IQR)
    bottom_cut <- descmobility_t2[i,]$"$25%" - (1.5* IQR)
    # get top and bottom outliers
    top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut)$pcode)
    bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut)$pcode)
    # store in outliers list
    box_outliers[[i]] <- list(mobil[i],top,bottom)
}

# 4 Extremes
quart_extremes <- list()
for (i in 1:length(mobil)){
    # calculate range
    top_cut <- descmobility_t2[i,]$"75%"
    bottom_cut <- descmobility_t2[i,]$"$25%"
    # get top and bottom outliers
    top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut)$pcode)
    bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut)$pcode)
    # store in outliers list
    ext_outliers[[i]] <- list(mobil[i],top,bottom)
}

# Per mobility variable, within modality constraint
# The sample is so small it doesn't get any outliers with 1.5 * IQR
modality_outliers <- list()
mobility_outliers <- list()
for (j in 1:length(modal)){
    for (i in 1:length(mobil)){
        # calculate range
        top_quart <- modality_mobility_t2[modality_mobility_t2$stat=="75%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        bottom_quart <- modality_mobility_t2[modality_mobility_t2$stat=="25%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        IQR <- top_quart - bottom_quart
        top_cut <- top_quart + IQR
        bottom_cut <- bottom_quart - IQR
        # get top and bottom outliers
        top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut & mobility_t2$modal_k15 == modal[j])$pcode)
        bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut & mobility_t2$modal_k15 == modal[j])$pcode)
        # store in outliers list
        mobility_outliers[[i]] <- list(mode = mobil[i],top = top,bottom = bottom)
    }
    modality_outliers[[j]] <- list(modality = modal[j],mobility = mobility_outliers)
}

# The easiest way to store all these outliers is in data frames, despite the many NULL values.
# The data set is not that big...
d <- mobility_t2[,c(1:3,26)]
for (i in 1:length(mobil)){
    # calculate range
    IQR <- (descmobility_t2[i,]$"75%") - (descmobility_t2[i,]$"25%")
    top_cut <- descmobility_t2[i,]$"75%" + (1.5* IQR)
    bottom_cut <- descmobility_t2[i,]$"$25%" - (1.5* IQR)
    # get top and bottom outliers
    top <- as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut)$pcode)
    bottom <- as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut)$pcode)
    # store in outliers list
    box_outliers[[i]] <- list(mobil[i],top,bottom)
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- mobil[i]
}
mobility_t2_outliers <- d
 
d <- mobility_t2[,c(1:3,26)]
for (i in 1:length(mobil)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_quart <- modality_mobility_t2[modality_mobility_t2$stat=="75%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        bottom_quart <- modality_mobility_t2[modality_mobility_t2$stat=="25%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        IQR <- top_quart - bottom_quart
        top_cut <- top_quart + IQR
        bottom_cut <- bottom_quart - IQR
        # get top and bottom outliers
        top <- append(top,as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- mobil[i]
}
modality_mobility_t2_outliers <- d

d <- mobility_t2[,c(1:3,26)]
for (i in 1:length(mobil)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_quart <- modality_mobility_t2[modality_mobility_t2$stat=="75%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        bottom_quart <- modality_mobility_t2[modality_mobility_t2$stat=="25%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        IQR <- top_quart - bottom_quart
        top_cut <- top_quart + (1.5*IQR)
        bottom_cut <- bottom_quart - (1.5*IQR)
        # get top and bottom outliers
        top <- append(top,as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- mobil[i]
}
modality_mobility_t2_trueoutliers <- d

##### STEP 5 #####
# identifying extremes ####
# in reality, outliers are important before clustering, as classes themselves or to clean
# at this stage I need extremes 
# 1 top or bottom quartile
d <- mobility_t2[,c(1:3,26)]
for (i in 1:length(mobil)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_cut <- modality_mobility_t2[modality_mobility_t2$stat=="75%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        bottom_cut <- modality_mobility_t2[modality_mobility_t2$stat=="25%" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        # get top and bottom outliers
        top <- append(top,as.vector(subset(mobility_t2, mobility_t2[,i+5] > top_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(mobility_t2, mobility_t2[,i+5] < bottom_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- mobil[i]
}
modality_mobility_t2_topbottom <- d

# 2 top or bottom performer in its class
d <- mobility_t2[,c(1:3,26)]
for (i in 1:length(mobil)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_cut <- modality_mobility_t2[modality_mobility_t2$stat=="max" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        bottom_cut <- modality_mobility_t2[modality_mobility_t2$stat=="min" & modality_mobility_t2$type==paste0("type_",modal[j]), i+2]
        # get top and bottom outliers
        top <- append(top,as.vector(subset(mobility_t2, mobility_t2[,i+5] == top_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(mobility_t2, mobility_t2[,i+5] == bottom_cut & mobility_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- mobil[i]
}
modality_mobility_t2_extremes <- d


##### STEP 6 #####
# getting the relevant neighbourhoods ####
# for mapping and closer investigation, restricted to performance in critical car classes

#identify TOD neighbourhoods
modality_mobility_t2_topbottom$neighbourhood_type <- tod[match(modality_mobility_t2_topbottom$pcode,tod$pcode),]$neighbourhood_type
modality_mobility_t2_topbottom$neighbourhood_name <- tod[match(modality_mobility_t2_topbottom$pcode,tod$pcode),]$neighbourhood_name
modality_mobility_t2_extremes$neighbourhood_type <- tod[match(modality_mobility_t2_extremes$pcode,tod$pcode),]$neighbourhood_type
modality_mobility_t2_extremes$neighbourhood_name <- tod[match(modality_mobility_t2_extremes$pcode,tod$pcode),]$neighbourhood_name
modality_mobility_t2_outliers$neighbourhood_type <- tod[match(modality_mobility_t2_outliers$pcode,tod$pcode),]$neighbourhood_type
modality_mobility_t2_outliers$neighbourhood_name <- tod[match(modality_mobility_t2_outliers$pcode,tod$pcode),]$neighbourhood_name
modality_mobility_t2_trueoutliers$neighbourhood_type <- tod[match(modality_mobility_t2_trueoutliers$pcode,tod$pcode),]$neighbourhood_type
modality_mobility_t2_trueoutliers$neighbourhood_name <- tod[match(modality_mobility_t2_trueoutliers$pcode,tod$pcode),]$neighbourhood_name

# output files for exploration in Excel
write.table(modality_mobility_t2_topbottom, paste0(output_folder,"modality_mobility_topbottom.txt"), sep="\t")
write.table(modality_mobility_t2_extremes, paste0(output_folder,"modality_mobility_extremes.txt"), sep="\t")
write.table(modality_mobility_t2_outliers, paste0(output_folder,"modality_mobility_outliers.txt"), sep="\t")
write.table(modality_mobility_t2_trueoutliers, paste0(output_folder,"modality_mobility_trueoutliers.txt"), sep="\t")



# prepare an outlier specific table for PostGIS
d <- modality_mobility_t2_outliers
cols <- c(colnames(d)[c(1:3,25,26,4)],"outlier_type","attribute","position")
mobility_list <- data.frame(cols)
for (i in cols) mobility_list$i <- NA

for (j in 1:nrow(d)){
    for (i in 1:length(mobil)){
        toadd <- d[!is.na(d[,mobil[2]]),c(1:4,which(colnames(d)==mobil[2]))]
        toadd$mode <- mobil[2]
        toadd$type <- "outlier"    
    }
}

modality_mobility_t2_topbottom
modality_mobility_t2_extremes


##### STEP 7 #####
# calculating modality outliers and extremes ####

# 1 top or bottom quartile
d <- modality_t2[,c(1:3,31)]
d$neighbourhood_type <- tod[match(d$pcode,tod$pcode),]$neighbourhood_type
d$neighbourhood_name <- tod[match(d$pcode,tod$pcode),]$neighbourhood_name
modality_vars <- colnames(modality_t2)[6:30]
for (i in 1:length(modality_vars)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_cut <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.75, type=8)
        bottom_cut <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.25, type=8)
        # get top and bottom outliers
        top <- append(top,as.vector(subset(modality_t2, modality_t2[,i+5] > top_cut & modality_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(modality_t2, modality_t2[,i+5] < bottom_cut & modality_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- modality_vars[i]
}
modality_t2_topbottom <- d

# 2 top or bottom performer in its class - extremes
d <- modality_t2[,c(1:3,31)]
d$neighbourhood_type <- tod[match(d$pcode,tod$pcode),]$neighbourhood_type
d$neighbourhood_name <- tod[match(d$pcode,tod$pcode),]$neighbourhood_name
for (i in 1:length(modality_vars)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_cut <- max(modality_t2[modality_t2$modal_k15==modal[j], i+5])
        bottom_cut <- min(modality_t2[modality_t2$modal_k15==modal[j], i+5])
        # get top and bottom outliers
        top <- append(top,as.vector(subset(modality_t2, modality_t2[,i+5] == top_cut & modality_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(modality_t2, modality_t2[,i+5] == bottom_cut & modality_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- modality_vars[i]
}
modality_t2_extremes <- d

# 3 outliers in its class
d <- modality_t2[,c(1:3,31)]
d$neighbourhood_type <- tod[match(d$pcode,tod$pcode),]$neighbourhood_type
d$neighbourhood_name <- tod[match(d$pcode,tod$pcode),]$neighbourhood_name
for (i in 1:length(modality_vars)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_quart <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.75, type=8)
        bottom_quart <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.25, type=8)
        IQR <- top_quart - bottom_quart
        top_cut <- top_quart + IQR
        bottom_cut <- bottom_quart - IQR
        # get top and bottom outliers
        top <- append(top,as.vector(subset(modality_t2, modality_t2[,i+5] > top_cut & modality_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(modality_t2, modality_t2[,i+5] < bottom_cut & modality_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- modality_vars[i]
}
modality_t2_outliers <- d

# 4 true outliers (1.5 IQR) in its class
d <- modality_t2[,c(1:3,31)]
d$neighbourhood_type <- tod[match(d$pcode,tod$pcode),]$neighbourhood_type
d$neighbourhood_name <- tod[match(d$pcode,tod$pcode),]$neighbourhood_name
for (i in 1:length(modality_vars)){
    top <- vector()
    bottom <- vector()
    for (j in 1:length(modal)){
        # calculate range
        top_quart <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.75, type=8)
        bottom_quart <- quantile(modality_t2[modality_t2$modal_k15==modal[j], i+5],probs = 0.25, type=8)
        IQR <- top_quart - bottom_quart
        top_cut <- top_quart + (1.5*IQR)
        bottom_cut <- bottom_quart - (1.5*IQR)
        # get top and bottom outliers
        top <- append(top,as.vector(subset(modality_t2, modality_t2[,i+5] > top_cut & modality_t2$modal_k15 == modal[j])$pcode))
        bottom <- append(bottom,as.vector(subset(modality_t2, modality_t2[,i+5] < bottom_cut & modality_t2$modal_k15 == modal[j])$pcode))
        # store in outliers data frame
    }
    d$temp <- NA
    d$temp[d$pcode %in% top] <- "top"
    d$temp[d$pcode %in% bottom] <- "bottom"
    colnames(d)[which(colnames(d) == "temp")] <- modality_vars[i]
}
modality_t2_trueoutliers <- d

# output files for exploration in Excel
write.table(modality_t2_topbottom, paste0(output_folder,"modality_t2_topbottom.txt"), sep="\t")
write.table(modality_t2_extremes, paste0(output_folder,"modality_t2_extremes.txt"), sep="\t")
write.table(modality_t2_outliers, paste0(output_folder,"modality_t2_outliers.txt"), sep="\t")
write.table(modality_t2_trueoutliers, paste0(output_folder,"modality_t2_trueoutliers.txt"), sep="\t")



# And only the extremes that are bad, because no cycling is ok if lots of walking takes place.
# although it might be useful to note that there is much less cycling than anticipated

# Relevant modality types to investigate outliers in: 1,3,4,9,10

# variation within T2 modality is still huge... I wasn't expecting that.
# i'm not capturing all modality vars
# individual preference plays a bigger role, than just patterns
# external factors play a big role
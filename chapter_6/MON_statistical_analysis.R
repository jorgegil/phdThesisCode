#MON statistical analysis

library("RPostgreSQL")
library("psych")
library("ineq")
library("corrgram")
library("corrplot")
library("Hmisc") 
library("sm") 

def.par <- par(no.readonly = TRUE)


#connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")
mon<- dbGetQuery(con,"SELECT pcode, journeys, legs, persons, distance, duration, distance_legs, duration_legs, 
                    walk, cycle, car, bus, tram, train, transit, avg_dist, avg_journeys_pers, avg_dist_pers, 
                    car_dist, transit_dist, car_dur, transit_dur, short_walk, short_cycle, short_car, 
                    medium_cycle, medium_car, medium_transit, far_car, far_transit 
                    FROM survey.mobility_patterns_home_od WHERE journeys IS NOT NULL") 
          #AND pcode IN (SELECT pcode FROM survey.sampling_points)")

journeys <- dbGetQuery(con,"SELECT (afstr*100) distance, rrsdduur duration, kmotief purpose,
                aankbzh activity, mode_leg as mode, mode_main, pcode, home_pcode, agg_pcode, mm_code FROM survey.randstad_journeys")

# some constants
margins <- c(0.25,0.25,0.25,0.25)
bins <- pretty(range(c(0, 100)), n=21)
filter <- 60
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)


# 1 Selecting data for analysis
#### distribution of number of journeys
hist(mon$journeys,breaks=pretty(range(c(0,1400)),n=40),col=colour,main="journeys",xlab="")
hist(subset(mon,mon$journeys>=filter)$journeys,breaks=pretty(range(c(0,1400)),n=40),col=colour,main="journeys >= 60",xlab="")

#####
# histograms to show distribution of small sample journeys
par(mfrow=c(1,4),mai=margins, omi=margins, yaxs="i", las=1)

hist(mon$walk,breaks=bins,col=colour,main="walk share",xlab="",ylab="")
hist(mon$cycle,breaks=bins,col=colour,main="cycle share",xlab="",ylab="")
hist(mon$car,breaks=bins,col=colour,main="car share",xlab="",ylab="")
hist(mon$transit,breaks=bins,col=colour,main="transit share",xlab="",ylab="")

hist(subset(mon,mon$journeys<filter)$walk,breaks=bins,col=colour,main="walk share",xlab="",ylab="")
hist(subset(mon,mon$journeys<filter)$cycle,breaks=bins,col=colour,main="cycle share",xlab="",ylab="")
hist(subset(mon,mon$journeys<filter)$car,breaks=bins,col=colour,main="car share",xlab="",ylab="")
hist(subset(mon,mon$journeys<filter)$transit,breaks=bins,col=colour,main="transit share",xlab="",ylab="")

# taking histogram data to create more advanced visuals
par(mfrow=c(1,4),mai=margins, omi=margins, yaxs="i", las=1, ps=14)

hist<- hist(mon$walk, breaks=bins, plot=FALSE)
subhist<- hist(subset(mon,mon$journeys<filter)$walk, breaks=bins, plot=FALSE)
dat<- rbind(subhist$counts,hist$counts)
colnames(dat) <- bins[-length(bins)]
barplot(dat, space=c(0, 0.1),main="walk share",col=twocolour)

hist<- hist(mon$cycle, breaks=bins, plot=FALSE)
subhist<- hist(subset(mon,mon$journeys<filter)$cycle, breaks=bins, plot=FALSE)
dat<- rbind(subhist$counts,hist$counts)
colnames(dat) <- bins[-length(bins)]
barplot(dat, space=c(0, 0.1),main="cycle share",col=twocolour)

hist<- hist(mon$car, breaks=bins, plot=FALSE)
subhist<- hist(subset(mon,mon$journeys<filter)$car, breaks=bins, plot=FALSE)
dat<- rbind(subhist$counts,hist$counts)
colnames(dat) <- bins[-length(bins)]
barplot(dat, space=c(0, 0.1),main="car share",col=twocolour)

hist<- hist(mon$transit, breaks=bins, plot=FALSE)
subhist<- hist(subset(mon,mon$journeys<filter)$transit, breaks=bins, plot=FALSE)
dat<- rbind(subhist$counts,hist$counts)
colnames(dat) <- bins[-length(bins)]
barplot(dat, space=c(0, 0.1),main="transit share",col=twocolour)

# testing difference between full and subset
submon <- subset(mon,journeys >= filter)

nrow(subset(submon, walk==0))
nrow(subset(submon,walk>90))
nrow(subset(submon,walk==100))
nrow(subset(submon,cycle==0))
nrow(subset(submon,cycle>90))
nrow(subset(submon,cycle==100))
nrow(subset(submon,transit==0))
nrow(subset(submon,transit>90))
nrow(subset(submon,transit==100))
nrow(subset(submon,car==0))
nrow(subset(submon,car>90))
nrow(subset(submon,car==100))

nrow(subset(mon,walk==0))
nrow(subset(mon,walk>90))
nrow(subset(mon,walk==100))
nrow(subset(mon,cycle==0))
nrow(subset(mon,cycle>90))
nrow(subset(mon,cycle==100))
nrow(subset(mon,transit==0))
nrow(subset(mon,transit>90))
nrow(subset(mon,transit==100))
nrow(subset(mon,car==0))
nrow(subset(mon,car>90))
nrow(subset(mon,car==100))

#####
# simple facts and figures about mobility data
sum(submon$journeys)
sum(submon$legs)
sublegs <- subset(journeys,agg_pcode==home_pcode & home_pcode %in% submon$pcode)
subjourneys <- subset(journeys,agg_pcode==home_pcode & home_pcode %in% submon$pcode & mm_code!=3)

walkdist <- subset(sublegs,mode==1 & distance>0)$distance
cycledist <- subset(sublegs,mode==2 & distance>0)$distance
cardist <- subset(sublegs,mode %in% c(3,4) & distance>0)$distance
localtransitdist <- subset(sublegs,mode %in% c(5,6) & distance>0)$distance
raildist <- subset(sublegs,mode==7 & distance>0)$distance
totaldist <- sum(as.numeric(walkdist),na.rm=TRUE)+sum(as.numeric(cycledist),na.rm=TRUE)+sum(as.numeric(cardist),na.rm=TRUE)+sum(as.numeric(localtransitdist),na.rm=TRUE)+sum(as.numeric(raildist),na.rm=TRUE)
mmjourneys <- nrow(subset(journeys,agg_pcode==home_pcode & home_pcode %in% submon$pcode & mm_code %in% c(1,2,4,5)))

psych::describe(walkdist)
Hmisc::describe(walkdist)
psych::describe(cycledist)
Hmisc::describe(cycledist)
psych::describe(cardist)
Hmisc::describe(cardist)
psych::describe(localtransitdist)
Hmisc::describe(localtransitdist)
psych::describe(raildist)
Hmisc::describe(raildist)

#a simple histogram
h <- hist(walkdist,breaks=c(seq(0,max(x),100)))
plot(h$counts,log="x",main="Walking distance frequency")

#but density plots look much nicer
options(scipen=4) #this forces the axis numbers not to be scientific shortenend

#function to rescale between 0 and 1
range01 <- function(x){(x-min(x, na.rm=TRUE))/(max(x, na.rm=TRUE)-min(x, na.rm=TRUE))}
#function to make density data coordinates for a polygon
density_data <- function(dists){
  d <- density(dists,adjust=0.5)
  dens <- subset(data.frame(x=d$x,y=d$y),x>0) #remove zeros and negative values
  dens <- data.frame(x=c(min(dens$x),dens$x),y=c(0,scale(dens$y,center=FALSE,scale=TRUE)))
  #dens <- data.frame(x=c(min(dens$x),dens$x),y=c(0,range01(dens$y)))
  return(dens)
}

par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
d <- density_data(walkdist)
plot(d,log="x",main="Walk distance density",type="l",lwd=1,lty=2,col="blue")
polygon(d,col=colour,border="black",lwd=0.2)

#I can make a plot with overlapping transparent polygons or lines
#function to add alpha value to standard R colours
alphacol <- function(colour,a){rgb(col2rgb(colour)[1],col2rgb(colour)[2],col2rgb(colour)[3],alpha=a,max=255)}

modes <- list(mode=c("Walk","Bicycle","Car","Local transit","Rail"),
              data=list(walkdist,cycledist,cardist,localtransitdist,raildist),
              line=c("blue","orange","black","green","red"), 
              fill=c(alphacol("blue",50),alphacol("orange",50),alphacol("black",50),alphacol("green",50),alphacol("red",50)))

# a polygons chart with transparency
d <- density_data(modes$data[[1]])
plot(d,log="x",type="l",lwd=0,lty=0,main="Modes distance density",xlab="Distance in metres",ylab="Density",xlim=c(100,max(modes$data[[5]])))
polygon(d,col=modes$fill[[1]],border=modes$line[[1]],lwd=1,lty=1)
for (i in 2:5){
  d <- density_data(modes$data[[i]])
  polygon(d,col=modes$fill[[i]],border=modes$line[[i]],lwd=1,lty=1)
}
legend("topright",box.lwd,legend=modes$mode,border=modes$line,fill=modes$fill)

# a lines chart
d <- density_data(modes$data[[1]])
plot(d,log="x",type="l",lwd=0,lty=0,main="Modes distance density",xlab="Distance in metres",ylab="Density",xlim=c(100,max(modes$data[[5]])))
lines(d,lwd=2,col=modes$line[[1]])
for (i in 2:5){
  d <- density_data(modes$data[[i]])
  lines(d,lwd=2,col=modes$line[[i]])
}
legend("topright",legend=modes$mode,col=modes$line,lty=1, lwd=2)



########
# 2 Analysing mobility patterns

#####
# 2.1 descriptive statistics and histograms
submon_data <- submon[9:ncol(submon)]
descmon <- as.data.frame(round(describe(submon_data),digits=2))
rstudio::viewData(descmon)

par(mfrow=c(6,4),mai=margins, omi=margins, yaxs="i", las=1, ps=11)
for (i in 1:ncol(submon_data)){
  hist(submon_data[,i],col=colour,main=colnames(submon_data)[i],xlab="",ylab="")
}

#the same but ignoring places with 0 values (important for transit)
#and this should not affect the rest
for (i in 1:ncol(submon_data)){
  hist(subset(submon_data,submon_data[,i]>0)[,i],col=colour,main=colnames(submon_data)[i],xlab="",ylab="")
}

#####
# 2.2 gini coefficient and correlations
#gini coefficient

#this function is different from the one in reldist
#gini(c(100,0,0,0))=0.75 or gini(c(100,0))=0.5 and with newgini = 1 in both cases
newgini <- function(x, unbiased = TRUE, na.rm = FALSE){
  if (!is.numeric(x)){
    warning("'x' is not numeric; returning NA")
    return(NA)
  }
  if (!na.rm && any(na.ind <- is.na(x)))
    stop("'x' contain NAs")
  if (na.rm)
    x <- x[!na.ind]
  n <- length(x)
  mu <- mean(x)
  N <- if (unbiased) n * (n - 1) else n * n
  ox <- x[order(x)]
  dsum <- drop(crossprod(2 * 1:n - n - 1,  ox))
  dsum / (mu * N)
}
#a simple implementation of the reldist version
othergini <- function(x) {
  n <- length(x)
  x <- sort(x)
  G <- sum(x * 1:n)
  G <- 2 * G/(n * sum(x))
  G -1 - (1/n)
}

gini_submon <- apply(submon_data,2,Gini)
#is the same as
gini_submon <- apply(submon_data,2,othergini)
#but the result for a large sample with many more cases than the simple examples is almost identical
newgini_submon <- apply(submon_data,2,newgini)
#so I stick with the 'official' in the ineq package

gini_submon <- round(apply(submon_data,2,Gini),digits=4)
gini_submon_nozero <- round(apply(submon_data,2,Gini),digits=4)
gini_submon_noextremes <- round(apply(submon_data,2,Gini),digits=4)
#to get the values without the 0 as for the histogram
for (i in 1:ncol(submon_data)){
  gini_submon_nozero[i]<-round(Gini(subset(submon_data,submon_data[,i]>0)[,i]),digits=4)
}
#and getting rid of the 0 and 100, but the result is the same as the first...
for (i in 1:ncol(submon_data)){
  gini_submon_noextremes[i]<-round(Gini(subset(submon_data,submon_data[,i]>0 && submon_data[,i]<100)[,i]),digits=4)
}

#####
# correlation matrix and correlograms
corr_matrix <- round(cor(submon_data,submon_data),digits=2)

#with the simply graphic corrgram package
corrgram(submon_data, order=FALSE, lower.panel=panel.shade, upper.panel=panel.shade, 
          text.panel=panel.txt, main="Mobility indicators correlation")
corrgram(submon_data, order=TRUE, lower.panel=panel.shade, upper.panel=panel.ellipse, 
         text.panel=panel.txt, main="PCA clustered mobility indicators")

#but I prefer the more elaborate corrplot package.
#This makes a nice combination of coorelation, p value, numbers and colour.
#mon correlation
submon_rmatrix <- round(rcorr(as.matrix(submon_data))$r,digits=3)
submon_r2matrix <- round((rcorr(as.matrix(submon_data))$r)^2,digits=3)
submon_pmatrix <- round(rcorr(as.matrix(submon_data))$P,digits=5)
#mon correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=9)
corrplot(submon_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=submon_pmatrix, sig.level=0.001)
corrplot(submon_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=submon_pmatrix, insig = "p-value", sig.level=-1)

# 2.3 and 2.4 maps done in QGIS (maybe later here, especially for batch production!)
# standardise values for 2.4 maps
std_mon <- data.frame(mon[1:8],scale(mon[9:30]))
#invert direction of car variables to make indicators
std_mon$car <- -std_mon$car
std_mon$short_car <- -std_mon$short_car
std_mon$medium_car <- -std_mon$medium_car
std_mon$far_car <- -std_mon$far_car
std_mon$car_dist <- -std_mon$car_dist
std_mon$car_dur <- -std_mon$car_dur
std_mon$avg_dist <- -std_mon$avg_dist
std_mon$avg_journeys_pers <- -std_mon$avg_journeys_pers
std_mon$avg_dist_pers <- -std_mon$avg_dist_pers

if(dbExistsTable(con,c("analysis","mobility_indicators"))){
  dbRemoveTable(con,c("analysis","mobility_indicators"))
}
dbWriteTable(con,c("analysis","mobility_indicators"),std_mon)

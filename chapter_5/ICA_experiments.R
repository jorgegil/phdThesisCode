#new experiments for ICA journal paper

library("RPostgreSQL")
library("Hmisc")
library("psych")
library("ineq")

# some constants
def.par <- par(no.readonly = TRUE)
margins <- c(0.25,0.25,0.25,0.25)
bins <- pretty(range(c(0, 100)), n=21)
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0.9,0.2,0.25)

#connect to database
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

#get regional centrality data sets
multimodal_centrality <- dbGetQuery(con,"SELECT road_id, node, randstad_code, all_cogn_angular_seg_close, all_cogn_angular_seg_betw,
    all_temporal_close, all_temporal_betw, local_cogn_angular_temp_close, local_cogn_angular_temp_betw,
    nonmotor_cogn_angular_temp_close, nonmotor_cogn_angular_temp_betw, local_cogn_angular_seg_close, local_cogn_angular_seg_betw,
    nonmotor_cogn_angular_seg_close, nonmotor_cogn_angular_seg_betw FROM analysis.regional_centrality_multimodal")
private_centrality <- dbGetQuery(con,"SELECT road_id, car_metric_close, car_metric_betw, car_temporal_close, car_temporal_betw, 
    car_angular_close, car_angular_betw, car_axial_close, car_axial_betw, car_continuity_close, car_continuity_betw,
    car_segment_close, car_segment_betw, nonmotor_angular_close, nonmotor_angular_betw, private_angular_close, private_angular_betw,
    private_temporal_close, private_temporal_betw FROM analysis.regional_centrality_private")
transit_centrality <- dbGetQuery(con,"SELECT multimodal_sid, stopname, rail_length_close, rail_length_betw, rail_stops_close, rail_stops_betw, 
    transit_length_close, transit_length_betw, transit_temporal_close, transit_temporal_betw, transit_stops_close, transit_stops_betw, 
    transit_transfer_close, transit_transfer_betw, tracks_length_close, tracks_length_betw, tracks_temporal_close, tracks_temporal_betw, 
    tracks_stops_close, tracks_stops_betw, tracks_transfer_close, tracks_transfer_betw FROM analysis.regional_centrality_transit")
transit_national_centrality <- dbGetQuery(con,"SELECT multimodal_sid, rail_length_close, rail_length_betw, rail_stops_close, rail_stops_betw, transit_length_close,
    transit_length_betw, transit_temporal_close, transit_temporal_betw, transit_stops_close, transit_stops_betw, transit_transfer_close, transit_transfer_betw 
    FROM analysis.national_centrality_transit")
rail_closeness <- dbGetQuery(con,"SELECT * FROM analysis.mobility_rail_closeness")
landuse_centrality <- dbGetQuery(con,"SELECT node, car_interfaces_angular_close_n, nonmotor_interfaces_angular_close_n, private_interfaces_angular_close_n,
    localtransit_interfaces_cogtopo_close_n, transit_interfaces_cogtopo_close_n, car_angular_close_n, nonmotor_angular_close_n, private_angular_close_n,
    localtransit_cogtopo_close_n, transit_cogtopo_close_n FROM analysis.regional_centrality_sample")

#get car counts
car_counts <- dbGetQuery(con,"SELECT road_nr, meter_id, weekday_aadt, workday_aadt, road_id,
    road_number, road_class, car_metric_close, car_metric_betw, car_angular_close,
    car_angular_betw, car_axial_close, car_axial_betw, car_continuity_close, car_continuity_betw,
    car_segment_close, car_segment_betw, car_temporal_close, car_temporal_betw, private_angular_close,
    private_angular_betw FROM analysis.mobility_car_counts")
car_counts <- merge(car_counts,multimodal_centrality[,c("road_id",
            "all_cogn_angular_seg_close", "all_cogn_angular_seg_betw",
            "all_temporal_close", "all_temporal_betw")],by="road_id")
#replace 0 by NA
car_counts[car_counts[,3] == 0 & !is.na(car_counts[,3]),3] <- NA
car_counts[car_counts[,4] == 0,4] <- NA

#get car network
car_network <- dbGetQuery(con,"SELECT sid, length, motorway, main, randstad, 
    randstad_code FROM network.roads_randstad WHERE car=True OR car IS NULL")

#get rail counts
rail_counts <- dbGetQuery(con,"SELECT * FROM analysis.mobility_rail_counts")

#get land use version 1
landuse <- dbGetQuery(con,"SELECT road_sid road_id, randstad_code, work, work_area, leisure, leisure_area, 
    activity, activity_area, work_200, leisure_200, activity_200, work_area_200, leisure_area_200, activity_area_200
    FROM analysis.roads_landuse_density")
landuse <- subset(landuse, !is.na(landuse$"work_200") | !is.na(landuse$"leisure_200") | !is.na(landuse$"activity_200"))
landuse$total_units <- landuse$"work_200"+landuse$"leisure_200"+landuse$"activity_200"
landuse$total_area <- landuse$"work_area_200"+landuse$"leisure_area_200"+landuse$"activity_area_200"
landuse <- merge(landuse,multimodal_centrality[,c("road_id","all_cogn_angular_seg_close", "all_cogn_angular_seg_betw",
    "all_temporal_close", "all_temporal_betw","nonmotor_cogn_angular_seg_close", "nonmotor_cogn_angular_seg_betw")],by="road_id",all=FALSE)
landuse <- merge(landuse,private_centrality[,c("road_id","car_metric_close", "car_metric_betw", "car_temporal_close", "car_temporal_betw", 
    "car_angular_close", "car_angular_betw", "car_axial_close", "car_axial_betw", "car_continuity_close", "car_continuity_betw",
    "car_segment_close", "car_segment_betw", "nonmotor_angular_close", "nonmotor_angular_betw", "private_angular_close", "private_angular_betw")],by="road_id",all.x=TRUE)
apply(landuse,2,as.numeric)

#get land use version 2
landuse <- dbGetQuery(con,"SELECT road_sid road_id, randstad_code, work_200, active_200, work_area_200, active_area_200
    FROM analysis.roads_landuse_density_full WHERE randstad_code != 'Outer ring' AND (work_200 >0 OR active_200>0)")
#landuse <- subset(landuse, !is.na(landuse$"work_200") | !is.na(landuse$"active_200"))
landuse$total_units <- landuse$"work_200"+landuse$"active_200"
landuse$total_area <- landuse$"work_area_200"+landuse$"active_area_200"
landuse <- merge(landuse,multimodal_centrality[,c("road_id","all_cogn_angular_seg_close", "all_cogn_angular_seg_betw",
        "all_temporal_close", "all_temporal_betw","nonmotor_cogn_angular_seg_close", "nonmotor_cogn_angular_seg_betw")],by="road_id",all=FALSE)
landuse <- merge(landuse,private_centrality[,c("road_id","car_temporal_close", "car_temporal_betw", "car_angular_close", "car_angular_betw", 
        "nonmotor_angular_close", "nonmotor_angular_betw", "private_temporal_close", "private_temporal_betw", "private_angular_close", "private_angular_betw")],by="road_id",all.x=TRUE)
apply(landuse,2,as.numeric)



#----- distance measure exploration -----
# only for car network

car_centrality <- private_centrality[!is.na(private_centrality[,2]),]
#exclude segments with low closeness values as these represent isolated islands. There's several dozens of islands
#and 1383 segments (if not more).
car_centrality <- subset(car_centrality,car_centrality$"car_angular_close" > 0.0000022)

par(mfrow=c(3,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(2,4,6,8,10,12,14,16,18)){
    hist(car_centrality[,i],col=colour,main=colnames(car_centrality)[i],xlab="",ylab="")
}
par(mfrow=c(3,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3,5,7,9,11,13,15,17,19)){
    hist(car_centrality[,i],col=colour,main=colnames(car_centrality)[i],xlab="",ylab="")
}
par(mfrow=c(3,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3,5,7,9,11,13,15,17,19)){
    plot(density(car_centrality[!is.na(car_centrality[,i]),i]),col=colour,main=colnames(car_centrality)[i],xlab="",ylab="")
}
par(mfrow=c(3,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3,5,7,9,11,13,15,17,19)){
    hist(log(car_centrality[,i]),col=colour,main=colnames(car_centrality)[i],xlab="",ylab="")
}

descriptive_car <- as.data.frame(round(psych::describe(car_centrality),digits=6))
descriptive_car$gini <- round(apply(car_centrality,2,Gini),digits=4)

#correlation between car network distance measures
cclose <- cor(car_centrality[,c(2,4,6,8,10,12)],use="complete.obs",method="pearson")
cbetw <- cor(car_centrality[,c(3,5,7,9,11,13)],use="complete.obs",method="pearson")
#pearson values were nonsense before because distribution is not normal, but also because of the islands
cclose <- cor(car_centrality[,c(2,4,6,8,10,12)],use="complete.obs",method="spearman")
cbetw <- cor(car_centrality[,c(3,5,7,9,11,13)],use="complete.obs",method="spearman")
#to be able to get p-values, but only pairwise, not the whole matrix
cclose.test <- cor.test(car_centrality[,2],car_centrality[,4],method="spearman")
#this is the way to get p-value matrices
cclose.pmatrix <- rcorr(as.matrix(car_centrality[,c(2,4,6,8,10,12)]),type="pearson")$P
cbetw.pmatrix <- rcorr(as.matrix(car_centrality[,c(3,5,7,9,11,13)]),type="pearson")$P
cclose.pmatrix <- rcorr(as.matrix(car_centrality[,c(2,4,6,8,10,12)]),type="spearman")$P
cbetw.pmatrix <- rcorr(as.matrix(car_centrality[,c(3,5,7,9,11,13)]),type="spearman")$P

#to show that R2 is the same as doing R^2, at least for pearson 
cclose.lm <- lm(car_centrality[,2] ~ car_centrality[,4])
summary(cclose.lm)$r.squared
cclose.lm <- lm(car_centrality[,2] ~ log(car_centrality[,4]))
summary(cclose.lm)$r.squared
(cor.test(car_centrality[,2],car_centrality[,4],method="pearson")$estimate)^2
(cor.test(car_centrality[,2],log(car_centrality[,4]),method="pearson")$estimate)^2
#so I stick with R as the other doesn't give anything extra and I'm not doing regression any way

#except to get the residuals
par(mfrow=c(1,1),mai= c(0.5,0.5,0.5,0.5), omi= c(0.5,0.5,0.5,0.5))
car_residuals <- data.frame(car_centrality$road_id)
cclose.lm <- lm(car_centrality[,2] ~ car_centrality[,4])
plot(car_centrality[,2],car_centrality[,4])
abline(cclose.lm,col="red",lty=2)
car_residuals$met_temp <- resid(cclose.lm)
plot(car_centrality$car_temporal_close,car_residuals$met_temp, ylab="Residuals", xlab="Temporal closeness",main="Metric closeness difference")
abline(0,0)
cclose.lm <- lm(car_centrality[,2] ~ car_centrality[,6])
car_residuals$met_ang <- resid(cclose.lm)
cclose.lm <- lm(car_centrality[,4] ~ car_centrality[,6])
car_residuals$temp_ang <- resid(cclose.lm)
cclose.lm <- lm(car_centrality[,6] ~ car_centrality[,8])
car_residuals$ang_ax <- resid(cclose.lm)
cclose.lm <- lm(car_centrality[,6] ~ car_centrality[,10])
car_residuals$ang_cont <- resid(cclose.lm)

car_residuals$met_temp_rank <- rank(car_centrality$car_metric_close)-rank(car_centrality$car_temporal_close)
car_residuals$met_ang_rank <- rank(car_centrality$car_metric_close)-rank(car_centrality$car_angular_close)
car_residuals$temp_ang_rank <- rank(car_centrality$car_temporal_close)-rank(car_centrality$car_angular_close)
car_residuals$ang_ax_rank <- rank(car_centrality$car_angular_close)-rank(car_centrality$car_axial_close)
car_residuals$ang_cont_rank <- rank(car_centrality$car_angular_close)-rank(car_centrality$car_continuity_close)


#---- write results to postgresql for mapping ----
output<-"car_residuals_data"
if(dbExistsTable(con,c("analysis",output))){
    dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),car_residuals) 


#---- calculate network characteristics ----
unique(car_network$randstad_code) #should not consider roads in the outer ring/buffer
# all roads
allroads_l <- round(sum(subset(car_network, car_network$randstad_code!="Outer ring")$length),0)
allroads_c <- nrow(subset(car_network, car_network$randstad_code!="Outer ring"))
# motorways
motorways_l <- round(sum(subset(car_network, car_network$motorway == T & car_network$randstad_code!="Outer ring")$length),0)
motorways_c <- nrow(subset(car_network, car_network$motorway == T & car_network$randstad_code!="Outer ring"))
# main
mainroads_l <- round(sum(subset(car_network, car_network$main == T & car_network$randstad_code!="Outer ring")$length),0)
mainroads_c <- nrow(subset(car_network, car_network$main == T & car_network$randstad_code!="Outer ring"))
# secondary roads
secroads_l <- round(sum(subset(car_network, is.na(car_network$main) & is.na(car_network$motorway) & car_network$randstad_code!="Outer ring")$length),0)
secroads_c <- nrow(subset(car_network, is.na(car_network$main) & is.na(car_network$motorway) & car_network$randstad_code!="Outer ring"))
#road type shares
round(motorways_l/allroads_l*100,2)
round(motorways_c/allroads_c*100,2)
round(mainroads_l/allroads_l*100,2)
round(mainroads_c/allroads_c*100,2)
round(secroads_l/allroads_l*100,2)
round(secroads_c/allroads_c*100,2)


#---- calculate flow shares table for main roads ----
allroads_flow <- apply(car_centrality[,c(3,5,7,9,11,13)],2,sum)
motorways_flow <- apply(car_centrality[(car_centrality$road_id %in% subset(car_network, car_network$motorway == T)$sid),c(3,5,7,9,11,13)],2,sum)
mainroads_flow <- apply(car_centrality[(car_centrality$road_id %in% subset(car_network, car_network$main == T)$sid),c(3,5,7,9,11,13)],2,sum)
round(motorways_flow/allroads_flow*100,2)
round(mainroads_flow/allroads_flow*100,2)
round((motorways_flow+mainroads_flow)/allroads_flow*100,2)


#---- checking the 80/20 rule ----
x <- c(0,1,20,100)
y <- c(0,20,80,100)
par(mfrow=c(1,1),mai= c(1.1,1.1,0,0), omi= c(0.5,0.5,0.5,0.5))
#fit first degree polynomial equation:
fit  <- lm(y~x)
#log
fit2 <- lm(y~log(x+1))
#inverse
fit3 <- lm(y~I(1/(x+1)))
#square
fit4 <- lm(y~sqrt(x))
#compare estimates of different equations
sse <- function(rhs, x, y) sort(sapply(rhs, function(rhs, x, y, verbose = TRUE) {
    fo <- as.formula(paste("y", rhs, sep = "~"))
    nms <- setdiff(all.vars(fo), c("x", "y"))
    start <- as.list(setNames(rep(1, length(nms)), nms))
    fm <- nls(fo, data.frame(x, y), start = start)
    if (verbose) { print(fm); cat("---\n") }
    deviance(fm)
}, x = x, y = y))
# modified equations to suit
rhs <- c("a*x+b", "a*x*x+b*x+c", "a*log(x+1)+b", "a*sqrt(x)+b", "a*(1/(x+1))+b","a*x/(1+b*x)")
sse(rhs, x, y)
#the best result comes from equation 6, actually an almost perfect fit!

#generate range of 50 numbers starting from 0 and ending at 100
xx <- seq(0,100, length=50)
par(mfrow=c(1,1),mai= c(1.1,1.1,0,0), omi= c(0.5,0.5,0.5,0.5))
plot(x,y, xlab="roads %", ylab="movement %",pch=19,cex=0.5)
#lines(xx, predict(fit, data.frame(x=xx)), col="red")
#lines(xx, predict(fit2, data.frame(x=xx)), col="green")
#lines(xx, predict(fit3, data.frame(x=xx)), col="blue")
#lines(xx, predict(fit4, data.frame(x=xx)), col="purple")
lines(xx, (21.1216*xx/(1+0.2053*xx)), col="red")
title(main="Flow model: y = 21.1216*x/(1+0.2053*x)",outer=TRUE)
#if I test the values for main roads:
(21.1216*0/(1+0.2053*0))
(21.1216*1/(1+0.2053*1))
(21.1216*5.44/(1+0.2053*5.44))
(21.1216*20/(1+0.2053*20))
(21.1216*100/(1+0.2053*100))

# but this only refered to the main roads, and these are not necessarily in the top 20% 
####

#---- taking actual top rank to get the total flow/betweenness in that ----
measures <- c(2,4,6,8,10,12) #closeness
measures <- c(3,5,7,9,11,13) #betweenness

flow_20 <- 0
flow_1 <- 0
n <- 0
for (i in measures){
    n <- n+1
    qnt <- quantile(car_centrality[,i],0.8)
    total <- sum(car_centrality[car_centrality[,i]>qnt,i])
    flow_20[n] <- round(total/sum(car_centrality[,i]),2)
    qnt <- quantile(car_centrality[,i],0.99)
    total <- sum(car_centrality[car_centrality[,i]>qnt,i])
    flow_1[n] <- round(total/sum(car_centrality[,i]),2)
}
flow_20
flow_1

# does top rank closeness and betweenness actually capture road designated hierarchy?
share_motor <- 0
share_main <- 0
share_combi <- 0
n <- 0
for (i in measures){
    n <- n+1
    qnt <- quantile(car_centrality[,i],0.9)
    ids <- car_centrality[car_centrality[,i]>qnt,1]
    share_motor[n] <- round(nrow(subset(car_network, car_network$motorway == T & car_network$sid %in% ids))/motorways_c,2)
    share_main[n] <- round(nrow(subset(car_network, car_network$main == T & car_network$sid %in% ids))/mainroads_c,2)
    share_combi[n] <- round(nrow(subset(car_network, (car_network$main == T | car_network$motorway == T) & car_network$sid %in% ids))
                            /(mainroads_c+motorways_c),2)
}
share_motor
share_main
share_combi


#---- correlation with car counts ----

par(mfrow=c(2,2),mai= c(0.5,0.5,0.5,0.5), omi= c(0.5,0.5,0.5,0.5))
par(mfrow=c(2,1),mai= c(3.5,1,1,1), omi= c(1,1,1,1),cex=3)
hist(car_counts[,3],col=colour,main="Weekday AADT",ylim=range(0,200),xlab="AADT volume")
hist(log(car_counts[,3]),col=colour,main="",ylim=range(0,200),xlab="AADT log(volume)")
hist(car_counts[,4],col=colour,main=colnames(car_counts)[4])
hist(log(car_counts[,4]),col=colour,main=paste("log ",colnames(car_counts)[4],sep=""))
car_counts$log_weekday_aadt <- log(car_counts[,3])
car_counts$log_workday_aadt <- log(car_counts[,4])

#exract two separate measurement sets as the values might correspond to two different years
#or maybe even calculation methods. should only be merged if ranked or scaled.
#But also set 1 is bimodal for workdays, which might indicate a difference in methods
car_counts_set1 <- subset(car_counts,nchar(car_counts$meter_id) == 4)
car_counts_set2 <- subset(car_counts,nchar(car_counts$meter_id) > 4)

hist(car_counts_set1[,22],col=colour,main=paste("Utrecht - ",colnames(car_counts)[22],sep=""))
hist(car_counts_set1[,23],col=colour,main=paste("Utrecht - ",colnames(car_counts)[23],sep=""))
hist(car_counts_set2[,22],col=colour,main=paste("Zuid Holland - ",colnames(car_counts)[22],sep=""))
hist(car_counts_set2[,23],col=colour,main=paste("Zuid Holland - ",colnames(car_counts)[23],sep=""))

# the counts seem to be bi-modal for workday data in Utrecht only,
# which is not good for any correlation
cor(as.matrix(car_counts[,c(22,8,18,10,12,14,16,20)]),use="complete.obs",method="pearson")[1,]
cor(as.matrix(car_counts[,c(22,9,19,11,13,15,17,21)]),use="complete.obs",method="pearson")[1,]

cor(as.matrix(car_counts[,c(3,8,18,10,12,14,16,20)]),use="complete.obs",method="spearman")[1,]
cor(as.matrix(car_counts[,c(3,9,19,11,13,15,17,21)]),use="complete.obs",method="spearman")[1,]
# with two separate sets the results are even more reasonable
# Utrecht set
cor(as.matrix(car_counts_set1[,c(22,8,18,10,12,14,16,20)]),use="complete.obs",method="pearson")[1,]
cor(as.matrix(car_counts_set1[,c(3,9,19,11,13,15,17,21)]),use="complete.obs",method="spearman")[1,]
# South Holland set
cor(as.matrix(car_counts_set2[,c(22,8,18,10,12,14,16,20)]),use="complete.obs",method="pearson")[1,]
cor(as.matrix(car_counts_set2[,c(3,9,19,11,13,15,17,21)]),use="complete.obs",method="spearman")[1,]

#decisions:
# will not use workday data, only wekday;
# will use logged values for counts with closeness, and pearson;
# can use raw values for counts with betweenness, and spearman;
# but can also log betweenness values and use pearson;
# will use the full set, not split into areas.
round(cor(as.matrix(car_counts[,c(22,8,18,10,12,14,16,20,24,26)]),use="complete.obs",method="pearson"),3)[1,]
round(rcorr(as.matrix(car_counts[,c(22,8,18,10,12,14,16,20,24,26)]))$P,digits=5)[1,]
round(cor(as.matrix(car_counts[,c(22,9,19,11,13,15,17,21,25,27)]),use="complete.obs",method="pearson"),3)[1,]
round(rcorr(as.matrix(car_counts[,c(22,9,19,11,13,15,17,21,25,27)]))$P,digits=5)[1,]

# the same goes for the plots
par(mfrow=c(1,1),mai= c(1.2,1.2,1,1), omi= c(1.2,1.2,1,1))
plot(car_counts[,10],car_counts[,3],pch=19,cex=0.5,xlab="angular closeness",ylab="car AADT")
plot(car_counts[,11],car_counts[,3],pch=19,cex=0.5,xlab="angular betweenness",ylab="car AADT")
plot(car_counts[,10],car_counts[,22],pch=19,cex=0.5,xlab="angular closeness",ylab="log car AADT")
plot(log(car_counts[,11]),car_counts[,22],pch=19,cex=0.5,xlab="log angular betweenness",ylab="log car AADT")
plot(rank(car_counts[,10]),rank(car_counts[,3]),pch=19,cex=0.5,xlab="rank angular closeness",ylab="rank car AADT")
plot(rank(car_counts[,11]),rank(car_counts[,3]),pch=19,cex=0.5,xlab="rank angular betweenness",ylab="rank car AADT")


#---- correlation with rail passenger counts ----
colnames(rail_counts)
colnames(rail_closeness)
#description of passenger counts data
par(mfrow=c(1,1),mai=c(1.1,1,1,1), omi=margins, yaxs="i", las=1)
hist(rail_closeness[,3],col=colour,xlab="Passengers",ylab="",main="2006 rail passenger count")
hist(log(rail_closeness[,3]),col=colour,xlab="log(Passengers)",ylab="",main="2006 rail passenger count")
round(psych::describe(rail_closeness[,3]),digits=6)

#description of centrality measures, focus on ones used later on
reg_betw <- c(7,13,15,17,19,21,23,43,47,37,41)
reg_close <- c(7,12,14,16,18,20,22,42,46,36,40)
nat_betw <- c(7,25,27,29,31,33,35)
nat_close <- c(7,24,26,28,30,32,34)
measures <- list(reg_betw=reg_betw,reg_close=reg_close,nat_betw=nat_betw,nat_close=nat_close)

for (i in 1:length(measures)){
    par(mfrow=c(4,3),mai=margins, omi=margins, yaxs="i", las=1)
    for(j in measures[[i]]){
        hist(rail_counts[,j],col=colour,main=colnames(rail_counts)[j],xlab="",ylab="")
    }
}

par(mfrow=c(3,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in reg_close){
    hist(rail_closeness[,i],col=colour,main=colnames(rail_closeness)[i],xlab="",ylab="")
}

# test different distance types and measures
# test integration of transit networks
# test integration of transit and private modes
# test impact of boundary (national/regional)
for (i in 1:length(measures)){
    print(round(cor(as.matrix(rail_counts[,measures[[i]]]),use="complete.obs",method="spearman"),3)[1,])
    print(round(rcorr(as.matrix(rail_counts[,measures[[i]]]))$P,digits=5)[1,])
}

rail_counts_reg <- rail_counts[!is.na(rail_counts$"reg_full_angular_seg_close"),]
for (i in 1:length(measures)){
    print(round(cor(as.matrix(rail_counts_reg[,measures[[i]]]),use="complete.obs",method="spearman"),3)[1,])
    print(round(rcorr(as.matrix(rail_counts_reg[,measures[[i]]]))$P,digits=5)[1,])
}

# test radius, but only with closeness

# rank correlation of stops, listing names

# rank hierarchy of modes


#---- test centrality against land use ----
sapply(landuse,class)
colnames(landuse)
landuse <- subset(landuse,landuse$"car_angular_close" > 0.0000022 | landuse$"nonmotor_angular_close" > 0)

#checking all landuse variables
round(psych::describe(landuse[,c(3:16)]),digits=6)
#the absolute numbers are not to be trusted as there is a considerable amount of double counting
#the land use is taken from previously calculated links to segments, and the same land use 
#can be linked to more than one segment. the correct calculation should have considered
#all land use points

par(mfrow=c(5,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3:16)){
    hist(landuse[,i],col=colour,main=colnames(landuse)[i],xlab="",ylab="")
}
par(mfrow=c(5,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3:16)){
    hist(log(landuse[,i]),col=colour,main=colnames(landuse)[i],xlab="",ylab="")
}

#making histograms only for relevant variables
par(mfrow=c(5,3),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3:16)){
    hist(log(landuse[,i]),col=colour,main=colnames(landuse)[i],xlab="",ylab="")
}

# landuse version 1
print(round(cor(as.matrix(landuse[,c(9:38)]),use="complete.obs",method="spearman"),3)[c(1:6),c(7:29)])
print(round(rcorr(as.matrix(landuse[,c(9:38)]))$P,digits=5)[c(1:6),c(7:29)])

# landuse version 2
round(psych::describe(landuse[,c(3:8)]),digits=6)

par(mfrow=c(3,2),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3:8)){
    hist(landuse[,i],col=colour,main=colnames(landuse)[i],xlab="",ylab="")
}
par(mfrow=c(3,2),mai=margins, omi=margins, yaxs="i", las=1)
for (i in c(3:8)){
    hist(log(landuse[,i]),col=colour,main=colnames(landuse)[i],xlab="",ylab="")
}

print(round(cor(as.matrix(landuse[,c(3:24)]),use="complete.obs",method="spearman"),3)[c(1:6),c(7:22)])
print(round(rcorr(as.matrix(landuse[,c(3:24)]))$P,digits=5)[c(1:6),c(7:22)])


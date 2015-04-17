#SOCIO_statistical_analysis

library("RPostgreSQL")
library("psych")
library("corrgram")
library("corrplot")
library("MASS")
library("reshape")
library("Hmisc") 
library("cluster") 
library("fpc")
library("pvclust")
library("RColorBrewer")
library("ggplot2")

def.par <- par(no.readonly = TRUE)

#connect to database
drv <-dbDriver("PostgreSQL")
con <-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

# some constants
margins <- c(0.25,0.25,0.5,0.25)
bins <- pretty(range(c(0, 100)), n=21)
filter <- 60
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0,0.4,0.8)


# 0. get the data #####
mon <- dbGetQuery(con,"SELECT pcode, individuals, households, male, female, age_0_14, age_15_24, age_25_44, age_45_64, age_65_74,
  age_75_more, household_size, oneperson_hh, nochildren_hh, withchildren_hh, low_income, high_income, cars_hh,
  workers, own_car, own_drivers_licence, primary_edu, middle_edu, secondary_edu, higher_edu 
  FROM survey.socio_economic_individuals_pcode WHERE individuals > 0")
large_sample <- dbGetQuery(con,paste0("SELECT pcode FROM survey.mobility_patterns_home_od WHERE journeys >= ",filter))
mon <- subset(mon, pcode %in% large_sample$pcode)
#remove NA: this is safe and temporary, the source data should be fixed to have 0
mon[is.na(mon)] <- 0

cbs <- dbGetQuery(con,paste0("SELECT pcode, population, households, male, female, age_0_14, age_15_24, age_25_44, age_45_64, age_65_74,
  age_75_more, household_size, oneperson_hh, nochildren_hh, withchildren_hh, household_income, low_income, high_income, cars_hh, 
  own_property, workers FROM survey.socio_economic_pcode WHERE population >= ",filter))


# 1. descriptive stats, histograms and Gini ######
#for the cbs data set
cbs_data <- cbs[4:ncol(cbs)]

par(mfrow=c(4,5),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(cbs_data)){
  hist(cbs_data[,i],col=colour,main=colnames(cbs_data)[i],xlab="",ylab="")
}
                           
desccbs <- as.data.frame(round(psych::describe(cbs_data),digits=4))
desccbs$gini <- round(apply(cbs_data,2,Gini),digits=4)
desccbs$variable <- colnames(cbs_data)

#for the mon data set
mon_data <- mon[4:ncol(mon)]

par(mfrow=c(5,5),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(mon_data)){
  hist(mon_data[,i],col=colour,main=colnames(mon_data)[i],xlab="",ylab="")
}

descmon <- as.data.frame(round(psych::describe(mon_data),digits=4))
descmon$gini <- round(apply(mon_data,2,Gini),digits=4)
descmon$variable <- colnames(mon_data)


# 2. transformation, test and correlation #####

#create shorter cbs data set removing the car and property ownership variables that have many NA
cbs_data_short <- cbs_data[1:(ncol(cbs_data)-3)]
cbs_data_short$workers <- cbs_data$workers

#this omits records containing invalid values: required for correlation and k-means
cbs_data <- na.omit(cbs_data)
cbs_data_short <- na.omit(cbs_data_short)
mon_data <- na.omit(mon_data)

#correlation
#cbs_matrix <- round(cor(cbs_data),digits=3)
#this is the same as eliminating records with NA
#cbs_matrix <- round(cor(cbs_data,use="complete.obs"),digits=3)
#this does pairwise elimination, should get more records but result is the same...
#cbs_matrix <- round(cor(cbs_data,use="pairwise.complete.obs"),digits=3)
#shoud be the same for the values in the short version
#cbs_short_matrix <- round(cor(cbs_data_short,use="pairwise.complete.obs"),digits=3)
cbs_rmatrix <- round(rcorr(as.matrix(cbs_data))$r,digits=3)
cbs_r2matrix <- round((rcorr(as.matrix(cbs_data))$r)^2,digits=3)
#calculate p values
cbs_pmatrix <- round(rcorr(as.matrix(cbs_data))$P,digits=5)

#graphic with corrgram package
#par(mfrow=c(1,1),mai=margins, omi=margins, ps=12)
#corrgram(cbs_data, order=FALSE,lower.panel=panel.shade, upper.panel=panel.ellipse,text.panel=panel.txt, main="Socio-economic variables correlation")
#corrgram(cbs_data, order=TRUE,add=TRUE, lower.panel=panel.shade, upper.panel=panel.ellipse,text.panel=panel.txt, main="Socio-economic variables correlation")
#with the corrplot package
par(mfrow=c(1,1),mai=margins, omi=margins, ps=10)
corrplot(cbs_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=cbs_pmatrix, sig.level=0.001)
corrplot(cbs_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=cbs_pmatrix, insig = "p-value", sig.level=-1)

#cbs_short correlation
cbs_short_rmatrix <- round(rcorr(as.matrix(cbs_data_short))$r,digits=3)
cbs_short_r2matrix <- round((rcorr(as.matrix(cbs_data_short))$r)^2,digits=3)
cbs_short_pmatrix <- round(rcorr(as.matrix(cbs_data_short))$P,digits=5)
#cbs_short correlogram
corrplot(cbs_short_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=cbs_short_pmatrix, sig.level=0.001)
corrplot(cbs_short_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=cbs_short_pmatrix, insig = "p-value", sig.level=-1)

#mon correlation
mon_rmatrix <- round(rcorr(as.matrix(mon_data))$r,digits=3)
mon_r2matrix <- round((rcorr(as.matrix(mon_data))$r)^2,digits=3)
mon_pmatrix <- round(rcorr(as.matrix(mon_data))$P,digits=5)
#mon correlogram
corrplot(mon_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=mon_pmatrix, sig.level=0.001)
corrplot(mon_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=mon_pmatrix, insig = "p-value", sig.level=-1)


# 3. clustering #####

#CBS data tests
#select relevant data including the postcodes, before removing records
cbs_data <- cbs[,!(names(cbs) %in% c("population","households","male","female","oneperson_hh","nochildren_hh","withchildren_hh","low_income","high_income","workers"))]
cbs_data <- cbs[,!(names(cbs) %in% c("population","households","male","female","age_0_14","household_size","workers"))]
cbs_data <- na.omit(cbs_data)
scbs_data <- cbs_data[2:ncol(cbs_data)]
scbs_sample1 <- scbs_data[sample(1:nrow(scbs_data), 500, replace=FALSE),]
scbs_sample2 <- scbs_data[sample(1:nrow(scbs_data), 500, replace=FALSE),]
cbs_clusters <- na.omit(cbs)

#scaling the variables for clustering
#between 0 and 1
#range01 <- function(x){(x-min(x, na.rm=TRUE))/(max(x, na.rm=TRUE)-min(x, na.rm=TRUE))}
#scbs_data <- as.data.frame(apply(cbs_data[,2:ncol(cbs_data)],2, range01))
#result identical to this package
scbs_data <- reshape::rescaler(scbs_data, type = "range")
#this standardizes the variables, centers the mean and scales the rest between -std and std
scbs_data <- scale(scbs_data)


# Hierarchical clustering #####
# can be important for cross validation of cluster results
# and definition of number of clusters
scbs_dist <- dist(scbs_data, method = "euclidean")
fit <- hclust(scbs_dist, method="ward") 
plot(fit) # display dendogram
groups <- cutree(fit, k=5) # cut tree into 5 clusters
# draw dendogram with red borders around the 5 clusters 
rect.hclust(fit, k=5, border="red")
rect.hclust(fit, k=7, border="green")
rect.hclust(fit, k=10, border="blue")
rect.hclust(fit, k=12, border="yellow")

selk <- c(5,7,10,12)
for (i in selk){
  cbs_clusters <- data.frame(cbs_clusters, cutree(hclust(scbs_dist, method="ward"), k=i))
  colnames(cbs_clusters)[ncol(cbs_clusters)] <- paste("h",i,sep="_")
}

# Ward Hierarchical Clustering with Bootstrapped p values. THIS TAKES AGES!!! Only for small data sets.
fit <- pvclust(t(scbs_data), method.hclust="ward",method.dist="euclidean")
plot(fit) # dendogram with p values
# add rectangles around groups highly supported by the data
pvrect(fit, alpha=.95)

# Doing a normal k-means method #####
# Determine number of clusters
screeplot <- (nrow(scbs_data)-1)*sum(apply(scbs_data,2,var))
#k-means for various number of k
for (i in 2:15) screeplot[i] <- sum(kmeans(scbs_data, centers=i)$withinss)
#scree plot
par(mfrow=c(1,1),mai=margins, omi=margins, ps=12)
plot(1:15, screeplot, type="b", xlab="Number of Clusters", ylab="Within groups sum of squares")

# calculate for a given k
cbs_fit <- kmeans(scbs_data, 7)
cbs_clusters <- data.frame(cbs_data, k_7=cbs_fit$cluster)
# for a given k get the cluster sizes
cbs_fit$size
# for a given k get the cluster centres (mean)
cbs_fit$centers

#k-means for group of selected k
selk <- c(4,7,8,10,12)
for (i in selk){
  cbs_clusters <- data.frame(cbs_clusters, kmeans(scbs_data, i)$cluster)
  colnames(cbs_clusters)[ncol(cbs_clusters)] <- paste("k_st",i,sep="_")
}


# k-medoids #####
#As an alternative use the k-medoids instead.
#This function has its own method for identifying k and standardizes de value if required
#This way get the representative medoid, and can still get all the stats

#get recommended k. the function gives many other values, but the k is weird and suggests mostly 2...
cbs_k <- pamk(scbs_data,krange=1:15,criterion="asw",scaling=TRUE,critout=TRUE)$nc
#testing different samples of the data can be good to check stability of the clusters
cbs_k <- pamk(scbs_sample1,krange=1:15,criterion="asw",scaling=TRUE,critout=TRUE)
cbs_k <- pamk(scbs_sample2,krange=1:15,criterion="asw",scaling=TRUE,critout=TRUE)

#calculate clusters for selected k
cbs_fit <- pam(scbs_data, 12, stand=TRUE)
#information about the cluster shape
cbs_fit$clusinfo
#id of the medoid of each cluster
cbs_fit$id.med
#value of the medoid of each cluster
cbs_fit$medoid
#other descriptive stats of the result
aggregate(scbs_data,by=list(cbs_fit$clustering),FUN=mean)
aggregate(scbs_data,by=list(cbs_fit$clustering),FUN=min)
aggregate(scbs_data,by=list(cbs_fit$clustering),FUN=max)
#write the results to the data table
cbs_clusters <- data.frame(cbs_data, km_7=cbs_fit$clustering)

#write selected k
selk <- c(2,4,7,8,10,12)
for (i in selk){
  cbs_clusters <- data.frame(cbs_clusters, pam(scbs_data, i, stand=TRUE)$clustering)
  colnames(cbs_clusters)[ncol(cbs_clusters)] <- paste("km",i,sep="_")
}

# Visualise clusters #####
# Cluster Plot against 1st 2 principal components, vary parameters for most readable graph
clusplot(scbs_data, cbs_data_clusters$km_10, color=TRUE, shade=TRUE, labels=2, lines=0)
# Centroid Plot against 1st 2 discriminant functions
plotcluster(scbs_data, cbs_fit$cluster)



## MON data #####
mon_clusters <- mon
mon_data <- mon[,!(names(mon) %in% c("individuals","households","male","female","age_0_14","household_size","own_drivers_licence","workers"))]
mon_data <- na.omit(mon_data)
smon_data <- mon_data[2:ncol(mon_data)]
smon_data <- scale(smon_data)
smon_dist <- dist(smon_data, method = "euclidean")

#hierarchical clustering
smon_fit <-hclust(smon_dist, method="ward")
plot(smon_fit)
# calculate and signal selected cluster solutions
selk <- c(2,3,4,5,6,7,8,9,10,12,13)
for (i in selk){
  rect.hclust(smon_fit, k=i, border=i)
  mon_clusters <- data.frame(mon_clusters, cutree(smon_fit, k=i))
  colnames(mon_clusters)[ncol(mon_clusters)] <- paste("h",i,sep="_")
}

#scree plot
screeplot <- (nrow(smon_data)-1)*sum(apply(smon_data,2,var))
#k-means for various number of k
for (i in 2:15) screeplot[i] <- sum(kmeans(smon_data, centers=i)$withinss)
#scree plot
par(mfrow=c(1,1),mai=margins, omi=margins, ps=12)
plot(1:15, screeplot, type="b", xlab="Number of Clusters", ylab="Within groups sum of squares")

# calculate selected cluster solutions
selk <- c(2,3,4,5,6,7,8,9,10,11,12)
for (i in selk){
  mon_fit <- pam(smon_data, i, stand=TRUE)
  mon_clusters <- data.frame(mon_clusters, mon_fit$clustering)
  colnames(mon_clusters)[ncol(mon_clusters)] <- paste("k",i,sep="_")
}

#visualise clusters
clusplot(smon_data, mon_clusters$k_8, color=TRUE, shade=TRUE, labels=0, lines=0)
# Centroid Plot against 1st 2 discriminant functions
plotcluster(smon_data, mon_clusters$k_8)



#description of cluster solutions - per cluster #####
mon_cluster_summary <- matrix(NA,0,9)
colnames(mon_cluster_summary) <- c("clusters","number","size","diameter","widest gap","avg_distance","silo_width","separation","avg_toother")
for (j in 37:ncol(mon_clusters)){
  mon_stats <- cluster.stats(d=smon_dist, mon_clusters[,j])
  mon_temp_summary <- matrix(NA,mon_stats$cluster.number,9)
   
  for (i in 1:mon_stats$cluster.number){
    mon_temp_summary[i,1] <- colnames(mon_clusters)[j]
    mon_temp_summary[i,2] <- i
    mon_temp_summary[i,3] <- round(mon_stats$cluster.size[i])
    # diameter is the maximum within cluster distance
    mon_temp_summary[i,4] <- round(mon_stats$diameter[i],4)
    # list of the widest gap within each cluster: might be identical to diameter?
    mon_temp_summary[i,5] <- round(mon_stats$cwidegap[i],4)
    # average within cluster distance
    mon_temp_summary[i,6] <- round(mon_stats$average.distance[i],4)
    # aveage cluster silhouette widhts
    mon_temp_summary[i,7] <- round(mon_stats$clus.avg.silwidths[i],4)
    # separation is the minimum between cluster distance
    mon_temp_summary[i,8] <- round(mon_stats$separation[i],4)
    # aveage between cluster distances
    mon_temp_summary[i,9] <- round(mon_stats$average.toother[i],4)
  }
  mon_cluster_summary <- rbind(mon_cluster_summary,mon_temp_summary)
}


# 4. Validation of clusters #####
#description of cluster solutions #####
#quality of solutions indices
mon_cluster_quality <- matrix(NA,(ncol(mon_clusters)-25),14)
colnames(mon_cluster_quality) <- c("clusters","number","within_ss","avg_within","avg_between","wb_ratio","avg_silhouette","widest_gap","g3","dunn","dunn2","ch","entropy","sep_index")

for (i in 26:ncol(mon_clusters)){
  mon_stats <- cluster.stats(d=smon_dist, mon_clusters[,i],wgap=TRUE,G3 = TRUE, sepindex=TRUE, sepprob=1)
  #,G2 = TRUE this is too slow
  r <- i-25
  mon_cluster_quality[r,1] <- colnames(mon_clusters)[i]
  #description - global
  mon_cluster_quality[r,2] <- mon_stats$cluster.number
  mon_cluster_quality[r,3] <- round(mon_stats$within.cluster.ss,digits=4)
  mon_cluster_quality[r,4] <- round(mon_stats$average.within,digits=4)
  mon_cluster_quality[r,5] <- round(mon_stats$average.between,digits=4)
  #ratio of within/between
  mon_cluster_quality[r,6] <- round(mon_stats$wb.ratio,digits=4)
  # calculates the average width of the silhouette of all observations. 0 is between clusters, 1 is well placed.
  mon_cluster_quality[r,7] <- round(mon_stats$avg.silwidth,digits=4)
  # The widest within cluster gap
  mon_cluster_quality[r,8] <- round(mon_stats$widestgap,digits=4)
  
  #quality tests
  #Goodman Kruskal -1 (inversion) 0 (no relation) 1 (agreement)
  mon_cluster_quality[r,9] <- round(mon_stats$g3,digits=4)
  #Dunn's validity index - the higher the better
  mon_cluster_quality[r,10] <- round(mon_stats$dunn,digits=4)
  # Another version of Dunn's index
  mon_cluster_quality[r,11] <- round(mon_stats$dunn2,digits=4)
  # Calinksy Harabasz index - the higher the better
  mon_cluster_quality[r,12] <- round(mon_stats$ch,digits=4)
  # distribution of memberships Meila - the higher the better
  mon_cluster_quality[r,13] <- round(mon_stats$entropy,digits=4)
  # Hennig - formalise separation between clusters, good for selecting number of clusters
  mon_cluster_quality[r,14] <- round(mon_stats$sindex,digits=4)
}

#line charts of the various indices 
#plot(mon_cluster_quality[1:11,6],type="l",col="red",ylab="G3",xlab="k",main="Hierarchical clustering")
#plot(mon_cluster_quality[1:11,7],type="l",col="green",ylab="Dunn",xlab="k",main="Hierarchical clustering")
#plot(mon_cluster_quality[1:11,8],type="l",col="blue",ylab="CH",xlab="k",main="Hierarchical clustering")
#plot(mon_cluster_quality[1:11,9],type="l",col="black",ylab="entropy",xlab="k",main="Hierarchical clustering")
for (i in 3:14){
  plot(mon_cluster_quality[12:22,i],type="l",col="red",ylab="index value",xlab="k",main=colnames(mon_cluster_quality)[i], xaxs="i",xaxt="n")
  axis(1, at=1:11, labels=mon_cluster_quality[12:22,2])
}

#Direct comparison between two cluster solutions
cs <- cluster.stats(d=smon_dist, mon_clusters$h_8,alt.clustering =mon_clusters$k_8,compareonly=TRUE)
#Corrected Rand Index - 0 (not agree) 1 (agree)
cs$corrected.rand
#Variation of information - 0 (similarity) > (variation)
cs$vi
cs <- cluster.stats(d=smon_dist, mon_clusters$h_4,alt.clustering =mon_clusters$k_4,compareonly=TRUE)
cs$corrected.rand
cs$vi

# for the selected clusters against the rest in the solution
mon_cluster_comparison <- matrix(NA,(ncol(mon_clusters)-36),4)
colnames(mon_cluster_comparison) <- c("k1","k2","cri","vi")
mon_cluster_comparison[,1] <- "k_4"

for (i in 36:ncol(mon_clusters)){
  mon_stats <- cluster.stats(d=smon_dist, mon_clusters[,i],alt.clustering = mon_clusters[,mon_cluster_comparison[1,1]],compareonly=TRUE)
  r <- i-36
  mon_cluster_comparison[r,2] <- colnames(mon_clusters)[i]
  mon_cluster_comparison[r,3] <- round(mon_stats$corrected.rand,digits=4)
  mon_cluster_comparison[r,4] <- round(mon_stats$vi,digits=4)
}

#compare share of k4 in k8, how it subdivides
k_share <- data.frame(count(mon_clusters,vars=c("k_4","k_8")))
k_share$share <- round(k_share$freq/merge(k_share,count(mon_clusters,"k_4"),by="k_4")$freq.y*100,digits=1)
x <- table(mon_clusters[,c("k_8","k_4")])
mosaicplot(x,shade=T)
x <- table(mon_clusters[,c("k_4","k_8")])
mosaicplot(x,shade=T)
#chisq.test(x)


# Produce thematic maps for expert inspection #####
#write results to postgresql for mapping
output<-"socio_economic_pcode_clusters"
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),cbs_clusters) 

output<-"socio_economic_individuals_pcode_clusters"
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),mon_clusters) 


# 5. Statistical description of socio-economic types #####

#k-medoid details of selected k=4
mon_fit <- pam(smon_data, 4, stand=TRUE)
#information about the cluster shape, done already. mon_fit$clusinfo
#descriptive statistics of clusters
k4_descriptive <- data.frame(variable=names(colMeans(mon_data[2:ncol(mon_data)])) , mean_sample=round(colMeans(mon_data[2:ncol(mon_data)]),digits=2))
k4_descriptive[,3:6] <- t(round(aggregate(mon_data[2:ncol(mon_data)],by=list(mon_fit$clustering),FUN=mean)[2:17],digits=2))
colnames(k4_descriptive)[3:6] <- c("mean_1","mean_2","mean_3","mean_4")
k4_descriptive[,7:10] <- t(round(aggregate(mon_data[2:ncol(mon_data)],by=list(mon_fit$clustering),FUN=min)[2:17],digits=2))
colnames(k4_descriptive)[7:10] <- c("min_1","min_2","min_3","min_4")
k4_descriptive[,11:14] <- t(round(aggregate(mon_data[2:ncol(mon_data)],by=list(mon_fit$clustering),FUN=max)[2:17],digits=2))
colnames(k4_descriptive)[11:14] <- c("max_1","max_2","max_3","max_4")

#value of the medoid of each cluster must be taken from the non-scaled data
k4_scaled <- data.frame(variable=colnames(mon_fit$medoids), t(round(mon_fit$medoids,digits=4)))
#colnames(k4_scaled) <- c("variable",rownames(mon_data[mon_fit$id.med,]))
colnames(k4_scaled) <- c("variable",mon_clusters[mon_fit$id.med,]$pcode)
k4_scaled[,6:9] <- t(round(aggregate(smon_data,by=list(mon_fit$clustering),FUN=mean)[2:17],digits=4))
colnames(k4_scaled)[6:9] <- c("mean_1","mean_2","mean_3","mean_4")

#k-medoid details of selected k=8
mon_fit <- pam(smon_data, 8, stand=TRUE)
#descriptive statistics of clusters
k8_descriptive <- data.frame(variable=names(colMeans(mon_data[2:ncol(mon_data)])) , mean_sample=round(colMeans(mon_data[2:ncol(mon_data)]),digits=2))
k8_descriptive[,3:10] <- t(round(aggregate(mon_data[2:ncol(mon_data)],by=list(mon_fit$clustering),FUN=mean)[2:17],digits=2))
colnames(k8_descriptive)[3:10] <- c("mean_1","mean_2","mean_3","mean_4","mean_5","mean_6","mean_7","mean_8")

#value of the medoid of each cluster must be taken from the non-scaled data
k8_scaled <- data.frame(variable=colnames(mon_fit$medoids), t(round(mon_fit$medoids,digits=4)))
colnames(k8_scaled) <- c("variable",mon_clusters[mon_fit$id.med,]$pcode)
k8_scaled[,10:17] <- t(round(aggregate(smon_data,by=list(mon_fit$clustering),FUN=mean)[2:17],digits=4))
colnames(k8_scaled)[10:17] <- c("mean_1","mean_2","mean_3","mean_4","mean_5","mean_6","mean_7","mean_8")

#heatmap of the means and medoids
par(mar=c(2,8,2,2))
data_matrix <- t(data.matrix(apply(k8_scaled[,10:17],2,rev)))
pal <- rev(brewer.pal(11,"RdBu"))
breaks <- seq(-2.5,3,0.5)
image(x=1:nrow(data_matrix),y=1:ncol(data_matrix),z=data_matrix,axes=FALSE,xlab="",ylab="",col=pal[1:(length(breaks)-1)],breaks=breaks)
text(1:nrow(data_matrix),par("usr")[4]+1, labels=colnames(k8_scaled[,10:17]),xpd=TRUE,cex=0.85)
axis(2,at=1:ncol(data_matrix),labels=colnames(data_matrix),col="white",las=1,cex.axis=0.85)
abline(h=c(1:ncol(data_matrix))+0.5,v=c(1:nrow(data_matrix))+0.5,col="white",lwd=1,xpd=FALSE)

data_matrix <- t(data.matrix(apply(k8_scaled[,2:9],2,rev)))
image(x=1:nrow(data_matrix),y=1:ncol(data_matrix),z=data_matrix,axes=FALSE,xlab="",ylab="",col=pal[1:(length(breaks)-1)],breaks=breaks)
text(1:nrow(data_matrix),par("usr")[4]+1, labels=colnames(k8_scaled[,2:9]),xpd=TRUE,cex=0.85)
axis(2,at=1:ncol(data_matrix),labels=colnames(data_matrix),col="white",las=1,cex.axis=0.85)
abline(h=c(1:ncol(data_matrix))+0.5,v=c(1:nrow(data_matrix))+0.5,col="white",lwd=1,xpd=FALSE)


# 6. Visualisation of socio-economic types #####

#this was the first version, scaled but with different range between variables
smon_data <- data.frame(pcode=mon_data$pcode,scale(mon_data[2:ncol(mon_data)]))
#this is an alternative, goes between 0 and 1 but retains the centre. However the centre value is weird
smon_data <- data.frame(pcode=mon_data$pcode,scale(mon_data[2:ncol(mon_data)],center=TRUE,scale=FALSE))
smon_data <- data.frame(pcode=smon_data$pcode,apply(smon_data,2,function(x)round((x-min(x))/(max(x)-min(x)),4)))
#this is the best solution, goes between -1 and 1 retaining the centre at 0. range is not maxed like in most parallel plots.
smon_data <- data.frame(pcode=mon_data$pcode,scale(mon_data[2:ncol(mon_data)],center=TRUE,scale=FALSE))
smon_data <- data.frame(pcode=smon_data$pcode,apply(smon_data[2:ncol(mon_data)],2,function(x)round(x*(1/max(abs(max(x)),abs(min(x)))),4)))

#add the selected cluster solutions
smon_data$k_4 <- mon_clusters$k_4
smon_data$k_8 <- mon_clusters$k_8

#recalculate the medoids and means based on the new range
k4_means <- data.frame(pcode=k4_scaled$variable,t(subset(smon_data,smon_data$pcode %in% colnames(k4_scaled)[2:5])[,2:17]),t(aggregate(smon_data[,2:17],by=list(smon_data$k_4),FUN=mean))[2:17,])
#the medoids values are in the wrong order, fix it
for (i in 2:5) k4_means[,i] <- t(subset(smon_data,smon_data$pcode == colnames(k4_scaled)[i])[,2:17])
colnames(k4_means) <- colnames(k4_scaled)

k8_means <- data.frame(pcode=k8_scaled$variable,t(subset(smon_data,smon_data$pcode %in% colnames(k8_scaled)[2:9])[,2:17]),t(aggregate(smon_data[,2:17],by=list(smon_data$k_8),FUN=mean))[2:17,])
#the medoids values are in the wrong order, fix it
for (i in 2:9) k8_means[,i] <- t(subset(smon_data,smon_data$pcode == colnames(k8_scaled)[i])[,2:17])
colnames(k8_means) <- colnames(k8_scaled)


#my chosen colour brewer palettes
clusterpal <- brewer.pal(8,"Set1")
variablepal <- brewer.pal(5,"Pastel1")
#correspondence between cluster number and palette colours
cluster4col <- c(clusterpal[2],clusterpal[3],clusterpal[1],clusterpal[4])
cluster8col <- c(clusterpal[2],clusterpal[3],clusterpal[7],clusterpal[8],clusterpal[4],clusterpal[5],clusterpal[1],clusterpal[6])


# Boxplots for the clusters #####
# (parallel coords might not be suitable) with the mean overlaid
#sectors of variables are indicated and coloured
par(mfrow=c(4,2),mai=c(0.25,0.25,0.25,0.25), omi=c(1,0.25,0.25,0.25))
for (i in 1:8){
  boxplot(subset(smon_data,k_8==i)[,2:17], ylim=c(-1,1),main=paste("Cluster ",i,sep=""),lwd=0.5, axes=FALSE, frame.plot=TRUE)
  abline(h=0,col="black",lty=3)
  lines(k8_means[,9+i],lwd=3,col=cluster8col[i])
  if (i <= 6) axis(side=1,at=c(1:16),labels=FALSE)
  if (i > 6) axis(side=1,at=c(1:16),labels=colnames(smon_data)[2:17],las=2)
  axis(side=2, labels=TRUE)
  coord <- par("usr")
  rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
  rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
  rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
  rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
  rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
}
title("Distribution of variables in each cluster",outer=TRUE)

#4 clusters
par(mfrow=c(2,2),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25))
for (i in 1:4){
  boxplot(subset(smon_data,k_4==i)[,2:17], ylim=c(-1,1),main=paste("Cluster ",i,sep=""),lwd=0.5, axes=FALSE, frame.plot=TRUE)
  abline(h=0,col="black",lty=3)
  lines(k4_means[,5+i],lwd=3,col=cluster4col[i])
  if (i <= 2) axis(side=1,at=c(1:16),labels=FALSE)
  if (i > 2) axis(side=1,at=c(1:16),labels=colnames(smon_data)[2:17],las=2)
  axis(side=2, labels=TRUE)
  coord <- par("usr")
  rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
  rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
  rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
  rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
  rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
}
title("Distribution of variables in each cluster",outer=TRUE)

par(def.par)


# Boxplots for the individual variables #####
# with colour indicating each cluster
par(mfrow=c(4,4),mai=c(0.25,0.25,0.25,0.25), omi=margins)
for (i in 2:17){
  boxplot(smon_data[,i]~smon_data$k_8,col=cluster8col,main=colnames(smon_data)[i],ylim=c(-1,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
  abline(h=0,col="black",lty=3)
  if (i <= 13) axis(side=1,at=c(1:8),labels=FALSE)
  if (i > 13) axis(side=1,at=c(1:8))
  axis(side=2, labels=TRUE)
}
title("Position of clusters in each variable",outer=TRUE)

#4 clusters
par(mfrow=c(4,4),mai=c(0.25,0.25,0.25,0.25), omi=margins)
for (i in 2:17){
  boxplot(smon_data[,i]~smon_data$k_4,col=cluster4col,main=colnames(smon_data)[i],ylim=c(-1,1),lwd=0.5, axes=FALSE, frame.plot=TRUE)
  abline(h=0,col="black",lty=3)
  if (i <= 13) axis(side=1,at=c(1:4),labels=FALSE)
  if (i > 13) axis(side=1,at=c(1:4))
  axis(side=2, labels=TRUE)
}
title("Position of clusters in each variable",outer=TRUE)


# Multi line plots for the means #####
# with colour indicating each cluster
par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25))
plot(k8_means$mean_1,type="l",ylim=c(-1,1),col=cluster8col[1],lwd=3,xaxt="n")
abline(h=0,col="black",lty=3)
for (i in 2:8) lines(k8_means[,9+i],type="l",col=cluster8col[i],lwd=3)
axis(1,at=1:nrow(k8_means),labels=k8_means$variable,cex.axis=0.85, las=2)
title("Mean of clusters",outer=TRUE)
coord <- par("usr")
rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
legend(x="top",legend=c(1:8),ncol=8,cex=1,bty="n",col=cluster8col,lty=1,lwd=3,xpd=TRUE)

#4 clusters
par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25))
plot(k4_means$mean_1,type="l",ylim=c(-1,1),col=cluster4col[1],lwd=3,xaxt="n")
abline(h=0,col="black",lty=3)
for (i in 2:4) lines(k4_means[,5+i],type="l",col=cluster4col[i],lwd=3)
axis(1,at=1:nrow(k4_means),labels=k4_means$variable,cex.axis=0.85, las=2)
title("Mean of clusters",outer=TRUE)
coord <- par("usr")
rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
legend(x="top",legend=c(1:4),ncol=4,cex=1,bty="n",col=cluster4col,lty=1,lwd=3,xpd=TRUE)


#and the same for the medoids
par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25))
plot(k8_means[,2],type="l",ylim=c(-1,1),col=cluster8col[1],lwd=3,xaxt="n")
abline(h=0,col="black",lty=3)
for (i in 2:8) lines(k8_means[,1+i],type="l",col=cluster8col[i],lwd=3)
axis(1,at=1:nrow(k8_means),labels=k8_means$variable,cex.axis=0.85, las=2)
title("Medoid of clusters",outer=TRUE)
coord <- par("usr")
rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
legend(x="top",legend=c(1:8),ncol=8,cex=1,bty="n",col=cluster8col,lty=1,lwd=3,xpd=TRUE)

#4 clusters
par(mfrow=c(1,1),mai=c(0.25,0.25,0.25,0.25), omi=c(1.5,0.25,0.25,0.25))
plot(k4_means[,2],type="l",ylim=c(-1,1),col=cluster4col[1],lwd=3,xaxt="n")
abline(h=0,col="black",lty=3)
for (i in 2:4) lines(k4_means[,1+i],type="l",col=cluster4col[i],lwd=3)
axis(1,at=1:nrow(k4_means),labels=k4_means$variable,cex.axis=0.85, las=2)
title("Medoid of clusters",outer=TRUE)
coord <- par("usr")
rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
legend(x="top",legend=c(1:4),ncol=4,cex=1,bty="n",col=cluster4col,lty=1,lwd=3,xpd=TRUE)


#hand-made parallel plots are possible but not useful unless a density of plot
#is achieved. I think the same or better is achieved with the boxplots above.
par(mfrow=c(4,2),mai=c(0.25,0.25,0.25,0.25), omi=c(1,0.25,0.25,0.25))
for (i in 1:8){
  plot_data <- subset(smon_data,k_8==i)
  plot(as.numeric(plot_data[i,2:17]),type="l",ylim=c(-1,1),main=paste("Cluster ",i,sep=""),lwd=0.5, axes=FALSE, frame.plot=TRUE, col=paste(cluster8col[i],"44",sep=""))
  abline(h=0,col="black",lty=3)
  for (j in 2:nrow(plot_data))  lines(as.numeric(plot_data[j,2:17]),lwd=0.5,col=paste(cluster8col[i],"44",sep=""))
  if (i <= 6) axis(side=1,at=c(1:16),labels=FALSE)
  if (i > 6) axis(side=1,at=c(1:16),labels=colnames(smon_data)[2:17],las=2)
  axis(side=2, labels=TRUE)
  coord <- par("usr")
  rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2)
  rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2)
  rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2)
  rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2)
  rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2)
}
title("Distribution of variables in each cluster",outer=TRUE)

#transparent rectangles
rect(coord[1],coord[3],5.5,coord[4],border=variablepal[1],lwd=2,col=paste(variablepal[1],"22",sep=""))
rect(5.5,coord[3],8.5,coord[4],border=variablepal[2],lwd=2,col=paste(variablepal[2],"22",sep=""))
rect(8.5,coord[3],10.5,coord[4],border=variablepal[3],lwd=2,col=paste(variablepal[3],"22",sep=""))
rect(10.5,coord[3],12.5,coord[4],border=variablepal[4],lwd=2,col=paste(variablepal[4],"22",sep=""))
rect(12.5,coord[3],coord[2],coord[4],border=variablepal[5],lwd=2,col=paste(variablepal[5],"22",sep=""))


### these don't work
#parallel coordinates plots of the clusters. try to overlay mean and lighten lines
#not possible with this function that automatically rescales each individual variable for every cluster.
par(mfrow=c(4,2),mai=margins, omi=margins, yaxs="i", las=1, yaxp=c(-3,3,1))
parcoord(subset(smon_data,k_8==1)[,2:17])
parcoord(subset(smon_data,k_8==2)[,2:17])
parcoord(subset(smon_data,k_8==3)[,2:17])
parcoord(subset(smon_data,k_8==4)[,2:17])
parcoord(subset(smon_data,k_8==5)[,2:17])
parcoord(subset(smon_data,k_8==6)[,2:17])
parcoord(subset(smon_data,k_8==7)[,2:17])
parcoord(subset(smon_data,k_8==8)[,2:17])


#cleanup
rm(list=ls())
library("RPostgreSQL")
library("Hmisc")
library("corrgram")
library("corrplot")


drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5432", user="postgres")

rail_counts <- dbGetQuery(con,"SELECT * FROM analysis.mobility_rail_counts")
rail_closeness <- dbGetQuery(con,"SELECT * FROM analysis.mobility_rail_closeness")

# some constants
margins <- c(0.25,0.25,0.5,0.25)
bins <- pretty(range(c(0, 100)), n=21)
filter <- 60
twocolour <- c(rgb(0.6,0.05,0.1),rgb(1,0.3,0.35))
colour <- rgb(0,0.4,0.8)


#prepare rail counts data
#national analysis
rail_counts_national <- data.frame(rail_counts[5:7], rail_counts[24:35])
rail_counts_national <- na.omit(rail_counts_national)
rail_counts_national <- data.frame(log(rail_counts_national[1:3]+1),rail_counts_national[4:ncol(rail_counts_national)])
rail_counts_national_rank <- data.frame(apply(-rail_counts_national,2,rank,ties.method = "random"))

#regional analysis
#rail_counts_regional <- data.frame(rail_counts[5:7], rail_counts[12:23],rail_counts[36:ncol(rail_counts)])
rail_counts_regional <- data.frame(rail_counts[5:7], rail_counts[12:23],rail_counts[36:37],rail_counts[40:55])
rail_counts_regional <- na.omit(rail_counts_regional)
rail_counts_regional <- data.frame(log(rail_counts_regional[1:3]+1),rail_counts_regional[4:ncol(rail_counts_regional)])
rail_counts_regional_rank <- data.frame(apply(-rail_counts_regional,2,rank,ties.method = "random"))

#regional closeness
rail_counts_closeness <- na.omit(rail_closeness)
rail_counts_closeness <- data.frame(log(rail_counts_closeness[3]+1),rail_counts_closeness[4:ncol(rail_counts_closeness)])
rail_counts_closeness_rank <- data.frame(apply(-rail_counts_closeness,2,rank,ties.method = "random"))

#for the most recent counts, very few counts
rail_counts_data <- data.frame(rail_counts[8:10], rail_counts[24:ncol(rail_counts)])
rail_counts_data <- data.frame(rail_counts[8:10], rail_counts[12:23])

#histograms of the data sets
par(mfrow=c(3,5),mai=margins, omi=margins, yaxs="i", las=1)
for (i in 1:ncol(rail_counts_national)){
  hist(rail_counts_national[,i],col=colour,main=colnames(rail_counts_national)[i],xlab="",ylab="")
}
for (i in 1:ncol(rail_counts_regional)){
  hist(rail_counts_regional[,i],col=colour,main=colnames(rail_counts_regional)[i],xlab="",ylab="")
}
for (i in 1:ncol(rail_counts_closeness)){
  hist(rail_counts_closeness[,i],col=colour,main=colnames(rail_counts_closeness)[i],xlab="",ylab="")
}

#simple correlation
cor(rail_counts_national[1:3],rail_counts_national[4:ncol(rail_counts_national)])
cor(rail_counts_regional[1:3],rail_counts_regional[4:ncol(rail_counts_regional)])
cor(rail_counts_closeness[1],rail_counts_closeness[2:ncol(rail_counts_closeness)])
cor(rail_counts_closeness_rank[1],rail_counts_closeness_rank[2:ncol(rail_counts_closeness)])

#correlation matrices for rail centrality with rail counts
national_counts_rmatrix <- round(rcorr(as.matrix(rail_counts_national))$r,digits=3)
national_counts_r2matrix <- round((rcorr(as.matrix(rail_counts_national))$r)^2,digits=3)
national_counts_pmatrix <- round(rcorr(as.matrix(rail_counts_national))$P,digits=5)

regional_counts_rmatrix <- round(rcorr(as.matrix(rail_counts_regional))$r,digits=3)
regional_counts_r2matrix <- round((rcorr(as.matrix(rail_counts_regional))$r)^2,digits=3)
regional_counts_pmatrix <- round(rcorr(as.matrix(rail_counts_regional))$P,digits=5)
regional_rank_rmatrix <- round(rcorr(as.matrix(rail_counts_regional_rank))$r,digits=3)
regional_rank_r2matrix <- round((rcorr(as.matrix(rail_counts_regional_rank))$r)^2,digits=3)
regional_rank_pmatrix <- round(rcorr(as.matrix(rail_counts_regional_rank))$P,digits=5)

closeness_counts_rmatrix <- round(rcorr(as.matrix(rail_counts_closeness))$r,digits=3)
closeness_counts_r2matrix <- round((rcorr(as.matrix(rail_counts_closeness))$r)^2,digits=3)
closeness_counts_pmatrix <- round(rcorr(as.matrix(rail_counts_closeness))$P,digits=5)
closeness_counts_matrix <- data.frame(closeness_counts_rmatrix[,1],closeness_counts_r2matrix[,1],closeness_counts_pmatrix[,1])
closeness_rank_rmatrix <- round(rcorr(as.matrix(rail_counts_closeness_rank))$r,digits=3)
closeness_rank_r2matrix <- round((rcorr(as.matrix(rail_counts_closeness_rank))$r)^2,digits=3)
closeness_rank_pmatrix <- round(rcorr(as.matrix(rail_counts_closeness_rank))$P,digits=5)
closeness_rank_matrix <- data.frame(closeness_rank_rmatrix[,1],closeness_rank_r2matrix[,1],closeness_rank_pmatrix[,1])

#correlogram
par(mfrow=c(1,1),mai=margins, omi=margins, ps=10)
corrplot(national_counts_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=national_counts_pmatrix, sig.level=0.001)
corrplot(national_counts_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=national_counts_pmatrix, insig = "p-value", sig.level=-1)

corrplot(regional_counts_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=regional_counts_pmatrix, sig.level=0.001)
corrplot(regional_counts_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=regional_counts_pmatrix, insig = "p-value", sig.level=-1)

corrplot(regional_rank_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=regional_rank_pmatrix, sig.level=0.001)
corrplot(regional_rank_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=regional_rank_pmatrix, insig = "p-value", sig.level=-1)

corrplot(closeness_counts_rmatrix, method="number",type="lower",cl.pos="n",tl.col="black",tl.pos="lt",p.mat=closeness_counts_pmatrix, sig.level=0.001)
corrplot(closeness_counts_rmatrix, method="shade",type="upper",add=TRUE,cl.pos="n",tl.pos="n",p.mat=closeness_counts_pmatrix, insig = "p-value", sig.level=-1)


#rank of stations from counts and names
rank_names <- rail_counts[which(!is.na(rail_counts$reg_mm_temporal_close)),c("stopname","y2006","reg_mm_temporal_close","reg_mm_temporal_betw","reg_nonmotor_angular_seg_betw","reg_nonmotor_temporal_ped_betw")]
rank_names$closerank <- rank(rank_names$reg_mm_temporal_close)
rank_names$betwrank <- rank(rank_names$reg_mm_temporal_betw)
rank_names$cogbetwrank <- rank(rank_names$reg_nonmotor_angular_seg_betw)
rank_names$pedbetwrank <- rank(rank_names$reg_nonmotor_temporal_ped_betw)
rank_names$combinedrank <- rank_names$closerank+rank_names$betwrank

rank_movement <- rank_names[order(-rank_names$y2006), ]
rank_centrality <- rank_names[order(-rank_names$combinedrank), ]
View(rank_names[order(-rank_names$pedbetwrank), "stopname"])
View(rank_names[order(-rank_names$cogbetwrank), "stopname"])

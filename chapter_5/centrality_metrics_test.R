#calculate centrality for various maps around the Amsterdam area

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
  mode <- setup[1]
  metrics <- setup[2]
  boundary <- setup[3]
}else{
  #select mode: nonmotor, car, private, all, transit
  mode<-"car"
  #select distance metrics: metric,temporal,axial+0.000001 axial,cumangular angular,continuity_v2+0.000001 continuity,segment+0.000001 segment
  metrics<-"metric,temporal,axial+0.000001 axial,cumangular angular,continuity_v2+0.000001 continuity,segment+0.000001 segment"
  #select the boundary of analysis: study_area,study_area_buffer,analysis_area_centre,analysis_area_north,analysis_area_east
  boundary <- "study_area"
}

#get background network
if (mode=="nonmotor")sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad 
        WHERE (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL)
        AND ST_Intersects(the_geom,(SELECT the_geom FROM survey.amsterdam_boundaries WHERE code='",boundary,"'))",sep="")
if (mode=="car")sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE (car=TRUE OR car IS NULL)
        AND ST_Intersects(the_geom,(SELECT the_geom FROM survey.amsterdam_boundaries WHERE code='",boundary,"'))",sep="")
if (mode=="private")sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad 
		WHERE (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL OR car=TRUE OR car IS NULL)
        AND ST_Intersects(the_geom,(SELECT the_geom FROM survey.amsterdam_boundaries WHERE code='",boundary,"'))",sep="")
if (mode=="all")sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE 
		(mobility='public' OR (mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL OR car=TRUE OR car IS NULL))) 
		AND ST_Intersects(the_geom,(SELECT the_geom FROM survey.amsterdam_boundaries WHERE code='",boundary,"'))",sep="")
if (mode=="transit")sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE 
		(mobility='public' OR (mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))) 
		AND ST_Intersects(the_geom,(SELECT the_geom FROM survey.amsterdam_boundaries WHERE code='",boundary,"'))",sep="")

sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#prepare data frame for results
net <- V(g)$name
metrics<-list.edge.attributes(g)
nmetrics<-length(metrics)
centrality<-as.data.frame(matrix(NA,length(net),nmetrics*2))
rownames(centrality)<-net
for (m in 1:nmetrics){
  colnames(centrality)[(m*2)-1]<-paste(boundary,metrics[m],"close",sep="_")
  colnames(centrality)[(m*2)]<-paste(boundary,metrics[m],"betw",sep="_") 
}

for (i in 1:length(metrics)){
  #calculate closeness centrality
  cloN<-closeness(g,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  centrality[,((i*2)-1)]<-cloN[match(rownames(centrality),names(cloN))]
  #calculate betweenness centrality
  betN<-betweenness(g,directed=F,weights=get.edge.attribute(g, metrics[i]))
  centrality[,(i*2)]<-betN[match(rownames(centrality),names(betN))]
}
#write the result to the database
output<-paste("amsterdam_centrality",mode,boundary,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),centrality) 

#clean up
dbDisconnect(con)
rm(list = ls())
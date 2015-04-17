#calculate regional private centrality
#FOR ALL PRIVATE MODES (COMBINED AND IN TURN)

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
  mode<-setup[1]
  metrics<-setup[2]
}else{
  #select mode: nonmotor, car, private, all
  mode<-"car"
  #select distance metrics: metric,cumangular angular,temporal,axial+0.000001 axial,continuity_v2+0.000001 continuity,segment+0.000001 segment
  metrics<-"cumangular angular"
}

#get background private network
if (mode=="nonmotor"){sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
                     osql<-paste("CREATE TEMP TABLE temp_origins AS SELECT sid FROM network.roads_randstad 
                     WHERE (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL) AND randstad_code<>'Outer ring'",
                     "INSERT INTO temp_origins SELECT road_sid FROM network.areas_randstad WHERE randstad_code<>'Outer Ring'",
                     "SELECT sid as road_id FROM temp_origins",sep=";")}
if (mode=="car"){sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE car=TRUE OR car IS NULL",sep="")
                     osql<-"SELECT sid as road_id FROM network.roads_randstad WHERE (car=TRUE OR car IS NULL) AND randstad_code<>'Outer ring'"}
if (mode=="private"){sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad 
					WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL OR car=TRUE OR car IS NULL",sep="")
                     osql<-paste("CREATE TEMP TABLE temp_origins AS SELECT sid FROM network.roads_randstad WHERE randstad_code<>'Outer ring'",
                     "INSERT INTO temp_origins SELECT road_sid FROM network.areas_randstad WHERE randstad_code<>'Outer Ring'",
                     "SELECT sid as road_id FROM temp_origins",sep=";")}

sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#get origin links, removing isolated lines
net <- V(g)$name
#o<- dbGetQuery(con,osql)
#o<-subset(o,road_id %in% net)

#prepare data frame for results
metrics<-list.edge.attributes(g)
#centrality<-data.frame(road_id=o$road_id)
centrality<-data.frame(road_id=net)

for (i in 1:length(metrics)){
  #calculate closeness centrality
  cloN<-closeness(g,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  #vids=V(g)[name %in% o$road_id],
  #add new column to output data
  centrality$new<-cloN[match(centrality$road_id,names(cloN))]
  #rename new column with name of weight
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"close",sep="_")
  #calculate betweenness centrality
  betN<-betweenness(g,directed=F,weights=get.edge.attribute(g, metrics[i]))
  #betN<-betweenness(g,directed=F,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  #betN<-subset(betN,road_id %in% o$road_id)
  centrality$new<-betN[match(centrality$road_id,names(betN))]
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"betw",sep="_")
}
#write the result to the database
output<-paste("regional_centrality",mode,metrics[i],sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),centrality) 

#clean up
dbDisconnect(con)
rm(list = ls())
#calculate regional transit centrality
#FOR ALL MODES (COMBINED AND IN TURN)

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
  mode<-setup[1]
}else{
  #select mode: rail, tram, metro, bus, transit
  mode<-"transit"
}

#get background transit network
if (mode=="rail")sql<-"SELECT source, target, length, 1.0 as stops FROM graph.transit_multimodal WHERE rail=TRUE AND transfer=0"
if (mode=="tram")sql<-"SELECT source, target, length, 1.0 as stops FROM graph.transit_multimodal WHERE tram=TRUE AND transfer=0"
if (mode=="metro")sql<-"SELECT source, target, length, 1.0 as stops FROM graph.transit_multimodal WHERE metro=TRUE AND transfer=0"
if (mode=="bus")sql<-"SELECT source, target, length, 1.0 as stops FROM graph.transit_multimodal WHERE bus=TRUE AND transfer=0"
if (mode=="transit")sql<-"SELECT source, target, length+0.00001 length, temporal, 1.0 as stops, transfer+1.0 as transfer FROM graph.transit_multimodal"

sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#prepare data frame for results
net <- V(g)$name
metrics<-list.edge.attributes(g)
centrality<-data.frame(stop_id=net)

for (i in 1:length(metrics)){
  #calculate closeness centrality
  cloN<-closeness(g,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  #add new columns to output data
  centrality$new<-cloN[match(centrality$stop_id,names(cloN))]
  #rename new column with name of weight
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"close",sep="_")
  #calculate betweenness centrality
  betN<-betweenness(g,directed=F,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  centrality$new<-betN[match(centrality$stop_id,names(betN))]
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"betw",sep="_")
}

#write the result to the database
output<-paste("regional_centrality",mode,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),centrality) 

#clean up
rm(list = ls())
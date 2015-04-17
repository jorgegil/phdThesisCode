#calculate regional multimodal centrality
#FOR ALL MODES, without buildings

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	mode<-setup[1]
	metrics<-setup[2]
}else{
	#select mode: all, nonmotor, car
	mode <- "all"
	#select distance metrics: metric or (segment+transter) or temporal or temporal_ped or temporal_bike 
	#or cogn_angular_seg or cogn_angular_mix_seg+0.000001 cogn_angular_mix_seg 
	#or cogn_axial_seg+0.000001 cogn_axial_seg or cogn_axial_mix_seg+0.000001 cogn_axial_mix_seg
	metrics<-"temporal"
}

#get background mobility network, don't include buildings
if (mode=="all") #includes all private and all transit
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR (mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL OR car=TRUE OR car IS NULL))",sep="")
if (mode=="nonmotor") #includes non motor and all transit
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR (mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))",sep="")
if (mode=="local") #includes non motor and local transit (no rail)
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE 
		(mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))
		OR (mobility='public' AND rail IS NULL)",sep="")
if (mode=="car") #includes car and all transit
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR (mobility='private' AND (car=TRUE OR car IS NULL))",sep="")

sql_res<-dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)

#prepare data frame for results
net <- V(g)$name
metrics<-list.edge.attributes(g)
centrality<-data.frame(node=net)

for (i in 1:length(metrics)){
  #calculate closeness centrality
  cloN<-closeness(g,normalized=T,weights=get.edge.attribute(g, metrics[i]))
  #add new columns to output data
  centrality$new<-cloN[match(centrality$node,names(cloN))]
  #rename new column with name of weight
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"close",sep="_")
  #calculate betweenness centrality
  betN<-betweenness(g,directed=F,weights=get.edge.attribute(g, metrics[i]))
  centrality$new<-betN[match(centrality$node,names(betN))]
  colnames(centrality)[ncol(centrality)]<-paste(mode,metrics[i],"betw",sep="_")
}

#write the result to the database
output<-paste("multimodal_centrality",mode,metrics[1],sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),centrality) 

#clean up
dbDisconnect(con)
rm(list = ls())

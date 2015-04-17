#calculate local catchment area

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

#analysis settings
setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	base<-setup[1]
	metrics<-setup[2]
	origins<-setup[3]
}else{
	#base network: nonmotor or car
	base<-"nonmotor" 
	#distance unit: metric or cumangular or axial or continuity_v2 or segment or temporal or temporal_ped or temporal_bike
	metrics<-"metric"
	#origins to consider: which origins to consider for calculating the catchment area. shouldn't be more than 1000 points
	origins<-"all"
}

#prepare origins
if (!exists("origins")) origins <- ""
if (origins == "all") origins <- ""
if (origins == "named") origins <- "WHERE pcode in (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL)"

#get background private network
if (base=="nonmotor"){
			sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad 
                     WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
				FROM survey.sampling_roads_interfaces ",origins,";",
            "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
			  FROM (SELECT * FROM survey.sampling_areas_interfaces ",origins,")
             as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",";",
			  "SELECT * FROM temp_local_links;",sep="")
}
if (base=="car"){
			sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE car=TRUE OR car IS NULL",sep="")
            osql<-paste("SELECT target_id::text as link,pcode::text FROM survey.sampling_roads_interfaces ",origins,sep="")
}
if (base=="private"){
			sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE car=TRUE OR car IS NULL
			OR pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
				FROM survey.sampling_roads_interfaces ",origins,";",
            "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
			  FROM (SELECT * FROM survey.sampling_areas_interfaces ",origins,")
             as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",";",
			  "SELECT * FROM temp_local_links;",sep="")
}

sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#get postcode links as origin
o<- dbGetQuery(con,osql)
#eliminate links to roads not on background network
netid<-V(g)$name
o<-subset(o,link %in% netid)

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
metrics<-list.edge.attributes(g)
nmetrics<-length(metrics)

localcatch<-matrix(NA,length(netid),npostcode)
rownames(localcatch)<-netid
colnames(localcatch)<-as.character(postcode)

#get shortest paths from each origin to get distance matrix
#then reduce to shortest distance for each different metric
for (i in 1:npostcode){
  	#calculate distance matrix
  	sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[i])$link],weights=get.edge.attribute(g,metrics))
  	#get the minimum value
  	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
  	#replace infinite by NA
	minsp[is.infinite(minsp)] <- NA
	#add new column to modality environment
	localcatch[,i]<-as.integer(minsp[match(rownames(localcatch),names(minsp))])
}

#write the result to the database
output<-paste("pcode_catchment",base,metrics,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),as.data.frame(localcatch)) 

#clean up
dbDisconnect(con)
rm(list = ls())
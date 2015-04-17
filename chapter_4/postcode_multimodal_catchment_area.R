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
	postcode<-setup[3]
}else{
	#base network: all, nonmotor or car
	base<-"all" 
	#select distance metrics: metric, (segment+transter), temporal, temporal_ped, temporal_bike, 
	#cogn_angular_seg, cogn_angular_mix_seg+0.000001 cogn_angular_mix_seg,
	#cogn_axial_seg+0.000001 cogn_axial_seg, cogn_axial_mix_seg+0.000001 cogn_axial_mix_seg
	metrics<-"cogn_angular_seg"
	#select specific postocdes or all
	postcode<-"all"
}

#get background mobility network, don't include buildings
if (base=="all"){
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR 
		(mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL OR car=TRUE OR car IS NULL))",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
				FROM survey.sampling_roads_interfaces WHERE pcode in 
            (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL)",
            "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
			  FROM (SELECT * FROM survey.sampling_areas_interfaces WHERE pcode in 
            (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL))
            as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",
			  "SELECT * FROM temp_local_links",sep=";")
}
if (base=="nonmotor"){
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR (mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
				FROM survey.sampling_roads_interfaces WHERE pcode in 
            (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL)",
            "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
			  FROM (SELECT * FROM survey.sampling_areas_interfaces WHERE pcode in 
            (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL)) 
            as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",
			  "SELECT * FROM temp_local_links",sep=";")
}
if (base=="car"){
		sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR (mobility='private' AND (car=TRUE OR car IS NULL))",sep="")
            osql<-"SELECT target_id::text as link,pcode::text FROM survey.sampling_roads_interfaces WHERE pcode in 
            (SELECT pcode FROM survey.sampling_points WHERE neighbourhood_type IS NOT NULL)"
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
if (postcode == "all") postcode<-unique(o$pcode) else postcode<-unlist(strsplit(postcode, split=","))
npostcode<-length(postcode)
metrics<-list.edge.attributes(g)
nmetrics<-length(metrics)

localcatch<-as.data.frame(matrix(NA,length(netid),npostcode*nmetrics))
rownames(localcatch)<-netid

#get shortest paths from each origin to get distance matrix
#then reduce to shortest distance for each different metric
for (i in 1:npostcode){
	for (j in 1:nmetrics){
		#calculate distance matrix
		sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[i])$link],weights=get.edge.attribute(g,metrics[j]))
		#get the minimum value
		if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
		#replace infinite by NA
		minsp[is.infinite(minsp)] <- NA
		#update new column in catchment area
		names(localcatch)[((i-1)*nmetrics)+j]<-paste(metrics[j],postcode[i],sep="_")
		localcatch[,((i-1)*nmetrics)+j]<-as.integer(minsp[match(rownames(localcatch),names(minsp))])
	}
}

#write the result to the database
output<-paste("pcode_multimodal_catchment",base,metrics[1],sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),as.data.frame(localcatch)) 

#clean up
dbDisconnect(con)
rm(list = ls())
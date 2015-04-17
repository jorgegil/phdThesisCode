#regional accessibility
#FOR EVERY REGIONAL MODE

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

#analysis settings
setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	modality<-setup[1]
	odist<-setup[2]
	oprox<-as.integer(setup[3])
	ddist<-setup[4]
	drange<-as.integer(unlist(strsplit(setup[5], split=",")))
	tactivity<-unlist(strsplit(setup[6], split=","))
	dcost<-setup[7]
	tdist<-setup[8]
	trange<-as.integer(setup[9])
	f_decay<-setup[10]
}else{
	#analysis modality: bicycle, motorway, main, rail, tram, metro, bus
	modality<-"bicycle"
	#access cost (metric, cumangular, axial, continuity_v2, segment, temporal) 
	odist<-"metric"
	oprox<-400
	#access dist (metric, segment, temporal) and range/activity pairs
	ddist<-"metric"
	drange<-c(10000,15000,30000,30000,20000,20000)
	tactivity<-c("retail","education","office","industry","assembly","sports")
	#target distance (metric, cumangular, axial, continuity_v2, segment, temporal) and range from access
	tdist<-"metric"
	trange<-400
	#decay function
	f_decay<-function(x,y){return(1-(x/y)^3)}
	#or using a string - eval(parse(text=string))
}
#end of analysis settings


#get background access network
if (modality=="main" || modality=="motorway"){
	sql<-paste("SELECT source, target, ",odist,", ",tdist," FROM graph.roads_dual_randstad 
	WHERE car=TRUE OR car IS NULL",sep="")
}else{
	sql<-paste("SELECT source, target, ",odist,", ",tdist," FROM graph.roads_dual_randstad 
	WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
}
sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
net<-data.frame(id=V(g)$name)


#get main regional network
if (modality=="main" || modality=="motorway")
	sql<-paste("SELECT source, target, ",ddist," FROM graph.roads_dual_randstad WHERE car=True",sep="")
if (modality=="bicycle")
	sql<-paste("SELECT source, target, ",ddist," FROM graph.roads_dual_randstad WHERE bicycle=True OR (car=TRUE AND (bicycle=True OR bicycle IS NULL))",sep="")
if (modality=="rail" || modality=="metro" || modality=="tram" || modality=="bus")
	sql<-paste("SELECT source, target, ",ddist," FROM graph.multimodal WHERE ",modality,"=True AND transfer=0",sep="")
sql_res<- dbGetQuery(con,sql)
rg<-graph.data.frame(sql_res,directed=F)
rnet<-data.frame(id=V(rg)$name)


#get modality environment access points
#convert graph column names for network column names... should have been identical!
if (modality=="main" || modality=="motorway" || modality=="bicycle"){
  if (odist=="metric"){ ondist <- "length metric" }
  if (tdist=="metric"){ tndist <- "length metric" }
  if (odist=="cumangular"){ ondist <- "cumul_angle cumangular" }
  if (tdist=="cumangular"){ tndist <- "cumul_angle cumangular" }
  if (odist=="segment"){ ondist <- "segment_topo segment" }
  if (tdist=="segment"){ tndist <- "segment_topo segment" }
  if (odist=="axial"){ ondist <- "axial_topo axial" }
  if (tdist=="axial"){ tndist <- "axial_topo axial" }
  if (odist=="continuity_v2"){ ondist <- "contv2_topo continuity_v2" }
  if (tdist=="continuity_v2"){ tndist <- "contv2_topo continuity_v2" }
  if (odist=="temporal"){ ondist <- "time_dist temporal" }
  if (tdist=="temporal"){ tndist <- "time_dist temporal" }
}

if (modality=="main")
	sql<-paste("SELECT sid::text as sid, sid::text as stop, ",ondist,", ",tndist," FROM network.roads_randstad WHERE main=True",sep="")
if (modality=="motorway")
	sql<-paste("SELECT sid::text as sid, sid::text as stop, ",ondist,", ",tndist," FROM network.roads_randstad WHERE motorway_access=True",sep="")
if (modality=="bicycle")
	sql<-paste("SELECT sid::text as sid, sid::text as stop, ",ondist,", ",tndist," FROM network.roads_randstad WHERE bicycle=True OR (main=True AND (bicycle=True or bicycle IS NULL))",sep="")
#get transit stop access points, to roads and also to pedestrian areas
if (modality=="rail" || modality=="metro" || modality=="tram" || modality=="bus")
		sql<-paste("CREATE TEMP TABLE temp_transit_links AS SELECT road_id::text as sid, multimodal_id::text as stop
		FROM network.transit_roads_interfaces WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",modality,"');",
		"INSERT INTO temp_transit_links SELECT road_id, multimodal_id FROM network.transit_areas_interfaces 
		WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",modality,"');",
		"SELECT * FROM temp_transit_links;",sep="")
	
d<- dbGetQuery(con,sql)
if (modality=="rail" || modality=="metro" || modality=="tram" || modality=="bus")
	dbSendQuery(con,"DROP TABLE temp_transit_links CASCADE")	
#eliminate access points that don't connect to background and regional networks
d<-subset(d,sid %in% net$id)
d<-subset(d,stop %in% rnet$id)

#get postcode links as origin
osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
		FROM survey.sampling_roads_interfaces","INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
		FROM survey.sampling_areas_interfaces as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",
		"SELECT * FROM temp_local_links",sep=";")
o<- dbGetQuery(con,osql)
#eliminate links that do not connect to background network
o<-subset(o,link %in% net$id)

#get links to activities of the whole region
sql<-paste("SELECT road_sid::text as link, ",paste(tactivity,collapse=", ")," FROM urbanform.roads_landuse WHERE randstad=True", sep="")
t<- dbGetQuery(con,sql)
#eliminate links that are not in the background network
t<-subset(t,link %in% net$id)

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
nactivity<-length(tactivity)
regional_access<-as.data.frame(matrix(postcode,npostcode,1+(nactivity*2),byrow=FALSE))
names(regional_access)[1]<-"pcode"

tempstr <- "CREATE TEMP TABLE temp_targets (target_id integer,"
for (n in 1:nactivity){
	#compose string of target activities
	tempstr <- paste(tempstr,tactivity[n]," integer,",tactivity[n],"_area"," float,",sep="")
	
	names(regional_access)[(n*2)]<-paste(tactivity[n],"_count",sep="")
	regional_access[,(n*2)]<-NA
	names(regional_access)[(n*2)+1]<-paste(tactivity[n],"_area",sep="") 
	regional_access[,(n*2)+1]<-NA
}
tempstr <- paste(tempstr,"road_id integer) ",sep="")
dbSendQuery(con,tempstr)

#get shortest path from each origin to a regional access point to make a distance matrix
#then select those access points within range and calculate activities from there
for (i in 1:npostcode){
	#measure distance to local access nodes
	sp<-shortest.paths(g,v=V(g)[name %in% subset(o, pcode==postcode[i])$link],to=V(g)[name %in% d$sid],weights=get.edge.attribute(g, odist))
	if (modality=="main" || modality=="motorway" || modality=="bicycle"){
		#subtract half of the weight of the destination
		sp<-sp-(d[match(colnames(sp),d$sid),odist]/2)
	}
	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
	#replace infinite by NA
	minsp[is.infinite(minsp)] <- NA
	apoints<-names(subset(minsp, minsp<=oprox))

  if (length(apoints)>0){
  	#measure regional distance from access points to destination access points
  	sp<-shortest.paths(rg,v=V(rg)[name %in% subset(d, d$stop %in% apoints)$stop],
  		to=V(rg)[name %in% subset(d, !(d$stop %in% apoints))$stop],weights=get.edge.attribute(rg, ddist))
  	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
  	#replace infinite by NA
  	minsp[is.infinite(minsp)] <- NA
  	
  	for (j in 1:nactivity){
  		#select those destination points within regional range for activity
  		dpoints<-names(subset(minsp, minsp<=drange[j]))
  		#get target activity  
  		tpoints<-subset(t,t[,j+1] > 0)
  		#measure distance from destination points to activity
  		sp<-shortest.paths(g,v=V(g)[name %in% dpoints],to=V(g)[name %in% tpoints$link], weights=get.edge.attribute(g,tdist))
  		#subtract half of the weight of the access points
  		if (modality=="main" || modality=="motorway" || modality=="bicycle"){
  		  sp<-sp-(d[match(d$sid,row.names(sp)),tdist]/2)
  		}
  		#get only those links within desired range
  		if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
  		#replace infinite by NA
  		minsp[is.infinite(minsp)] <- NA

      tid<-data.frame(road_id=names(subset(minsp, minsp <= trange)))
  		#write these ids to the database
  		if(dbExistsTable(con,c("temp","target_roads"))){
  			dbWriteTable(con,c("temp","target_roads"),tid,append = T)
  		} else {
  			dbWriteTable(con,c("temp","target_roads"),tid)
  		}
  		
  		#get building information on those links
  		if (modality=="main" || modality=="motorway" || modality=="bicycle"){
  			sql<-paste("SELECT sid as target_id, min(",tactivity[j],") count, min(",tactivity[j],"_area) area 
  			FROM urbanform.buildings_randstad WHERE sid IN 
  			(SELECT object_id FROM urbanform.buildings_roads_interfaces_randstad WHERE target_id IN 
  			(SELECT road_id FROM temp.target_roads)) GROUP BY sid",sep="")
  		}else{			
  			sql<-paste("SELECT sid as target_id, min(",tactivity[j],") as count, min(",tactivity[j],"_area) as area 
  			FROM urbanform.buildings_randstad WHERE sid IN 
  			(SELECT object_id FROM urbanform.buildings_roads_interfaces_randstad WHERE target_id IN 
  			(SELECT road_id::integer FROM temp.target_roads)) OR sid IN 
  			(SELECT object_id FROM urbanform.buildings_areas_interfaces_randstad WHERE target_id IN 
  			(SELECT group_id FROM network.areas WHERE road_sid IN (SELECT road_id::integer FROM temp.target_roads)))
  			GROUP BY sid",sep="")
  		}		
  		system.time(act<-dbGetQuery(con,sql))
  	
  		#alternative version - choose whichever is quickest as these queries are slow
  		sql<-paste("INSERT INTO temp_targets SELECT bld.object_mm_id, ",tactivity[j],", ",tactivity[j],"_area, rd.target_id 
  			FROM (SELECT * FROM urbanform.buildings_roads_interfaces_randstad WHERE target_id IN (SELECT road_id::integer FROM temp.target_roads)) as rd 
  			JOIN urbanform.buildings_randstad as bld ON (rd.object_id=bld.sid);",
  			"INSERT INTO temp_targets SELECT bld.object_mm_id, ",tactivity[j],", ",tactivity[j],"_area, rd.road_sid 
  			FROM (SELECT * FROM network.areas_randstad WHERE road_sid IN (SELECT road_id::integer FROM temp.target_roads)) as rd 
  			JOIN urbanform.buildings_areas_interfaces_randstad as ar ON (rd.group_id=ar.target_id)
  			JOIN urbanform.buildings_randstad as bld ON (ar.object_id=bld.sid);",
  			"SELECT target_id, ",tactivity[j]," as count, ",tactivity[j],"_area as area FROM temp_targets;",sep="")
  		system.time(act<-dbGetQuery(con,sql))
  		dbSendQuery(con,"DELETE FROM temp_targets")
  		
  		#remove duplicate targets
  		act<-act[!duplicated(act$target_id),]
  
  		#calculate total count and area
  		tcount<-sum(act$count,na.rm=TRUE)
  		tarea<-sum(act$area,na.rm=TRUE)
  		#update results data
  		if(!is.na(tcount) & !is.infinite(tarea)){
  			access_transit[i,(j*2)]<-tcount    
  			access_transit[i,(j*2)+1]<-tarea
  		}	
  		dbSendQuery(con,"DELETE FROM temp.target_roads")
  	}
  }
	rm(apoints,dpoints,tpoints,act,minsp,nearest,sp,tid)
 }

#write the result to the database
output<-paste("pcode",mode,"accessibility",modality,tdist,trange,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),access_transit)

#cleanup
dbSendQuery(con,"DROP TABLE temp.target_roads CASCADE") 
rm(list = ls())
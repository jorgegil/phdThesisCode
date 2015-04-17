#local proximity
#FOR ALL MODES

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

#analysis settings
setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	base<-setup[1]
	metrics<-setup[2]
	targets<-setup[3]
}else{
	#base network: nonmotor or car
	base<-"car" 
	#distance metrics: metric, cumangular, axial, continuity_v2, segment, temporal
	metrics<-"metric,cumangular,axial,segment"
	#target features: pedestrian,bicycle,motorway,main,rail,metro,tram,bus
	targets<-"motorway,main"
	#end of analysis settings
}

#get background network
if (base=="nonmotor"){
          sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad 
                     WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text 
				FROM survey.sampling_roads_interfaces","INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text
			  FROM survey.sampling_areas_interfaces as int JOIN network.areas as net ON (int.area_group_id=net.group_id)",
			  "SELECT * FROM temp_local_links",sep=";")
}
if (base=="car"){sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE car=TRUE OR car IS NULL",sep="")
                     osql<-"SELECT target_id::text as link,pcode::text FROM survey.sampling_roads_interfaces"
}
sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#get postcode links as origin
o<- dbGetQuery(con,osql)
#eliminate links to roads not on background network
net<-data.frame(id=V(g)$name)
o<-subset(o,link %in% net$id)

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
targets<-unlist(strsplit(targets, split=","))
ntargets<-length(targets)
metrics<-list.edge.attributes(g)
nmetrics<-length(metrics)
local_prox<-as.data.frame(matrix(postcode,npostcode,1+(ntargets*nmetrics*2),byrow=FALSE))
names(local_prox)[1]<-"pcode"
dbSendQuery(con,"CREATE TEMP TABLE temp_targets (road_id character varying)")
tlist<-list("a list")

for (n in 1:ntargets){
	#get target nodes of whole region
	if (targets[n]=="pedestrian" || targets[n]=="bicycle")tsql<-paste("INSERT INTO temp_targets SELECT sid::text FROM network.roads_randstad 
						 WHERE ",targets[n],"=TRUE;",
						 "INSERT INTO temp_targets SELECT road_sid::text FROM network.areas_randstad;",
						 "SELECT road_id::text FROM temp_targets;",sep="")
	if (targets[n]=="motorway" || targets[n]=="main")tsql<-paste("INSERT INTO temp_targets SELECT sid::text FROM network.roads_randstad 
						WHERE ",targets[n],"=True;",
						"SELECT road_id::text FROM temp_targets;",sep="")
	if (targets[n]=="rail" || targets[n]=="metro" || targets[n]=="tram" || targets[n]=="bus")tsql<-paste("INSERT INTO temp_targets SELECT road_id::text FROM network.transit_roads_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "INSERT INTO temp_targets SELECT road_id::text FROM network.transit_areas_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "SELECT road_id::text FROM temp_targets;",sep="")
						 
	t<- dbGetQuery(con,tsql)
	dbSendQuery(con,"DELETE FROM temp_targets")
	#eliminate targets that are not in base network
	t<-subset(t,road_id %in% net$id)
	#add to targets list
	tlist[[n]]<-t
	names(tlist)[n]<-targets[n]
	#insert null values
	for (m in 1:nmetrics){
		names(local_prox)[((((n-1)*nmetrics)+m)*2)]<-paste(targets[n],metrics[m],"id",sep="_")
		local_prox[,((((n-1)*nmetrics)+m)*2)]<-NA
		names(local_prox)[((((n-1)*nmetrics)+m)*2)+1]<-paste(targets[n],metrics[m],"dist",sep="_") 
		local_prox[,((((n-1)*nmetrics)+m)*2)+1]<-NA
	}
}

#get shortest path for each origin to make a distance matrix
#then select the nearest feature of each type
for (j in 1:npostcode){
	for (k in 1:nmetrics){
		#measure distance to base nodes in region
		sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[j])$link],weights=get.edge.attribute(g,metrics[k]))
		if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
  		for (n in 1:ntargets){
			mint<-minsp[names(minsp) %in% tlist[[n]][,1]]
			#identify nearest
			near<- min(mint)
			tid<-names(subset(mint, mint == near))[1]
			tdist<-round(near, digits=2)
			#update results data
			if(!is.na(tid) & !is.infinite(tdist)){
				  local_prox[j,((((n-1)*nmetrics)+k)*2)]<-tid    
				  local_prox[j,((((n-1)*nmetrics)+k)*2)+1]<-tdist
			}
			tid<-NA
			tdist<-NA
		}
	}
}
#write the result to the database
output<-paste("pcode_local_proximity",base,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),local_prox)

#cleanup
rm(list = ls())
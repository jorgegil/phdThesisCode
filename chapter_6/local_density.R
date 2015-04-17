#local density
#FOR ALL MODES AND TARGETS

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

#analysis settings
setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	base<-setup[1]
	metrics<-setup[2]
	radius<-as.integer(unlist(strsplit(setup[3], split=",")))
	targets<-setup[4]
}else{
	#base network: nonmotor or car
	base<-"car" 
	#distance unit: metric or cumangular or axial or continuity_v2 or segment or temporal
	metrics<-"metric"
	#radius for every target, based on distance unit
	radius<-c(400,800,1600,2400,3600)
	#target features: xcross, tcross, pedestrian, bicycle, nonmotor, motorway, main, car, rail, metro, tram, bus
	targets<-"xcross, tcross, motorway, main, car"
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

#sql<-paste("SELECT road_sid::text as link, ",paste(tactivity,collapse=", ")," FROM urbanform.roads_landuse 
#		WHERE randstad=True", sep="")

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
targets<-unlist(strsplit(targets, split=","))
ntargets<-length(targets)
nradius<-length(radius)
local_dens<-as.data.frame(matrix(postcode,npostcode,1+(ntargets*nradius*2),byrow=FALSE))
names(local_dens)[1]<-"pcode"
tlist<-list("a list")
dbSendQuery(con,"CREATE TEMP TABLE temp_targets (road_id character varying, weight double precision)")

for (n in 1:ntargets){
	#get target nodes of whole region
	if (targets[n]=="pedestrian" || targets[n]=="bicycle")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length 
						FROM network.roads_randstad WHERE ",targets[n],"=TRUE;",
						 "INSERT INTO temp_targets SELECT road_sid::text, length FROM network.areas_randstad;",
						 "SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="nonmotor")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length 
						FROM network.roads_randstad WHERE pedestrian=TRUE or pedestrian IS NULL or bicycle=TRUE or bicycle IS NULL;",
						 "INSERT INTO temp_targets SELECT road_sid::text, length FROM network.areas_randstad;",
						 "SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="motorway" || targets[n]=="main")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length
						FROM network.roads_randstad WHERE ",targets[n],"=True;",
						"SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="car")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length
						FROM network.roads_randstad WHERE car=TRUE or car IS NULL;",
						"SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="xcross")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, start_id FROM network.roads_randstad 
						WHERE start_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count>3);",
						"INSERT INTO temp_targets SELECT sid::text, end_id FROM network.roads_randstad 
						WHERE end_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count>3);",
						"SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="tcross")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, start_id FROM network.roads_randstad 
						WHERE start_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count=3);",
						"INSERT INTO temp_targets SELECT sid::text, end_id FROM network.roads_randstad 
						WHERE end_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count=3);",
						"SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="culdesac")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, start_id FROM network.roads_randstad 
						WHERE start_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count=1);",
						"INSERT INTO temp_targets SELECT sid::text, end_id FROM network.roads_randstad 
						WHERE end_id in (SELECT sid FROM network.roads_nodes_randstad WHERE count=1);",
						"SELECT road_id, weight FROM temp_targets;",sep="")
	if (targets[n]=="rail" || targets[n]=="metro" || targets[n]=="tram" || targets[n]=="bus")tsql<-
						paste("INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_roads_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_areas_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "SELECT road_id, weight FROM temp_targets;",sep="")
						 
	t<- dbGetQuery(con,tsql)
	dbSendQuery(con,"DELETE FROM temp_targets")
	#eliminate links to non-car roads
	t<-subset(t,road_id %in% net$id)
	#add to targets list
	tlist[[n]]<-t
	names(tlist)[n]<-targets[n]
	
	#insert null values
	for (m in 1:nradius){
		names(local_dens)[((((n-1)*nradius)+m)*2)]<-paste(targets[n],radius[m],"count",sep="_")
		local_dens[,((((n-1)*nradius)+m)*2)]<-NA
		names(local_dens)[((((n-1)*nradius)+m)*2)+1]<-paste(targets[n],radius[m],"size",sep="_") 
		local_dens[,((((n-1)*nradius)+m)*2)+1]<-NA
	}
}

#get shortest path for each origin to make a distance matrix
#then select the nearest feature of each type
for (j in 1:npostcode){
	#measure distance to base nodes in region
	sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[j])$link],weights=get.edge.attribute(g,metrics))
	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
	for (k in 1:nradius){
		#identify in radius
		tid<-names(subset(minsp, minsp <= radius[k]))
		for (n in 1:ntargets){
			if (targets[n]=="pedestrian" || targets[n]=="bicycle" || targets[n]=="nonmotor" || 
				targets[n]=="motorway" || targets[n]=="main" || targets[n]=="car") {			
				tcount<-length(subset(tlist[[n]], tlist[[n]]$road_id %in% tid)$weight)
				tsize<-sum(subset(tlist[[n]], tlist[[n]]$road_id %in% tid)$weight)
			}else{
				tcount<-length(unique(subset(tlist[[n]], tlist[[n]]$road_id %in% tid)$weight))
				tsize<-0
			}
			#update results data
			if(!is.na(tcount) & !is.infinite(tsize)){
				  local_dens[j,((((n-1)*nradius)+k)*2)]<-tcount    
				  local_dens[j,((((n-1)*nradius)+k)*2)+1]<-tsize
			}
			tcount<-NA
			tsize<-NA
		}
	}
 }
#write the result to the database
output<-paste("pcode_local_density",base,metrics,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),local_dens)

#cleanup
rm(list = ls())
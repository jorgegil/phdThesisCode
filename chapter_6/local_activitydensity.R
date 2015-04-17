#local proximity
#FOR ALL MODES AND ACTIVITIES

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
	base<-"nonmotor" 
	#distance unit: metric or cumangular or axial or continuity_v2 or segment or temporal
	metrics<-"axial"
	#radius for every target, based on distance unit
	radius<-c(1,2,3,4,5)
	#activities: retail,education,office,industry,assembly,sports
	targets<-"retail,education,office,industry,assembly,sports"
	#end of analysis settings
}

#get background network
if (base=="nonmotor"){
          sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE pedestrian=TRUE OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL",sep="")
			osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text ",
							"FROM survey.sampling_roads_interfaces; ",
              "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text ",
						  "FROM survey.sampling_areas_interfaces as int JOIN network.areas as net ON (int.area_group_id=net.group_id); ",
						  "SELECT * FROM temp_local_links;",sep="")
          }
if (base=="car"){sql<-paste("SELECT source, target, ",metrics," FROM graph.roads_dual_randstad WHERE car=TRUE OR car IS NULL",sep="")
                osql<-"SELECT target_id::text as link,pcode::text FROM survey.sampling_roads_interfaces"
                 }
if (base=="local_transit"){ #includes non motor and local transit (no rail)
    sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE 
		(mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))
		OR (mobility='public' AND rail IS NULL)",sep="")
    osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text ",
                 "FROM survey.sampling_roads_interfaces; ",
                 "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text ",
                 "FROM survey.sampling_areas_interfaces as int JOIN network.areas as net ON (int.area_group_id=net.group_id); ",
                 "SELECT * FROM temp_local_links;",sep="")
}
if (base=="transit"){ #includes non motor and all transit
    sql<-paste("SELECT source, target, ",metrics," FROM graph.multimodal_randstad WHERE mobility='public' OR
    		(mobility='private' AND (pedestrian=TRUE OR pedestrian IS NULL OR bicycle=TRUE OR bicycle IS NULL))",sep="")
    osql<- paste("CREATE TEMP TABLE temp_local_links AS SELECT target_id::text as link,pcode::text ",
                 "FROM survey.sampling_roads_interfaces; ",
                 "INSERT INTO temp_local_links SELECT net.road_sid::text, int.pcode::text ",
                 "FROM survey.sampling_areas_interfaces as int JOIN network.areas as net ON (int.area_group_id=net.group_id); ",
                 "SELECT * FROM temp_local_links;",sep="")
}


sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#get postcode links as origin
o<- dbGetQuery(con,osql)
#eliminate links to roads not on background network
net<-V(g)$name
o<-subset(o,link %in% net)

#sql<-paste("SELECT road_sid::text as link, ",paste(tactivity,collapse=", ")," FROM urbanform.roads_landuse 
#		WHERE randstad=True", sep="")

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
targets<-unlist(strsplit(targets, split=","))
ntargets<-length(targets)
nradius<-length(radius)
local_access<-as.data.frame(matrix(postcode,npostcode,1+(ntargets*nradius*2),byrow=FALSE))
names(local_access)[1]<-"pcode"

targetstr<-""
for (n in 1:ntargets){
	#compose string of target activities
	targetstr<-paste(targetstr,"bld.",targets[n],", bld.",targets[n],"_area, ",sep="")
	#insert null values
	for (m in 1:nradius){
		names(local_access)[((((n-1)*nradius)+m)*2)]<-paste(targets[n],radius[m],"count",sep="_")
		local_access[,((((n-1)*nradius)+m)*2)]<-NA
		names(local_access)[((((n-1)*nradius)+m)*2)+1]<-paste(targets[n],radius[m],"area",sep="_") 
		local_access[,((((n-1)*nradius)+m)*2)+1]<-NA
	}
}

#get relevant targets
tsql<-paste("CREATE TEMP TABLE temp_targets AS SELECT bld.multimodal_sid::text target_id, ",targetstr,"rd.target_id::text road_id ",
		"FROM urbanform.buildings_roads_interfaces as rd ",
		"JOIN urbanform.buildings as bld ON (rd.object_id=bld.sid); ",
		"INSERT INTO temp_targets SELECT bld.multimodal_sid::text, ",targetstr,"rd.road_sid::text ",
		"FROM network.areas as rd ",
		"JOIN urbanform.buildings_areas_interfaces as ar ON (rd.group_id=ar.target_id) ",
		"JOIN urbanform.buildings as bld ON (ar.object_id=bld.sid); ",
		"SELECT * FROM temp_targets;",sep="")
t<-dbGetQuery(con,tsql)
dbSendQuery(con,"DROP TABLE temp_targets CASCADE")

#get shortest path for each origin to make a distance matrix
#then select the nearest features of each type
for (j in 1:npostcode){
	#measure distance to base nodes in region
	sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[j])$link],weights=get.edge.attribute(g,metrics))
	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
	for (k in 1:nradius){
		#identify targets in radius
		tr <- names(subset(minsp, minsp <= radius[k]))
		if (length(tr) > 0){
			tradius <- subset(t,t$road_id %in% tr)
			#remove duplicate targets
			tradius <- tradius[!duplicated(tradius$target_id),]
			if (nrow(tradius)>0){
				for (n in 1:ntargets){
					tcount<-sum(tradius[,targets[n]], na.rm = TRuE)
					tarea<-sum(tradius[,paste(targets[n],"_area",sep="")], na.rm = TRuE)
		
					if(!is.na(tcount) & !is.infinite(tarea)){
						#update results data
						local_access[j,((((n-1)*nradius)+k)*2)]<-tcount   
						local_access[j,((((n-1)*nradius)+k)*2)+1]<-tarea
					}
		  
					tcount<-NA
					tarea<-NA
				}
			}
		}
	}
 }
#write the result to the database
output<-paste("pcode_local_accessibility",base,metrics,sep="_")
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
  dbWriteTable(con,c("analysis",output),local_access)

#cleanup
dbDisconnect(con)
rm(list = ls())
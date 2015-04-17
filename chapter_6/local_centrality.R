#local centrality
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
    centdata<-setup[4]
    toprank<-as.integer(setup[5])
	targets<-setup[6]
}else{
	#base network: nonmotor, car
	base<-"nonmotor" 
	#distance unit: metric,cumangular,axial,continuity_v2,segment,temporal
	metrics<-"metric"
	#radius for every target, based on distance unit
	radius<-c(800,1600)
    #centrality results: private, multimodal, transit
	centdata <- "multimodal"
	#top rank for the base, % value
	toprank<-20
	#target features: pedestrian, bicycle, nonmotor, car, main, motorway, rail, localtransit
	targets<-"bicycle,rail,localtransit"
	#end of analysis settings
}

#get base network
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
sql_res<- dbGetQuery(con,sql)
g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#get postcode links as origin
o<- dbGetQuery(con,osql)
#eliminate links to roads not on background network
net<-V(g)$name
o<-subset(o,link %in% net)

#get table columns containing the pre-calculated centrality results
if (centdata=="private"){
    #centrality <- dbGetQuery(con,paste("SELECT road_id, ",base,"_angular_close,",base,"_angular_betw FROM analysis.regional_centrality_private",sep=""));
    centrality <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.regional_centrality_private;
                ALTER TABLE temp_centrality DROP COLUMN the_geom;
                SELECT road_id::text node, * FROM temp_centrality;")
    dbSendQuery(con,"DROP TABLE temp_centrality")
}
if (centdata=="multimodal"){
    #centrality <- dbGetQuery(con,paste("SELECT road_id, ",base,"_cogn_angular_seg_close, 
    #    ",base,"_cogn_angular_seg_betw, ",base,"_cogn_angular_temp_close,",base,"_cogn_angular_temp_betw 
    #    FROM analysis.regional_centrality_multimodal",sep=""));
    centrality <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.regional_centrality_multimodal;
        ALTER TABLE temp_centrality DROP COLUMN the_lines;ALTER TABLE temp_centrality DROP COLUMN the_points;
        SELECT road_id::text node, * FROM temp_centrality;")
    dbSendQuery(con,"DROP TABLE temp_centrality")
}
if (centdata=="transit"){
    centrality <- dbGetQuery(con,"CREATE TEMP TABLE temp_centrality AS SELECT * FROM analysis.regional_centrality_transit;
                ALTER TABLE temp_centrality DROP COLUMN the_geom;
                SELECT multimodal_sid::text node, * FROM temp_centrality;")
    dbSendQuery(con,"DROP TABLE temp_centrality")
}
#get relevant results columns
closeresults<-colnames(centrality)[intersect(which(!grepl("rank",colnames(centrality))),which(grepl("close",colnames(centrality))))]
betwresults<-colnames(centrality)[intersect(which(!grepl("rank",colnames(centrality))),which(grepl("betw",colnames(centrality))))]

#get background catchment results this is far too slow! quicker to calculate again
#sql<-paste("SELECT * FROM aux.pcode_catchment_",base,"_",metrics,sep="")
#sql<-paste("SELECT road_id, \"",3235,"\" dist FROM aux.pcode_catchment_",base,"_",metrics," WHERE \"",3235,"\" <=1600 ",sep="") #," WHERE \"",3235,"\" <=1600 "
#dist_matrix<- dbGetQuery(con,sql)

#prepare data frame for results
postcode<-unique(o$pcode)
npostcode<-length(postcode)
results<-c(closeresults,betwresults)
nresults<-length(results)
targets<-unlist(strsplit(targets, split=","))
ntargets<-length(targets)
nradius<-length(radius)

if (centdata=="multimodal" || centdata=="private"){
    local_private_agg<-as.data.frame(matrix(postcode,npostcode,1+(nradius*nresults*2),byrow=FALSE))
    #set column names and insert null values
    for (n in 1:nradius){
        for (m in 1:nresults){
            names(local_private_agg)[(((n-1)*nresults*2)+(m-1)*2)+2]<-paste(results[m],radius[n],"mean",sep="_")
            local_private_agg[,(((n-1)*nresults*2)+(m-1)*2)+2]<-NA
            names(local_private_agg)[(((n-1)*nresults*2)+(m-1)*2)+3]<-paste(results[m],radius[n],"max",sep="_") 
            local_private_agg[,(((n-1)*nresults*2)+(m-1)*2)+3]<-NA
        }
    }
    names(local_private_agg)[1]<-"pcode"
    
    local_private_share<-as.data.frame(matrix(postcode,npostcode,1+(nradius*nresults*ntargets),byrow=FALSE))
    names(local_private_share)[1]<-"pcode"
    #set column names and insert null values
    for (n in 1:nradius){
        for (m in 1:nresults){
            for (k in 1:ntargets){
                names(local_private_share)[(((n-1)*nresults*ntargets)+(m-1)*ntargets)+(k+1)]<-paste(targets[k],results[m],radius[n],sep="_")
                local_private_share[,(((n-1)*nresults*ntargets)+(m-1)*ntargets)+(k+1)]<-NA
            }
        }
    }
}

if (centdata=="multimodal" || centdata=="transit"){
    local_transit_agg<-as.data.frame(matrix(postcode,npostcode,1+(nradius*nresults*4),byrow=FALSE))
    names(local_transit_agg)[1]<-"pcode"
    #set column names and insert null values
    for (n in 1:nradius){
        for (m in 1:nresults){
            names(local_transit_agg)[(((n-1)*nresults*4)+(m-1)*4)+2]<-paste(results[m],radius[n],"rail_mean",sep="_")
            local_transit_agg[,(((n-1)*nresults*4)+(m-1)*4)+2]<-NA
            names(local_transit_agg)[(((n-1)*nresults*4)+(m-1)*4)+3]<-paste(results[m],radius[n],"rail_max",sep="_") 
            local_transit_agg[,(((n-1)*nresults*4)+(m-1)*4)+3]<-NA
            names(local_transit_agg)[(((n-1)*nresults*4)+(m-1)*4)+4]<-paste(results[m],radius[n],"transit_mean",sep="_")
            local_transit_agg[,(((n-1)*nresults*4)+(m-1)*4)+4]<-NA
            names(local_transit_agg)[(((n-1)*nresults*4)+(m-1)*4)+5]<-paste(results[m],radius[n],"transit_max",sep="_") 
            local_transit_agg[,(((n-1)*nresults*4)+(m-1)*4)+5]<-NA
        }
    }
    
    local_transit_share<-as.data.frame(matrix(postcode,npostcode,1+(nradius*nresults*ntargets),byrow=FALSE))
    names(local_transit_share)[1]<-"pcode"
    #set column names and insert null values
    for (n in 1:nradius){
        for (m in 1:nresults){
            for (k in 1:ntargets){
                names(local_transit_share)[(((n-1)*nresults*ntargets)+(m-1)*ntargets)+(k+1)]<-paste(targets[k],results[m],radius[n],sep="_")
                local_transit_share[,(((n-1)*nresults*ntargets)+(m-1)*ntargets)+(k+1)]<-NA
            }
        }
    }
}

tlist<-list("a list")
dbSendQuery(con,"CREATE TEMP TABLE temp_targets (road_id character varying, length double precision)")
for (n in 1:ntargets){
	#get target nodes of whole region
	if (targets[n]=="pedestrian" || targets[n]=="bicycle")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length 
						FROM network.roads_randstad WHERE bicycle=TRUE;",
						 "INSERT INTO temp_targets SELECT road_sid::text, length FROM network.areas_randstad;",
						 "SELECT road_id, length FROM temp_targets;",sep="")
	if (targets[n]=="nonmotor")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length 
						FROM network.roads_randstad WHERE pedestrian=TRUE or pedestrian IS NULL or bicycle=TRUE or bicycle IS NULL;",
						 "INSERT INTO temp_targets SELECT road_sid::text, length FROM network.areas_randstad;",
						 "SELECT road_id, length FROM temp_targets;",sep="")
	if (targets[n]=="motorway" || targets[n]=="main")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length
						FROM network.roads_randstad WHERE ",targets[n],"=True;",
						"SELECT road_id, length FROM temp_targets;",sep="")
	if (targets[n]=="car")tsql<-paste("INSERT INTO temp_targets SELECT sid::text, length
						FROM network.roads_randstad WHERE car=TRUE or car IS NULL;",
						"SELECT road_id, length FROM temp_targets;",sep="")
	if (targets[n]=="rail" || targets[n]=="tram" || targets[n]=="metro" || targets[n]=="bus")tsql<-
						paste("INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_roads_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_areas_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network='",targets[n],"');",
						 "SELECT road_id, length FROM temp_targets;",sep="")
	if (targets[n]=="localtransit")tsql<-
	                paste("INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_roads_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network in ('tram','metro','bus'));",
	          "INSERT INTO temp_targets SELECT road_id::text, multimodal_id FROM network.transit_areas_interfaces 
						 WHERE multimodal_id in (SELECT multimodal_sid FROM network.transit_stops WHERE network in ('tram','metro','bus'));",
	          "SELECT road_id, length FROM temp_targets;",sep="")
	
	t<- dbGetQuery(con,tsql)
	dbSendQuery(con,"DELETE FROM temp_targets")
	#eliminate links that are not in base
	t<-subset(t,road_id %in% net)
	#add to targets list
	tlist[[n]]<-t
	names(tlist)[n]<-targets[n]
}

#calculate background rank results
#dbSendQuery(con,"DROP TABLE net_centrality")
#dbSendQuery(con,"DROP TABLE temp_window_table")
#dbSendQuery(con,"DROP TABLE temp_central_net")

if (centdata=="private"){
    privaterank <- list("a list")
    dbSendQuery(con,"CREATE TEMP TABLE net_centrality (road_id character varying, length double precision, centrality double precision)")
    dbSendQuery(con,"CREATE TEMP TABLE temp_window_table AS SELECT *, NULL::double precision as total  FROM net_centrality")
    dbSendQuery(con,"CREATE TEMP TABLE temp_central_net AS SELECT * FROM temp_window_table")
    
    for (i in 1:nresults){
        sql<-paste("INSERT INTO net_centrality SELECT road_id, length, ",results[i]," FROM analysis.regional_centrality_private WHERE ",results[i]," IS NOT NULL;",
                "INSERT INTO temp_window_table SELECT s.*, sum(length) OVER previous_rows as total FROM net_centrality s WINDOW previous_rows as (ORDER BY centrality desc ROWS between UNBOUNDED PRECEDING and CURRENT ROW);",
                "INSERT INTO temp_central_net SELECT * FROM temp_window_table WHERE total < (SELECT sum(length)*",as.character(toprank/100)," FROM net_centrality) ORDER BY centrality DESC;",
                "SELECT road_id FROM temp_central_net;",sep="")
        top<-dbGetQuery(con,sql)
        privaterank[[i]]<-top
        dbSendQuery(con,"DELETE FROM net_centrality;DELETE FROM temp_window_table;DELETE FROM temp_central_net;")
    }
}
if (centdata=="multimodal"){
    #for private modes
    privaterank <- list("a list")
    dbSendQuery(con,"CREATE TEMP TABLE net_centrality (road_id character varying, length double precision, centrality double precision)")
    dbSendQuery(con,"CREATE TEMP TABLE temp_window_table AS SELECT *, NULL::double precision as total  FROM net_centrality")
    dbSendQuery(con,"CREATE TEMP TABLE temp_central_net AS SELECT * FROM temp_window_table")

    for (i in 1:nresults){
        sql<-paste("INSERT INTO net_centrality SELECT road_id, length, ",results[i]," FROM analysis.regional_centrality_multimodal WHERE ",results[i]," IS NOT NULL AND the_lines IS NOT NULL;",
                   "INSERT INTO temp_window_table SELECT s.*, sum(length) OVER previous_rows as total FROM net_centrality s WINDOW previous_rows as (ORDER BY centrality desc ROWS between UNBOUNDED PRECEDING and CURRENT ROW);",
                   "INSERT INTO temp_central_net SELECT * FROM temp_window_table WHERE total < (SELECT sum(length)*",as.character(toprank/100)," FROM net_centrality) ORDER BY centrality DESC;",
                   "SELECT road_id FROM temp_central_net;",sep="")
        top<-dbGetQuery(con,sql)
        privaterank[[i]]<-top
        dbSendQuery(con,"DELETE FROM net_centrality;DELETE FROM temp_window_table;DELETE FROM temp_central_net;")
    }

    #for transit modes
    transitrank <- list("a list")
    dbSendQuery(con,"DROP TABLE net_centrality; CREATE TEMP TABLE net_centrality (node character varying, centrality double precision)")
    dbSendQuery(con,"DROP TABLE temp_central_net; CREATE TEMP TABLE temp_central_net AS SELECT * FROM net_centrality")
    
    for (i in 1:nresults){
        sql<-paste("INSERT INTO net_centrality SELECT node, ",results[i]," FROM analysis.regional_centrality_multimodal WHERE ",results[i]," IS NOT NULL AND the_points IS NOT NULL;",
                   "INSERT INTO temp_central_net SELECT top.* FROM (SELECT * FROM net_centrality ORDER BY centrality DESC LIMIT (SELECT count(*)*",as.character(toprank/100)," top FROM net_centrality)) as top;",
                   "SELECT node FROM temp_central_net;",sep="")
        top<-dbGetQuery(con,sql)
        transitrank[[i]]<-top
        dbSendQuery(con,"DELETE FROM net_centrality;DELETE FROM temp_central_net;")
    }
}
if (centdata=="transit"){
    transitrank <- list("a list")
    dbSendQuery(con,"CREATE TEMP TABLE net_centrality (node character varying, centrality double precision)")
    dbSendQuery(con,"CREATE TEMP TABLE temp_central_net AS SELECT * FROM net_centrality")
    
    for (i in 1:nresults){
        sql<-paste("INSERT INTO net_centrality SELECT node, ",results[i]," FROM analysis.regional_centrality_transit WHERE ",results[i]," IS NOT NULL;",
                   "INSERT INTO temp_central_net SELECT top.* FROM (SELECT * FROM net_centrality ORDER BY centrality DESC LIMIT (SELECT count(*)*",as.character(toprank/100)," top FROM net_centrality)) as top;",
                   "SELECT node FROM temp_central_net;",sep="")
        top<-dbGetQuery(con,sql)
        transitrank[[i]]<-top
        dbSendQuery(con,"DELETE FROM net_centrality;DELETE FROM temp_central_net;")
    }
}

#get shortest path for each origin to make a distance matrix
#then calculate centrality values for features of each type
for (j in 1:npostcode){
	#measure distance to base nodes in region
	sp<-shortest.paths(g,v=V(g)[name %in% subset(o,pcode==postcode[j])$link],weights=get.edge.attribute(g,metrics))
	if (nrow(sp)>1) minsp<-apply(sp,2,min) else minsp<-sp[1,]
	for (k in 1:nradius){
		#identify in radius
		rid<-names(subset(minsp, minsp <= radius[k]))
        
        ###
        if (centdata=="private" || centdata=="multimodal"){
            #get centrality results in radius
            rcentrality <- subset(centrality, centrality$node %in% rid)
            
            if (nrow(rcentrality)>0){
                #calculate aggregate values
                for (m in 1:nresults){
        	        rmean <- mean(rcentrality[,results[m]])
        	        rmax <- max(rcentrality[,results[m]])
                    
        	        #update results data
        	        if(!is.na(rmean) & !is.infinite(rmax)){
        	            local_private_agg[j,(((k-1)*nresults*2)+(m-1)*2)+2]<-rmean    
        	            local_private_agg[j,(((k-1)*nresults*2)+(m-1)*2)+3]<-rmax
        	        }
        	        rmean<-NA
        	        rmax<-NA
            
                    #calculate target share values
                    for (n in 1:ntargets){
                        #get total share and share in top rank
                        ttotal <- subset(tlist[[n]], tlist[[n]]$road_id %in% rid)
                        if (nrow(ttotal)>0){
                            ttop <- subset(ttotal, ttotal$road_id %in% privaterank[[m]]$road_id)
                            #calculate target share values
                            tshare<-sum(ttop$length)/sum(ttotal$length)
                            #update results data
                            if(!is.na(tshare)) local_private_share[j,(((k-1)*nresults*ntargets)+(m-1)*ntargets)+(n+1)]<-tshare
                            tsahre<-NA
                        }
                    }#next target
                }#next results column
            }#calculated centrality
        }#end private
        
        ####
        if (centdata=="multimodal" || centdata=="transit"){
        
            #calculate transit aggregate values
            for (n in 1:ntargets){
                #get targets in radius
                rtargets <- subset(tlist[[n]], tlist[[n]]$road_id %in% rid)
                
                if (nrow(rtargets) > 0){
                    rcentrality <- subset(centrality, centrality$node %in% rtargets$length)
                    if (nrow(rcentrality)>0){
                        for (m in 1:nresults){
                            rmean <- mean(rcentrality[,results[m]])
                            rmax <- max(rcentrality[,results[m]])
                            
                            #update results data
                            if(!is.na(rmean) & !is.infinite(rmax)){
                                if (targets[n]=="rail"){
                                    local_transit_agg[j,(((k-1)*nresults*4)+(m-1)*4)+2]<-rmean    
                                    local_transit_agg[j,(((k-1)*nresults*4)+(m-1)*4)+3]<-rmax
                                }
                                if (targets[n]=="localtransit"){
                                    local_transit_agg[j,(((k-1)*nresults*4)+(m-1)*4)+4]<-rmean    
                                    local_transit_agg[j,(((k-1)*nresults*4)+(m-1)*4)+5]<-rmax
                                }
                            }
                            rmean<-NA
                            rmax<-NA
                        }
                     
                        #calculate target share values
                        #get share in top rank
                        ttop <- subset(rtargets, rtargets$length %in% transitrank[[m]]$node)
                        if (nrow(ttop) >0){
                            #calculate target share values
                            tshare<-nrow(ttop)/nrow(rtargets)
                            #update results data
                            if(!is.na(tshare)) local_transit_share[j,(((k-1)*nresults*ntargets)+(m-1)*ntargets)+(n+1)]<-tshare
                            tsahre<-NA
                        }
                    }
                }
            }#get next target
        }#end transit
 	}#next radius
 }#next postcode

#write the result to the database
if (centdata=="private" || centdata=="multimodal"){
    output1<-paste("pcode_centrality_private_agg",base,centdata,sep="_")
    output2<-paste("pcode_centrality_private_share",base,centdata,sep="_")
    if(dbExistsTable(con,c("analysis",output1))) dbRemoveTable(con,c("analysis",output1))
    if(dbExistsTable(con,c("analysis",output2))) dbRemoveTable(con,c("analysis",output2))
    dbWriteTable(con,c("analysis",output1),local_private_agg)
    dbWriteTable(con,c("analysis",output2),local_private_share)
}
if (centdata=="transit" || centdata=="multimodal"){
    output3<-paste("pcode_centrality_transit_agg",base,centdata,sep="_")
    output4<-paste("pcode_centrality_transit_share",base,centdata,sep="_")
    if(dbExistsTable(con,c("analysis",output3))) dbRemoveTable(con,c("analysis",output3))
    if(dbExistsTable(con,c("analysis",output4))) dbRemoveTable(con,c("analysis",output4))
    dbWriteTable(con,c("analysis",output3),local_transit_agg)
    dbWriteTable(con,c("analysis",output4),local_transit_share)
}

#cleanup
dbSendQuery(con,"DROP TABLE temp_targets CASCADE;DROP TABLE net_centrality CASCADE; DROP TABLE temp_central_net CASCADE;")
dbDisconnect(con)
rm(list = ls())
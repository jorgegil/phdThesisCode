#super centrality algorithm with lots of features, but really slow...
#v1.9
# add correct calculation of activity accessibility with distance decay functions

library("RPostgreSQL")
library("igraph")
drv<-dbDriver("PostgreSQL")
con<-dbConnect(drv,dbname="phd_work", port="5433", user="postgres")

#analysis settings
setup<-commandArgs(trailingOnly=TRUE)
if (length(setup)>0){
	graph <- setup[1]
	edges <- setup[2]
	edistance <- setup[3]
	eweight <- setup[4]
	outfilter <- setup[5]
	betwsample <- as.integer(setup[6])
	onodes <- setup[7]
	oweight <- setup[8]
	dnodes <- setup[9]
	dweight <- setup[10]
	rdistance <- setup[11]
	nearradius <- setup[12]
	farradius <- setup[13]
	neardecay <- setup[14]
	fardecay <- setup[15]
	analysis <- setup[16]
	output <- setup[17]
}else{
	#graph: the table containing the graph edges, can have a WHERE condition if "all" edges are selected
	#here : graph.multimodal_randstad
	graph <- "graph.multimodal_randstad"
	#edges: the list of edges that define the background network.
	# default should be "all" and accepts custom condition in the graph parameter. The options are relevant in my work.
	#here: all, nonmotor, car, private, transit, multimodal, nonmotor_transit, car_transit, nonmotor_buildings, car_buildings
	edges <- "transit"
	#edge distance: the impedance metric for the edges
	#here: temporal, temporal_ped, temporal_bike, angular, cogn_angular_seg, etc.
	edistance <- "cogn_angular_seg"
	#edge weight: a route attraction weight for the edges, must be preceded by a coma
	# default is 1. not advisable to use values outside [0,1].
	#here: not used
	eweight <- ""
	#results filter: the table with nodes that are used for storing the results
	#can reduce closeness calculation time if it coincides with the origin nodes or if no betweenneess is calculated
	# default is "" for all nodes.
	#here: name of pre-prepared table that contains the "node" ids as text and other attributes, with no geometry.
	outfilter <- "SELECT multimodal_sid::text node FROM network.transit_stops WHERE network='rail'"
	#betweenness sample: the % of all nodes to use as origin and destination.
	#0 for no betweenness. 100 for all nodes.
	#here: 10% has proven quite good in relation to the complete analysis
	betwsample <- 0
	#origin nodes: the table with nodes that are used as origin of a trip
	# with closeness or catchment only these get a value
	# with betweenness or route these generate trips, but all others can get a value
	#here:name of pre-prepared table that contains the ids as text in attribute "node" and other attributes, with no geometry.
	onodes <- ""
	#origin weight: the trip generation value of the origin.
	#for values [0,1] it's a weighting factor. for values >=1 it's a multiplier that affects normalisation.
	# default is 1. 0 removes origin.
	oweight <- ""
	#destination nodes: the table with nodes that are used as destination of a trip
	# with betweenness or route these generate trips, but all others can get a value
	#here: name of pre-prepared table that contains the ids as text in attribute "node" and other attributes, with no geometry.
	dnodes <- ""
	#destination weight: the attraction value of the destination.
	#for values [0,1] it's a weighting factor. for values >=1 it's a multiplier that affects normalisation.
	# default is 1. 0 removes destination.
	dweight <- ""
	#radius distance: the cutoff metric for the route. can be diference from edistance, must be preceded by a coma
	#here: ,metric,angular,temporal,temporal_ped,temporal_bike
	rdistance <- ""
	#near radius: the cutoff distance before which the routes are not valid.
	#0 is default value. "" for default only, else series of values (same length as farradius). 
	#here: not used
	nearradius <- ""
	#far radius: the cutoff distance beyond which the routes are not valid.
	#N is default. "" for default only, else series of values (same length as nearradius). 
	#here: depends on the type of rdistance
	farradius <- ""
	#near radius decay: function to describe how the near radius limit decays with proximity
	#here: not used
	neardecay <- ""
	#far radius decay: function to describe how the far radius limit decays with distance
	#here: not used
	fardecay <- ""
	#function(x,y){return(1-(x/y)^3)}
	#or using a string - eval(parse(text=string))
	#type of analysis: route,catchment,nearest,density,accessibility,centrality
	analysis <- "centrality"
	#name of output table, without schema
	output <- "randstad_rail_transit_topo"
}

#get background network edges
#for unimodal
if (edges=="nonmotor") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL)",sep="")
if (edges=="private") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='private'",sep="")
if (edges=="car") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='private' AND (car=True OR car IS NULL)",sep="")
if (edges=="localtransit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' AND rail IS NULL AND (transfer=0 OR transfer>1)",sep="")
if (edges=="transit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' AND (transfer=0 OR transfer>1)",sep="")
if (edges=="rail") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' AND transfer=0 AND rail=TRUE",sep="")
#for multimodal
if (edges=="nonmotor_localtransit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE (mobility='public' AND rail IS NULL) OR (mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL))",sep="")
if (edges=="nonmotor_transit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' OR (mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL))",sep="")
if (edges=="private_transit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' OR mobility='private'",sep="")
if (edges=="car_transit") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='public' OR (mobility='private' AND (car=True OR car IS NULL))",sep="")
if (edges=="multimodal") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility<>'building'",sep="")
#for building links
if (edges=="nonmotor_buildings") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='building' OR (mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL))",sep="")
if (edges=="private_buildings") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='building' OR mobility='private'",sep="")
if (edges=="car_buildings") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='building' OR (mobility='private' AND (car=True OR car IS NULL))",sep="")
if (edges=="localtransit_buildings") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='building' OR (mobility='public' AND rail IS NULL) OR (mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL))",sep="")
if (edges=="transit_buildings") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph," WHERE mobility='building' OR mobility='public' OR (mobility='private' AND (pedestrian=True OR pedestrian IS NULL OR bicycle=True OR bicycle IS NULL))",sep="")
if (edges=="all") sql <- paste("SELECT source, target, ",edistance,eweight,rdistance," FROM ",graph,"",sep="")

sql_res <- dbGetQuery(con,sql)
if (nrow(sql_res) == 0) stop("Error reading graph from database.")

g<-graph.data.frame(sql_res,directed=F)
rm(sql_res)

#identify isolated islands
gcluster <- clusters(g)
if (gcluster$no > 1){
  maxclust <- which(gcluster$csize == max(gcluster$csize))
  
  #keep only main cluster
  g<-induced.subgraph(g,which(gcluster$membership == maxclust),"create_from_scratch")
}

#get vertice ids
net <- V(g)$name
lnet <- length(net)

#get ids for results filter
if (outfilter != ""){
	fsql <- outfilter #paste("SELECT * FROM ",outfilter,sep="")
	f <- dbGetQuery(con,fsql)
	if (nrow(f) == 0) stop("Error reading filter from database.")
	rm(fsql)
	#eliminate nodes that do not link to background network
	f <- subset(f,node %in% net)
	nf <- nrow(f)
}else{
	f <- data.frame(node = net)
  f$node <- as.character(f$node)
	nf <- lnet
}

#get ids for origin nodes
if (onodes != ""){
	osql <- onodes #paste("SELECT * FROM ",onodes,sep="")
	o <- dbGetQuery(con,osql)
	if (nrow(o) == 0) stop("Error reading origins from database.")
	rm(osql)
	#eliminate nodes that do not link to background network
	o <- subset(o,node %in% net)
	no <- nrow(o)
}else{
	o <- data.frame(node = net)
	o$node <- as.character(o$node)
	no <- lnet
}

#assign origin weight
if (oweight != ""){
	g <- set.vertex.attribute(g, "oweight", index=V(g), o[match(V(g)$name,o$node),oweight])
	if (max(o[,oweight], na.rm =TRUE) > 1)	calcoweight <- "multiplier" else calcoweight <- "weighting"
}else{
  calcoweight <- "" 
}

#get ids for destination nodes
if (dnodes != ""){
	dsql <- dnodes #paste("SELECT * FROM ",dnodes,sep="")
	d <- dbGetQuery(con,dsql)
	if (nrow(d) == 0) stop("Error reading destinations from database.")
	rm(dsql)
	#eliminate nodes that do not link to background network
	d <- subset(d,node %in% net)
	nd <- nrow(d)
}else{
	d <- data.frame(node = net)
	d$node <- as.character(d$node)
	nd <- lnet
}

#assign destination weight to graph
if (dweight != ""){
	g <- set.vertex.attribute(g, "dweight", index=V(g), d[match(V(g)$name,d$node),dweight])
	if (max(d[,dweight], na.rm =TRUE) > 1) calcdweight <- "multiplier" else calcdweight <- "weighting"
}else{
  calcdweight <- ""
}

#get the betweenness sample
if (betwsample > 0 && betwsample < 100){
	beto <- sample(o$node, round((no*betwsample/100),digits=0))
	betd <- sample(d$node, round((nd*betwsample/100),digits=0))
}
if (betwsample >= 100) {
	beto <- o$node
	betd <- d$node
}

#get radius values
if (rdistance != "") rdistance <- substr(rdistance, 2, nchar(rdistance))

if (nearradius != ""){
	nearradius <- as.numeric(unlist(strsplit(nearradius, split=",")))
	nearradius <- append(nearradius,0)
}else{
	nearradius <- 0
}

if (farradius != ""){
	farradius <- as.numeric(unlist(strsplit(farradius, split=",")))
	farradius <- append(farradius,Inf)
}else{
	farradius <- Inf
}

nnradius<-length(nearradius)
nfradius<-length(farradius)

if (nnradius > nfradius){
	farradius <- rep(farradius, times=nnradius)
	radius <- nearradius
	nradius <- nnradius
}else{
	nearradius <- rep(nearradius, times=nfradius)
	radius <- farradius
	nradius <- nfradius
}

#run analysis
#if (analysis=="route"){}
#if (analysis=="catchment"){}
#if (analysis=="distance"){}
#if (analysis=="density"){}

#########
#ACCESSIBILITY
if (analysis=="accessibility"){
	#prepare data frame for results
	netresults <- as.data.frame(matrix(f$node,nf,1+nradius,byrow=FALSE))
	names(netresults)[1]<-"node"
	#insert null values
	for (m in 1:nradius){
		names(netresults)[m+1]<-paste("access",edistance,tolower(as.character(radius[m])),rdistance,sep="_")
		netresults[,m+1] <- 0
	}
	
	#select nodes that are in filter or an origin
	validnet <- f$node
	#see if radius calculation is necessary
	if (rdistance != "") calcradius <- TRUE else calcradius <- FALSE

	#LOOP GRAPH NODES
	for (j in 1:length(validnet)){
    	#PROCESS VALID NODES
		#exclude current node from targets
    	targets <- subset(d, node != validnet[j])$node
			
		#calculate distance to targets
		sp <- t(shortest.paths(g,v=V(g)[name %in% validnet[j]],to=V(g)[name %in% targets],weights=get.edge.attribute(g,edistance)))
    	#remove infinites
    	sp <- subset(sp, !is.infinite(sp))
		
		#calculate radius distance to targets
		if (calcradius && rdistance != edistance){
			rp <- t(shortest.paths(g,v=V(g)[name %in% validnet[j]],to=V(g)[name %in% targets],weights=get.edge.attribute(g,rdistance)))
		    #remove infinites
    	    rp <- subset(rp, !is.infinite(rp))
		}
			
		#ITERATE THROUGH RADII
		for (i in 1:nradius){		
			#apply radius
			if (calcradius){
				if (rdistance != edistance) rtargets <- subset(rp, rp >= nearradius[i] & rp <= farradius[i])
				if (rdistance == edistance) rtargets <- subset(sp, sp >= nearradius[i] & sp <= farradius[i])
			  	dtargets <- subset(sp, row.names(sp) %in% row.names(rtargets)) # && sp!=NA)
		  	}else{
				dtargets <- sp #subset(sp, sp!=NA)
		  	}

		  	if (nrow(dtargets) > 0){
				#calculate quadratic distance decay times the area of use at that distance 
				dtargets <- sweep((dtargets^-2),1,get.vertex.attribute(g,"dweight",index=V(g)[name %in% row.names(dtargets)]),'*')
				#add destination area
				knodes <- sum(as.numeric(get.vertex.attribute(g,"dweight",index=V(g)[name %in% row.names(dtargets)])))
				#calculate accessibility for node
				netresults[netresults$node==validnet[j],(i+1)] <- sum(as.numeric(dtargets), na.rm = TRUE)
				#netresults[netresults$node==validnet[j],(i+1)] <- ((knodes^2)-knodes)/sum(dtargets, na.rm = TRUE) #this is normalised
			}
        	#HAS NO TARGETS
        	else{
          		netresults[netresults$node==net[j],(i+1)] <- 0
        	}        
        #NEXT RADIUS
		}#END RADIUS
	#NEXT VALID NODE
	}#END GRAPH NODES
}
#END ACCESSIBILITY



#########
#CENTRALITY
if (analysis=="centrality"){
	#prepare data frame for results
	netresults <- as.data.frame(matrix(f$node,nf,1+(nradius*3),byrow=FALSE))
	names(netresults)[1]<-"node"
	#insert null values
	for (m in 1:nradius){
		names(netresults)[((m-1)*3)+2]<-paste("close",edistance,tolower(as.character(radius[m])),rdistance,sep="_")
		netresults[,((m-1)*3)+2] <- 0
		names(netresults)[((m-1)*3)+3]<-paste("betw",edistance,tolower(as.character(radius[m])),rdistance,sep="_") 
		netresults[,((m-1)*3)+3] <- 0
		names(netresults)[((m-1)*3)+4]<-paste("k",edistance,tolower(as.character(radius[m])),rdistance,sep="_") 
		netresults[,((m-1)*3)+4] <- 0
	}
	#container for betweenness intermediate results
	bet <- data.frame(node = net, cent = rep(0, times=lnet))

	#select nodes that are in filter or an origin
	validnet <- f$node
	#see if radius calculation is necessary
	if (rdistance != "") calcradius <- TRUE else calcradius <- FALSE

	#LOOP GRAPH NODES
	for (j in 1:length(validnet)){
    #PROCESS VALID NODES
		#exclude current node from targets
    	targets <- subset(d, node != validnet[j])$node
			
		#calculate distance to targets
		sp <- t(shortest.paths(g,v=V(g)[name %in% validnet[j]],to=V(g)[name %in% targets],weights=get.edge.attribute(g,edistance)))
    	#remove infinites
    	sp <- subset(sp, !is.infinite(sp))
		
		#calculate radius distance to targets
		if (calcradius && rdistance != edistance){
			rp <- t(shortest.paths(g,v=V(g)[name %in% validnet[j]],to=V(g)[name %in% targets],weights=get.edge.attribute(g,rdistance)))
		    #remove infinites
    	    rp <- subset(rp, !is.infinite(rp))
		}

		#get o weight, is the same for every radius
		if (oweight != "" && validnet[j] %in% o$node) poweight <- o[o$node==validnet[j],oweight] else poweight <- 1
			
		#calculate all paths, is necessary for radius N. probably won't work for very large graphs...
		if (betwsample > 0 && validnet[j] %in% beto){
			targets <- subset(betd, betd %in% targets)
			ap <- get.shortest.paths(g,V(g)[name %in% validnet[j]],to=V(g)[name %in% targets],weights=get.edge.attribute(g,edistance),output="vpath")
			#extract the id of the last node of paths (not its V index)
      		alltargets <- unlist(lapply(ap,tail,n=1))
      		#build paths excluding first and last nodes
			allpaths <- lapply(lapply(ap,head,n=-1),tail,n=-1)
		}
			
		#ITERATE THROUGH RADII
			for (i in 1:nradius){		
				#apply radius
			  if (calcradius){
			  	  if (rdistance != edistance) rtargets <- subset(rp, rp >= nearradius[i] & rp <= farradius[i])
			  	  if (rdistance == edistance) rtargets <- subset(sp, sp >= nearradius[i] & sp <= farradius[i])
				  dtargets <- subset(sp, row.names(sp) %in% row.names(rtargets)) # && sp!=NA)
			  }else{
			    dtargets <- sp #subset(sp, sp!=NA)
			  }
 
			  if (nrow(dtargets) > 0){
  				#CLOSENESS
					#calculate node count, the number of destinations
					if (calcdweight == "multiplier"){
						dtargets <- sweep(dtargets,1,get.vertex.attribute(g,"dweight",index=V(g)[name %in% row.names(dtargets)]),'*')
						#add to destinations if required
						knodes <- sum(get.vertex.attribute(g,"dweight",index=V(g)[name %in% row.names(dtargets)]))
						#apply oweight: add to destinations if required
						knodes <- as.numeric(knodes + (poweight-1))
					}else{
						knodes <- as.numeric(nrow(dtargets))
					}
					#calculate closeness
					netresults[netresults$node==validnet[j],((i-1)*3)+2] <- ((knodes^2)-knodes)/sum(dtargets, na.rm = TRUE)
					netresults[netresults$node==validnet[j],((i-1)*3)+4] <- knodes
  				#END CLOSENESS
  	  			
  				#BETWEENNESS: within the closeness loop to re-use the radius calculation
  				if (betwsample > 0 && validnet[j] %in% beto){
  					#select possible targets within radius
  					targets <- subset(betd, betd %in% row.names(dtargets))
            if (length(targets) > 0){
    					#select relevant paths to these targets
    					goodtargets <- subset(alltargets, V(g)[alltargets]$name %in% targets)
    					goodpaths <- allpaths[which(V(g)[alltargets]$name %in% targets)]
  					  #get d weight
  				  	if (dweight != "") pdweight <- get.vertex.attribute(g,"dweight",index=goodtargets) else pdweight <- 1
  				  	#calculate path weight
  			  		pweight <- poweight*pdweight
  			  		#calculate path overlap
  				  	for (k in 1:length(goodpaths)) bet$cent[goodpaths[[k]]] <- bet$cent[goodpaths[[k]]] + pweight[k]
    					netresults[,((i-1)*3)+3] <- netresults[,((i-1)*3)+3] + bet$cent[match(netresults$node,bet$node)]
    					bet$cent <- 0
            }
  				}
          #END BETWEENNESS
			  }
        #HAS NO TARGETS
        else{
          netresults[netresults$node==net[j],((i-1)*3)+2] <- -1
          netresults[netresults$node==net[j],((i-1)*3)+4] <- 0
        }        
        #NEXT RADIUS
			}
      #END RADIUS
		#NEXT VALID NODE
	}
	#END GRAPH NODES
}
#END CENTRALITY
		
#write the results to the database
if(dbExistsTable(con,c("analysis",output))){
  dbRemoveTable(con,c("analysis",output))
}
dbWriteTable(con,c("analysis",output),netresults)

#cleanup
dbDisconnect(con)
rm(list = ls())
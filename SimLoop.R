########### main loop between-herd model#############################
Current <- Queue[1,]
Queue <- Queue[-(1),] # remove this event from the Queue
  # update the status of that farm
# call the function Event. If the function event returns 1, then save this in the history vector
# maybe a bit comlicated construction
#if (Current[,2]!=5){
status_id <- Status[Current[,3]]
#} else {
#status_id <-0
#}# I assign a value 0, because I will not need any statustype for the event culling. #The herd to be culled  will be taken from the culling list
# from the id of the culling list I can find which is the status Status[id_] of the current farm 
if (eval(event(Current[,1],Current[,2],status_id,Current[,3]))==1){  # If the function event returns a new event save it in the history, and draw it on tyhe map
   History <-rbind(History,data.frame(Eventime=Current[,1],Event_char=Current[,2],farm_id=Current[,3],x_coord=Re(Coord[as.numeric(Current[,3])]),y_coord=Im(Coord[as.numeric(Current[,3])]))) # record it in the history vector. In the history vector add the coord
}  
#time<-Current[,1]
# to decide which is the next event compare the time of the 3 vectors (detected, infected, culled)
next_events<-rbind(List_to_infect[1,],List_to_remove[1,])
index_next_event<- which.min(next_events[,1])
Queue <- rbind(Queue,next_events[index_next_event,])
# now remove this event from the list_to_infect or list_to_detect or list_to_cull
# now remove this event from the list_to_infect or list_to_detect or list_to_cull
if(all.equal(cbind(List_to_infect[1,2],List_to_infect[1,3]),cbind(Queue[1,2],Queue[1,3]))==TRUE){
  List_to_infect <-List_to_infect[-c(1),]
} else if(all.equal(cbind(List_to_remove[1,2],List_to_remove[1,3]),cbind(Queue[1,2],Queue[1,3]))==TRUE){
  List_to_remove <-List_to_remove[-c(1),]
}  

#####################################################################

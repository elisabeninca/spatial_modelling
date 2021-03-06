Read me code
================
Elisa Benincà, Jan van de Kassteele, Michiel van Boven

  - [About this repository](#about-this-repository)
  - [Code to generate the point
    patterns](#code-to-generate-the-point-patterns)
      - [Load the packages](#load-the-packages)
      - [Choose a covariance model and set the
        parameters](#choose-a-covariance-model-and-set-the-parameters)
      - [Run the covariance model](#run-the-covariance-model)
      - [Simulate the intensity field. Based on this field we will draw
        the configurations of
        points.](#simulate-the-intensity-field.-based-on-this-field-we-will-draw-the-configurations-of-points.)
      - [Simulate inhomogeneous Poisson process to draw configurations
        of 2000 points from the generated intensity
        fields](#simulate-inhomogeneous-poisson-process-to-draw-configurations-of-2000-points-from-the-generated-intensity-fields)
  - [Spatial SIR transmission model with the Sellke
    construction](#spatial-sir-transmission-model-with-the-sellke-construction)
      - [Load the configuration of points and the matrices of Qinit and
        Tinf](#load-the-configuration-of-points-and-the-matrices-of-qinit-and-tinf)
      - [Choose one of the point
        patterns](#choose-one-of-the-point-patterns)
      - [Calculate the matrix of distances between
        points](#calculate-the-matrix-of-distances-between-points)
      - [Define the transmission kernel and calculate the hazard
        matrix](#define-the-transmission-kernel-and-calculate-the-hazard-matrix)
      - [Model the transmission event between
        hosts](#model-the-transmission-event-between-hosts)
      - [Start the simulation](#start-the-simulation)
      - [Show the simulation outputs](#show-the-simulation-outputs)

## About this repository

R code and documentation belonging to the paper ‘Trade-off between local
transmission and long-range dispersal drives infectious disease
outbreaks in spatially structured populations’ by Elisa Benincà, Thomas
Hagenaars, Jan van de Kassteele, Gert Jan Boender and Michiel van Boven

The main code used in the manuscript is the following:

1)  Code to generate the points patterns. Written in R and illustrated
    in markdown (see below)

2)  Code of the Spatial SIR transmission model with the Sellke
    construction. Written in R and illustrated in markdown (see below)

3)  The metapopulation dynamics calculations. Written in Mathematica.

## Code to generate the point patterns

The program generates the point patterns with the same number of points
(n=2000) and with different levels of clustering

### Load the packages

``` r
# Load packages
library(sp)
library(RandomFields)
library(gridExtra)
library(rprojroot)
library(here)
library(RColorBrewer)
```

Here, I show an example with just one pair of values for the scale and
variance parameters. By running a loop over all possible pairs of scale
and variance values, one can generate point patterns for all the 25
configurations.

### Choose a covariance model and set the parameters

``` r
# Set spConform to FALSE to enable faster simulation
# Set seed to NA to make seed arbitrary
# See help(RFoptions)
RFoptions(spConform = FALSE, seed = NA)

# Set the total number of points
n.points <- 2000

# First choose a covariance model. See help(RMmodel) for the options
# We choose the RMstable model here. See help(RMstable)
# Parameters:
#   var = variance of the random field
#   scale = correlation distance. Note: the effective correlation distance depends on the model!
#   alpha = 'smoothness' parameter (0, 2]. alpha = 1 is exponential decay
scalepar_values <- c(0.1, 2, 4, 8, 16)
varpar_values   <- c(1, 2, 4, 8, 16)

# Initalize a matrix of zeros where you store the number of points
points_conf <- as.data.frame(
  matrix(0,
    nrow = n.points,
    ncol = length(scalepar_values)*length(varpar_values)*2)) # Multiply for 2 because you have x and y coordinates
```

### Run the covariance model

``` r
# Choose one set of scale and variance parameters
scalepar <- scalepar_values[4]
varpar   <- varpar_values[4]

# Covariance model
cov.model <- RMwhittle(var = varpar, scale = scalepar, nu = 1)
```

### Simulate the intensity field. Based on this field we will draw the configurations of points.

I plot the log(intensity) (l.h.s. panel) of the field

``` r
# Set the locations in the x and y direction
# We make a rectangular grid in the unit square
# (also used for plotting the results later on)
x.seq <- seq(from = 0, to = 200, by = 1)
y.seq <- seq(from = 0, to = 200, by = 1)

# Calculate the mean intensity
# This is the mean number of points per grid cell: n.points/n.cells
# However, because of the exponent in the rf term, we should divide by the smearing factor: exp(0.5*var)
n.cells <- length(x.seq)*length(y.seq)
mean.intensity <- n.points/n.cells/exp(0.5*cov.model@par.general$var)

# Set up a dataframe for all results
# We use the expand.grid function from the base package
result.data <- expand.grid(x = x.seq, y = y.seq)

# Fix seed
set.seed(1)

# Add this to result.data
result.data <- within(result.data, {
  # Generate a realisation of the random field
  rf <- RFsimulate(model = cov.model, x = x, y = y)
  # Calculate log intensity
  log.intensity <- log(mean.intensity) + rf
  # Intensity (needs to be positive)
  intensity <- exp(log.intensity)
})

# Add this to result.data
result.data <- within(result.data, {
  # Generate a realisation of the random field
  rf <- RFsimulate(model = cov.model, x = x, y = y)
  # Calculate log intensity
  log.intensity <- log(mean.intensity) + rf
  # Intensity (needs to be positive)
  intensity <- exp(log.intensity)
})

# The sum of all intensities is approximately equal to n.points
# We take care of this later
sum(result.data$intensity)
```

    [1] 701.0775

N.B.: Because of the stochasticity of the process, if you run the model
yourself you will not get exactly the same configurations we have used.

Plot of the log(intensity):

``` r
# Plot log(intensity)
z.breaks <- pretty(result.data$log.intensity, n = 10)
cols <- colorRampPalette(colors = brewer.pal(n = 9, name = "Blues"))(n = length(z.breaks) - 1)
par(mar = c(4.5, 4.5, 0.5, 0.5))
image(x = x.seq, y = y.seq,
z = matrix(result.data$log.intensity, nrow = length(x.seq), ncol = length(y.seq)),
breaks = z.breaks, col = cols)
```

![](README_files/figure-gfm/unnamed-chunk-5-1.png)<!-- -->

### Simulate inhomogeneous Poisson process to draw configurations of 2000 points from the generated intensity fields

For each grid cell, draw a number of points from a multinomial
distribution with a given probability vector. We use the link between
the Poisson distribution and the Multinomial distribution to condition
on the total n.points. The probability = intensity/sum(intensity). Plot
the configuration of points.

``` r
# Simulate inhomogeneous Poisson process
# For each grid cell, draw a number of points from a Multinomial distribution with a given probability vector
# We use the link between the Poisson distribution and the Multinomial distribution to condition on the total n.points
# The probability = intensity/sum(intensity).
# Within the grid cell, the location of the points is uniform in space
result.data <- within(result.data, {
# The number of points within each cell
  n <- rmultinom(n = 1, size = n.points, prob = intensity/sum(intensity))
})

# What is the size of cells?
x.dim <- diff(x.seq)[1]
y.dim <- diff(y.seq)[1]

# Draw points
points.list <- with(result.data, mapply(
  x = x, y = y, n = n,
  FUN = function(x, y, n) {
    # Only draw points if n > 0
    if (n > 0) {
      return(cbind(
        x = runif(n = n, min = x - x.dim/2, max = x + x.dim/2),
        y = runif(n = n, min = y - y.dim/2, max = y + y.dim/2)))
    }
  }))

points_Z.list <- with(result.data, mapply(
  x = x, y = y, n = n,
  FUN = function(x, y, n) {
    # Only draw points if n > 0
    if (n > 0) {
      return(cbind(
        x_Z = runif(n = n, min = x - x.dim/2, max = x + x.dim/2),
        y_Z = runif(n = n, min = y - y.dim/2, max = y + y.dim/2)))
    }
  }))
points.mat <- do.call(what = "rbind", args = points.list)

# Plot the results
plot(points.mat, pch = ".") 
```

![](README_files/figure-gfm/unnamed-chunk-6-1.png)<!-- -->

## Spatial SIR transmission model with the Sellke construction

The model simulates infections spread between immobile hosts
(e.g. poultry farms, plants) using the Sellke construction. The model
assumes only removal of the detected hosts (i.e. no preventive
removal)

### Load the configuration of points and the matrices of Qinit and Tinf

``` r
# load the configurations of points previously generated. See code above.
load("configuration_points_200X200_whittle.Rdata")
# the matrices of Tinf and Qinit have been generated by the following code. To use exactly the same matrices used in the paper load the matrices here 
# numsim <-2000
# totpoints <- nrow(points_conf)
# Q_init_matrix <- matrix(0,nrow=numsim,ncol=totpoints)
# T_inf_matrix <- matrix(0,nrow=numsim,ncol=totpoints)
# for (ii in 1:numsim){
#  Q_init_matrix[ii,] <- rexp(totpoints, rate = 1)
#  T_inf_matrix[ii,] <- rgamma(totpoints,10, scale=7/10)
# }
load("TinfQinit.Rdata")
```

### Choose one of the point patterns

``` r
index<-27
# select one point pattern (x and y coordinates) out of the 25. The matrix has 50 columns, because there are x and y coordinates for each point
matrix_points <- points_conf[,c(index,index+1)]  # I select one point pattern as example
totpoints <- nrow(matrix_points) # total number of points
colnames(matrix_points) <- c("xcoord","ycoord")
# add a column for the index
Index_points <- c(1:totpoints)
```

### Calculate the matrix of distances between points

``` r
# Calculate the matrix of distances
# Express the coordinates as complex numbers for fast calculation of the euclidean distance
Coord <- (complex(length.out=2,real=matrix_points$xcoord,imaginary=matrix_points$ycoord));
distancematrix <- as.matrix(abs(outer(Coord,Coord,"-")))
```

### Define the transmission kernel and calculate the hazard matrix

``` r
#rescale the parameters h0 used in Boender et al. to account for the change in size and number of farms (see main text)
h0 <- 0.002*5360/totpoints; 
alpha  <- 2.1;
r0  <- 1.9;
h_kernel <- function(r){h0/(1 + (r/r0)^alpha)} ; # transmission kernel as a function of r
beta<-1;
# create an hazard matrix evaluating for each host j the chance to be infected by host i as a function of distance 
hazardmatrix  <- as.matrix(apply(distancematrix,MARGIN=c(1,2),FUN=h_kernel));
diag(hazardmatrix) <- matrix(0,nrow=totpoints); # because the chance of infecting itself is 0
```

### Model the transmission event between hosts

``` r
### Define the function handling the events in the spatial transmission model
# Event function has four entries: event_time= time at which an event occurs, eventtype= type of event, statustype=status of host,id_= ID of host
# eventtype:  2=infection; 3=removal;
# statustype: 1= susceptible; 2= infectious; 3= culled;
event <- function(time_event,eventype,statustype,id_){
  if (eventype==2 & statustype==1){
  # calculate the CFI up to that moment
  # I let the CFI grow also for the infected hosts, because they are infected. Of course, the already infected hosts will not be considered in the calculation of the next infection time, because they are already infected 
    CFI <<- CFI+ beta*apply(matrix(hazardmatrix[which(indexI==1),],nrow=length(which(indexI==1)),totpoints),   MARGIN=2,FUN=sum)*(time_event-tt)     # In the rows (i) the infected, in the columns (j) the susceptibles
    # save the CFI in the matrix of CFI
    index_new_event <<- index_new_event + 1
    CFI_matrix[index_new_event,] <<- CFI
    timevector <<- rbind(timevector,time_event)
    # update the status vector and the indices vectors for S and for I
    Status[id_] <<- 2 # now Status= 2 (infected) 
    indexI[id_] <<- 1 # infected
    indexS[id_] <<- 1 # not susceptible anymore
    # save the number of infected over time in a list
    infected_over_time <<- rbind(infected_over_time,c(time_event,length(indexI[indexI==1])))
    # calculate the slope of the force of infection from this moment onwards
    bb[which(indexS==0)] <<- beta*apply(matrix(hazardmatrix[which(indexI==1),which(indexS==0)],nrow=length(which(indexI==1)),ncol=length(which(indexS==0))), MARGIN=2,FUN=sum)       
    # in the rows (i) the infected, in thecolumns (j) the susceptibles
    # calculate the next infection events
    t_infection[which(indexS==0)] <<- (Q_init[which(indexS==0)]-CFI[which(indexS==0)])/bb[which(indexS==0)]
    t_infection[which(indexS==1|indexS==3)] <<- 10000000 # I set a very high number which is not going to happen
    # update the list of points to infect
    next_infection_host <<- which.min(t_infection)  
    next_infection_time <<- t_infection[which.min(t_infection)]
    #update the time
    tt <<- time_event
    #update the list of hosts to infect
    List_to_infect <<- rbind(List_to_infect,data.frame(Event_time = tt+next_infection_time,   Type_event = rep(2,length(next_infection_host)), id_host = next_infection_host))
    List_to_infect <<- List_to_infect[order(List_to_infect[,1]),] 
    #update the list of hosts to remove
    List_to_remove <<- rbind(List_to_remove,data.frame(Event_time=tt+T_inf[id_],Type_event=3,id_host=id_))
    List_to_remove <<- List_to_remove[order(List_to_remove[,1]),] 
    return(1)} else if (eventype==2 & statustype==2) {# already infected
      return(0)} else if (eventype==2 & statustype==3) {# if it has been culled it cannot be infected
        return(0)} else if (eventype==3 & statustype==1) {# it does not occur
          return(0)}else if (eventype==3 & statustype==2){
            # calculate the CFI up to that moment
            # I let the CFI grow also for the infected hosts, because they are infected. 
            # Of course they will not be considered in the calculation of the next infection time, because they are already infected 
            CFI <<- CFI + beta*apply(matrix(hazardmatrix[which(indexI==1),],nrow=length(which(indexI==1)),totpoints),MARGIN=2,FUN=sum)*(time_event-tt) 
            index_new_event <<- index_new_event + 1
            CFI_matrix[index_new_event,] <<- CFI
            # track the CFI over time
            timevector <<- rbind(timevector,time_event)  # track the time
            # update the status vector and the indices vectors for S and for I
            Current[,3] <<- id_
            Status[id_] <<- 3   #culled 
            indexI[id_] <<- 3   #culled, it will not contribute to the infectious matrix anymore
            indexS[id_] <<- 3   #culled, it is not susceptible anymore
            # save the number of infected over time in a list
            infected_over_time <<- rbind(infected_over_time,c(time_event,length(indexI[indexI==1])))
            if(length(which(indexI==1))!=0){ # if there are still individual infected
              # update the slope of the force of infection 
              bb[which(indexS==0)] <<- beta*apply(matrix(hazardmatrix[which(indexI==1),which(indexS==0)],nrow=length(which(indexI==1)), ncol=length(which(indexS==0))),MARGIN=2,FUN=sum) 
              # calculate for each susceptible the next possible infection event
              t_infection[which(indexS==0)] <<- (Q_init[which(indexS==0)]-CFI[which(indexS==0)])/bb[which(indexS==0)]
              t_infection[which(indexS==1|indexS==3)]  <<- 10000000
              # update the time
              tt <<- time_event
              next_infection_host <<- which.min(t_infection)  
              next_infection_time <<- t_infection[which.min(t_infection)]
              # if the next infection host is already in the queue, you need to remove the old one and add the new one with the     updated time of infection
              if ((next_infection_host%in%List_to_infect$id_host)==TRUE){
                List_to_infect <<- List_to_infect[-(which((List_to_infect$id_host%in%next_infection_host)==TRUE)),]
              }
              List_to_infect <<- rbind(List_to_infect,data.frame(Event_time=tt+next_infection_time,Type_event=rep(2,length(next_infection_time)),id_host=next_infection_host))
              List_to_infect <<- List_to_infect[order(List_to_infect[,1]),] 
            } else if (length(which(indexI==1)) == 0){# if there are no infection events anymore the cumulative force infection of the susceptible should be set to 0 
              #update the slope of the force of infection 
              bb[which(indexS==0)] <<- 0           
              List_to_infect <<- {}
            } 
            return(1)}
}
```

### Start the simulation

I first call the R file where I initialize the variables (“InitSim.R”)
Then I call the file (“SimLoop.R”) that calls in a loop the function
Event() defined above

``` r
########## start the simulation #####################################
#ptm <- proc.time()
K<-100  # define the first infected
T_inf <- T_inf_matrix[K,]   # rgamma(totpoints,10, scale=7/10) # mean=7, std=2
Q_init <- Q_init_matrix[K,] # rexp(totpoints, rate = 1) # these are the thresholds (exposure to infection) picked from an exponential distribution of mean 1
```

``` r
source("InitSim.R") # initialization and setting of the first infected
while(nrow(Queue)!=0){
source("Simloop.R")
}
```

### Show the simulation outputs

The outputs are stored in the matrix History

``` r
head(History)
```

``` 
  Event_time Type_event host_id  x_coord  y_coord
1   0.000000          2     100 77.36292 3.481041
2   1.881869          2      79 73.90368 3.113401
3   2.955072          2     151 72.87699 5.065190
4   3.555003          2     134 75.70076 4.334627
5   4.410185          2     129 74.89995 3.800681
6   5.483276          2     200 77.97323 8.404548
```

``` r
tail(History)
```

``` 
    Event_time Type_event host_id  x_coord   y_coord
173   49.56258          3      30 82.69106 0.8412298
174   49.90415          3     123 74.09210 3.9681077
175   51.13527          3     181 76.48365 7.4355415
176   51.88571          2      14 68.07397 1.2165525
177   56.44712          3      44 68.55203 1.7210090
178   61.34625          3      14 68.07397 1.2165525
```

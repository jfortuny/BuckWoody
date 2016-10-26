# Database NYCTaxiData in TEST-BI06\SQLserverR
# Methodology described at https://azure.microsoft.com/en-us/documentation/articles/data-science-process-overview/
# Code available at https://github.com/Azure/Azure-MachineLearning-DataScience/tree/master/Misc/RSQL

# page 19
.libPaths(c(.libPaths(), "C:\\Program Files\\Microsoft SQL Server\\MSSQL13.SQLSERVERR\\R_SERVICES\\library"))
.libPaths()

# Compute Context #########################################################################################
# RxInSqlServer()
library(RevoScaleR)
# User SQLserverR_user has password Amerilife01
# Connection String
connStr <- "Driver=SQL Server;Server=TEST-BI06\\SQLServerR;Database=NYCTaxiData;Uid=SQLserverR_user;Pwd=Amerilife01"
# Compute context
sqlShareDir <- paste("F:\\Rshare", Sys.getenv("SQLServerR_user"), sep = "")
sqlWait <- TRUE
sqlConsoleOutput <- FALSE
cc <- RxInSqlServer(connectionString = connStr,
    shareDir = sqlShareDir,
    wait = sqlWait, consoleOutput = sqlConsoleOutput)
rxSetComputeContext(cc)

# SQLServerData object ####################################################################################
# RxSqlServerData()
sampleDataQuery <- "select top 1000 tipped, tip_amount, fare_amount,
passenger_count,trip_time_in_secs,trip_distance,
pickup_datetime, dropoff_datetime,
cast(pickup_longitude as float) as pickup_longitude,
cast(pickup_latitude as float) as pickup_latitude,
cast(dropoff_longitude as float) as dropoff_longitude,
cast(dropoff_latitude as float) as dropoff_latitude,
payment_type from nyctaxi_sample
tablesample(1 percent) repeatable(98052) "

ptypeColInfo <- list(
    payment_type = list(
        type = "factor",
        levels = c("CSH", "CRD", "DIS", "NOC", "UNK"),
        newLevels = c("CSH", "CRD", "DIS", "NOC", "UNK")
    )
)

inDataSource <- RxSqlServerData(sqlQuery = sampleDataQuery,
    connectionString = connStr,
    colInfo = ptypeColInfo,
    colClasses = c(pickup_longitude = "numeric", pickup_latitude = "numeric",
                   dropoff_longitude = "numeric", dropoff_latitude = "numeric"),
     rowsPerRead = 500
     )
str(inDataSource)

# Exploratory Data Analysis ###############################################################################
# user requires db_datawriter to execute this next statement
rxGetVarInfo(data = inDataSource)

start.time <- proc.time()
# user seems to require db_owner rights to execute this next statement
rxSummary( ~ fare_amount:F(passenger_count, 1, 6), data = inDataSource)
used.time <- proc.time() - start.time
print(paste("It takes CPU Time=", round(used.time[1] + used.time[2], 2), " seconds, Elapsed Time=",
           round(used.time[3], 2), " seconds to summarize the inDataSource.", sep = ""))

# Data Visualization ######################################################################################
# create histogram
rxHistogram( ~ fare_amount, data = inDataSource, title = "Fare Amount Histogram")
# create map
# 1 utility function
mapPlot <- function(inDataSource, googMap) {
    library(ggmap)
    library(mapproj)
    ds <- rxImport(inDataSource)
    p <- ggmap(googMap) +
    geom_point(aes(x = pickup_longitude, y = pickup_latitude),
        data = ds, alpha = 0.5, color = "darkred", size = 1.5)
    return(list(myplot = p))
}
# 2 create the map object
library(ggplot2)
library(ggmap)
library(mapproj)
gc <- geocode("Times Square", source = "google")
googMap <- get_googlemap(center = as.numeric(gc), zoom = 12, maptype = "roadmap", color = "color");
# 3 call the utility function
myplots <- rxExec(mapPlot, inDataSource, googMap, timesToRun = 1)
plot(myplots[[1]][["myplot"]]);

# Feature Engineering #####################################################################################
# In R with an R script
env <- new.env()
env$ComputeDist <- function(pickup_long, pickup_lat, dropoff_long, dropoff_lat) {
    R <- 6371 / 1.609344 #radius in mile
    delta_lat <- dropoff_lat - pickup_lat
    delta_long <- dropoff_long - pickup_long
    degrees_to_radians = pi / 180.0
    a1 <- sin(delta_lat / 2 * degrees_to_radians)
    a2 <- as.numeric(a1) ^ 2
    a3 <- cos(pickup_lat * degrees_to_radians)
    a4 <- cos(dropoff_lat * degrees_to_radians)
    a5 <- sin(delta_long / 2 * degrees_to_radians)
    a6 <- as.numeric(a5) ^ 2
    a <- a2 + a3 * a4 * a6
    c <- 2 * atan2(sqrt(a), sqrt(1 - a))
    d <- R * c
    return(d)
}

featuretable = paste0("NYCTaxiDirectDistFeatures")
featureDataSource = RxSqlServerData(table = featuretable,
    colClasses = c(pickup_longitude = "numeric",
    pickup_latitude = "numeric", dropoff_longitude = "numeric",
    dropoff_latitude = "numeric", passenger_count = "numeric",
    trip_distance = "numeric", trip_time_in_secs = "numeric",
    direct_distance = "numeric"), connectionString = connStr
  )

rxDataStep(inData = inDataSource, outFile = featureDataSource, overwrite = TRUE,
    varsToKeep = c("tipped", "fare_amount", "passenger_count", "trip_time_in_secs",
    "trip_distance", "pickup_datetime", "dropoff_datetime",
    "pickup_longitude", "pickup_latitude", "dropoff_longitude",
    "dropoff_latitude"),
    transforms = list(direct_distance = ComputeDist(pickup_longitude, pickup_latitude, dropoff_longitude,
    dropoff_latitude)),
    transformEnvir = env, rowsPerRead = 500, reportProgress = 3
  )

rxGetVarInfo(data = featureDataSource)

#  In R with a SQL Server function
ptypeColInfo <- list(
    payment_type = list(
        type = "factor",
        levels = c("CSH", "CRD", "DIS", "NOC", "UNK"),
        newLevels = c("CSH", "CRD", "DIS", "NOC", "UNK")
    )
)
featureEngineeringQuery = "SELECT tipped, fare_amount, passenger_count,
                            trip_time_in_secs, trip_distance, pickup_datetime,
                            dropoff_datetime,
                            dbo.fnCalculateDistance(
                                cast(pickup_latitude as float),
                                cast(pickup_longitude as float),
                                cast(dropoff_latitude as float),
                                cast(dropoff_longitude as float)) as direct_distance,
                            pickup_latitude, pickup_longitude, dropoff_latitude,
                            dropoff_longitude, payment_type
    FROM nyctaxi_sample
    tablesample (1 percent) repeatable (98052)"

featureDataSource = RxSqlServerData(sqlQuery = featureEngineeringQuery,
    colInfo = ptypeColInfo, colClasses = c(pickup_longitude = "numeric",
    pickup_latitude = "numeric", dropoff_longitude = "numeric",
    dropoff_latitude = "numeric",
    passenger_count = "numeric",
    trip_distance = "numeric",
    trip_time_in_secs = "numeric",
    direct_distance = "numeric",
    fare_amount = "numeric"),
    connectionString = connStr
    )

# Creating and Saving Models ##############################################################################
# Using an R environment
str(featureDataSource)
logitObj <- rxLogit(tipped ~ passenger_count + trip_distance + trip_time_in_secs +
    direct_distance, data = featureDataSource)
summary(logitObj)

# save the model in SQL Server for future use
# First serialize it
modelbin <- serialize(logitObj, NULL)
modelbinstr = paste(modelbin, collapse = "")

#--Create a stored procedure for saving model in the nyc_taxi_models table (database NYCTaxiData)
# CREATE PROCEDURE[dbo] .[myPersistModel]
#   @m nvarchar(max)
# AS
# BEGIN
#   --SET NOCOUNT ON added to prevent extra result sets from
#   --interfering with SELECT statements.
#   SET NOCOUNT ON;
#   insert into nyc_taxi_models(model) values(convert(varbinary(max), @m, 2))
# END

# Persist model by calling a stored procedure from SQL
library(RODBC)
conn <- odbcDriverConnect(connStr)
q <- paste("EXEC PersistModel @m='", modelbinstr, "'", sep = "")
sqlQuery(conn, q)

# Consuming Models ########################################################################################
# Using an R environment
scoredOutput <- RxSqlServerData(connectionString = connStr,
    table = "taxiScoreOutput")
# now predict
rxPredict(modelObject = logitObj, data = featureDataSource, outData = scoredOutput,
    predVarNames = "Score", type = "response",
    writeModelVars = TRUE, overwrite = TRUE)


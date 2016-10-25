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
connStr <- "Driver=SQL Server;Server=TEST-BI06.algtest.local\\SQLServerR;Database=NYCTaxiData;Uid=SQLserverR_user;Pwd=Amerilife01"
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

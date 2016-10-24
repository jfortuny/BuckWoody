# SQL Server connection set-up
connStr <- "Driver=SQL Server;Server Name=test-sql06.algtest.local\\sqlserverR;DatabaseName=NYCTaxiData;Uid=sa;Pwd=Lrsfqb6bRwZNUQouEkPE"
sqlShareDir <- paste("C:\\temp\\", Sys.getenv("USERNAME"), sep = "")
sqlWait <- TRUE
sqlConsoleOutput <- FALSE

# Compute Context
cc <- RxInSqlServer(connectionString = connStr, 
    shareDir = sqlShareDir, 
    wait = sqlWait, consoleOutput = sqlConsoleOutput)
rxSetComputeContext(cc)

# Query
sampleDataQuery <- "SELECT TOP (10000) [medallion]
      ,[fare_amount]
      ,[surcharge]
  FROM [dbo].[nyctaxi_sample]"
inDataSource <- RxSqlServerData(sqlQuery = sampleDataQuery, connectionString = connStr,
    colClasses = c(medallion = "string", fare_amount = "numeric", surcharge = "numeric"),
    rowsPerRead = 500)
str(inDataSource)

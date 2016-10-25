# page 13
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

# page 14
execute sp_execute_external_script
    @language = N 'R', 
    @script = N 'OutputDataSet<-InputDataSet;',
    @input_data_1 = N 'select * from [dbo].[nyctaxi_sample];' 
with result sets();
# more examples: https://msdn.microsoft.com/library/mt591996.aspx

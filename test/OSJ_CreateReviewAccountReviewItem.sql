USE [OSJSupervision]
GO

/****** Object:  StoredProcedure [dbo].[OSJ_CreateReviewAccountReviewItem]    Script Date: 3/22/2024 4:46:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[OSJ_CreateReviewAccountReviewItem]  
/********************************************************************************************  
Stored Procedure: $HeaderUTC$  
=============================================================================================  
Name:  OSJ_CreateReviewAccountReviewItem  
---------------------------------------------------------------------------------------------  
Author:  William Lee  
---------------------------------------------------------------------------------------------  
Version:  1.0  
---------------------------------------------------------------------------------------------  
Project:  OSJ Manager Surveillance System  
---------------------------------------------------------------------------------------------  
Purpose: Create ReviewAccount records & ReviewItem records from ReviewAccountTransaction records.  
---------------------------------------------------------------------------------------------  
Syntax:  EXEC OSJ_CreateReviewAccountReviewItem 50 ,1 
=============================================================================================  
Comments:   
---------------------------------------------------------------------------------------------  
$LogUTC[5]$  
  1.0 2006-12-06 William Lee Initial version
  1.1 2014-09-05  Khushboo Dubey     -- Added a Parameter @TenantID for implementing MultiTenancy Feature.This will add the data in table specific to LPL and AXA    
  1.2 2014-09-10  Shripriya Chanduru	Added DIS error/log processing logic
=============================================================================================  
(C) Copyright 2006 LPL, Inc.. All Rights Reserved.  
THIS SOURCE CODE IS THE PROPERTY OF LPL, Inc.. IT MAY BE USED BY RECIPIENT ONLY FOR THE   
PURPOSE FOR WHICH IT WAS TRANSMITTED AND WILL BE RETURNED UPON REQUEST OR WHEN NO LONGER   
NEEDED BY RECIPIENT. IT MAY NOT BE COPIED OR COMMUNICATED WITHOUT THE WRITTEN CONSENT   
OF LPL, Inc.   
********************************************************************************************/  
 @reviewItemTypeID int,  
 @TenantID int, -- Added a Parameter @TenantID for implementing MultiTenancy Feature
 @cutOffDate datetime=NULL  
AS  
 SET NOCOUNT ON  
   
 IF @cutOffDate IS NULL SELECT @cutOffDate=getdate()  
 DECLARE @err int  
 
 DECLARE @DISErrorNumber int
 DECLARE @ErrorMessage VARCHAR(1024)
 DECLARE @SPName sysname
 
 	SET @SPName = 'OSJ_CreateReviewAccountReviewItem'

  --Create the temp table if they do not exist. Aids in debugging runs.
	IF NOT EXISTS (select * from tempdb.dbo.sysobjects where id = object_id(N'tempdb.dbo.#StoredProcProgressMessages'))
		CREATE TABLE #StoredProcProgressMessages
		(
			MessageTime DATETIME,
			ProcedureName varchar(256),
			Message varchar(2048),
			ErrorCode int
		)

	IF NOT EXISTS (select * from tempdb.dbo.sysobjects where id = object_id(N'tempdb.dbo.#StoredProcErrorMessages'))
		CREATE TABLE #StoredProcErrorMessages
		(
			ErrorNumber int,
			ErrorMessage varchar(2048)
		)


	INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'Start Procedure', -1 )

	SET @DISErrorNumber = -1
  
  
 DECLARE @LastReviewCreatedDt datetime  
 SELECT  
  @LastReviewCreatedDt = LastReviewItemCreatedDt  
 FROM  
  OSJSupervision.dbo.ReviewItemType   
 WHERE  
  ReviewItemTypeID=@reviewItemTypeID
  AND TenantID = @TenantID    --Filter data specific to TenantID(1= LPL and 3= AXA) 
  
  
 DECLARE @reviewAccountID int  
 SELECT  
  @reviewAccountID = ISNULL(MAX(ReviewAccountID),0)  
 FROM  
  OSJSupervision.dbo.ReviewAccount (nolock)
  WHERE TenantID = @TenantID    --Filter data specific to TenantID(1= LPL and 3= AXA) 
   
   
 DECLARE @ID_tbl table  
 (  
  ID int identity (1,1),  
  accountNo char(8)  
 )   
 INSERT INTO  
  @ID_tbl(accountNo) -- filter out a list of unique tranRecordId that are possible fornt-running  
 SELECT  
  DISTINCT AccountNo  
 FROM  
  OSJSupervision.dbo.ReviewAccountTransaction (nolock)  
 WHERE  
  ReviewItemTypeID=@reviewItemTypeID  
  AND ReviewAccountID IS NULL
  AND TenantID = @TenantID    --Filter data specific to TenantID(1= LPL and 3= AXA) 
  AND RecordedDate > @LastReviewCreatedDt  
  AND RecordedDate < @cutOffDate  
  
  INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'STarting Transaction', -1 )
   
   
 BEGIN TRAN  
 -- create ReviewAccount records  
 INSERT INTO OSJSupervision.dbo.ReviewAccount  
 (  
  ReviewAccountID,  
  AccountNo,  
  AccountName,  
  Age,  
  InvestmentObj,  
  --AccountLocationCode,  
  RepID,  
  --NetWorth,  
  LiquidNetWorth,  
  AnnualIncome,  
  LPLAccountValue,  
  ReviewItemTypeID,
  TenantID  
 )  
   
   
 SELECT   
  @reviewAccountID+[ID],   
  a.accountNo,  
  lpl.AccountName,  
  datediff (mm, lpl.PrimaryBirthdate, getdate())/12,  
  invobj.Name,  
  lpl.RepID,  
  liqnetw.Name,  
  anninc.Name,  
  lpl.LPLAccountValue,  
  @reviewItemTypeID,
  @TenantID  
 FROM  
  @ID_tbl a   
  INNER JOIN LPLCustomer.dbo.AccountLPL lpl (nolock) ON  
   a.accountNo = lpl.LPLAccountNo  
  LEFT OUTER JOIN Beta.dbo.Beta_Acct_Demo bad ON  
   a.accountNo = bad.AccountNo   
  LEFT OUTER JOIN Support.dbo.InvestmentObjective invobj (nolock)  
   ON lpl.InvestmentObjectiveCode = invobj.LPLCode   
  LEFT OUTER JOIN Support.dbo.AnnualIncome anninc (nolock)  
   ON bad.CombinedNetIncome = anninc.LPLCode   
  LEFT OUTER JOIN Support.dbo.LiquidNetWorth liqnetw (nolock)  
   ON bad.SpouseNetIncome = liqnetw.LPLCode   
   
SELECT @DISErrorNumber = @@ERROR
        IF @DISErrorNumber <> 0
	BEGIN
		SET @ErrorMessage = 'Failed to insert records into OSJSupervision.dbo.ReviewAccount '
		GOTO SP_EXIT
	END

	INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'Successfully inserted records into OSJSupervision.dbo.ReviewAccount ', -1 )
   
  
 UPDATE  
  OSJSupervision.dbo.ReviewAccountTransaction  
 SET  
  ReviewAccountID=  @reviewAccountID+a.[ID]  
 FROM   OSJSupervision.dbo.ReviewAccountTransaction rac (nolock)   INNER JOIN @ID_tbl a ON rac.AccountNo=a.accountNo  
 WHERE  
  ReviewItemTypeID=@reviewItemTypeID  
  AND ReviewAccountID IS NULL
  AND TenantID = @TenantID    --Filter data specific to TenantID(1= LPL and 3= AXA)   
  AND RecordedDate > @LastReviewCreatedDt  
  AND RecordedDate < @cutOffDate  
  
SELECT @DISErrorNumber = @@ERROR
        IF @DISErrorNumber <> 0
	BEGIN
		SET @ErrorMessage = 'Failed to update the table OSJSupervision.dbo.ReviewAccountTransaction'
		GOTO SP_EXIT
	END

	INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'Successfully updated the table OSJSupervision.dbo.ReviewAccountTransaction', -1 )
    
   
 -- create ReviewItem records  
 EXEC @err=OSJ_CreateReviewItem @reviewItemTypeID ,@TenantID 
 
 SELECT @DISErrorNumber = @@ERROR
        IF @DISErrorNumber <> 0
	BEGIN
		SET @ErrorMessage = 'Failed to execute OSJ_CreateReviewItem'
		GOTO SP_EXIT
	END

	INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'Successfully executed OSJ_CreateReviewItem', -1 )
  
  DELETE FROM #StoredProcErrorMessages
  
SP_EXIT:  
 IF @DISErrorNumber <> 0
 BEGIN
	ROLLBACK 
	
	 INSERT INTO #StoredProcProgressMessages
	( MessageTime, ProcedureName, Message, ErrorCode )
	VALUES
	(Getdate(), @SPName, 'Transaction Rollback', -1 )
END
 ELSE  
  COMMIT
  
 IF @ErrorMessage IS NOT NULL
	BEGIN
	
		--DELETE FROM #StoredProcErrorMessages
		
	  INSERT INTO #StoredProcErrorMessages
	    (ErrorNumber, ErrorMessage)
	  VALUES
	    ( @DISErrorNumber, @ErrorMessage )
    
	  PRINT @ErrorMessage
	 END
GO



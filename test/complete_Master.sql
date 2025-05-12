USE [OSJSupervision]
GO

/****** Object:  StoredProcedure [dbo].[complete_Master]    Script Date: 3/22/2024 4:26:24 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE [dbo].[complete_Master]     
(    
 @Tenantid int ,
 @ReviewitemId int=NULL   
)    
                                     
AS                                      
BEGIN                                      
 /*==============================================================================                                                      
Project: OSJ Review Tool - Rewrite                                                     
------------------------------------------------------------------------------                                                      
Description:                                                      
----------------------------------------------------------------------------                                                      
Return Type:  
Comments: 
04/26/2016 Sai Amirineni Adding new column ReasonForCOAFlag.                                      
==============================================================================*/                                      
 SET NOCOUNT ON                                      
                                      
 DECLARE @err INT,                                      
  @ErrorMessage VARCHAR(1024),                                      
  @SPName SYSNAME,                                      
  @DISErrorNumber INT                                      
                                      
 SELECT @SPName = 'complete_Master'                                      
                                      
 IF NOT EXISTS (                                      
   SELECT *                                      
   FROM tempdb.dbo.sysobjects                                      
   WHERE id = object_id(N'tempdb.dbo.#StoredProcProgressMessages')                                      
   )                                      
  CREATE TABLE #StoredProcProgressMessages (                                      
   MessageTime DATETIME,                                      
   ProcedureName VARCHAR(256),                                      
   Message VARCHAR(2048),                                      
   ErrorCode INT                                      
   )                                      
                                      
 INSERT INTO #StoredProcProgressMessages (                                      
  MessageTime,                                      
  ProcedureName,                                      
  Message,                                      
  ErrorCode                                      
  )                                      
 VALUES (                                      
  Getdate(),                                      
  @SPName,                                      
  'Start Procedure',                                      
  - 1                                      
  )                                      
                                      
 SET @DISErrorNumber = - 1                                      
 
if(@Reviewitemid is null or @reviewitemid ='')
 Begin                                      
 
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CompleteTaskList]') AND type in (N'U'))      
DROP TABLE [dbo].[CompleteTaskList]      
      
      
CREATE TABLE [dbo].[CompleteTaskList](      
 [RowNumber] [int] IDENTITY(1,1) NOT NULL,      
 [TaskId] [int] NULL,      
 [TaskTypeId] [int] NULL,      
 [TaskTypeDescription] [varchar](64) NULL,      
 [CompletionDate] [datetime] NULL,      
 [DueDate] [datetime] NULL,      
 [Notes] [varchar](4000) NULL,      
 [Status] [varchar](30) NULL,      
 [ClientName] [varchar](80) NULL,       
 [BranchID] [char](4) NULL,      
 [RepId] [char](4) NULL,      
 [OSJREPID] [char](4) NULL,      
 [MasterRepId] [char](4) NULL,      
 [RepName] [varchar](30) NULL,      
 [AccountID] [int] NULL,      
 [LPLCustomerAccountID] [int] NULL,      
 [AccountNumber] [char](8) NULL,      
 [StatusId] [int] NULL,      
 [DisplayGroup] [smallint] NULL,      
 [CreateDate] [datetime] NULL,      
 [ReviewedBy] [char](4) NULL,      
 [DisplayText] [varchar](50) NULL,      
 [Name1] [varchar](30) NULL,      
 [Name2] [varchar](30) NULL,      
 [Name3] [varchar](30) NULL,      
 [Name4] [varchar](30) NULL,      
 [Name5] [varchar](30) NULL,      
 [Name6] [varchar](30) NULL,      
 [AccountName] [varchar](40) NULL,      
 [StreetAddress1] [varchar](80) NULL,      
 [StreetAddress2] [varchar](80) NULL,      
 [City] [varchar](30) NULL,      
 [State] [char](2) NULL,      
 [Zip] [char](9) NULL,      
 [ClientPhone] [char](11) NULL,      
 [SSN] [char](9) NULL,      
 [DOB] [datetime] NULL,      
 [GroupID] [int] NULL,      
 [IsSSN] [bit] NULL,      
 [IsHighRisk] [bit] NULL,      
 [HighRiskConditions] [varchar](4000) NULL,      
 [ApprovalStatus] [varchar](20) Default 'Reviewed',      
 [RequiresApproval] [bit] NULL,      
 [ownTask] [bit] NULL,      
 [DataMissing] [bit] NULL,      
 [ComCount] [int] NULL,      
 [ComStatus] [varchar](20) NULL,      
 [CommunicationStatusID] [int] NULL,      
 [CommunicationID] [int] NULL,      
 [DPId] [char](4) NULL,      
 [TenantID] [int] NULL,      
 [ReviewerName] [varchar](30) NULL,
 [ReasonForCOAFlag] [VARCHAR] (4000) NULL     
) ON [PRIMARY]      
  
  End    
 If(@tenantid = 1)  
 Begin                 
                                
 Print 'Started Step 1 , Loading all columns from ReviewItemCompleted/ReviewItemType/ReviewStatus'                                   
 SELECT @SPName = 'OSJ_GetReviewItemList_complete_ServerPaging_Filtering_Internal'                                      
 EXEC OSJ_GetReviewItemList_complete_ServerPaging_Filtering_Internal  @Reviewitemid                                    
 Print 'Completed Step 1'                                     
                                 
 Print 'Started Step 2, Loading HighRisk Columns'                                  
 SELECT @SPName = 'update_isHighRisk_completeTaskList'                                      
 EXEC update_isHighRisk_completeTaskList  @Reviewitemid                                    
 Print 'Completed Step 2'                                    
                                      
 Print 'Started Step 3, Loading Communications Columns'                                  
 SELECT @SPName = 'update_Communication_completeTaskList'                                      
 EXEC update_Communication_completeTaskList  @Reviewitemid                                       
 Print 'Completed Step 3'                                    
                                 
 Print 'Started Step 4, Loading all the Beta Columns'                                     
 SELECT @SPName = 'exec Update_ReviewAccountno_BetaCoumns_Complete'                                  
 EXEC  Update_ReviewAccountno_BetaCoumns_Complete @Reviewitemid            
 Print 'Completed Step 4'                                  
                                 
                                     
 Print 'Started Step 5, Loading all the Groupinfo and LPLAccount Columns'                                     
 SELECT @SPName = 'update_GroupInfo_AccountLPL_columns_Complete'                                  
 EXEC update_GroupInfo_AccountLPL_columns_Complete @Reviewitemid                                    
 Print 'Completed Step 5'                                  
                                 
 Print 'Started Step 6, Updating the Notes columns'                                       
 SELECT @SPName = 'update_Notes_Complete'                                      
 EXEC update_Notes_Complete @Reviewitemid                               
 Print 'Completed Step 6'                                     
                                 
                                 
 Print 'Started Step 7, Updating RequiresApproval'                                       
 SELECT @SPName = 'update_approval'                                      
 EXEC update_approval @Reviewitemid                                    
 Print 'Completed Step 7'                   
                 
 Print 'Started Step 8, Updating DataMissing'                                       
 SELECT @SPName = 'update_dataMissing_complete'                                      
 EXEC update_dataMissing_complete @Reviewitemid                                    
 Print 'Completed Step 8'   
   
  Print 'Started Step 9, Updating the ReasonForCOAFlag columns'                           
  SELECT @SPName = 'update_ReasonForCOAFlag_complete'                          
  EXEC update_ReasonForCOAFlag_complete                         
  Print 'Completed Step 9'                 
                  
 update tasklog                 
 set CheckEndDate = getdate(),Tenantid = @Tenantid       
 where   TaskName = 'completeMaster'    
   
End  
  
ELSE If(@Tenantid=3)  
BEGIN  
   
 Print 'Started Step 1 , Loading all columns from ReviewItemCompleted/ReviewItemType/ReviewStatus'                                     
 SELECT @SPName = 'OSJ_GetReviewItemList_complete_ServerPaging_Filtering_Internal_AXA'                                        
 EXEC OSJ_GetReviewItemList_complete_ServerPaging_Filtering_Internal_AXA  @Reviewitemid                                  
 Print 'Completed Step 1'  
   
 --Print 'Started Step 2, Loading HighRisk Columns'                                  
 --SELECT @SPName = 'update_isHighRisk_completeTaskList_AXA'                                      
 --EXEC update_isHighRisk_completeTaskList_AXA  @Reviewitemid                               
 --Print 'Completed Step 2'   
   
 Print 'Started Step 2, Loading all the Beta Columns'                                     
 SELECT @SPName = 'exec Update_ReviewAccountno_BetaCoumns_Complete'                                  
 EXEC  Update_ReviewAccountno_BetaCoumns_Complete  @Reviewitemid           
 Print 'Completed Step 2'   
   
 Print 'Started Step 3, Loading all the Groupinfo and LPLAccount Columns'                                     
 SELECT @SPName = 'update_GroupInfo_AccountLPL_columns_Complete'                                  
 EXEC update_GroupInfo_AccountLPL_columns_Complete  @Reviewitemid                                   
 Print 'Completed Step 3'  
   
 Print 'Started Step 4, Updating the Notes columns'                                       
 SELECT @SPName = 'update_Notes_Complete'                                     
 EXEC update_Notes_Complete @Reviewitemid                                     
 Print 'Completed Step 4'   
   
   
 Print 'Started Step 5, Updating RequiresApproval'                                       
 SELECT @SPName = 'update_approval'                                      
 EXEC update_approval  @Reviewitemid                                
 Print 'Completed Step 5'   
   
   
 --Print 'Started Step 8, Updating DataMissing'                                       
 --SELECT @SPName = 'update_dataMissing_complete'                                      
 --EXEC update_dataMissing_complete @Reviewitemid                                    
 --Print 'Completed Step 8'  
 
   Print 'Started Step 6, Updating the ReasonForCOAFlag columns'                           
  SELECT @SPName = 'update_ReasonForCOAFlag_complete'                          
  EXEC update_ReasonForCOAFlag_complete                         
  Print 'Completed Step 6'  
  
   Print 'Started Step 7, Updating NAO Accountno and Names'                                       
 SELECT @SPName = 'Update_NAO_AccountNo_Name_Complete_Adhoc_AXA'                                     
 EXEC Update_NAO_AccountNo_Name_Complete_Adhoc_AXA 96 --AXA Naar Only                                    
 Print 'Completed Step 7 , Update_NAO_AccountNo_Name_Complete_Adhoc_AXA'     
   
 update tasklog                 
 set CheckEndDate = getdate(),Tenantid = @Tenantid       
 where   TaskName = 'completeMaster_AXA'    
     
   
   
END   
 if(@reviewitemid is null or @reviewitemid ='')
 Begin  
	 Print 'Started Last Step , Creating Index, estimate time 10 mins'                                       
	 SELECT @SPName = 'Create_CompleteTaskList_Index'                                      
	 EXEC Create_CompleteTaskList_Index                                     
	 Print 'Completed Last Step '                                        
 END                      
End     
GO



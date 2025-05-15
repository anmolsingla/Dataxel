USE [OSJSupervision]
GO

/****** Object:  StoredProcedure [dbo].[update_Notes_83]    Script Date: 3/22/2024 5:11:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[update_Notes_83]                        
AS                        
BEGIN                        
 /*==============================================================================                                    
Project: OSJ Review Tool - Rewrite                                   
------------------------------------------------------------------------------                                    
Description:                                    
----------------------------------------------------------------------------                                    
Return Type:                         
==============================================================================*/                        
 SET NOCOUNT ON                        
                        
                        
                      
                      
  DECLARE @err INT,                        
  @ErrorMessage VARCHAR(1024),                        
  @SPName SYSNAME,                        
  @DISErrorNumber INT                     
  SELECT @SPName = 'update_Notes'                      
             
 IF OBJECT_ID('tempdb..#internal') IS NULL 
	BEGIN
	create table #internal            
	(            
		commentDate1 DateTime,            
		Reviewitemid1 int            
	)
	END
	ELSE
	BEGIN
	TRUNCATE TABLE #internal
	END         
                        
   
   insert into #internal(commentDate1,Reviewitemid1)          
                    
       select max(CommentDate)commentDate1, REVIEWItemid as Reviewitemid1                   
       from                       
       ReviewItemComment ric (NOLOCK) inner join (select taskid from IncompleteTaskList (NOLOCK) where tasktypeid = 83  )             
       sellist on sellist.taskId=  ric.ReviewItemid                          
       group by Reviewitemid                
            
                         
    IF OBJECT_ID('tempdb..#StoredProcProgressMessages') IS NULL 
	BEGIN
		CREATE TABLE #StoredProcProgressMessages 
		(                          
			MessageTime DATETIME,                          
			ProcedureName VARCHAR(256),                          
			Message VARCHAR(2048),                          
			ErrorCode INT                          
		)                          
    END 
	--ELSE
	--BEGIN
	--TRUNCATE TABLE #StoredProcProgressMessages 
	--END
	
 
	INSERT INTO #StoredProcProgressMessages ( MessageTime, ProcedureName, Message, ErrorCode )                          
	VALUES ( Getdate(), @SPName, 'Start Procedure', - 1 ) 
                        
 SET @DISErrorNumber = - 1                
               
 print 'started update_Notes'                    
                             
                        
    BEGIN TRANSACTION                      
                     
                    
     update incompleteTaskList set Notes = notes.CommentText    
     from    
     (select CommentText,Reviewitemid  from ReviewitemComment RIC inner join #internal on #internal.Reviewitemid1=RIC.Reviewitemid and                      
  #internal.CommentDate1 = RIC. commentDate) notes                         
     where TaskId = notes.ReviewItemID                      
                          
  SET @err = @@ERROR                        
                        
  IF @err <> 0     
  BEGIN                        
                        
   SET @ErrorMessage = 'Failed to Update record in incompleteTaskList'                       
                        
   BEGIN                        
    ROLLBACK                        
   INSERT INTO #StoredProcProgressMessages (  MessageTime, ProcedureName, Message, ErrorCode )                          
		VALUES (  Getdate(), @SPName,  'Transaction Rollback',   - 1 )                          
                          
		INSERT INTO IncompleteErrorMessageTable ( MessageTime, ProcedureName, Message, ErrorCode  )                          
		VALUES ( Getdate(), @SPName, @ErrorMessage, - 1  )                      
   END                    
   END                        
                      
  COMMIT                     
  
    --IF NOT EXISTS (  SELECT * FROM tempdb.dbo.sysobjects  WHERE id = object_id(N'tempdb.dbo.#internal')) 
	--d_rop table #internal         
    print 'completed update_Notes'                         
                                 
 End   

GO



USE [OSJSupervision]
GO

/****** Object:  StoredProcedure [dbo].[AR_Load_BS_REP_SupervisorType]    Script Date: 3/22/2024 4:34:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[AR_Load_BS_REP_SupervisorType]
/********************************************************************************************        
Stored Procedure: $HeaderUTC$        
=============================================================================================        
Name:  AR_Load_BS_REP_SupervisorType
---------------------------------------------------------------------------------------------        
Author:  Sourav Paul
---------------------------------------------------------------------------------------------        
Version:  1.0        
---------------------------------------------------------------------------------------------        
Project:  AR
---------------------------------------------------------------------------------------------        
Purpose:   
      1. This procedure loads the table Load_BS_REP_SupervisorType from the View
		 BS_REP_SupervisorType
       
---------------------------------------------------------------------------------------------        
Syntax:  EXECUTE [AR_Load_BS_REP_SupervisorType] 
=============================================================================================        
Comments: TBD  
=============================================================================================        
(C) Copyright 2007 LPL, Inc.. All Rights Reserved.        
THIS SOURCE CODE IS THE PROPERTY OF LPL, Inc.. IT MAY BE USED BY RECIPIENT ONLY FOR THE         
PURPOSE FOR WHICH IT WAS TRANSMITTED AND WILL BE RETURNED UPON REQUEST OR WHEN NO LONGER         
NEEDED BY RECIPIENT. IT MAY NOT BE COPIED OR COMMUNICATED WITHOUT THE WRITTEN CONSENT         
OF LPL, Inc.         
********************************************************************************************/ 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra line from result sets
	SET NOCOUNT ON;	
	
	-- For Proper Transaction Control
 	SET XACT_ABORT ON; 

	BEGIN TRY          
		BEGIN TRANSACTION 

			-- Clean the table
			DELETE FROM Load_BS_REP_SupervisorType
			
			-- Load the table from BS_REP_SupervisorType [View]
			INSERT INTO Load_BS_REP_SupervisorType(
				 rep_id
				,master_id
				,osj_mgr_id
				,dprepid
				,rtype_code
				,corr_BD
				,SupervisorRepType
			)
			SELECT 
				 rep_id
				,master_id
				,osj_mgr_id
				,dprepid
				,rtype_code
				,corr_BD
				,SupervisorRepType 
			FROM dbo.BS_REP_SupervisorType WITH(NOLOCK)

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		--======================--
		-- Handle the Exception --
		--======================--
		DECLARE @ErrorMessage	VARCHAR(MAX),
				@ErrorSeverity	TINYINT,
				@ErrorState		TINYINT

		IF (XACT_STATE()) = -1		--Rolling back transaction
			ROLLBACK TRANSACTION  
		ELSE IF (XACT_STATE()) = 1	--Committing transaction    
			COMMIT TRANSACTION

		SELECT @ErrorMessage=ERROR_MESSAGE(), @ErrorSeverity=ERROR_SEVERITY(), @ErrorState=ERROR_STATE()
    
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)                     
	END CATCH  
END

GO



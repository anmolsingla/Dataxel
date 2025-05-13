CREATE PROCEDURE [dbo].[CW_selectAccountPositions_csv]  
	@AccountListCSV	Varchar(max),    	
    @EndDate DATETIME = NULL,	       
	@OfficeId varchar(10)=NULL,	
	@UserName VARCHAR(40)=NULL,	
	@FirmID int = 1,
	@SeparateByAccountType bit = 0	
AS     
/********************************************************************************************
Stored Procedure: CW_selectAccountPositions_csv
---------------------------------------------------------------------------------------------
Version :   1.0
---------------------------------------------------------------------------------------------
Purpose :	Return positions for the accounts passed in
---------------------------------------------------------------------------------------------
Revisions:	
1.0		01/03/2019	Steve Humpal			Initial version
1.1		11/13/2020	Robb Murdock			Add UA Relish Project filtering
1.2		12/10/2020	kamalika				Avoid dropping temp tables.  Instead create & truncate.
1.3		04/01/2024	Shravan Pullagurla		Used Support.dbo.AccountClassMaster table in case of Support.dbo.AccountClass
---------------------------------------------------------------------------------------------
Unit Tests:
 exec Reporting..CW_selectAccountRelatedMF @AccountListCsv = '18043716', @UserName = null

 exec Reporting..[CW_selectAccountPositions_csv] 
		@AccountListCSV='18043697,18043699,18043700,18043702,18043703,18043704,18043705,18043707,18043709,18043710,18043711,18043712,18043714'
		,@EndDate = '02/08/2019'
		,@OfficeId = '0000'
		,@FirmID = 1			

 exec Reporting..[CW_getAccountPositions_xml] 
		@AccountListXml='<Accounts><Id>18044971</Id><Id>18044972</Id></Accounts>'
		,@EndDate = '02/08/2019'
		,@OfficeId = '0000'
		,@FirmID = 1	

---------------------------------------------------------------------------------------------
********************************************************************************************/
   
SET NOCOUNT ON   
SET Transaction Isolation Level Read Uncommitted 

DECLARE @COB_EndDate		DATETIME
DECLARE @CurrentAsOfDate	DATETIME -- for positions we always need to get the most current Sec History record
DECLARE @MFNAsOfDate 		DATETIME

SELECT @COB_EndDate		= PortfolioManager.dbo.fn_GetPriceDate(@EndDate)
SELECT @CurrentAsOfDate	= AsOfDate FROM LPLCustomer.dbo.AsOfDates  WHERE TableName = 'SecurityBeta'
SELECT @MFNAsOfDate 	= AsOfDate FROM LPLCustomer.dbo.AsOfDates  WHERE TableName = 'PositionMFN'    

/*******************************************************************
PARSE CSV ACCOUNT IDS INTO A TABLE
*******************************************************************/

-- KP 12/10/2020: Avoid dropping temp tables.  Instead create & truncate.

IF OBJECT_ID ('tempdb..#Accounts') IS NOT NULL 
	BEGIN
		TRUNCATE  TABLE #Accounts
	END
ELSE
BEGIN
CREATE TABLE #Accounts  (SummaryAccountID		INT,
						 AccountID				INT,
                         AccountLocationCode	INT,
						 LPLAccountNo			CHAR(8) NULL,
						 RepId					CHAR(4) NULL,
						 SponsorCode			VARCHAR(4), 
						 SponsorAccountNo		VARCHAR(20), 
						 SponsorType			CHAR(1),
						 AsOfDate				DateTime
						 )
 END
INSERT INTO #Accounts(AccountId)
SELECT Value from Reporting.dbo.udfParseCsv (@AccountListCSV) option(maxrecursion 0)

UPDATE #Accounts
	SET 
		SummaryAccountId = A.AccountId, 
		LPLAccountNo = A.LPLAccountNo,
		RepId = A.RepID,
		AccountLocationCode = A.AccountLocationCode,
		SponsorCode = A.SponsorCode,
		SponsorType = A.SponsorType,
		SponsorAccountNo = A.SponsorAccountNo,
		AsOfDate = IsNull(aod.AsOfDate, A.AsOfDate) 
FROM 
	#Accounts acct
JOIN 
	lplcustomer.dbo.account A
		on acct.AccountID = A.AccountId  
LEFT JOIN 
	LPLCustomer.dbo.AsOfDates aod 
		ON a.SponsorCode = aod.SponsorCode AND a.SponsorType = aod.SponsorType       

-- make sure MFN is using MFNDate  
UPDATE #Accounts SET AsOfDate = @MFNAsOfDate    
FROM #Accounts acct WHERE acct.AccountLocationCode = 128   

/*******************************************************************************
  Fetch NON LPL Position Data
  Per RE's sp query below includes IDM/Broadridge & DirectBusiness L0 positions
********************************************************************************/
SELECT     
	-- START RELISH
	[ExcludePosition]	=  convert(bit, case when PortfolioManager.dbo.fn_UA_Reporting_Filter (max(P.PositionId), @UserName, @FirmId, MAX(A.AccountLocationCode) ) = 0 then 1 else 0 end), 
	-- END RELISH
	L.SummaryAccountID						AS AccountID,			
	MAX(L.AccountID)						AS AccountIDOriginal,
	MAX(A.SponsorAccountNo)					AS AccountNo,
	MAX(A.AccountLocationCode)				AS AccountLocationCode,        
	SUM(P.Quantity)							AS Quantity,        
	SUM(P.MarketValue)						AS MarketValue,        
	MAX(P.PositionSourceCode)				AS PositionSourceCode,	
	MAX(S.SecurityID)						AS SecurityID,			
	MAX(COALESCE(aco.AssetClassCode, ac.AssetClassCode))	AS AssetClassCode,        
	MAX(COALESCE(pdst.SecurityTypeID, sct.SecurityTypeID))	AS SecurityTypeID,		
	CASE 
		WHEN MAX(L.AsOfDate) < @COB_EndDate THEN MAX(L.AsOfDate) 
		ELSE @COB_EndDate 
	END										AS EndPriceDate,   
	MAX(S.SecuritySourceCode)				AS SecuritySourceCode,	
	CASE 
		WHEN MAX(S.UnitQuantity) IS NULL THEN 1 
		WHEN MAX(S.UnitQuantity) = 0     THEN 1 
		ELSE MAX(S.UnitQuantity) 
	END										AS UnitQuantity,		
	MAX(P.Price)							AS Price,			
	MAX(ISNULL(S.FACTOR, 1))				AS Factor,
	MAX(S.Cusip)							AS Cusip,
	MAX(S.Symbol)							AS Symbol,
	MAX(COALESCE(so.SecurityDescription, p.[Description], S.[Description])) AS [Description],
	1 AccountTypeCode
FROM 
	#Accounts L        
JOIN 
	LPLCustomer.dbo.Account A  
		ON A.AccountID = L.AccountID AND A.AccountLocationCode = L.AccountLocationCode        
JOIN 
	LPLCustomer.dbo.Position P  
		ON P.AccountID = A.AccountID AND P.AccountLocationCode = A.AccountLocationCode        
LEFT JOIN 
	LPLCustomer.dbo.SecurityHistoryAll S  
		ON P.SecurityID = S.SecurityID     
			AND P.SecuritySourceCode=S.SecuritySourceCode 
			AND @COB_EndDate BETWEEN ISNULL(S.SecurityStartDate, '1/1/1900') AND ISNULL(S.SecurityEndDate, '12/31/2099')    
LEFT JOIN 
	LPLCustomer.dbo.SecurityOverride so  
		ON S.SecurityId = so.SecurityId AND so.OfficeId = @OfficeId  
LEFT JOIN 
	LPLCustomer..AssetClass ac  
		ON s.AssetClassCode = ac.AssetClassCode AND ac.OfficeId IS NULL             
LEFT JOIN 
	LPLCustomer.dbo.AssetClassOverride aco  
		ON s.SecurityId = aco.SecurityId AND aco.OfficeId = @OfficeId            
LEFT JOIN 
	LPLCustomer.dbo.SecurityTypeExtended sct  
		ON s.PMSecurityTypeId = sct.SecurityTypeId
-- product definition overrides
LEFT JOIN
	Support.dbo.ProductDefinition pd 
		ON s.SecurityNo=pd.BetaSecurityNo AND s.Cusip=pd.Cusip
LEFT JOIN
	LPLCustomer.dbo.SecurityTypeExtended pdst 
		ON pd.ProductCode = pdst.SecTypeCode AND pdst.Enabled=1
WHERE 
(
	(
		P.Quantity > 0 
		AND L.AccountLocationCode IN (4,8,16,32,64,2048,4096,8192,65536,1048576,2097152,4194304)  
	)
	/*Defect #32248 */
	OR
	(
		P.Quantity < 0 
		AND L.AccountLocationCode IN (16)
	)
	/* End Defect #32248 */
)
GROUP BY 
	L.SummaryAccountID,
	P.PositionSourceCode, 
	P.SecurityID, 
	S.SecuritySourceCode
    
UNION ALL    
	
/*******************************************************************************
  Fetch NON LPL Networked Position Data
********************************************************************************/
SELECT 
	[ExcludePosition]			= convert(bit,0),	
	L.SummaryAccountID						AS AccountID, 
	MAX(L.AccountID)						AS AccountIDOriginal,
	MAX(A.SponsorAccountNo)					AS AccountNo,
	MAX(A.AccountLocationCode)				AS AccountLocationCode,    
	SUM(P.Quantity)							AS Quantity,    
	SUM(P.MarketValue)						AS MarketValue,    
	MAX(p.PositionSourceCode)				AS PositionSourceCode,    
	ISNULL(MAX(S.SecurityIDAsOf), 0)			AS SecurityID,			
	MAX(COALESCE(aco.AssetClassCode, ac.AssetClassCode))	AS AssetClassCode,    
	MAX(sct.SecurityTypeID)					AS SecurityTypeID,		
	CASE 
		WHEN MAX(L.AsOfDate) < @COB_EndDate	THEN MAX(L.AsOfDate) 
		ELSE @COB_EndDate 
	END										AS EndPriceDate,   
	MAX(S.SecuritySourceCode)				AS SecuritySourceCode,	
	CASE 
		WHEN MAX(S.UnitQuantity) IS NULL THEN 1 
		WHEN MAX(S.UnitQuantity) = 0 THEN 1 
		ELSE MAX(S.UnitQuantity) 
	END										AS UnitQuantity,		
	MAX(P.Price)							AS Price,
	MAX(ISNULL(S.FACTOR, 1))				AS Factor,
	MAX(S.Cusip)							AS Cusip,
	MAX(S.Symbol)							AS Symbol,
	MAX(COALESCE(so.SecurityDescription, p.[Description], S.[Description])) AS [Description],
	1 AccountTypeCode
FROM 
	#Accounts L    
JOIN 
	LPLCustomer.dbo.Account A  
		ON A.AccountID = L.AccountID AND A.AccountLocationCode = L.AccountLocationCode        
JOIN 
	LPLCustomer.dbo.Position P  
		ON P.SponsorAccountID = A.AccountID AND P.SponsorAccountLocationCode = A.AccountLocationCode        
LEFT JOIN 
	LPLCustomer.dbo.SecurityHistoryAll S  
		ON P.SecurityID = S.SecurityID 
		AND P.SecuritySourceCode = S.SecuritySourceCode  
		AND @COB_EndDate BETWEEN IsNull(S.SecurityStartDate,'1/1/1900') AND IsNull(S.SecurityEndDate, '12/31/2099')    
LEFT JOIN 
	LPLCustomer.dbo.SecurityOverride so  
		ON S.SecurityId = so.SecurityId AND so.OfficeId = @OfficeId 
LEFT JOIN 
	LPLCustomer.dbo.AssetClass ac  
		ON s.AssetClassCode = ac.AssetClassCode AND ac.OfficeId IS NULL         
LEFT JOIN 
	LPLCustomer.dbo.AssetClassOverride aco  
		ON s.SecurityId = aco.SecurityId AND aco.OfficeId = @OfficeId         
LEFT JOIN
	 LPLCustomer.dbo.SecurityTypeExtended sct 
		ON s.PMSecurityTypeId = sct.SecurityTypeId
WHERE 
	P.Quantity > 0 
	AND L.AccountLocationCode IN (128,256,512,1024,131072)  
GROUP BY 
	L.SummaryAccountID, 
	p.SecurityID, 
	p.SecuritySourceCode, 
	p.PositionSourceCode    

UNION ALL
	
/*******************************************************************************
  Fetch NON LPL Cash Position Data
********************************************************************************/
SELECT
	[ExcludePosition]			= convert(bit,0),	
    A.AccountID,
   	L.AccountID								AS AccountIDOriginal,
    A.SponsorAccountNo						AS AccountNo,
	A.AccountLocationCode,
	ISNULL(b.CASHBALANCE, 0) + ISNULL(b.MARGINBALANCE, 0) AS Quantity,		
    ISNULL(b.CASHBALANCE, 0) + ISNULL(b.MARGINBALANCE, 0) AS MarketValue,	
	A.AccountLocationCode					AS PositionSourceCode,	
	0										AS SecurityID,	
    'CASH'									AS AssetClassCode,       
    24										AS SecurityTypeID,		
	CASE WHEN L.AsOfDate < @COB_EndDate 
	THEN L.AsOfDate ELSE @COB_EndDate 
	END										AS EndPriceDate,   
    1										AS SecuritySourceCode,  
	1										AS UnitQuantity,    
	1										AS Price,				
	1										AS Factor,
	''										AS Cusip,
	'CASH'									AS Symbol,	
	'CASH'									AS [Description],
	1 AccountTypeCode
FROM 
    #Accounts L 
JOIN 
	LPLCustomer.dbo.Account AS A  
		ON A.AccountID = L.AccountID AND A.AccountLocationCode = L.AccountLocationCode
LEFT JOIN 
	LPLCustomer.dbo.BalanceIDM b  
		ON L.AccountID = b.AccountID
LEFT JOIN 
	Support.dbo.AccountClassMaster AS AC 
		ON Ac.LPLCode = A.AccountClassCode
LEFT JOIN	
	PortfolioManager..AccountDetails AD 
		ON A.AccountID = AD.AccountID
WHERE 
	L.AccountLocationCode IN (1048576, 2097152, 4194304)

UNION ALL
	
/*******************************************************************************
  Fetch LPL Position Data
********************************************************************************/
SELECT 
	[ExcludePosition]			= convert(bit,0),	
    p.AccountID							AS AccountID,
    p.AccountID							AS AccountIDOriginal,
    MAX(A.LPLAccountNo)					AS AccountNo,
    MAX(A.AccountLocationCode)			AS AccountLocationCode,
    SUM(P.Quantity)						AS Quantity,			--PE: Added to match cash position records
    SUM(P.MarketValue)					AS MarketValue,
    MAX(P.PositionSourceCode)			AS PositionSourceCode,
    ISNULL(MAX(S.SecurityIDAsOf),0)		AS SecurityID,			--PE: This is returned AS SECURITYNO in PE
    MAX(COALESCE(aco.AssetClassCode, ac.AssetClassCode))	AS AssetClassCode,       
    MAX(coalesce(pdst.SecurityTypeID, sct.SecurityTypeID)) AS SecurityTypeID,		--PE: ISNULL(S.PMSecurityTypeID, 0) AS PMSecurityTypeID (results look the same but note different name)
    @COB_EndDate						AS EndPriceDate,
	MAX(SH.SecuritySourceCode)			AS SecuritySourceCode,  --PE: P.SecuritySourceCode AS SECURITYSOURCECODE (results look the same)
    MAX(SH.UnitQuantity)				AS UnitQuantity,		--PE: MAX(ISNULL(S.UnitQuantity, 0)) AS UnitQuantity (results look the same)    
	MAX(P.Price)						AS Price,				
	MAX(ISNULL(S.FACTOR, 1))			AS Factor,
	MAX(SH.Cusip)						AS Cusip,
	MAX(SH.Symbol)						AS Symbol,
	MAX(COALESCE(so.SecurityDescription, MMF.[Name], p.[Description], SH.[Description])) AS [Description],
	CASE 
		WHEN @SeparateByAccountType=1 THEN IsNull(p.AccountTypeCode,1) 
		ELSE 1 
	END									AS AccountTypeCode
FROM  
    #Accounts A 
JOIN 
	LPLCustomer.dbo.Position AS P    
		ON P.AccountID = A.AccountID AND P.AccountLocationCode = A.AccountLocationCode
-- join first to get the current info - @CurrentAsOfDate        
LEFT JOIN LPLCustomer.dbo.SecurityHistoryAll AS S  
		ON  P.SecurityID = S.SecurityID AND P.SecuritySourceCode = S.SecuritySourceCode
		AND @CurrentAsOfDate BETWEEN ISNULL(S.SecurityStartDate, '1/1/1900') AND ISNULL(S.SecurityEndDate, '12/31/2099')
LEFT JOIN 
	LPLCustomer.dbo.SecurityOverride so  
		ON S.SecurityId = so.SecurityId AND so.OfficeId = @OfficeId 
-- now get the display attributes based on report END date
LEFT JOIN 
	LPLCustomer.dbo.SecurityHistoryAll AS SH  
		ON P.SecurityID = SH.SecurityID AND P.SecuritySourceCode = SH.SecuritySourceCode
		AND @COB_EndDate BETWEEN ISNULL(SH.SecurityStartDate, '1/1/1900') AND ISNULL(SH.SecurityEndDate, '12/31/2099')
LEFT JOIN 
	LPLCustomer.dbo.AssetClass AS ac  
		ON SH.AssetClassCode = ac.AssetClassCode AND ac.OfficeId IS NULL     
LEFT JOIN 
	LPLCustomer.dbo.AssetClassOverride AS aco  
		ON SH.SecurityId = aco.SecurityId AND aco.OfficeId = @OfficeId
LEFT JOIN 
	LPLCustomer.dbo.SecurityTypeExtended sct  
		ON sh.PMSecurityTypeId = sct.SecurityTypeId
-- product definition overrides
LEFT JOIN 
	Support.dbo.ProductDefinition pd 
		ON sh.SecurityNo = pd.BetaSecurityNo and sh.Cusip = pd.Cusip
LEFT JOIN 
	LPLCustomer.dbo.SecurityTypeExtended pdst 
		ON pd.ProductCode = pdst.SecTypeCode and pdst.[Enabled] = 1
LEFT JOIN 
	PortfolioManager.dbo.AccountDetails AD  
		ON A.AccountID = AD.AccountID
LEFT JOIN 
	Support.dbo.MoneyMarketFund MMF 
		ON MMF.SecurityNo = S.SecurityNo AND MMF.FirmID = @FirmID
WHERE
    p.PositionSourceCode IN (1,2,16) 
	AND A.AccountLocationCode IN (1, 2)
GROUP BY
    p.AccountID, 
	p.SecurityID, 
	p.SecuritySourceCode, 
	p.PositionSourceCode, 
	AD.Notes, 
	CASE 
		WHEN @SeparateByAccountType=1 THEN IsNull(p.AccountTypeCode,1) 
		ELSE 1 
	END

UNION ALL

/*******************************************************************************
  Fetch LPL Cash Position Data
********************************************************************************/
SELECT
	[ExcludePosition]			= convert(bit,0),	
    A.AccountID,
    A.AccountID								AS AccountIDOriginal,
    A.LPLAccountNo							AS AccountNo,
	A.AccountLocationCode,
	-IsNull(av.CashBalanceAmt, 0) + -IsNull(MarginBalanceAmt, 0) AS Quantity,			
    -IsNull(av.CashBalanceAmt, 0) + -IsNull(MarginBalanceAmt, 0) AS MarketValue,
	0										AS PositionSourceCode,
    0										AS SecurityID,	
    'CASH'									AS AssetClassCode,       
    24										AS SecurityTypeID,	
	@COB_EndDate							AS EndPriceDate,   
    1										AS SecuritySourceCode,  
    1										AS UnitQuantity,		    
	1										AS Price,				
	1										AS Factor,
	''										AS Cusip,
	'CASH'									AS Symbol,	
	'CASH'									AS [Description],
	1 AccountTypeCode
FROM 
    #Accounts L 
JOIN 
	LPLCustomer.dbo.Account AS A  
		ON A.AccountID = L.AccountID AND A.AccountLocationCode = L.AccountLocationCode
LEFT JOIN 
	BETA.dbo.Beta_Acct_Values AS av  
		ON Av.AccountNo = A.LPLAccountNo
LEFT JOIN 
	Support.dbo.AccountClassMaster AS AC 
		ON Ac.LPLCode = A.AccountClassCode
LEFT JOIN 
	PortfolioManager..AccountNicknames an  
		ON a.LplAccountNo=an.lplaccountnumber
LEFT OUTER JOIN	
	PortfolioManager..AccountDetails AD  
		ON A.AccountID = AD.AccountID
WHERE 
	L.AccountLocationCode IN (1, 2)

-- KP 12/10/2020: Avoid dropping temp tables.  Instead create & truncate.
--IF OBJECT_ID ('tempdb..#Accounts') IS NOT NULL 
--	D_ROP TABLE #Accounts
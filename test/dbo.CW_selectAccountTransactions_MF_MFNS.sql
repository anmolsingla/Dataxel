CREATE PROCEDURE [dbo].[CW_selectAccountTransactions_MF_MFNS]
	@AccountListCsv		Varchar(max),
	@SinceInception		bit = 0,
	@StartDate			DATETIME = NULL,
	@EndDate			DATETIME = NULL	
AS     
BEGIN
/********************************************************************************************
Stored Procedure:CW_selectAccountTransactions_MF_MFNS
---------------------------------------------------------------------------------------------
Version :   1.0
---------------------------------------------------------------------------------------------
Purpose :	Return MF account transaction data for a single account or an account group.
---------------------------------------------------------------------------------------------

Revions	:	1.0		10/19/2019	Steve Humpal	initial version 
			2.0		01/20/2021	Ayelet Soffer	Do not d_rop temp tables, truncate them instead
			2.1		01/04/2022	Steve Humpal	Updated to include PSTransferFlag
			2.2		04/19/2022	Steve Humpal	Updated to include ExcludeFromClassification
			2.3		08/13/2022	Steve Humpal	Updated to include SecurityNo
			2.4     05/22/2023 Ratul Pramanick	Implemented InterestReinvest Flag
---------------------------------------------------------------------------------------------
Unit Tests:
		exec  Reporting..CW_selectAccountTransactions_MF_MFNS
			@AccountListCsv = '18043087' ,   
			@SinceInception = 0,
			@StartDate = '6/26/2000',
			@EndDate = '12/31/2019'
---------------------------------------------------------------------------------------------
********************************************************************************************/
SET NOCOUNT ON   
SET Transaction Isolation Level Read Uncommitted
 
DECLARE @COB_StartDate	DATETIME

IF @SinceInception = 1
  BEGIN
	SELECT @COB_StartDate = '06/26/2000'
  END
ELSE
  BEGIN
	SELECT @COB_StartDate = PortfolioManager.dbo.fn_GetPriceDate(@StartDate)   	
  END

--IF OBJECT_ID ('tempdb..#SponsorAccountsMFNS') IS NOT NULL D_ROP TABLE #SponsorAccountsMFNS
--select * into #SponsorAccountsMFNS
--from Reporting.dbo.CW_udfSponsorAcctsMF(@AccountListCsv)

IF OBJECT_ID ('tempdb..#SponsorAccountsMFNS') IS NULL
BEGIN
	CREATE TABLE #SponsorAccountsMFNS (
		SummaryAccountID int, 
		SummaryAccountLocationCode int, 
		SponsorAccountNo varchar(20),   
		SponsorCode varchar(4), 
		SponsorType varchar(1), 
		SponsorCodeMapped varchar(4),
		AsOfDate datetime, 
		SSN varchar(9), 
		RepId char(4),
		CUSIP VARCHAR(9), 
		SecurityID INT)
END
ELSE
BEGIN
	TRUNCATE TABLE #SponsorAccountsMFNS
END

INSERT INTO #SponsorAccountsMFNS SELECT 
										SummaryAccountID,   
										SummaryAccountLocationCode,   
										SponsorAccountNo,     
										SponsorCode,   
										SponsorType,   
										SponsorCode,   
										AsOfDate,  
										SSN,   
										RepId,   
										CUSIP,   
										SECURITYID  

								FROM Reporting.dbo.CW_udfSponsorAcctsMF(@AccountListCsv)

if exists (select 1 from Beta.dbo.BETA_MF_SYNTHETIC_ACTIVITY DB join #SponsorAccountsMFNS A on DB.FundAcct = a.SponsorAccountNo AND DB.SponsorMnemonic = a.SponsorCode and DB.CUSIP = A.CUSIP)
begin

	/*******************************************************************************
	 Fetch BETA FN Synthetics Transactions
	********************************************************************************/
	SELECT 'MFNS' as TransSource,     
		A.SummaryAccountID as AccountID,    
		A.SummaryAccountLocationCode as AccountLocationCode,    
		'' as LPLAccountNo,    
		A.SponsorAccountNo as Accountno,    
		ISNULL(S.SecurityIDAsOf,-1) as SecurityID,			
		case when DB.DebitCreditInd=1 then (-1 * DB.Quantity) else DB.Quantity end AS QUANTITY,   
		COALESCE(NullIf(DB.Amount, 0), DB.Quantity * hp.Price, 0) * (CASE WHEN DB.DebitCreditInd=1 THEN -1 ELSE 1 END) AS AMOUNT,   
		ISNULL(S.SecuritySourceCode, 0) as SecuritySourceCode,
		DB.FundAcct as SponsorAccountNo,    
		CAST(COALESCE(pcRDIV.FeeFlag,pc.FeeFlag,0) as int) as FEEFLAG,    
		CAST(COALESCE(pcRDIV.DividendFlag,pc.DividendFlag,0) as int) as DIVIDENDFLAG, 
		CAST(COALESCE(pcRDIV.CapGainFlag,pc.CapGainFlag,0) as int) as CAPGAINFLAG,  
		CAST(COALESCE(pcRDIV.DividendReinvestFlag,pc.DividendReinvestFlag,0) as int) as DIVIDENDREINVESTFLAG,     
		CAST(COALESCE(pcRDIV.CapGainReinvestFlag,pc.CapGainReinvestFlag,0) as int) as CAPGAINREINVESTFLAG,
		CAST(COALESCE(pcRDIV.InterestFlag,pc.InterestFlag,0) as int)  as INTERESTFLAG,     
		CAST(COALESCE(pcRDIV.PrincipalPaymentFlag,pc.PrincipalPaymentFlag,0) as int) as PRINCIPALPAYMENTFLAG,     
		CAST(COALESCE(pcRDIV.AccountFlowFlag,pc.AccountFlowFlag,0) as int) as FLOWFLAG,    
		CAST(COALESCE(pcRDIV.SecurityFlowFlag,pc.SecurityFlowFlag,0) as int) as SecurityFlowFlag,    
		CAST(COALESCE(pcRDIV.CheckForInternalExchangeFlag,pc.CheckForInternalExchangeFlag,0) as int) as CheckForInternalExchangeFlag,
		CAST(COALESCE(pcRDIV.ApplyOffsettingFlowFlag,pc.ApplyOffsettingFlowFlag,0) as int) as ApplyOffsettingFlowFlag,
		0	AS	InterestReinvestFlag,
		NULL AS ExtFlowAmt,          
		NULL AS IntFlowAmt,    
		COALESCE(pcRDIV.ReversalCode, pc.ReversalCode, '') AS ReversalCode,	
		'D'                                                 AS RECORDTYPE,
		COALESCE(pcRDIV.Code, pc.Code, 'N/A')  as SOURCECODE,	
		CASE WHEN DB.OpenCloseIndicator in ('OB', 'CS') THEN 1	ELSE 0 END AS SyntheticOpenCloseFlag,
		a.SponsorCode,
		Case When S.MLPCODE IN ('I','B') Then 1 Else 0 End as REITFlag,
		1									AS UnitQuantity,	
		ISNULL(S.FACTOR, 1)					AS FACTOR,			
		0									AS DIRECTFEE,
		16									AS TRANSACTIONSOURCE,
		ISNULL(S.PMSecurityTypeID, 0)		AS SecurityTypeID,		
		''									AS BuySellInd,				
		NULL								AS Price,					
		0									AS WHOLECONVERSIONFACTOR,	
		ISNULL(S.SecurityIdentifier,'')		AS SecurityIdentifier,		
		''									AS PMSecTypeDescription,
		''									AS AssetClassCode,
		DB.asofdate							AS ActivityAsOfDate,
		NULL								AS Cusip_Isin,	
		COALESCE(so.SecurityDescription,s.[Description],tdbo.TransactionDescription,DB.TransactionDetail,pcRDIV.Description,pc.Description,'') AS TransactionDescription, 
		''				AS SubsidiaryNo,
		''				AS AccountType,
		''				AS RanDAccountHld,
		''				AS Desc1,
		''				AS Desc2,
		Classification = 
			CASE 
				WHEN atm1.SrcTransPK IS NOT NULL THEN 2
				WHEN atm2.DestTransPK IS NOT NULL THEN 1
				WHEN ate.TransPK IS NOT NULL THEN 6
				ELSE 0 -- 0 is unclassified 
			END, 
		ISNULL(A.SSN,'') AS SSNTaxID,
		0				AS TransferFlag,
		0				AS JournalFlag,
		ISNULL(S.CUSIP,'') AS CUSIP,
		ISNULL(S.Symbol,'') AS Symbol,
		COALESCE(pcRDIV.Description,pc.Description,'N/A') AS SourceCodeDescription,
		CAST(db.RecordID as varchar) AS TransactionPrimaryKey,
		'MFN Synthetic' AS DataSource,
		COALESCE(atm1.SrcTransPK, atm2.SrcTransPK) AS SrcTransPK,
		COALESCE(atm1.DestTransPK, atm2.DestTransPK) AS DestTransPK,
		COALESCE(atm1.SrcActLocCode, atm2.SrcActLocCode) AS SrcActLocCode,
		COALESCE(atm1.DestActLocCode, atm2.DestActLocCode) AS DestActLocCode,
		CAST(COALESCE(pcRDIV.InvestmentRedemptionFlag,pc.InvestmentRedemptionFlag,0) as int) AS InvestmentRedemptionFlag,
		0 AS ChangeSign,
		1 AS AccountTypeCode,
		CAST(COALESCE(pcRDIV.TradeFlag,pc.TradeFlag,0) as int) AS TradeFlag,
		CAST(COALESCE(pcRDIV.PSTransferFlag,pc.PSTransferFlag,0) as bit) AS PSTransferFlag,
		CAST(COALESCE(pcRDIV.ExcludeFromClassification,pc.ExcludeFromClassification,0) as bit) AS ExcludeFromClassification,
		ISNULL(DB.SecurityNo, 0) as SecurityNo
	FROM #SponsorAccountsMFNS A  
	 JOIN Beta.dbo.BETA_MF_SYNTHETIC_ACTIVITY DB  ON DB.FundAcct = a.SponsorAccountNo AND DB.SponsorMnemonic = a.SponsorCode and DB.CUSIP = A.CUSIP
	 LEFT JOIN PortfolioManager.dbo.TransactionDirectBusinessOverride AS tdbo  
		ON tdbo.DataSource = 'MFN Synthetic' AND tdbo.TransactionPrimaryKey = CAST(db.RecordID as varchar)
	 LEFT JOIN LPLCustomer.dbo.SecurityHistory S  ON S.SecurityNo = DB.SecurityNo
		 AND DB.AsofDate BETWEEN ISNULL(S.SecurityStartDate,'1/1/1900') AND ISNULL(S.SecurityEndDate, '12/31/2099')
	 LEFT JOIN LPLCustomer.dbo.SecurityOverride so  ON S.SecurityId = so.SecurityId
	 left join PortfolioManager.dbo.TransactionCodeFlowMapping pc  on DB.TransType=pc.Code and pc.Source='MFN'
	 LEFT JOIN PortfolioManager.dbo.TransactionCodeFlowMapping pcRDIV  ON ISNULL(pc.DIVIDENDFLAG, 0) = 1 AND (case when DB.DebitCreditInd=1 then (-1 * DB.Quantity) else DB.Quantity end) <> 0 AND pcRDIV.Code = '064' AND pcRDIV.Source ='FANMAIL'
	 left join PMPricing.dbo.HistoricalPriceBeta hp  on s.SecurityIDAsOf=hp.SecurityID and DB.AsOfDate=hp.AsOfDate
	 LEFT JOIN (SELECT atm.SrcTransPK, atm.SrcActLocCode, min(atm.DestTransPK) as DestTransPK, min(atm.DestActLocCode) as DestActLocCode
			FROM #SponsorAccountsMFNS acct join PortfolioManager.dbo.ActivityTransferMapping atm  
			ON acct.SponsorAccountNo = atm.SrcAccountNumber
			GROUP BY atm.SrcTransPK, atm.SrcActLocCode) atm1 
			 ON atm1.SrcTransPK = CAST(db.RecordID as varchar) and atm1.SrcActLocCode = A.SummaryAccountLocationCode
		LEFT JOIN (SELECT min(atm.SrcTransPK) AS SrcTransPK, min(atm.SrcActLocCode) AS SrcActLocCode, atm.DestTransPK, atm.DestActLocCode
			FROM #SponsorAccountsMFNS acct join PortfolioManager.dbo.ActivityTransferMapping atm  
			ON acct.SponsorAccountNo = atm.DestAccountNumber
			GROUP BY atm.DestTransPK, atm.DestActLocCode) atm2  
			 ON atm2.DestTransPK = CAST(db.RecordID as varchar) and atm2.DestActLocCode = A.SummaryAccountLocationCode
		LEFT JOIN PortfolioManager.dbo.ActivityTransferExclusions ate  ON ate.TransPK = CAST(db.RecordID as varchar) and ate.AccountLocationCode = A.SummaryAccountLocationCode
	WHERE  DB.AsofDate >= ( CASE WHEN @SinceInception=1 THEN '1/1/1900' ELSE @COB_StartDate END) AND DB.AsOfDate <= A.AsOfDate
	   and NOT EXISTS (   
		SELECT 1 from PORTFOLIOMANAGER.DBO.FfDirectBusiness W    
		where w.DataSource='MFN Synthetic' and W.TransactionPrimaryKey = CAST(db.RecordID as varchar)
	   )  
end

END
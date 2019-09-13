USE SDO_DESENV
GO

/****** Object:  StoredProcedure [dbo].[spcJBCFluxoCaixa_CARGA]    Script Date: 06/09/2015 09:17:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spcJBCFluxoCaixa_CARGA]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spcJBCFluxoCaixa_CARGA]
GO

USE SDO_DESENV
GO

/****** Object:  StoredProcedure [dbo].[spcJBCFluxoCaixa_CARGA]    Script Date: 06/09/2015 09:17:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- 

CREATE proc [dbo].[spcJBCFluxoCaixa_CARGA]
  @dt smalldatetime 
  with encryption
as

  declare @vGroupNum int
  declare @vShipDate smalldatetime
  declare @vLineTotal money
  declare @vTipo varchar(3)


  declare cp1 cursor local fast_forward read_only for
    select 'PRE' as tipo
         , ordr.groupnum as forma
         , rdr1.ShipDate as data_base
         , SUM(rdr1.linetotal) as valor
      from RDR1
     inner join ORDR
        on ORDR.DocEntry = rdr1.DocEntry 
     where rdr1.InvntSttus = 'O'
       and ordr.DocStatus = 'O'
     group by ordr.groupnum, rdr1.ShipDate 
     union all
    select 'PRO' as tipo
         , oPOR.groupnum as forma
         , POR1.ShipDate as data_base
         , SUM(POR1.linetotal) as valor
      from POR1
     inner join OPOR 
        on oPOR.DocEntry = POR1.DocEntry 
     where POR1.InvntSttus = 'O'
       and oPOR.DocStatus = 'O'   
     group by oPOR.groupnum, POR1.ShipDate 
    order by 1, 3, 2
  open cp1

  while 1 = 1
  begin
    fetch next from cp1 into @vTipo, @vGroupNum, @vShipDate, @vLineTotal
    if @@FETCH_STATUS <> 0 break
    
    insert into #lancamentos (tipo, dt_vencimento, valor)
      SELECT @vTipo, DATEADD(day, InstDays, @vShipDate), ( @vLineTotal * InstPrcnt ) / 100
        from CTG1

       where CTGCode = @vGroupNum 
       
    if @@ROWCOUNT = 0
      insert into #lancamentos (tipo, dt_vencimento, valor)
        select @vTipo, @vShipDate, @vLineTotal 
    
  end
  close cp1
  deallocate cp1
  
CREATE TABLE #ContasAReceberPorVencimento (
	TransId int, 
	Line_ID int, 
	Account nvarchar(30),
	ShortName  nvarchar(30),
	TransType nvarchar(40),
	CreatedBy int,
	BaseRef nvarchar(22),
	SourceLine smallint,
	RefDate datetime,
	DueDate datetime,
	BalDueCred decimal(19, 9),
	BalDueDeb decimal(19, 9),
	BalDueCredBalDueDeb decimal(19, 9),
	Saldo decimal(19, 9),
	LineMemo nvarchar(100),
	CardName nvarchar(200),
	CardCode nvarchar(30),
	Balance  decimal(19, 9),
	SlpCode int,
	DebitCredit  decimal(19, 9),
	IsSales nvarchar(2),
	Currency nvarchar(6),
	BPLName nvarchar(200),
	Serial      int,
	FormaPagamento   varchar(100),      
	PeyMethodNF   	 varchar(100),	
	BancoNF			 varchar(100),
	Installmnt		 varchar(100),
	OrctComments	 varchar(200),
	BankName         varchar(100)
	,DocEntryNFS	 int
)

--execute [spcJBCContasAReceberPorVencimento] '*','2010-01-01 00:00:00','2020-01-01 00:00:00','V','*'

insert  into #ContasAReceberPorVencimento
EXECUTE [spcJBCContasAReceberPorVencimento] 
   '*'
  --,'1900-11-20'
  --,'2050-11-20'
  ,'1900-11-16'
  ,@dt
  ,'LC'
  ,'*'
  
CREATE TABLE #ContasAPagarPorVencimento (		
	ShortName nvarchar(30)
	, CardName nvarchar(200)
	, Lancamento datetime
	, Vencimento datetime
	, Origem nvarchar(40)
	, OrigemNr integer
	, Parcela smallint
	, ParcelaTotal smallint
	, Serial int
	, LineMemo nvarchar(100)
	, Debit decimal(19, 9)
	, Credit decimal(19, 9)
	, Saldo decimal(19, 9)
	,DueDate datetime
	,PeyMethodNF nvarchar (40)
)

--execute spcJBCContasAPagarPorVencimento '*','2010-01-01 00:00:00','2020-01-01 00:00:00','V'

insert into #ContasAPagarPorVencimento
execute spcJBCContasAPagarPorVencimento 
   '*'
  --,'1900-11-20'
  --,'2050-11-20'
  ,'1900-11-16'
  ,@dt 
  ,'V'


  insert into #lancamentos (tipo, dt_vencimento, valor)
    SELECT 'CAP'
          , dt_vencimento, 
           sum(vl_saldo)
    FROM
    (
 --   select 
	--	Saldo as 'vl_saldo' ,
	--	DueDate as 'dt_vencimento'
	--from 
	--	#ContasAReceberPorVencimento
	--union all
	select 
		Saldo as 'vl_saldo' ,
		Vencimento as 'dt_vencimento'
	from 	
	#ContasAPagarPorVencimento
--SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		1										AS nr_parcela,
--		OJDT.RefDate							AS dt_lancamento,
--		JDT1.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, JDT1.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				sum(JDT1.BalDueCred) 
--				- sum(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			sum(JDT1.BalDueCred) 
--			- sum(JDT1.BalDueDeb)
--		)	AS vl_saldo,		
--		'-51'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--	WHERE JDT1.BalDueCred <> 0
--		AND JDT1.TransType = 30
--	GROUP BY OCRD.CardName, OCRD.CardCode, OJDT.TransId, OJDT.ObjType, OJDT.RefDate, JDT1.DueDate, JDT1.BaseRef, JDT1.TransType, OADM.CompnyName, OADM.TaxIdNum, JDT1.ShortName

--	UNION ALL

--	/*********************************************************************
--	NOTAS FISCAIS DE Entrada EM ABERTO
--	**********************************************************************/
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		PCH6.InstlmntID							AS nr_parcela,
--		OPCH.DocDate							AS dt_lancamento,
--		PCH6.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, PCH6.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		'-52'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		OPCH.Serial								AS nr_nota,
--		OPCH.SlpCode							AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN OPCH ON OPCH.DocNum = JDT1.BaseRef
--		INNER JOIN PCH6 ON PCH6.DocEntry = OPCH.DocEntry AND PCH6.InstlmntID = JDT1.Line_ID+1
--	WHERE JDT1.BalDueCred <> 0
--		AND JDT1.TransType = 18
--	GROUP BY OCRD.CardName, OCRD.CardCode, OJDT.TransId, OJDT.ObjType, PCH6.InstlmntID, OPCH.DocDate, PCH6.DueDate, JDT1.BaseRef, JDT1.TransType, OPCH.Serial, OPCH.SlpCode, OADM.CompnyName, OADM.TaxIdNum

--	UNION ALL

--	/*********************************************************************
--	CONTAS A Pagar - BOLETOS EM ABERTO
--	**********************************************************************/
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OVPM.DocEntry							AS docentry,
--		OVPM.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OVPM.ObjType) as tp_doc_Nome,
--		VPM2.InstId								AS nr_parcela,
--		OVPM.DocDate							AS dt_lancamento,
--		OBOE.DueDate							AS dt_vencimento,
--		OBOE.PmntDate							AS dt_liquidacao,
--		DATEDIFF(day, OBOE.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		--SUM(JDT1.Debit) 		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		OBOE.PayMethCod	AS forma_pgto,
--		OBOE.PymMethNam AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN OVPM ON OVPM.DocEntry = JDT1.BaseRef
--		INNER JOIN VPM2 ON VPM2.DocNum = OVPM.DocEntry AND VPM2.InstId = JDT1.Line_ID+1
--		INNER JOIN OBOE ON OBOE.BoeKey = OVPM.BoeAbs
--	WHERE JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 24
--	GROUP BY OCRD.CardName, OCRD.CardCode, OVPM.DocEntry, OVPM.ObjType, VPM2.InstId, OVPM.DocDate, OBOE.DueDate, OBOE.PmntDate, OBOE.PayMethCod, OBOE.PymMethNam, JDT1.BaseRef, JDT1.TransType, OADM.CompnyName, OADM.TaxIdNum

--	UNION ALL

--	/*********************************************************************
--	CONTAS A Pagar - CHEQUES EM ABERTO
--	**********************************************************************/
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OVPM.DocEntry							AS docentry,
--		OVPM.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OVPM.ObjType) as tp_doc_Nome,
--		VPM2.InstId								AS nr_parcela,
--		OCHH.RcptDate							AS dt_lancamento,
--		OCHH.CheckDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, OCHH.CheckDate, GETDATE())AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		'-53'					AS forma_pgto,
--		'Cheque - A Depositar'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN OVPM ON OVPM.DocEntry = JDT1.BaseRef
--		INNER JOIN VPM2 ON VPM2.DocNum = OVPM.DocEntry AND VPM2.InstId = JDT1.Line_ID+1
--		INNER JOIN RCT1 ON RCT1.DocNum = OVPM.DocEntry
--		INNER JOIN OCHH ON OCHH.CheckKey = RCT1.CheckAbs

--	WHERE JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 24
--	GROUP BY OCRD.CardName, OCRD.CardCode, OVPM.DocEntry, OVPM.ObjType, VPM2.InstId, OVPM.DocDate, OCHH.RcptDate, OCHH.CheckDate, JDT1.BaseRef, JDT1.TransType, OADM.CompnyName, OADM.TaxIdNum


    ) as completo
    where dt_vencimento <= @dt 
    group by dt_vencimento 




  insert into #lancamentos (tipo, dt_vencimento, valor)
    SELECT 'CAR'
          , dt_vencimento, 
           sum(vl_saldo)
    FROM (
    select 
		Saldo as 'vl_saldo' ,
		DueDate as 'dt_vencimento'
	from 
		#ContasAReceberPorVencimento    
	
--SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		1										AS nr_parcela,
--		OJDT.RefDate							AS dt_lancamento,
--		JDT1.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, JDT1.DueDate, GETDATE())	AS dias,
--		JDT1.Debit + JDT1.Credit		AS vl_titulo,
--		(
--			JDT1.Debit + JDT1.Credit
--		) - (
--			ABS(
--				JDT1.BalDueCred
--				- (JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			JDT1.BalDueCred
--			- JDT1.BalDueDeb
--		)	AS vl_saldo,		
--		'-51'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--  from OADM, JDT1 
-- inner join OJDT 
--    on ojdt.TransId = jdt1.TransId 
-- inner join OCRD
--    on ocrd.CardCode = jdt1.ShortName 
-- where 1 = 1 --jdt1.ShortName = 'C000262'
--   and jdt1.BalDueDeb <> 0
--   and jdt1.TransType = 30

--	UNION ALL

--	/*********************************************************************
--	NOTAS FISCAIS DE SA�DA EM ABERTO
--	**********************************************************************/
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		INV6.InstlmntID							AS nr_parcela,
--		OINV.DocDate							AS dt_lancamento,
--		INV6.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, INV6.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		'-52'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		OINV.Serial								AS nr_nota,
--		OINV.SlpCode							AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN OINV ON OINV.DocNum = JDT1.BaseRef
--		INNER JOIN INV6 ON INV6.DocEntry = OINV.DocEntry AND INV6.InstlmntID = JDT1.Line_ID+1
--	WHERE JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 13
--	GROUP BY OCRD.CardName, OCRD.CardCode, OJDT.TransId, OJDT.ObjType, INV6.InstlmntID, OINV.DocDate, INV6.DueDate, JDT1.BaseRef, JDT1.TransType, OINV.Serial, OINV.SlpCode, OADM.CompnyName, OADM.TaxIdNum

--	UNION ALL

--	/*********************************************************************
--	CONTAS A RECEBER - BOLETOS EM ABERTO
--	**********************************************************************/
	
	
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName	AS cardname,
--		ORCT.DocEntry							AS docentry,
--		ORCT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(ORCT.ObjType) as tp_doc_Nome,
--		RCT2.InstId								AS nr_parcela,
--		ORCT.DocDate							AS dt_lancamento,
--		OBOE.DueDate							AS dt_vencimento,
--		OBOE.PmntDate							AS dt_liquidacao,
--		DATEDIFF(day, OBOE.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		( SUM(JDT1.Debit) + SUM(JDT1.Credit) ) - ( ABS ( MAX(JDT1.BalDueCred) - MAX(JDT1.BalDueDeb)	)	) AS vl_recebido,
--		ABS(MAX(JDT1.BalDueCred) - MAX(JDT1.BalDueDeb)) AS vl_saldo,
--		OBOE.PayMethCod	AS forma_pgto,
--		OBOE.PymMethNam AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN ORCT ON ORCT.DocEntry = JDT1.BaseRef
--		INNER JOIN RCT2 ON RCT2.DocNum = ORCT.DocEntry 
--		  and jdt1.Line_ID = 0
--		INNER JOIN OBOE ON OBOE.BoeKey = ORCT.BoeAbs
--	WHERE 1 = 1 and JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 24
--		and oboe.BoeStatus not in ('P', 'C') -- depositado, pago.
--	GROUP BY OCRD.CardName, OCRD.CardCode, ORCT.DocEntry, ORCT.ObjType, RCT2.InstId, ORCT.DocDate, OBOE.DueDate, OBOE.PmntDate, OBOE.PayMethCod, OBOE.PymMethNam, JDT1.BaseRef, JDT1.TransType, OADM.CompnyName, OADM.TaxIdNum

--	UNION ALL

--	/*********************************************************************
--	CONTAS A RECEBER - CHEQUES EM ABERTO
--	**********************************************************************/
--	SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		ORCT.DocEntry							AS docentry,
--		ORCT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(ORCT.ObjType) as tp_doc_Nome,
--		RCT2.InstId								AS nr_parcela,
--		OCHH.RcptDate							AS dt_lancamento,
--		OCHH.CheckDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, OCHH.CheckDate, GETDATE())AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		'-53'					AS forma_pgto,
--		'Cheque - A Depositar'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		NULL									AS nr_nota,
--		NULL									AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN ORCT ON ORCT.DocEntry = JDT1.BaseRef
--		INNER JOIN RCT2 ON RCT2.DocNum = ORCT.DocEntry AND RCT2.InstId = JDT1.Line_ID+1
--		INNER JOIN RCT1 ON RCT1.DocNum = ORCT.DocEntry
--		INNER JOIN OCHH ON OCHH.CheckKey = RCT1.CheckAbs

--	WHERE JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 24
--	GROUP BY OCRD.CardName, OCRD.CardCode, ORCT.DocEntry, ORCT.ObjType, RCT2.InstId, ORCT.DocDate, OCHH.RcptDate, OCHH.CheckDate, JDT1.BaseRef, JDT1.TransType, OADM.CompnyName, OADM.TaxIdNum


--UNION ALL

--	/*********************************************************************
--	ADIANTAMENTOS DE CLIENTE PENDENTES
--	**********************************************************************/
	
--SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		dpi6.InstlmntID							AS nr_parcela,
--		ODPI.DocDate							AS dt_lancamento,
--		dpi6.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, dpi6.DueDate, GETDATE())	AS dias,
--		SUM(JDT1.Debit) + SUM(JDT1.Credit)		AS vl_titulo,
--		(
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)										AS vl_recebido,
--		ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)										AS vl_saldo,
--		'-52'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		ODPI.Serial								AS nr_nota,
--		ODPI.SlpCode							AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN ODPI ON ODPI.DocNum = JDT1.BaseRef
--		INNER JOIN dpi6 ON dpi6.DocEntry = ODPI.DocEntry AND dpi6.InstlmntID = JDT1.Line_ID+1
--	WHERE JDT1.BalDueDeb <> 0
--		AND JDT1.TransType = 203
--	GROUP BY OCRD.CardName, OCRD.CardCode, OJDT.TransId, OJDT.ObjType, dpi6.InstlmntID, ODPI.DocDate, dpi6.DueDate, JDT1.BaseRef, JDT1.TransType, ODPI.Serial, ODPI.SlpCode, OADM.CompnyName, OADM.TaxIdNum


--UNION ALL

---- DEVOLU��ES DE VENDA PENDENTES

--SELECT 
--		OCRD.CardCode,
--		OCRD.CardName 	AS cardname,
--		OJDT.TransId							AS docentry,
--		OJDT.ObjType							AS tp_doc,
--		dbo.funcJBCNomeObjeto(OJDT.ObjType) as tp_doc_Nome,
--		rin6.InstlmntID							AS nr_parcela,
--		orin.DocDate							AS dt_lancamento,
--		rin6.DueDate							AS dt_vencimento,
--		NULL									AS dt_liquidacao,
--		DATEDIFF(day, rin6.DueDate, GETDATE())	AS dias,
--		(SUM(JDT1.Debit) + SUM(JDT1.Credit))	*(-1)	AS vl_titulo,
--		--SUM(JDT1.Debit) 		AS vl_titulo,
--		((
--			SUM(JDT1.Debit) + SUM(JDT1.Credit)
--		) - (
--			ABS(
--				MAX(JDT1.BalDueCred) 
--				- MAX(JDT1.BalDueDeb)
--			)
--		)		) *(-1)								AS vl_recebido,
--		(ABS(
--			MAX(JDT1.BalDueCred) 
--			- MAX(JDT1.BalDueDeb)
--		)								)*(-1)		AS vl_saldo,
--		'-52'							AS forma_pgto,
--		'N�o definido'										AS forma_pgto_nome,
--		'A'										AS situacao,
--		JDT1.BaseRef							AS doc_origem,
--		JDT1.TransType							AS tp_origem,
--		dbo.funcJBCNomeObjeto(JDT1.TransType) as tp_origem_Nome,
--		orin.Serial								AS nr_nota,
--		orin.SlpCode							AS cd_vendedor,
--		OADM.CompnyName + '  ' + OADM.TaxIdNum	AS NomeEmpresa,
--		'A'										AS sit_geral
--	FROM OADM, JDT1
--		INNER JOIN OJDT ON OJDT.TransId = JDT1.TransId
--		INNER JOIN OCRD ON OCRD.CardCode = JDT1.ShortName
--		INNER JOIN orin ON orin.DocNum = JDT1.BaseRef
--		INNER JOIN rin6 ON rin6.DocEntry = orin.DocEntry AND rin6.InstlmntID = JDT1.Line_ID+1
--	WHERE 1 = 1
--	  and JDT1.BalDueCred <> 0
--		AND JDT1.TransType = 14
--	GROUP BY OCRD.CardName, OCRD.CardCode, OJDT.TransId, OJDT.ObjType, rin6.InstlmntID, orin.DocDate, rin6.DueDate, JDT1.BaseRef, JDT1.TransType, orin.Serial, orin.SlpCode, OADM.CompnyName, OADM.TaxIdNum




     ) as completo
    where dt_vencimento <= @dt 
    group by dt_vencimento 

  delete from #lancamentos
   where dt_vencimento > @dt

drop table #ContasAReceberPorVencimento

drop table #ContasAPagarPorVencimento








GO


--exec spcJBCFluxoCaixa_CARGA '01-01-2050' 
USE [WFEFIL]
GO

/****** Object:  View [dbo].[V_RPT_DELINQUENCY]    Script Date: 6/18/2019 9:11:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW dbo.V_RPT_DELINQUENCY_NI
AS
SELECT
    LB.ALTERNATE_ID,
	LM.LS_NET_INVEST,
    CUST_NAME,
    PYMT_OPTION,
    (CASE
         WHEN PYMT_OPTION NOT IN ('T','D') THEN COALESCE(PAST_1,0) +  COALESCE(PAST_1_ADJ,0) + COALESCE(PAST_1_COMP,0) + COALESCE(PAST_31,0) + COALESCE(PAST_31_ADJ,0) + COALESCE(PAST_31_COMP,0) + COALESCE(PAST_61,0) + COALESCE(PAST_61_ADJ,0) + COALESCE(PAST_61_COMP,0) + COALESCE(PAST_91,0) +  COALESCE(PAST_91_ADJ,0) + COALESCE(PAST_91_COMP,0)
         ELSE COALESCE(PAST_1,0) + COALESCE(PAST_1_ADJ,0) + COALESCE(PAST_1_COMP,0) + COALESCE(PAST_31,0) + COALESCE(PAST_31_ADJ,0) + COALESCE(PAST_31_COMP,0) + COALESCE(PAST_61,0) + COALESCE(PAST_61_ADJ,0) + COALESCE(PAST_61_COMP,0) + COALESCE(PAST_91,0) +  COALESCE(PAST_91_ADJ,0) + COALESCE(PAST_91_COMP,0)
     END) +
    (CASE
         WHEN (FLOAT_RATE = 1) AND (FLOAT_TYPE = 'P') THEN LFI.INTEREST_DUE
         ELSE 0
     END) AS PAST_DUE_AMT,
    CASE
        WHEN ((CONTRACT_PYMT IS NULL OR CONTRACT_PYMT = 0) AND VARIABLE_PYMT_CODE = 1) THEN COALESCE(LV.VARIABLE_RATE,0)
        ELSE COALESCE(CONTRACT_PYMT,0)
    END AS CONTRACT_PYMT,
    LAST_PYMT_DATE,
    CASE
        WHEN PAID_TO_DATE IS NULL THEN ACTIV_DATE
        ELSE PAID_TO_DATE
    END AS NEXT_DUE_DATE,
    DELIN_STATUS_CODE,
    CASE
        WHEN DATEDIFF(MONTH,LAST_PYMT_DATE,CURRENT_MONTH) > 2 AND DELIN_STATUS_CODE > 60 THEN
            CASE
                WHEN LEASE_TYPE IN ('TL','XX','LL') THEN COALESCE (LS_NET_INVEST,0) + (((COALESCE(CTD_ITC,0) + COALESCE(AAI.AI_CTD_ITC,0)) - (LM1.RETAINED_ITC)) * COALESCE(BUYOUT_TAX_FACTOR,0))
                ELSE COALESCE(LS_NET_INVEST,0)
            END
        ELSE COALESCE(CBR,0) + COALESCE(R_CBR,0)
    END AS EXP_REM_AMT,
    COALESCE(LNA_PRINC_BAL_REM,0) PRINC_BAL_REM,
    NUM_OF_ASSETS,
    (DATEDIFF(MONTH,LAST_PYMT_DATE,CURRENT_MONTH) + 1) AS DAY_LAST_PYMT,
    'Past Due' + CASE
        WHEN DELIN_STATUS_CODE = 181 THEN ' Over 180 '
        WHEN DELIN_STATUS_CODE = 151 THEN ' 151-180 '
        WHEN DELIN_STATUS_CODE = 121 THEN ' 121-150 '
        WHEN DELIN_STATUS_CODE = 91 THEN ' 91-120 '
        WHEN DELIN_STATUS_CODE = 61 THEN ' 61-90 '
        WHEN DELIN_STATUS_CODE = 31 THEN ' 31-60 '
        ELSE ' 1-30 '
    END + 'Days. '+ 'Last Payment' + CASE
        WHEN (DATEDIFF(MONTH,LAST_PYMT_DATE,CURRENT_MONTH) + 1) > 3 THEN ' Over 90 '
        WHEN (DATEDIFF(MONTH,LAST_PYMT_DATE,CURRENT_MONTH) + 1) > 2 THEN ' 61-90 '
        WHEN (DATEDIFF(MONTH,LAST_PYMT_DATE,CURRENT_MONTH) + 1) > 1 THEN ' 31-60 '
        ELSE ' 1-30 '
    END  + 'Days Ago.' AS STATUS_MSG,
    COALESCE(LMRF.MF_CBR,0) AS MISC_FIN
FROM
    dbo.LS_BILLING_NF LB
    INNER JOIN dbo.LS_MASTER_NF LM ON LM.ALTERNATE_ID = LB.ALTERNATE_ID
    INNER JOIN dbo.PARAMETER_NF P ON P.ALTERNATE_ID = '00*00'
    INNER JOIN dbo.LS_CADDR_NF LC ON LC.ALTERNATE_ID = LM.ALTERNATE_ID
    LEFT OUTER JOIN dbo.LS_FLOAT_NF LF ON LM.ALTERNATE_ID = LF.ALTERNATE_ID
    LEFT OUTER JOIN dbo.LS_ADDL_MASTER_NF LAM ON LAM.ALTERNATE_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN dbo.LS_INCOME_NF LI ON LI.ALTERNATE_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN dbo.LS_LOAN_NON_ACCRUAL_NF LNA ON LNA.ALTERNATE_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN dbo.LESSOR_NF LN ON LB.LESSOR = LN.LESSOR
    LEFT OUTER JOIN (SELECT
                         SUM(LMRF.MF_CBR) AS MF_CBR,
                         LMR.MISC_CONTRACT_NO
                     FROM
                         dbo.LS_MISC_REP_NF LMR
                         INNER JOIN dbo.GL_ACCT_TABLE_NF GLA ON LMR.MISC_GL_CODE = GLA.GL_CODE
                         INNER JOIN dbo.LS_MISC_REP_FINANCE_NF LMRF ON LMRF.ID = LMR.ID
                     WHERE
                         GLA.GAT_INCL_IN_NET_INVEST = 1
                     GROUP BY
                         LMR.MISC_CONTRACT_NO) LMRF ON LMRF.MISC_CONTRACT_NO = LB.ALTERNATE_ID
    LEFT OUTER JOIN (SELECT
                         LS_FLOAT_NF_ID,
                         SUM(INTEREST_DUE) AS INTEREST_DUE
                     FROM
                         dbo.LS_FLOAT_INTEREST_DUE_PH
                     WHERE
                         MV_POS <= 4
                     GROUP BY
                         LS_FLOAT_NF_ID) LFI ON LFI.LS_FLOAT_NF_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN (SELECT
                         LSA.LS_BILLING_NF_ID,
                         SUM(AAI.AI_CTD_ITC) AS AI_CTD_ITC
                     FROM
                         dbo.AS_MASTER_NF AM
                         INNER JOIN dbo.LS_BILLING_ASSET_RECORDS LSA ON LSA.ASSET_RECORDS = AM.ID
                         INNER JOIN dbo.AS_MASTER_A_LOCATIONS_PH AMAL ON AMAL.AS_MASTER_NF_ID = AM.ID
                         INNER JOIN dbo.AS_ASSET_INCOME_NF AAI ON AAI.ALTERNATE_ID = AMAL.A_LOCATIONS
                     GROUP BY
                         LSA.LS_BILLING_NF_ID) AAI ON AAI.LS_BILLING_NF_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN (SELECT
                         LM1.ALTERNATE_ID,
                         SUM(CASE
                                WHEN A_DISP_DATE IS NOT NULL AND ITC_METHOD = 'P' OR ITC_METHOD IS NULL THEN 0
                                ELSE
                                    CASE
                                        WHEN BEG_DEPR_DATE IS NOT NULL THEN
                                            CASE
                                                WHEN DATEPART(YEAR, BEG_DEPR_DATE) > 1980 THEN
                                                    CASE
                                                        WHEN CONTRACT_TERM = 36 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 12 THEN 0
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 24 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .333
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 36 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .667
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        ELSE
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 12 THEN 0
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 24 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.2
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 36 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.4
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 48 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.6
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.8
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        END
                                                ELSE
                                                    CASE
                                                        WHEN CONTRACT_TERM > 83 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .333
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 84 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .667
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        WHEN CONTRACT_TERM > 59 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.5
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        WHEN CONTRACT_TERM > 35 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,BEG_DEPR_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END        
                                                        ELSE 0
                                                    END
                                                END
                                        ELSE
                                            CASE
                                                WHEN DATEPART(YEAR, ACTIV_DATE) > 1980 THEN
                                                    CASE
                                                        WHEN CONTRACT_TERM = 36 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 12 THEN 0
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 24 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .333
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 36 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .667
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        ELSE
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 12 THEN 0
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 24 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.2
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 36 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.4
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 48 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.6
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.8
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        END
                                                ELSE
                                                    CASE
                                                        WHEN CONTRACT_TERM > 83 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .333
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 84 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * .667
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        WHEN CONTRACT_TERM > 59 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 60 THEN COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0) * 0.5
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        WHEN CONTRACT_TERM > 35 THEN
                                                            CASE
                                                                WHEN (DATEDIFF(MONTH,ACTIV_DATE,CURRENT_MONTH) + 1) < 36 THEN 0
                                                                ELSE COALESCE(ITC_BASE,0) * COALESCE(ITC_NET_PCT,0)
                                                            END
                                                        ELSE 0
                                                    END
                                                END
                                    END
                         END) AS RETAINED_ITC
                     FROM
                         dbo.LS_MASTER_NF LM1
                         INNER JOIN dbo.LS_BILLING_NF LB1 ON LM1.ALTERNATE_ID = LB1.ALTERNATE_ID
                         INNER JOIN dbo.LS_BILLING_ASSET_RECORDS LSA ON LM1.ALTERNATE_ID = LSA.LS_BILLING_NF_ID
                         INNER JOIN dbo.AS_MASTER_NF AM ON LSA.ASSET_RECORDS = AM.ID
                         LEFT OUTER JOIN dbo.AS_FED_DEPR_NF AFD ON AFD.ID = AM.ID
                         INNER JOIN dbo.PARAMETER_NF P ON P.ALTERNATE_ID = '00*00'
                     GROUP BY
                         LM1.ALTERNATE_ID) LM1 ON LM1.ALTERNATE_ID = LB.ALTERNATE_ID
    LEFT OUTER JOIN (SELECT
                         R_CONTRACT_KEY,
                         SUM(COALESCE(R_CBR,0)) AS R_CBR
                     FROM
                         RE_MASTER_NF
                     GROUP BY
                         R_CONTRACT_KEY) RM ON RM.R_CONTRACT_KEY = LB.ALTERNATE_ID
    LEFT OUTER JOIN (SELECT
                         LV.LS_VARIABLE_NF_ID,
                         COALESCE(LV.VARIABLE_RATE,0) AS VARIABLE_RATE
                     FROM
                         dbo.LS_VARIABL_VARIABLE_DATE_PH LV
                         INNER JOIN (SELECT
                                         LS_VARIABLE_NF_ID,
                                         MIN(MV_POS) AS MV_POS
                                     FROM
                                         dbo.LS_VARIABL_VARIABLE_DATE_PH
                                     WHERE
                                         VARIABLE_RATE > 0
                                     GROUP BY
                                         LS_VARIABLE_NF_ID) LVM ON LVM.LS_VARIABLE_NF_ID = LV.LS_VARIABLE_NF_ID AND LVM.MV_POS = LV.MV_POS) LV ON LV.LS_VARIABLE_NF_ID = LB.ALTERNATE_ID
WHERE
    NUM_OF_ASSETS > 0
    AND REPO_DATE IS NULL
    AND DELIN_STATUS_CODE > 0

GO



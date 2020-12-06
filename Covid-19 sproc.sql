ALTER PROCEDURE StateResultsPctInc
	@arrStateId nvarchar(255),
	@DateSelected DATE
AS
BEGIN
-- ===========================================================================================================================
-- Author:			Richard Smaldone
-- Create date:		2020-12-05
-- Description:		Returns COVID-19 data regarding positive results
--
-- Params:			arrStateId - One or more states, submitted via comma-separated array.  Null value defaults to all states.
--								 Can also select states by Census region: West, Midwest, South, and Northeast, or All.
--
--					DateSelected - The date results should be returned for.
--					
-- ===========================================================================================================================


----- Including options to select All (Default) or by Census Region.
IF @arrStateId = 'All' OR @arrStateId IS NULL
	SET @arrStateId = 'UT,NC,WI,AS,MA,MI,TN,NH,AK,OK,KY,CO,NV,SD,VI,PA,WV,GA,RI,IN,DC,MD,OR,CT,AR,MN,AL,ID,TX,NM,ND,ME,PR,IL,MO,SC,DE,GU,FL,MP,CA,WY,HI,OH,NE,VT,NY,MS,NJ,IA,KS,LA,WA,AZ,MT,VA'

IF @arrStateId = 'West'
	SET @arrStateId = 'WA,OR,MT,ID,WY,CO,UT,NV,AZ,NM,CA'

IF @arrStateId = 'Midwest'
	SET @arrStateId = 'ND,SD,MN,NE,KS,IA,MO,WI,IL,IN,MI,OH'

IF @arrStateId = 'South'
	SET @arrStateId = 'TX,OK,AR,LA,MS,AL,TN,KY,WV,MD,DE,VA,NC,SC,GA,FL'

IF @arrStateId = 'Northeast'
	SET @arrStateId = 'PA,NY,NJ,CT,RI,MA,VT,NH,ME'
-----

-- Null defaults to yesterday's data
IF @DateSelected IS NULL
	SET @DateSelected = GETDATE()-1

-- Table up the selected states
IF OBJECT_ID('tempdb..#StateSelected') IS NOT NULL DROP TABLE #StateSelected
SELECT DISTINCT Items StateId INTO #StateSelected FROM dbo.Split(@arrStateId, ',') 


SELECT 
	*
FROM
	(
		SELECT
			cdate,
			ash.stateId,
			dataQualityGrade,
			CASE 
				WHEN dataQualityGrade = 'A+' THEN 5
				WHEN dataQualityGrade = 'A' THEN 4
				WHEN dataQualityGrade = 'B' THEN 3
				WHEN dataQualityGrade = 'C' THEN 2
				WHEN dataQualityGrade = 'D' THEN 1
				WHEN dataQualityGrade = 'F' THEN 0
			END AS dataQualityGradeNum,		-- We may want the quality grade in numeric format for easy visualization.
			positive As PositiveResults,
			LAG(positive,7) OVER (PARTITION BY ash.stateId ORDER BY cdate) PositiveResults7day, -- # of positive tests 7 days ago.
			LAG(positive,30) OVER (PARTITION BY ash.stateId ORDER BY cdate) PositiveResults30day, -- # of positive tests 30 days ago.	
			positive - LAG(positive,30) OVER (PARTITION BY ash.stateId ORDER BY cdate) PositiveResults30daydiff, -- Increase in positive cases over the past 30 days
			cast((positive - LAG(positive,30) OVER (PARTITION BY ash.stateId ORDER BY cdate) ) as float) / nullif(LAG(positive,30) OVER (PARTITION BY ash.stateId ORDER BY cdate),0)  PositiveResults30dayPctIncrease -- the rate at which positive covid tests have increased from 30 days ago.	
		FROM 
			dbo.[allstateshistory] ash
			INNER JOIN #StateSelected ss ON ss.StateId = ash.stateId
		WHERE
			cdate BETWEEN datediff(day,@DateSelected,-30) AND @DateSelected

	) covid
WHERE
	cdate = @DateSelected
ORDER BY
	cdate desc,
	stateId




END
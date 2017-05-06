/*

This script is designed to clean up backup history from the msdb database.  If not cleaned up regularly, lots of backup history can bloat the msdb system database and has some potential to slow down 
certain operations.  Trying to clean up lots of backup history at once can be problematic as well, so this script does it in batches (batch size determined by the @daysAtOnce variable).  Performing 
the cleanup in smaller batches reduces contention and potential blocking.

There are three CREATE INDEX statements in comments at the beginning of this script.  These are designed to make the cleanup process more efficient  It is advised to uncomment that section in order 
to create the indexes if you have not already created them in your environment, but be careful not to create duplicate indexes.

There are also three variables that need to be set for this script - 
	@earliest
	@cutoff
	@daysAtOnce

Be sure to set all of these variables to the desired values before you run the script.

*/

--uncomment this section to create indexes
/*
USE msdb
GO

CREATE INDEX [media_set_id] ON [dbo].[backupset] ([media_set_id])
CREATE INDEX [restore_history_id] ON [dbo].[restorefile] ([restore_history_id])
CREATE INDEX [restore_history_id] ON [dbo].[restorefilegroup] ([restore_history_id])
*/
--end index creation

USE msdb
GO

DECLARE @backup_date DATETIME  --this is the date that will be passed into the sp_delete_backuphistory procedure
DECLARE @countback INT         --this will be the counter for the number of days left in the backup history
DECLARE @daysToKeep INT        --this is the number of days you want to keep in the backup history

---SET THESE VARIABLES---

DECLARE @earliest DATETIME = CAST('2015-01-27' AS DATETIME) --set this to the earliest date in your backup history (can be found by running SELECT MIN(backup_start_date) from msdb.dbo.backupset)
DECLARE @cutoff DATETIME = CAST('2017-01-01' AS DATETIME) --set this to the target cutoff date (earliest date you want to see in your backup history)
DECLARE @daysAtOnce INT = 1 --set this to the number of days you want to delete in each iteration of the loop

---END VARIABLES TO SET

SELECT @daysToKeep = DATEDIFF(DD, @cutoff, GETDATE())
SELECT @countback = DATEDIFF(DD, @earliest, GETDATE())

PRINT CAST(@countback AS varchar) + ' = number of days of backup history remaining.  Target = ' + CAST(@daysToKeep AS varchar)
PRINT 'Starting work...'

WHILE @countback > @daysToKeep
BEGIN
 PRINT CAST(@countback AS varchar) + ' = number of days of backup history remaining.  Target = ' + CAST(@daysToKeep AS varchar)
 SET @backup_date = (SELECT DATEADD(DD, -@countback, GETDATE()))
 BEGIN TRAN DELE
 EXEC SP_DELETE_BACKUPHISTORY @backup_date
 COMMIT TRAN DELE
 SET @countback = @countback - @daysAtOnce
END
PRINT CAST(@countback AS varchar) + ' = number of days of backup history remaining.  Target = ' + CAST(@daysToKeep AS varchar)
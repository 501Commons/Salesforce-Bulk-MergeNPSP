//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Account_Address accountAddress = new C501_MM_Rule_Account_Address();
      accountAddress.execute(null);
*/
//  3) click Execute
//
// Abort scheduled jobs
/*
    List<CronJobDetail> scheduledJobs = [SELECT Id FROM CronJobDetail WHERE Name like 'Contact_%' or Name like 'Account_%'];
    for (CronJobDetail scheduledJob :scheduledJobs) {
        Id jobId = [SELECT Id FROM CronTrigger WHERE CronJobDetailId = :scheduledJob.Id].Id;
        System.abortJob(jobId);
    }
*/
//

global class C501_MM_Rule_Account_Address implements Schedulable {

    global void execute(SchedulableContext SC) {
   }
}
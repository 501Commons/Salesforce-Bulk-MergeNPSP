@istest
class C501_MassMerge_Scheduler_TEST {

    public static String CRON_EXP = '0 0 0 3 9 ? 2022';

    @testSetup static void setup() {
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();
    }

    static testmethod void C501_MassMerge_Scheduler_TEST_Schedule() {

        Test.startTest();

        // Schedule the test job
        String jobId = System.schedule('testBasicScheduledApex',
        C501_MassMerge_Scheduler_TEST.CRON_EXP, 
            new C501_MM_Rule_Discover());

        // Get the information FROM the CronTrigger API object
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, 
            NextFireTime
            FROM CronTrigger WHERE id = :jobId];

        // Verify the expressions are the same
        System.assertEquals(C501_MassMerge_Scheduler_TEST.CRON_EXP, 
            ct.CronExpression);

        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);

        // Verify the next time the job will run
        System.assertEquals('2022-09-03 00:00:00', 
            String.valueOf(ct.NextFireTime));

        Test.stopTest();

        //System.assert(
        //    100.0 == [SELECT Id, Merge_Confidence__c FROM C501_Account_Merge__c].Merge_Confidence__c);
   }
}
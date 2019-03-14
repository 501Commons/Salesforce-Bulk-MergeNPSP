@istest
class C501_MassMerge_Scheduler_TEST {

    public static String CRON_EXP = '0 0 0 3 9 ? 2022';

    @testSetup static void setup() {
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();
    }

    static testmethod void C501_MassMerge_Scheduler_TEST_Schedule() {

        Test.startTest();

        Account account1 = new Account(
            Name = 'Account1',
            BillingStreet = '123 Street',
            Phone = '(123) 456-7890'
        );
        insert account1;

        Account account2 = new Account(
            Name = 'Account2',
            BillingStreet = '123 Street',
            Phone = '(123) 456-7890'
        );
        insert account2;

        C501_Merge_Metric__c mergeMetric = new C501_Merge_Metric__c(
            Name = 'MergeMetric',
            Enable__c = true,
            AutoMerge_Percentage__c = 100.0
        );

        insert mergeMetric;

        C501_Account_Merge__c accountMerge = new C501_Account_Merge__c(
                Unique_Id__c = 'Name ' + account1.Id,
                Merge_Metric__c = mergeMetric.Id,
                Account__c = account1.Id,
                Merge_Target_Account__c = account2.Id,
                Merge_Confidence__c = 100.0,
                Merge_Action__c = 'Merge');

        insert accountMerge;

        // Schedule the test job
        String jobId = System.schedule('testBasicScheduledApex',
        C501_MassMerge_Scheduler_TEST.CRON_EXP, 
            new C501_MM_Rule_Contact_NameDOB());

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

        System.assert(
            100.0 == [SELECT Id, Merge_Confidence__c FROM C501_Account_Merge__c WHERE Unique_Id__c = :accountMerge.Unique_Id__c LIMIT 1].Merge_Confidence__c);

        Test.stopTest();

        //System.assert(
        //    100.0 == [SELECT Id, Merge_Confidence__c FROM C501_Account_Merge__c].Merge_Confidence__c);
   }

    static testmethod void C501_MM_Rule_Contact_NameDOB_TEST() {

        C501_MM_Rule_Contact_NameDOB scheduleNameDOB = new C501_MM_Rule_Contact_NameDOB();
        scheduleNameDOB.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c]) {
            mergeMetric.Enable__c = true;
            mergeMetric.AutoMerge_Percentage__c = 90.0;

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        scheduleNameDOB.execute(null);
   }   
}
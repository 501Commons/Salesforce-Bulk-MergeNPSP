//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Account_NoContacts accountNoContacts = new C501_MM_Rule_Account_NoContacts();
      accountNoContacts.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Account_NoContacts implements Schedulable {

    global void execute(SchedulableContext SC) {

        System.debug('***** C501_MM_Rule_Account_NoContacts:execute');

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'Account_NoContacts';

        // Get Merge Metric
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];
        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = mergeMetricName,
                Confidence__c = 90.0,
                AutoMerge_Percentage__c = 0.0,
                Description__c = 'Accounts with no contacts.'
            ));

            insert mergeMetrics;
        }

        if (!mergeMetrics[0].Enable__c) {
            return;
        }

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ScheduleJobs(mergeMetrics[0]);

        c501MassMerge_SharedCode.ProcessMergeCandidates(mergeMetrics[0], null);
   }
}
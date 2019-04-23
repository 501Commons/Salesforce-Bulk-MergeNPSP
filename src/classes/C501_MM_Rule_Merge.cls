//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Merge MergeRule = new C501_MM_Rule_Merge();
      MergeRule.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Merge implements Schedulable {

    global void execute(SchedulableContext SC) {

 		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ScheduleJobs(C501_MM_Rule_Merge.class.getName());

        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Merge_Date__c
            FROM C501_Merge_Metric__c];

        Set<String> sourceReportIds = new Set<String>();
        for (C501_Merge_Metric__c mergeMetric : mergeMetrics) {
            if (!String.isEmpty(mergeMetric.Source_Report__c)) {
                sourceReportIds.add(mergeMetric.Source_Report__c);
            }
        }

        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE Id in :sourceReportIds OR DeveloperName in :sourceReportIds];

        // Walk through Merge Metrics
        String reportIdMerge;
        C501_Merge_Metric__c mergeMetricMerge;

        for (C501_Merge_Metric__c mergeMetric : [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Merge_Date__c
            FROM C501_Merge_Metric__c]) {

            if (!mergeMetric.Enable__c) {
                continue;
            }

            //String reportId;
            String reportId = '';
            for (Report report :reports) {
                if (report.Id == mergeMetric.Source_Report__c || report.DeveloperName == mergeMetric.Source_Report__c) {
                    reportId = (String)report.Id;
                    break;
                }
            }
            
            if (String.isEmpty(reportId)) {
                continue;
            }

            if (mergeMetric.Last_Merge_Date__c == null || mergeMetric.Last_Merge_Date__c < mergeMetricMerge.Last_Merge_Date__c) {

                reportIdMerge = reportId;

                // Shallow Copy
                mergeMetricMerge = mergeMetric;

                System.debug('***** C501_MM_Rule_Merge:execute - Merge Metric Name: ' + mergeMetricMerge.Name + ' reportId: ' + reportId);
            }
        }

        if (mergeMetricMerge.Id == null) {
            return;
        }

        mergeMetricMerge.Last_Merge_Date__c = System.now();
        update mergeMetricMerge;

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.ProcessObjectMergeCandidates(mergeMetricMerge);

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.ProcessObjectMergeCandidates(mergeMetricMerge);
    }
}
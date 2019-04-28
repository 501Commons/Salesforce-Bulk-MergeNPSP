//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Merge mergeRule = new C501_MM_Rule_Merge();
      mergeRule.execute(null);
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
                Enable__c, Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c,
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
            SELECT Id, DeveloperName, FolderName, LastModifiedDate
            FROM Report
            WHERE Id in :sourceReportIds OR DeveloperName in :sourceReportIds];

        // Walk through Merge Metrics
        String reportIdMerge;
        C501_Merge_Metric__c mergeMetricMerge = new C501_Merge_Metric__c();
        List<C501_Merge_Metric__c> mergeMetricsUpdate = new List<C501_Merge_Metric__c>();
        Set<Id> mergeMetricDeleteChildren = new Set<Id>();

        for (C501_Merge_Metric__c mergeMetric : [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Merge_Date__c
            FROM C501_Merge_Metric__c]) {

            if (!mergeMetric.Enable__c) {
                continue;
            }

            String reportId;
            for (Report report :reports) {

                if ((String)report.Id == mergeMetric.Source_Report__c || report.DeveloperName == mergeMetric.Source_Report__c) {

                    System.debug('***** C501_MM_Rule_Merge:execute - Report Found - Merge Metric: ' + String.valueOf(mergeMetric.Name) + ' Report: ' + report.DeveloperName);

                    // Check for report change
                    if (mergeMetric.Source_Report_LastModifiedDate__c == null || mergeMetric.Source_Report_LastModifiedDate__c <> report.LastModifiedDate) {

                        mergeMetric.Source_Report_LastModifiedDate__c = report.LastModifiedDate;
                        mergeMetricsUpdate.add(mergeMetric);

                        // Queue merge metric to delete children since report changed
                        mergeMetricDeleteChildren.add(mergeMetric.Id);

                        System.debug('***** C501_MM_Rule_Merge:execute - Report Change Detected: ' + String.valueOf(mergeMetric.Name) + ' Report: ' + report.DeveloperName);
                    }

                    reportId = (String)report.Id;

                    break;
                }
            }

            if (String.isBlank(reportId)) {
                continue;
            }

            if (mergeMetric.Last_Merge_Date__c == null) {

                reportIdMerge = reportId;

                // Shallow Copy
                mergeMetricMerge = mergeMetric;

                break;
            }
            else if (mergeMetricMerge.Id == null || (mergeMetricMerge.Last_Merge_Date__c <> null && mergeMetric.Last_Merge_Date__c < mergeMetricMerge.Last_Merge_Date__c)) {

                reportIdMerge = reportId;

                // Shallow Copy
                mergeMetricMerge = mergeMetric;
            }
        }

        if (!mergeMetricsUpdate.isEmpty()) {
            update mergeMetricsUpdate;
        }

        if (!mergeMetricDeleteChildren.isEmpty()) {

            List<C501_Account_Merge__c> accountMergesDelete = [SELECT Id FROM C501_Account_Merge__c WHERE Merge_Metric__c in :mergeMetricDeleteChildren];
            if (!accountMergesDelete.isEmpty()) {
                delete accountMergesDelete;
            }

            List<C501_Contact_Merge__c> contactMergesDelete = [SELECT Id FROM C501_Contact_Merge__c WHERE Merge_Metric__c in :mergeMetricDeleteChildren];
            if (!contactMergesDelete.isEmpty()) {
                delete contactMergesDelete;
            }
        }

        if (mergeMetricMerge.Id == null) {
            return;
        }

        System.debug('***** C501_MM_Rule_Merge:execute - Merge Metric: ' + String.valueOf(mergeMetricMerge));

        mergeMetricMerge.Last_Merge_Date__c = System.now();
        update mergeMetricMerge;

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.ProcessObjectMergeCandidates(mergeMetricMerge);

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.ProcessObjectMergeCandidates(mergeMetricMerge);
    }
}
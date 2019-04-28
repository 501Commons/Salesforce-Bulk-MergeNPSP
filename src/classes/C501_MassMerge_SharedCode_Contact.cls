//
// GENERIC CLASS - Do Not Modify Code in this Class.  The Class is generated from the C501_MassMerge_SharedCode_Account.cls file
//

global with sharing class C501_MassMerge_SharedCode_Contact { 

    public class C501_MassMerge_SharedCode_ContactException extends Exception {}

    // the list of Contacts
    global List<SelectOption> ListObjectsWithConfidence(String mergeRule, Decimal fromMergeConfidence, Decimal toMergeConfidence) {

        System.debug('***** C501_MassMerge_SharedCode_Contact::ListObjectsWithConfidence - mergeRule: ' + mergeRule 
            + ' fromMergeConfidence: ' + fromMergeConfidence.toPlainString()
            + ' toMergeConfidence: ' + toMergeConfidence.toPlainString());

        Set<String> setSOUnique = new Set<String>();
        List<SelectOption> listSO = new List<SelectOption>();
        listSO.add(new SelectOption('', ''));

        if (String.isBlank(mergeRule)) {
            for (AggregateResult result : [
                SELECT Contact__c, Contact__r.Name
                FROM C501_Contact_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                    and Merge_Action__c <> 'Merge' 
                GROUP BY Contact__c, Contact__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Contact__c').toString(),
                        result.get('Name').toString()));
            }
        }
        else {
            for (AggregateResult result : [
                SELECT Contact__c, Contact__r.Name
                FROM C501_Contact_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                    and Merge_Action__c <> 'Merge' 
                    and Merge_Metric__r.Name = :mergeRule
                GROUP BY Contact__c, Contact__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Contact__c').toString(),
                        result.get('Name').toString()));
            }
        }

        List<SelectOption> listSOSorted = new List<SelectOption>();
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        listSOSorted = c501MassMerge_SharedCode.SelectOptionSortByLabel(listSO);

        return listSOSorted;
    }

    global void InsertObjectMergeCandidates(C501_Merge_Metric__c mergeMetric, List<C501_Contact_Merge__c> mergeObjects) {

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //

        String mergeMetricName = mergeMetric.Name;
        Decimal mergeMetricAutoPercentage = mergeMetric.AutoMerge_Percentage__c;

        Set<Id> objectIds = new Set<Id>();
        Set<String> mergeObjectsExisting = new Set<String>();
        Map<Id, C501_Contact_Merge__c> objectMergeMap = new Map<Id, C501_Contact_Merge__c>();
        List<C501_Contact_Merge__c> invalidMerges = new List<C501_Contact_Merge__c>();
        Set<Id> objectIdsValid = new Set<Id>();

        for (C501_Contact_Merge__c mergeObject :[
            SELECT Id, Unique_Id__c, Contact__c, Contact__r.IsDeleted, Merge_Target_Contact__c, Merge_Target_Contact__r.IsDeleted, Merge_Confidence__c, Merge_Action__c
            FROM C501_Contact_Merge__c
            WHERE Merge_Metric__r.Name = :mergeMetricName]) {

            if (mergeObject.Contact__c == null || mergeObject.Merge_Target_Contact__c == null) {
                invalidMerges.add(mergeObject);

                continue;
            }

            if (!mergeObject.Contact__r.IsDeleted) {
                objectIdsValid.add(mergeObject.Contact__c);
            }

            if (!mergeObject.Merge_Target_Contact__r.IsDeleted) {
                objectIdsValid.add(mergeObject.Merge_Target_Contact__c);
            }

            mergeObjectsExisting.add(mergeObject.Unique_Id__c);
            objectIds.add(mergeObject.Contact__c);
            objectIds.add(mergeObject.Merge_Target_Contact__c);
            objectMergeMap.put(mergeObject.Contact__c, mergeObject);
            objectMergeMap.put(mergeObject.Merge_Target_Contact__c, mergeObject);
        }

        if (!invalidMerges.isEmpty()) {
            delete invalidMerges;
        }

        Map<Id, C501_Contact_Merge__c> deleteMerges = new Map<Id, C501_Contact_Merge__c>();
        for (Id objectId :objectMergeMap.keyset()) {
            if (!objectIdsValid.contains(objectId)) {
                deleteMerges.put(objectMergeMap.get(objectId).Id, objectMergeMap.get(objectId));
            }
        }

        if (!deleteMerges.values().isEmpty()) {
            delete deleteMerges.values();
        }

		if (mergeObjects <> null && !mergeObjects.isEmpty()) {

            List<C501_Contact_Merge__c> mergeObjectsInsert = new List<C501_Contact_Merge__c>();
            for (C501_Contact_Merge__c mergeObject :mergeObjects) {
                if (!mergeObjectsExisting.contains(mergeObject.Unique_Id__c)) {
                    mergeObjectsInsert.add(mergeObject);
                    mergeObjectsExisting.add(mergeObject.Unique_Id__c);
                }
            }

            if (!mergeObjectsInsert.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(mergeObjectsInsert, false);

                for (Database.SaveResult result : insertResults) {
                    if (!result.isSuccess()) {
                        System.debug('***** C501_MassMerge_SharedCode_Contact::InsertObjectMergeCandidates Merge Results: ' + String.valueOf(result));
                    }
                }
            }
		}
    }

    global void ProcessObjectMergeCandidates(C501_Merge_Metric__c mergeMetric) {

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //

        String mergeMetricName = mergeMetric.Name;
        Decimal mergeMetricAutoPercentage = mergeMetric.AutoMerge_Percentage__c;

        System.debug('***** C501_MassMerge_SharedCode_Contact::ProcesContactMergeCandidates mergeMetricName: ' + mergeMetricName);

        Set<Id> objectIds = new Set<Id>();
        Map<Id, C501_Contact_Merge__c> objectMergeMap = new Map<Id, C501_Contact_Merge__c>();
        List<C501_Contact_Merge__c> invalidMerges = new List<C501_Contact_Merge__c>();
        List<C501_Contact_Merge__c> pendingMerges = new List<C501_Contact_Merge__c>();
        List<C501_Contact_Merge__c> pendingAutoMerges = new List<C501_Contact_Merge__c>();
        Set<Id> objectIdsValid = new Set<Id>();

        Map<Id, Id> contactHouseholdMap = new Map<Id, Id>();
        String strSoql = 'SELECT Id, Unique_Id__c, Contact__c, Contact__r.C501_Household_Id__c, Contact__r.IsDeleted, Merge_Target_Contact__c, Merge_Target_Contact__r.C501_Household_Id__c, Merge_Target_Contact__r.IsDeleted, Merge_Confidence__c, Merge_Action__c';
        strSoql += ' FROM C501_Contact_Merge__c';
        strSoql += ' WHERE Merge_Metric__r.Name = :mergeMetricName';

        for(C501_Contact_Merge__c mergeObject : Database.Query(strSoql)) {

            if (mergeObject.Contact__c == null || mergeObject.Merge_Target_Contact__c == null) {
                invalidMerges.add(mergeObject);

                continue;
            }

            if (!mergeObject.Contact__r.IsDeleted) {
                objectIdsValid.add(mergeObject.Contact__c);
                contactHouseholdMap.put(mergeObject.Contact__c, mergeObject.Contact__r.C501_Household_Id__c);
            }

            if (!mergeObject.Merge_Target_Contact__r.IsDeleted) {
                objectIdsValid.add(mergeObject.Merge_Target_Contact__c);
                contactHouseholdMap.put(mergeObject.Contact__c, mergeObject.Contact__r.C501_Household_Id__c);
            }

            if (mergeObject.Merge_Action__c == 'Merge') {
                pendingMerges.add(mergeObject);
            }

            if (mergeObject.Merge_Action__c == null || mergeObject.Merge_Action__c == '') {
                pendingAutoMerges.add(mergeObject);
            }

            objectIds.add(mergeObject.Contact__c);
            objectIds.add(mergeObject.Merge_Target_Contact__c);
            objectMergeMap.put(mergeObject.Contact__c, mergeObject);
            objectMergeMap.put(mergeObject.Merge_Target_Contact__c, mergeObject);
        }

        if (!invalidMerges.isEmpty()) {
            delete invalidMerges;
        }

        Map<Id, C501_Contact_Merge__c> deleteMerges = new Map<Id, C501_Contact_Merge__c>();
        for (Id objectId :objectMergeMap.keyset()) {
            if (!objectIdsValid.contains(objectId)) {
                deleteMerges.put(objectMergeMap.get(objectId).Id, objectMergeMap.get(objectId));
            }
        }

        if (!deleteMerges.values().isEmpty()) {
            delete deleteMerges.values();
        }

        // Check for batch queued merges
        if (!pendingMerges.isEmpty()) {
            System.debug('***** C501_MassMerge_SharedCode_Contact::ProcessObjectMergeCandidates Process pending merge candidates pendingMerges: ' + String.valueOf(pendingMerges));
            ProcessObjectMerges(pendingMerges, false);
        }

        // Check if AutoMerge Enabled
        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0) {
            return;
        }

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ProcessObjectMergeCandidates_Contact(mergeMetric, pendingMerges, contactHouseholdMap);
    }

    global void ProcessObjectMerges(List<C501_Contact_Merge__c> objectMerges, Boolean batchMerge)
    {
        // Jobs with Status = 'Holding' applies to batch jobs in the Apex flex queue (max allowed 100)
        //  https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/api/sforce_api_objects_asyncapexjob.htm
        List<AsyncApexJob> flexQueueJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Holding'];
        Integer remainingFlexQueueJobs = 100 - flexQueueJobs.size();

        Set<Id> objectsProcessed = new Set<Id>();
        List<C501_Contact_Merge__c> deleteMergeCandidates = new List<C501_Contact_Merge__c>();
        for (C501_Contact_Merge__c mergeCandidate : objectMerges) {

            // Check Contact and Target Contact same Id
            if (mergeCandidate.Contact__c == mergeCandidate.Merge_Target_Contact__c) {

                deleteMergeCandidates.add(mergeCandidate);
                continue;
            }

            // Check Contact and Target Contact valid
            if (mergeCandidate.Contact__c == null || mergeCandidate.Merge_Target_Contact__c == null) {

                deleteMergeCandidates.add(mergeCandidate);
                continue;
            }

            // Check whether Contact or Target Contact Id merge already attempted
            if (objectsProcessed.contains(mergeCandidate.Contact__c) || objectsProcessed.contains(mergeCandidate.Merge_Target_Contact__c)) {
                continue;
            }

            objectsProcessed.add(mergeCandidate.Contact__c);
            objectsProcessed.add(mergeCandidate.Merge_Target_Contact__c);

            if (batchMerge) {

                if (remainingFlexQueueJobs-- <= 0) {
                    break;
                }

                // NPSP - Not supported - throws error in Future call.  Check back if Salesforce fixes issue
                // https://github.com/SalesforceFoundation/Cumulus/issues/4178                

                System.debug('***** C501_MassMerge_SharedCode_Contact::ProcessObjectMerges Batch Schedule Merge mergeCandidate: ' + String.valueOf(mergeCandidate));

                // Schedule Batch Job in Flex Queue (can schedule up to 100 jobs)
                List<String> objectsMergeIds = new List<String> { mergeCandidate.Contact__c, mergeCandidate.Merge_Target_Contact__c };
                C501_MassMerge_Batch batchMergeRequest = new C501_MassMerge_Batch();
                batchMergeRequest.query = 'SELECT Id FROM Contact WHERE Id in (\'' + String.join(objectsMergeIds, '\',\'') + '\') ORDER BY CreatedDate DESC';
                batchMergeRequest.ContactMerge = true;
                Database.executeBatch(batchMergeRequest);
            }
            else {

                System.debug('***** C501_MassMerge_SharedCode_Contact::ProcessObjectMerges Schedule Merge mergeCandidate: ' + String.valueOf(mergeCandidate));

                ObjectsMerge( 
                    new Contact(
                        Id = mergeCandidate.Contact__c
                    ),
                    new List<Contact> { new Contact(
                        Id = mergeCandidate.Merge_Target_Contact__c
                    )
                } );

                // Limit 1 non-batch merge at a time to avoid any governor limit issues
                break;
            }
        }

        if (!deleteMergeCandidates.isEmpty()) {
            delete deleteMergeCandidates;
        }
    }

    global void ObjectsMerge(Contact masterObject, List<Contact> duplicateObjects) {

        if (masterObject == null || duplicateObjects == null || duplicateObjects.isEmpty()) {
            return;
        }

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ObjectsMerge_Contact(masterObject, duplicateObjects);

        // Merge Contacts into master
        System.debug('***** C501_MassMerge_SharedCode::ObjectsMerge Contact masterObject: ' + String.valueOf(masterObject) + ' duplicateObjects: ' + String.valueOf(duplicateObjects));

        Database.MergeResult[] objectResults = Database.merge(masterObject, duplicateObjects, false);

        for(Database.MergeResult res : objectResults) {
            if (res.isSuccess()) {
                System.debug('***** C501_MassMerge_SharedCode::ObjectsMerge Contact Merge Successful');
            }
            else {
                for (Database.Error err : res.getErrors()) {
                    System.debug('***** C501_MassMerge_SharedCode::ObjectsMerge Contact Merge Exception: ' + err.getMessage());
                }

                throw new C501_MassMerge_SharedCode_ContactException('Contact Merge Attempt - ' + String.valueOf(res.getErrors()));
            }
        }

        Set<Id> objectIds = new Set<Id> { masterObject.Id };
        for (Contact duplicateObject :duplicateObjects) {
            objectIds.add(duplicateObject.Id);
        }

        List<C501_Contact_Merge__c> deleteMerges = [
            SELECT Id
            FROM C501_Contact_Merge__c
            WHERE Contact__c = null
                OR Merge_Target_Contact__c = null
                OR Contact__c in :objectIds
                OR Merge_Target_Contact__c in :objectIds];

        if (!deleteMerges.isEmpty()) {
            delete deleteMerges;
        }
    }
}
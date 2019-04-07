/*
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

global virtual with sharing class C501_CTRL_MassMergeContacts {

    global integer cEmptyContactRecords {
        get {
            return 1;
        }
    }
    
    private C501_MassMerge_SharedCode c501MassMerge_SharedCode;
    private List<String> listStrFields;
    
    global boolean redirect { get; private set; }
    global ID idRedirect { get; private set; }
    
    // constructor
    global C501_CTRL_MassMergeContacts() {

        System.debug('***** C501_CTRL_MassMergeContacts::C501_CTRL_MassMergeContacts Constructor');

        redirect = false;
        c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        
        // handle optional parameters (must use string, not ID, to handle null)
        string id = ApexPages.currentPage().getParameters().get('id');
        if (id != null && id != '') contactFilter.Id = id;
        
        // Get list of fields FROM fieldset
        listStrFields = new List<String>();
        for (Schema.FieldSetMember f : SObjectType.Contact.FieldSets.MassMergeContacts.getFields()) {
            listStrFields.add(f.getFieldPath());
        }

        // Required fields
        listStrFields.add('Id');
        listStrFields.add('C501_Merge_Action__c');
    }   
    
    global list<SelectOption> listSOContacts {
        get {
            if (listSOContacts == null )
                listSOContacts = c501MassMerge_SharedCode.listContactsWithConfidence(contactFilter.C501_Merge_Rule__c, contactFilter.C501_Merge_Confidence_From__c, contactFilter.C501_Merge_Confidence_To__c);

            return listSOContacts;
        }

        set;
        }

    global list<SelectOption> listSORules {
        get {
            if (listSORules == null ) {
                listSORules = new List<System.SelectOption>();
                listSORules.add(new SelectOption('', ''));

          		AggregateResult[] allAggregatedByRule = [
                    SELECT Merge_Metric__r.Name
                    FROM C501_Contact_Merge__c
                    GROUP BY Merge_Metric__r.Name
                    ORDER BY Merge_Metric__r.Name ASC];

                for (AggregateResult result : allAggregatedByRule)  {
                    String ruleName = result.get('Name').toString();
                    listSORules.add(new SelectOption(ruleName, ruleName));
                }
            }

            return listSORules;
        }

        set;
        }

    // Confidence to filter the list of Contacts
    global Contact contactFilter {
        get {
            if (contactFilter == null) {
                contactFilter = new Contact();
                
                contactFilter.C501_Merge_Rule__c = null;
                contactFilter.C501_Merge_Confidence_From__c = 90.0;
                contactFilter.C501_Merge_Confidence_To__c = 100.0;
            }
            return contactFilter;
        }
        set;
    }

    // the user has changed the Contact dropdown
    global virtual PageReference ChangeContact() {

        listContacts = null;
        strSaveResults = null;

        return null;
    }

    // the user has changed the Rule dropdown
    global virtual PageReference ChangeRule() {

        listSOContacts = null;
        contactFilter.Id = null;
        listContacts = null;
        strSaveResults = null;

        return null;
    }

    // the user has changed the Confidence query
    global virtual PageReference ChangeMergeConfidence() {

        listSOContacts = null;
        contactFilter.Id = null;
        listContacts = null;
        strSaveResults = null;

        return null;
    }

    global virtual void ResetContacts() {

        System.debug('***** C501_CTRL_MassMergeContacts::ResetContacts');

        listSOContacts = null;
        contactFilter.Id = null;
        listContacts = null;
    }

    // status string for reporting the results of saving.
    global String strSaveResults { get; set; }
      
    // The list of Contacts.
    global list<Contact> listContacts {
        get {
            if (listContacts == null) {
                FillListContacts();

                System.debug('***** C501_CTRL_MassMergeContacts::listContacts listContacts: ' + String.valueOf(listContacts));
            }

            return listContacts;
        }
        
        set;
    }
        
    // helper function that the client can override, to query for the appropriate fields in Contacts.
    global virtual void FillListContacts() {

		Map<Id,C501_Contact_Merge__c> ContactsMerge = new Map<Id,C501_Contact_Merge__c>();

        if (contactFilter.Id <> null) {
        
            for(C501_Contact_Merge__c ContactMerge : [
                SELECT Id, Contact__c, Merge_Target_Contact__c, Merge_Confidence__c, Merge_Action__c, Merge_Metric__c, Merge_Metric__r.Name
                FROM C501_Contact_Merge__c
                WHERE (Contact__c = :contactFilter.Id OR Merge_Target_Contact__c = :contactFilter.Id) AND isDeleted = false]) {

                    ContactsMerge.put(
                        ContactMerge.Contact__c,
                        new C501_Contact_Merge__c(
                            Merge_Action__c = ContactMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Contact__c = ContactMerge.Contact__c,
                            Merge_Target_Contact__c = ContactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = ContactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + ContactMerge.Merge_Metric__r.Name
                    ));

                    ContactsMerge.put(
                        ContactMerge.Merge_Target_Contact__c,
                        new C501_Contact_Merge__c(
                            Merge_Action__c = ContactMerge.Merge_Action__c,
                            Merge_Confidence__c = ContactMerge.Merge_Confidence__c,
                            Contact__c = ContactMerge.Contact__c,
                            Merge_Target_Contact__c = ContactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = ContactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + ContactMerge.Merge_Metric__r.Name
                    ));
            }
        }
        else {

            Set<String> ContactIds = new Set<String>();
            for (SelectOption option : listSOContacts) {
                ContactIds.add(option.getValue());

                // Performance: Only allow 50 at a time to load in the webpage
                if (ContactIds.size() >= 50) {
                    break;
                }
            }

            Integer mergeIndex = 1;
            String mergeBuffer = '0';

            String mergeRule = contactFilter.C501_Merge_Rule__c;
            String strRuleSoql = '';
            if (mergeRule <> null && !String.isBlank(mergeRule)) {
                strRuleSoql = ' and Merge_Metric__r.Name = :mergeRule';
            }

            string strSoql = 'SELECT Id, Contact__c, Merge_Target_Contact__c, Merge_Confidence__c, Merge_Action__c, Merge_Metric__c, Merge_Metric__r.Name';

            strSoql += ' FROM C501_Contact_Merge__c';
            strSoql += ' WHERE (Contact__c in :ContactIds OR Merge_Target_Contact__c in :ContactIds) AND isDeleted = false';
            strSoql += strRuleSoql;
            strSoql += ' ORDER BY Contact__r.Name ASC';

            for(C501_Contact_Merge__c ContactMerge : Database.Query(strSoql)) {

                    if (ContactsMerge.containsKey(ContactMerge.Contact__c) || ContactsMerge.containsKey(ContactMerge.Merge_Target_Contact__c)) {
                        continue;
                    }

                    ContactsMerge.put(
                        ContactMerge.Contact__c,
                        new C501_Contact_Merge__c(
                            Merge_Action__c = ContactMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Contact__c = ContactMerge.Contact__c,
                            Merge_Target_Contact__c = ContactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = ContactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + ContactMerge.Merge_Metric__r.Name
                    ));

                    ContactsMerge.put(
                        ContactMerge.Merge_Target_Contact__c,
                        new C501_Contact_Merge__c(
                            Merge_Action__c = ContactMerge.Merge_Action__c,
                            Merge_Confidence__c = ContactMerge.Merge_Confidence__c,
                            Contact__c = ContactMerge.Contact__c,
                            Merge_Target_Contact__c = ContactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = ContactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + ContactMerge.Merge_Metric__r.Name
                    ));

                    mergeIndex++;
                    if (mergeIndex >= 10) {
                        mergeBuffer = '';
                    }
            }
        }

        String strSoql = 'SELECT ' + String.join(listStrFields, ',');

        Set<Id> ContactsMergeIds = ContactsMerge.keySet();
        strSoql += ' FROM Contact WHERE Id in :ContactsMergeIds';
        strSoql += ' order by C501_Merge_Metric_Name__c ASC NULLS FIRST';
        
        listContacts = Database.Query(strSoql);

        for ( Contact Contact :listContacts ) {
            if (ContactsMerge.containsKey(Contact.Id)) {
                C501_Contact_Merge__c mergeContact = ContactsMerge.get(Contact.Id);
                Contact.C501_Merge_Action__c = mergeContact.Merge_Action__c;
                Contact.C501_Merge_Confidence__c = mergeContact.Merge_Confidence__c;
                Contact.C501_Merge_Contact__c = mergeContact.Contact__c;
                Contact.C501_Merge_Target__c = mergeContact.Merge_Target_Contact__c;
                Contact.C501_Merge_Metric_Name__c = mergeContact.Merge_Metric_Name__c;
            }
        }

        // Update Contacts w/ Merge fields then query to get the correct sort order by Metric Name
        update listContacts;

        listContacts = Database.Query(strSoql);
    }
    
    global Boolean fHasListContacts {
        get {
            return listContacts != null && listContacts.size() > 0;
        }
    }     
 
    // used to track the Id's of all Contact records that get modified.
    global Set<ID> setContactsIdDirty {
        get {
            if (setContactsIdDirty == null) {
                setContactsIdDirty = new Set<ID>();
            }
            return setContactsIdDirty;
        }
        set;
    }
    
    // to allow vf page to see how many Contact records are dirty
    global Integer numberOfRecordsDirty {
        get { 
            if (setContactsIdDirty == null)
                return 0;
            else
                return setContactsIdDirty.size();
        }
    }
    
    // this gets called whenever a field in the Contacts datatable is modified.
    // use this to remember which existing Contacts records have been modified.
    global virtual PageReference ContactsRecordModified() {
        String strId = ApexPages.currentPage().getParameters().get('usersIdDirtied');
        if (strId != null && strId != '') setContactsIdDirty.add(strId);
        return null;
    }
    
    //save the Contacts created or modified
    global virtual PageReference SaveContacts() {
        
        if (listContacts == null) return null;
        
        strSaveResults = null;
        
        try {
            Map<String, List<Contact>> listContactsMerge = new Map<String, List<Contact>>();
            List<C501_Contact_Merge__c> listContactsMergeIgnore = new List<C501_Contact_Merge__c>();

            System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts listContacts: ' + String.valueOf(listContacts));

            for (Contact Contact : listContacts) {

                if (Contact.Id != null && Contact.C501_Merge_Action__c == 'Merge') {

                    System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts Check Merge Action - Merge Rule: ' + Contact.C501_Merge_Metric_Name__c);

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setContactsIdDirty.contains(Contact.Id)) 
                    if (listContactsMerge.containsKey(Contact.C501_Merge_Metric_Name__c)) {
                        List<Contact> Contacts = listContactsMerge.remove(Contact.C501_Merge_Metric_Name__c);
                        Contacts.add(Contact);
                        listContactsMerge.put(Contact.C501_Merge_Metric_Name__c, Contacts);
                    }
                    else {
                        listContactsMerge.put(Contact.C501_Merge_Metric_Name__c, new List<Contact> { Contact });
                    }

                    System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts Update Merge Action - Contact: ' + String.valueOf(Contact)
                        + ' listContactsMerge Keys: ' + String.valueOf(listContactsMerge.keySet()));
                }

                if (Contact.Id != null && Contact.C501_Merge_Action__c == 'Ignore') {

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setContactsIdDirty.contains(Contact.Id)) 
                    listContactsMergeIgnore.add(new C501_Contact_Merge__c(
                        Id = Contact.C501_Merge_Contact__c,
                        Contact__c = Contact.Id,
                        Merge_Target_Contact__c = Contact.C501_Merge_Target__c,
                        Merge_Action__c = Contact.C501_Merge_Action__c
                    ));
                }
            }

            Integer recordsUpdated = listContactsMergeIgnore.size() + listContactsMerge.size();
            
            if (!listContactsMergeIgnore.isEmpty()) {
                update listContactsMergeIgnore;
            }


            for (List<Contact> Contacts :listContactsMerge.values()) {
                if (Contacts.size() >= 2) {

                    // Investigation Needed: Scheduling in batch the merge throws an exception in NPSP code
/*
                    List<String> ContactsMergeIds = new List<String>();
                    for (Contact Contact :Contacts) {
                        ContactsMergeIds.add(String.valueOf(Contact.Id));
                    }

                    // Schedule Batch Job in Flex Queue (can schedule up to 100 jobs)
                    C501_MassMerge_Batch batchMerge = new C501_MassMerge_Batch();
                    batchMerge.query = 'SELECT Id FROM Contact WHERE Id in (\'' + String.join(ContactsMergeIds, '\',\'') + '\') ORDER BY CreatedDate DESC';
                    Database.executeBatch(batchMerge);
*/
                    c501MassMerge_SharedCode.ContactsMerge(new Contact(Id = Contacts[0].Id), new List<Contact> { new Contact( Id = Contacts[1].Id) });

                    // Limit to 1 Contact merge because an Contact merge with 5 contact merges is at SOQL limit of 100 - DML Merge must trigger a bunch of other SOQL calls (e.g., triggers).
                    //      If more than 5 contacts then will probably throw exception and won't finish other contact merges.  Need a new rule Contact only merges that looks at contcats within a single Contact to catch these unmerged contacts
                    break;
                }
            }

            strSaveResults = recordsUpdated + ' ' + Label.labelMassMergeSaveSuccess;
            ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM, strSaveResults));

            // successful save, so clear out dirty list
            setContactsIdDirty = null;

            // Refresh Contact and Contact Table
            ResetContacts();

            return null;            

        } catch (Exception e) {
            strSaveResults = Label.labelMassMergeErrorOnSave;
            ApexPages.addMessages(e); 
            return null;
        }
    }

    //save the Contacts modified, and then close the page.
    global virtual PageReference SaveAndCloseContacts() {
        SaveContacts();
        if (ApexPages.hasMessages(ApexPages.Severity.ERROR) ||
           ApexPages.hasMessages(ApexPages.Severity.FATAL) ||
            ApexPages.hasMessages(ApexPages.Severity.WARNING)) {
                return null; // don't close window.
        }
        return Cancel();    
    }
    
    // user wants to close this page
    global virtual PageReference Cancel() {
        // figure out which object to return to.
        idRedirect = contactFilter.Id;
        
        // trigger our redirect component to redirect using javascript.
        redirect = true;
        return null;
    }
    
    // this was a testmethod which can't be compiled in this class under api 31.  
    // but because it was marked global, it could not be completely removed.
    global static void CodeCoverageTests() {}
}
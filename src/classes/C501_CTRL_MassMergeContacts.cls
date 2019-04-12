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
        for (Schema.FieldSetMember f : SObjectType.contact.FieldSets.MassMergeContacts.getFields()) {
            listStrFields.add(f.getFieldPath());
        }

        // Required fields
        listStrFields.add('Id');
        listStrFields.add('AccountId');
        listStrFields.add('C501_Merge_Id__c');
        listStrFields.add('C501_Merge_Action__c');
        listStrFields.add('C501_Merge_Contact__c');
        listStrFields.add('C501_Merge_Target__c');
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
      
    // The list of contacts.
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
        
    // helper function that the client can override, to query for the appropriate fields in contacts.
    global virtual void FillListContacts() {

		Map<Id,C501_Contact_Merge__c> contactsMerge = new Map<Id,C501_Contact_Merge__c>();

        if (contactFilter.Id <> null) {
        
            for(C501_Contact_Merge__c contactMerge : [
                SELECT Id, Contact__c, Merge_Target_Contact__c, Merge_Confidence__c, Merge_Action__c, Merge_Metric__c, Merge_Metric__r.Name
                FROM C501_Contact_Merge__c
                WHERE (Contact__c = :contactFilter.Id OR Merge_Target_Contact__c = :contactFilter.Id) AND isDeleted = false]) {

                    contactsMerge.put(
                        contactMerge.Contact__c,
                        new C501_Contact_Merge__c(
                            Id = contactMerge.Id,
                            Merge_Action__c = contactMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Contact__c = contactMerge.Contact__c,
                            Merge_Target_Contact__c = contactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = contactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + contactMerge.Merge_Metric__r.Name
                    ));

                    contactsMerge.put(
                        contactMerge.Merge_Target_Contact__c,
                        new C501_Contact_Merge__c(
                            Id = contactMerge.Id,
                            Merge_Action__c = contactMerge.Merge_Action__c,
                            Merge_Confidence__c = contactMerge.Merge_Confidence__c,
                            Contact__c = contactMerge.Contact__c,
                            Merge_Target_Contact__c = contactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = contactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + contactMerge.Merge_Metric__r.Name
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

            for(C501_Contact_Merge__c contactMerge : Database.Query(strSoql)) {

                    if (contactsMerge.containsKey(contactMerge.Contact__c) || contactsMerge.containsKey(contactMerge.Merge_Target_Contact__c)) {
                        continue;
                    }

                    contactsMerge.put(
                        contactMerge.Contact__c,
                        new C501_Contact_Merge__c(
                            Id = contactMerge.Id,
                            Merge_Action__c = contactMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Contact__c = contactMerge.Contact__c,
                            Merge_Target_Contact__c = contactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = contactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + contactMerge.Merge_Metric__r.Name
                    ));

                    contactsMerge.put(
                        contactMerge.Merge_Target_Contact__c,
                        new C501_Contact_Merge__c(
                            Id = contactMerge.Id,
                            Merge_Action__c = contactMerge.Merge_Action__c,
                            Merge_Confidence__c = contactMerge.Merge_Confidence__c,
                            Contact__c = contactMerge.Contact__c,
                            Merge_Target_Contact__c = contactMerge.Merge_Target_Contact__c,
                            Merge_Metric__c = contactMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + contactMerge.Merge_Metric__r.Name
                    ));

                    mergeIndex++;
                    if (mergeIndex >= 10) {
                        mergeBuffer = '';
                    }
            }
        }

        String strSoql = 'SELECT ' + String.join(listStrFields, ',');

        Set<Id> contactsMergeIds = contactsMerge.keySet();
        strSoql += ' FROM Contact WHERE Id in :contactsMergeIds';
        strSoql += ' order by C501_Merge_Metric_Name__c ASC NULLS FIRST';
        
        listContacts = Database.Query(strSoql);

        for ( Contact Contact :listContacts ) {
            if (contactsMerge.containsKey(contact.Id)) {
                C501_Contact_Merge__c mergeContact = contactsMerge.get(contact.Id);
                contact.C501_Merge_Id__c = mergeContact.Id;
                contact.C501_Merge_Action__c = mergeContact.Merge_Action__c;
                contact.C501_Merge_Confidence__c = mergeContact.Merge_Confidence__c;
                contact.C501_Merge_Contact__c = mergeContact.Contact__c;
                contact.C501_Merge_Target__c = mergeContact.Merge_Target_Contact__c;
                contact.C501_Merge_Metric_Name__c = mergeContact.Merge_Metric_Name__c;
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
            Map<String, C501_Contact_Merge__c> listContactsMergeUpdate = new Map<String, C501_Contact_Merge__c>();
            Map<String, C501_Contact_Merge__c> listContactsMerges = new Map<String, C501_Contact_Merge__c>();

            System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts listContacts: ' + String.valueOf(listContacts));

            for (Contact contact : listContacts) {

                if (contact.Id != null && contact.C501_Merge_Action__c == 'Merge') {

                    System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts Check Merge Action - Merge Rule: ' + contact.C501_Merge_Metric_Name__c);

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setContactsIdDirty.contains(contact.Id)) 

                    if (!listContactsMerges.containsKey(contact.C501_Merge_Id__c)) {
                        listContactsMerges.put(contact.C501_Merge_Id__c, new C501_Contact_Merge__c(
                            Id = contact.C501_Merge_Id__c,
                            Merge_Target_Contact__c = contact.Id,
                            Merge_Action__c = 'Merge',
                            Merge_Confidence__c = contact.C501_Merge_Confidence__c
                        ));
                    }
                    else {
                        C501_Contact_Merge__c mergeContact = listContactsMerges.remove(contact.C501_Merge_Id__c);
                        mergeContact.Merge_Target_Contact__c = contact.Id;
                        listContactsMerges.put(contact.C501_Merge_Id__c, mergeContact);

                        if (mergeContact.Contact__c <> null && mergeContact.Merge_Target_Contact__c <> null) {
                            listContactsMergeUpdate.put(contact.C501_Merge_Id__c, new C501_Contact_Merge__c(
                                Id = contact.C501_Merge_Id__c,
                                Merge_Action__c = 'Merge'
                            ));
                        }
                    }
                }

                else if (contact.Id != null && contact.C501_Merge_Action__c == 'Master') {

                    System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts Check Master Action - Merge Rule: ' + contact.C501_Merge_Metric_Name__c);

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setContactsIdDirty.contains(contact.Id)) 

                    if (!listContactsMerges.containsKey(contact.C501_Merge_Id__c)) {
                        listContactsMerges.put(contact.C501_Merge_Id__c, new C501_Contact_Merge__c(
                            Id = contact.C501_Merge_Id__c,
                            Contact__c = contact.Id,
                            Merge_Action__c = 'Merge',
                            Merge_Confidence__c = contact.C501_Merge_Confidence__c
                        ));
                    }
                    else {
                        C501_Contact_Merge__c mergeContact = listContactsMerges.remove(contact.C501_Merge_Id__c);
                        mergeContact.Contact__c = contact.Id;
                        listContactsMerges.put(contact.C501_Merge_Id__c, mergeContact);

                        if (mergeContact.Contact__c <> null && mergeContact.Merge_Target_Contact__c <> null) {
                            listContactsMergeUpdate.put(contact.C501_Merge_Id__c, new C501_Contact_Merge__c(
                                Id = contact.C501_Merge_Id__c,
                                Merge_Action__c = 'Merge'
                            ));
                        }
                    }
                }

                else if (contact.Id != null && contact.C501_Merge_Action__c == 'Ignore') {

                    System.debug('***** C501_CTRL_MassMergeContacts::SaveContacts Check Ignore Action - Merge Rule: ' + contact.C501_Merge_Metric_Name__c);

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setContactsIdDirty.contains(contact.Id)) 
                    listContactsMergeUpdate.put(contact.C501_Merge_Id__c, new C501_Contact_Merge__c(
                        Id = contact.C501_Merge_Id__c,
                        Merge_Action__c = 'Ignore'
                    ));
                }
            }

            if (!listContactsMergeUpdate.values().isEmpty()) {
                update listContactsMergeUpdate.values();
            }

            c501MassMerge_SharedCode.ProcessContactMerges(listContactsMerges.values(), true);

            strSaveResults = (listContactsMerges.values().size() * 2) + ' ' + Label.labelMassMergeSaveSuccess;
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
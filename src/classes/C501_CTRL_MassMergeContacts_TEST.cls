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

@isTest
private with sharing class C501_CTRL_MassMergeContacts_TEST {
    
    @testSetup static void setup() {
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();

        C501_MM_Rule_Contact_NameDOB scheduleNameDOB = new C501_MM_Rule_Contact_NameDOB();
        scheduleNameDOB.execute(null);

        C501_MM_Rule_Contact_NameEmail scheduleNameEmail = new C501_MM_Rule_Contact_NameEmail();
        scheduleNameEmail.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c]) {
            mergeMetric.Enable__c = true;
            mergeMetric.AutoMerge_Percentage__c = 0.0;

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        // Create Contact Merges
        scheduleNameDOB.execute(null);
        scheduleNameEmail.execute(null);

        // Attempt to create Contact Merges again
        scheduleNameDOB.execute(null);
        scheduleNameEmail.execute(null);
    }

    //==================== TEST METHOD(s) ======================================

    private static testmethod void CodeCoverageTests() {

        Id masterContactId = [SELECT Id FROM Contact ORDER BY Id ASC LIMIT 1].Id;

        //point to our VF page
        PageReference p = new PageReference('Page.MassMergeContacts');
        p.getParameters().put('Id', masterContactId);
        Test.setCurrentPageReference(p);
        
        //instantiate the controller for this opp
        C501_CTRL_MassMergeContacts ctrl = new C501_CTRL_MassMergeContacts();
        System.AssertEquals(masterContactId, ctrl.contactFilter.Id);
        System.Assert(ctrl.listSOContacts.size() > 1);
        System.Assert(ctrl.listContacts.size() > 0);

        ctrl.contactFilter.Id = null;
        ctrl.ChangeMergeConfidence();
        ctrl.ChangeRule();
        ctrl.ChangeContact();
        ctrl.ResetContacts();
        
        System.Assert(ctrl.listSORules.size() > 0);

        // Check filter by Rule
        ctrl.contactFilter.Id = masterContactId;
        ctrl.contactFilter.C501_Merge_Rule__c = 'Contact_NameDOB';
        System.Assert(ctrl.listContacts.size() > 0);

        // Check filter by Confidence
        ctrl.contactFilter.Id = masterContactId;
        ctrl.contactFilter.C501_Merge_Confidence_From__c = 0.0;
        ctrl.contactFilter.C501_Merge_Confidence_To__c = 100.0;
        System.Assert(ctrl.listContacts.size() > 0);

        // Clear filter
        ctrl.ChangeRule();
        ctrl.contactFilter.Id = masterContactId;
        System.Assert(ctrl.listContacts.size() > 0);
        System.AssertEquals(0, ctrl.numberOfRecordsDirty);
        
        //ctrl.listContacts.get(0).Amount = 2;
        p.getParameters().put('usersIdDirtied', ctrl.listContacts.get(0).id);
        ctrl.ContactsRecordModified();
        System.AssertEquals(1, ctrl.setContactsIdDirty.size());
        
        Contact Contact = ctrl.listContacts.get(ctrl.listContacts.size() - 1);
        p.getParameters().put('usersIdDirtied', null);
        ctrl.ContactsRecordModified();
        System.AssertEquals(1, ctrl.setContactsIdDirty.size());
        System.AssertEquals(1, ctrl.numberOfRecordsDirty);

        // test the save!
        for (Contact ContactMerge :ctrl.listContacts) {
            ContactMerge.C501_Merge_Action__c = 'Merge';
        }
        ctrl.listContacts[ctrl.listContacts.size() - 1].C501_Merge_Action__c = 'Ignore';
        ctrl.SaveContacts();

        System.debug('***** C501_CTRL_MassMergeContacts_TEST::CodeCoverageTests' + ctrl.strSaveResults);
        //System.Assert(ctrl.strSaveResults.startsWith('Error'));
        ctrl.ChangeRule();
        ctrl.SaveContacts();      
        //System.AssertEquals(0, ctrl.numberOfRecordsDirty);  

        // Clear out household filter
        ctrl.contactFilter.Id = null;
        ctrl.SaveAndCloseContacts();      
    }
}
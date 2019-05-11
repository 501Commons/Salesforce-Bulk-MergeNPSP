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
public with sharing class C501_CTRL_MassMergeContacts_TEST {
    
    private static void setupTest() {

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Contact%']) {
            mergeMetric.AutoMerge_Percentage__c = 0.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        C501_MM_Rule_Merge scheduleMerge = new C501_MM_Rule_Merge();
        scheduleMerge.execute(null);

        c501MassMerge_SharedCode.PrintSalesforceStructure();
    }

    //==================== TEST METHOD(s) ======================================

    @isTest(SeeAllData='true')
    public static void ProcessContactMerges_BatchTest() {

        setupTest();

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Contact%'];
        List<Contact> listContacts = [SELECT Id FROM Contact WHERE LastName LIKE 'TESTDATA%'];

        C501_Contact_Merge__c contactMerge1 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listContacts[0].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = listContacts[0].Id,
                Merge_Target_Contact__c = listContacts[1].Id,
                Merge_Confidence__c = 100.0);

        insert contactMerge1;

        C501_Contact_Merge__c contactMerge2 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listContacts[2].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = listContacts[2].Id,
                Merge_Target_Contact__c = listContacts[3].Id,
                Merge_Confidence__c = 100.0,
                Merge_Action__c = 'Merge');

        insert contactMerge2;

        Test.StartTest();

        // Exception Note:  Currently not getting the exception in the test code for Batch scheduled job.  Thinking need to query the batch job status instead to figure out if exception thrown
        //
        Boolean exceptionRaised = false;
        try
        {
            C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
            c501MassMerge_SharedCode_Contact.ProcessObjectMerges(new List<C501_Contact_Merge__c> { contactMerge1 }, true);
        }
        catch (C501_MassMerge_SharedCode_Account.C501_MassMerge_SharedCode_AccountException customException)
        {
            exceptionRaised = true;
        }
        catch (System.DmlException dmlException) {
            exceptionRaised = true;
        }
        catch (Exception generalException) {
            exceptionRaised = true;
        }
       
        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void ProcessContactMerges_SyncTest() {

        setupTest();

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Contact%'];
        List<Contact> listContacts = [SELECT Id FROM Contact WHERE LastName LIKE 'TESTDATA%'];

        C501_Contact_Merge__c contactMerge1 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listContacts[0].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = listContacts[0].Id,
                Merge_Target_Contact__c = listContacts[1].Id,
                Merge_Confidence__c = 100.0);

        insert contactMerge1;

        C501_Contact_Merge__c contactMerge2 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listContacts[2].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = listContacts[2].Id,
                Merge_Target_Contact__c = listContacts[3].Id,
                Merge_Confidence__c = 100.0,
                Merge_Action__c = 'Merge');

        insert contactMerge2;

        Test.StartTest();

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.ProcessObjectMerges(new List<C501_Contact_Merge__c> { contactMerge1 }, false);

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void ProcessContactMerges_AcrossAccountsTest() {

        setupTest();

        Account account1 = new Account(
            Name = 'TESTDATA Account1',
            BillingStreet = '123 Street',
            Phone = '(123) 456-7890'
        );
        insert account1;

        Contact contact11 = new Contact(
            LastName = 'TESTDATA LastName',
            FirstName = 'FirstName',
            Birthdate = System.today(),
            AccountId = account1.Id
        );
        insert contact11;

        Account account2 = new Account(
            Name = 'TESTDATA Account2',
            BillingStreet = '123 Street',
            Phone = '(123) 456-7890'
        );
        insert account2;

        Contact contact21 = new Contact(
            LastName = 'TESTDATA LastName',
            FirstName = 'FirstName',
            Email = 'email@email.com',
            Gender__c = 'Male',
            AccountId = account2.Id
        );
        insert contact21;

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Contact%'];

        C501_Contact_Merge__c contactMerge1 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + contact11.Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = contact11.Id,
                Merge_Target_Contact__c = contact21.Id,
                Merge_Confidence__c = 100.0);

        insert contactMerge1;

        // Add some invalids merges
        //
        C501_Contact_Merge__c contactMerge2 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name2 ' + contact11.Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = contact11.Id,
                Merge_Confidence__c = 100.0);

        insert contactMerge2;

        C501_Contact_Merge__c contactMerge3 = new C501_Contact_Merge__c(
                Unique_Id__c = 'TESTDATA Name3 ' + contact11.Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Contact__c = contact11.Id,
                Merge_Target_Contact__c = contact11.Id,
                Merge_Confidence__c = 100.0);

        insert contactMerge3;

        Test.StartTest();

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.ProcessObjectMerges(new List<C501_Contact_Merge__c> { contactMerge1 }, false);

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void CodeCoverageTests() {

        setupTest();

        Id masterContactId = [SELECT Id FROM Contact WHERE LastName LIKE 'TESTDATA%' ORDER BY Id ASC LIMIT 1].Id;

        Test.StartTest();

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

        System.Assert(ctrl.listSOContacts.size() > 1);
        System.Assert(ctrl.listContacts.size() > 0);

        ctrl.ChangeMergeConfidence();
        ctrl.ChangeRule();
        ctrl.ChangeContact();
        ctrl.ResetContacts();
        
        System.Assert(ctrl.listSORules.size() > 0);

        // Check filter by Rule
        ctrl.contactFilter.Id = masterContactId;

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Name FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Contact%'];
        ctrl.contactFilter.C501_Merge_Rule__c = listMergeMetrics[0].Name;
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
        ctrl.listContacts[0].C501_Merge_Action__c = 'Master';

        ctrl.listContacts[ctrl.listContacts.size() - 1].C501_Merge_Action__c = 'Ignore';
        ctrl.listContacts[ctrl.listContacts.size() - 2].C501_Merge_Action__c = 'Ignore';

        ctrl.SaveContacts();

        System.debug('***** C501_CTRL_MassMergeContacts_TEST::CodeCoverageTests' + ctrl.strSaveResults);
        //System.Assert(ctrl.strSaveResults.startsWith('Error'));
        ctrl.ChangeRule();
        ctrl.SaveContacts();      
        //System.AssertEquals(0, ctrl.numberOfRecordsDirty);  

        // Clear out household filter
        ctrl.contactFilter.Id = null;
        ctrl.SaveAndCloseContacts();

        Test.StopTest();
    }
}
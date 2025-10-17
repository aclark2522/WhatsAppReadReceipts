/**
 * Wrapper class for Whatsapp constants
 * Provides lazy-loaded access to metadata values.
 */
public with sharing class WhatsappConfig {
    public String TO_ADDRESS;
    public String ORG_WIDE_EMAIL_ADDRESS;
    public String VERIFY_TOKEN;
    public Integer ERROR_CODE;
    public Boolean SEND_EMAIL;
    public Integer SUCCESS_CODE;
    public String APP_SECRET;

    public WhatsappConfig() {
        WhatsappWebhook__mdt constants = WhatsappWebhook__mdt.getInstance('Constants');
        if (constants == null) {
            throw new AuraHandledException('Missing WhatsappWebhook__mdt record named "Constants".');
        }

        TO_ADDRESS = constants.ToAddress__c;
        ORG_WIDE_EMAIL_ADDRESS = constants.OrgWideEmail__c;
        VERIFY_TOKEN = constants.VerifyToken__c;
        ERROR_CODE = Integer.valueOf(constants.ErrorCode__c);
        SUCCESS_CODE = Integer.valueOf(constants.SuccessCode__c);
        SEND_EMAIL = constants.SendDebugEmail__c;
        APP_SECRET = constants.AppSecret__c;
    }
}

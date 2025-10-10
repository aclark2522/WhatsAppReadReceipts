@RestResource(urlMapping='/webhooks/whatsapp')
global class WhatsappReceiver {
    
    private static String TO_ADDRESS;
    private static String ORG_WIDE_EMAIL_ADDRESS;
    private static String VERIFY_TOKEN;
    private static Integer ERROR_CODE;
    private static Boolean SEND_EMAIL;
    private static Integer SUCCESS_CODE;
    private static String APP_SECRET;
    
    private static void setConstants() {
        if (TO_ADDRESS == null || ORG_WIDE_EMAIL_ADDRESS == null || VERIFY_TOKEN == null || 
        ERROR_CODE == null || SEND_EMAIL == null || SUCCESS_CODE == null || APP_SECRET == null) {
            WhatsappWebhook__mdt constants = WhatsappWebhook__mdt.getInstance('Constants');
            
            if (constants != null) {
                
                TO_ADDRESS = constants.ToAddress__c;
                ORG_WIDE_EMAIL_ADDRESS = constants.OrgWideEmail__c;
                VERIFY_TOKEN = constants.VerifyToken__c;
                ERROR_CODE = Integer.valueOf(constants.ErrorCode__c);
                SUCCESS_CODE = Integer.valueOf(constants.SuccessCode__c);
                SEND_EMAIL = constants.SendDebugEmail__c;
                APP_SECRET = constants.AppSecret__c;
                
            }
        }
    }
    
    @HttpPost
    global static void handlePost() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        setConstants();
        
        String jsonBody = request.requestBody.toString();
        Map<String, String> headers = request.headers;
        
        Boolean isValid = verifySignature(jsonBody, headers.get('X-Hub-Signature-256'), APP_SECRET);
        if (isValid) {

            WhatsAppWebhookWrapper.Status status = getStatus(jsonBody);     
            String recipientNumber = status.recipient_id;     
            MessagingSession session = getMessagingSession(recipientNumber);
            Datetime dateTimeStamp = createDateTimeValue(status.timestamp);

            updateMessagingSession(session, status.status, dateTimeStamp);

            if (SEND_EMAIL) {
                sendJsonPackageToEmail(TO_ADDRESS, ORG_WIDE_EMAIL_ADDRESS, jsonBody);
            }
            
            Map<String, Boolean> responseBody = new Map<String, Boolean> {'Success' => true};
            setResponse(response, SUCCESS_CODE, JSON.serialize(responseBody));
            
        } else {
            
            Map<String, Boolean> responseBody = new Map<String, Boolean> {'Success' => false};
            setResponse(response, ERROR_CODE, JSON.serialize(responseBody));

        }
        
    }
    
    @HttpGet
    global static void handleGet() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response; 
        setConstants();
        
        String mode = request.params.get('hub.mode');
        Boolean isMode;
        if (mode == 'subscribe') {
            isMode = true;
        }
        
        if (isMode) {
            String verifyToken = request.params.get('hub.verify_token');
            
            if (verifyToken == VERIFY_TOKEN) {
                setResponse(response, SUCCESS_CODE, request.params.get('hub.challenge'));
            } else {
                setResponse(response, ERROR_CODE, 'Incorrect verification Token');
            }
        } else {
            setResponse(response, ERROR_CODE, 'Incorrect mode');
        }
    }
    
    private static MessagingSession getMessagingSession(String recipientNumber) {
        return [
            SELECT Id, ConversationId, SentDate__c, ReadDate__c, DeliveredDate__c, SendFailed__c
            FROM MessagingSession
            WHERE MessagingEndUserId IN (SELECT Id FROM MessagingEndUser WHERE MessagingPlatformKey = :recipientNumber)
            LIMIT 1
        ];
    }
    
    private static WhatsAppWebhookWrapper.Status getStatus(String jsonBody) {
        WhatsAppWebhookWrapper data = WhatsAppWebhookWrapper.parse(jsonBody);
        
        WhatsAppWebhookWrapper.Status status = new WhatsAppWebhookWrapper.Status();
		return data.entry[0].changes[0].value.statuses[0];
    }
    
    private static Datetime createDateTimeValue(String timeStamp) {
        Integer epochTime = Integer.valueOf(timeStamp);
        return Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(epochTime);
    }
    
    private static void updateMessagingSession(MessagingSession session, String status, Datetime updatedTimestamp) {
        Boolean needsUpdate = false;
    
        switch on status.toLowerCase().trim() {
            when 'sent' {
                if (session.SentDate__c == null) {
                    session.SentDate__c = updatedTimestamp;
                    needsUpdate = true;
                }
            }
            when 'delivered' {
                if (session.DeliveredDate__c == null) {
                    session.DeliveredDate__c = updatedTimestamp;
                    if (session.SentDate__c == null) {
                        session.SentDate__c = updatedTimestamp;
                    }
                    needsUpdate = true;
                }
            }
            when 'read' {
                if (session.ReadDate__c == null) {
                    session.ReadDate__c = updatedTimestamp;
                    if (session.SentDate__c == null) {
                        session.SentDate__c = updatedTimestamp;
                    }
                    needsUpdate = true;
                }
            }
            when 'failed' {
                if (session.SendFailed__c == false) {
                    session.SendFailed__c = true;
                    if (session.SentDate__c == null) {
                        session.SentDate__c = updatedTimestamp;
                    }
                    needsUpdate = true;
                }
            }
        }
    
        if (needsUpdate) {
            update session;
        }
    }
    
    
    private static Boolean verifySignature(String payload, String signatureHeader, String appSecret) {
        String providedSignature = signatureHeader.replace('sha256=', '');
        String expectedSignature = createExpectedSignature(payload, appSecret);
        
        return providedSignature.equalsIgnoreCase(expectedSignature);
    }

    @testVisible
    private static String createExpectedSignature(String payload, String appSecret) {        
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(appSecret));
        
        return EncodingUtil.convertToHex(mac);
    }
    
    private static void sendJsonPackageToEmail(String toEmailAddress, String orgWideEmailAddress, String body) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        email.setOrgWideEmailAddressId(
            [SELECT Id FROM OrgWideEmailAddress WHERE Address = :orgWideEmailAddress LIMIT 1].Id
        );
        
        email.setSubject('JSON: ' + Datetime.now().format('dd-MM-yyy h:mm a'));
        email.setToAddresses(new List<String> {toEmailAddress});
        email.setPlainTextBody(body);
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static RestResponse setResponse(RestResponse response, Integer statusCode, String body) {
        response.statusCode = statusCode;
        response.responseBody = Blob.valueOf(body);
        return response;
    }
}

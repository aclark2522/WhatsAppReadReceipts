/**
 * @description Handles incoming and outgoing WhatsApp webhook requests from Meta's API.
 * This class provides REST endpoints for message delivery status updates and webhook verification.
 * It also supports signature validation, session updates, and optional email debugging.
 *
 * @group Webhooks
 * @author Andrew Clark
 * @date 2025-10-10
 *
 * @methods
 *  - handlePost(): Processes incoming WhatsApp webhook POST requests.
 *  - handleGet(): Handles webhook verification requests from Meta.
 *  - initializeConfig(): Loads configuration values from custom metadata.
 *  - getMessagingSession(String): Retrieves the corresponding MessagingSession record by recipient number.
 *  - getStatus(String): Parses the JSON body to extract message status data.
 *  - createDateTimeValue(String): Converts a timestamp string into a Datetime value.
 *  - upsertRecord(sObject, WhatsAppWebhookWrapper.Status, Id): Updates a record based on message status.
 *  - upsertWhatsAppReceipts(WhatsAppWebhookWrapper.Status, Id): Updates a WhatsAppReceipt__c record.
 *  - verifySignature(String, String, String): Verifies the request authenticity using HMAC-SHA256.
 *  - createExpectedSignature(String, String): Generates the expected HMAC-SHA256 signature.
 *  - sendJsonPackageToEmail(String, String, String): Sends a JSON payload to an email address for debugging.
 *  - setResponse(RestResponse, Integer, String): Standardizes REST responses.
 */
@RestResource(urlMapping='/webhooks/whatsapp')
global class WhatsappReceiver {
    @testVisible
    private static WhatsappConfig CONFIG;
    
    /**
     * @description Loads constant values from the WhatsappWebhook__mdt metadata record.
     * These include email settings, verification tokens, status codes, and app secret.
     */
    @testVisible
    private static void initializeConfig() {
        
        if (CONFIG == null) {
            CONFIG = new WhatsappConfig();
        }
        
    }
    
    /**
     * @description Handles incoming webhook POST requests from WhatsApp Cloud API.
     * Validates the signature, updates related MessagingSession records,
     * and optionally sends debug email notifications.
     */
    @HttpPost
    global static void handlePost() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        initializeConfig();
        
        String jsonBody = request.requestBody.toString();
        Map<String, String> headers = request.headers;
        
        Boolean isValid = verifySignature(jsonBody, headers.get('X-Hub-Signature-256'), CONFIG.APP_SECRET);
        Map<String, Boolean> responseBody = new Map<String, Boolean>();
        if (!isValid) {
            responseBody.put('Success', false);
            setResponse(response, CONFIG.ERROR_CODE, JSON.serialize(responseBody));
            
            return;
        }
        
        WhatsAppWebhookWrapper.Status status = getStatus(jsonBody);
        
        if (status == null) {
            responseBody.put('Success', false);
            setResponse(response, CONFIG.ERROR_CODE, JSON.serialize(responseBody));
            
            return;
        }
        
        String recipientNumber = status.recipient_id;
        MessagingSession session = getMessagingSession(recipientNumber);
        
        if (session == null) {
            responseBody.put('Success', false);
            setResponse(response, CONFIG.ERROR_CODE, JSON.serialize(responseBody));
            
            return;
        }
        
        upsertRecord(session, status, null);
        upsertWhatsAppReceipts(status, session.Id);
        
        if (CONFIG.SEND_EMAIL) {
            sendJsonPackageToEmail(CONFIG.TO_ADDRESS, CONFIG.ORG_WIDE_EMAIL_ADDRESS, jsonBody);
        }
        
        responseBody.put('Success', true);
        setResponse(response, CONFIG.SUCCESS_CODE, JSON.serialize(responseBody));
        
    }
    
    /**
     * @description Handles webhook verification (GET) requests from WhatsApp.
     * Verifies the `hub.verify_token` against stored metadata and returns
     * the `hub.challenge` value if successful.
     */
    @HttpGet
    global static void handleGet() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        initializeConfig();
        
        String mode = request.params.get('hub.mode');
        
        if (mode != 'subscribe') {
            setResponse(response, CONFIG.ERROR_CODE, 'Incorrect mode');
            
            return;
        }
        
        String verifyToken = request.params.get('hub.verify_token');
        
        if (verifyToken != CONFIG.VERIFY_TOKEN) {
            setResponse(response, CONFIG.ERROR_CODE, 'Incorrect verification Token');
            
            return;
        }
        
        setResponse(response, CONFIG.SUCCESS_CODE, request.params.get('hub.challenge'));
    }
    
    /**
     * @description Retrieves the active MessagingSession record associated
     * with the provided WhatsApp recipient number.
     * @param recipientNumber The WhatsApp recipient's phone number.
     * @return The related MessagingSession record.
     */
    private static MessagingSession getMessagingSession(String recipientNumber) {
        List<MessagingSession> sessions = [
            SELECT Id, ConversationId, SentDate__c, ReadDate__c, DeliveredDate__c, SendFailed__c
            FROM MessagingSession
            WHERE MessagingEndUserId IN (SELECT Id FROM MessagingEndUser WHERE MessagingPlatformKey = :recipientNumber)
            LIMIT 1
        ];
        
        if (sessions.size() > 0) {
            
            return sessions[0];
        } else {
            
            return null;
        }
        
    }
    
    /**
     * @description Parses a WhatsApp webhook JSON body into a strongly-typed wrapper
     * and extracts the status object for processing.
     * @param jsonBody The raw JSON payload from the webhook request.
     * @return The Status object containing message state and timestamp data.
     */
    private static WhatsAppWebhookWrapper.Status getStatus(String jsonBody) {
        WhatsAppWebhookWrapper data;
        try {
            data = WhatsAppWebhookWrapper.parse(jsonBody);
        } catch (Exception e) {
            System.debug('Failed to parse WhatsApp webhook JSON: ' + e.getMessage());
            
            return null;
        }

        if (data == null || data.entry == null || data.entry.isEmpty()) {
            
            return null;
        }
    
        WhatsAppWebhookWrapper.Entry firstEntry = data.entry[0]; 
        
        if (firstEntry.changes == null || firstEntry.changes.isEmpty()) {
            
            return null;
        }
        
        WhatsAppWebhookWrapper.Change firstChange = firstEntry.changes[0];
        
        if (firstChange.value == null || firstChange.value.statuses == null || firstChange.value.statuses.isEmpty()) {
            
            return null;
        }
        
        return firstChange.value.statuses[0];
    }
    
    
    /**
     * @description Converts a UNIX epoch timestamp (in seconds) into a Salesforce Datetime value.
     * @param timeStamp The string timestamp value (epoch seconds).
     * @return A Datetime instance representing the timestamp.
     */
    private static Datetime createDateTimeValue(String timeStamp) {
        Integer epochTime = Integer.valueOf(timeStamp);
        
        return Datetime.newInstance(1970, 1, 1, 0, 0, 0).addSeconds(epochTime);
    }
    
    /**
     * @description Validates the webhook request signature to confirm authenticity.
     * Compares the provided HMAC-SHA256 signature with the expected signature.
     * @param payload The JSON request body as a string.
     * @param signatureHeader The 'X-Hub-Signature-256' header from the request.
     * @param appSecret The application secret key from metadata.
     * @return True if the signature is valid; otherwise, false.
     */
    private static Boolean verifySignature(String payload, String signatureHeader, String appSecret) {
        String providedSignature = signatureHeader.replace('sha256=', '');
        String expectedSignature = createExpectedSignature(payload, appSecret);
        
        return providedSignature.equalsIgnoreCase(expectedSignature);
    }
    
    /**
     * @description Generates the expected HMAC-SHA256 signature for the given payload and app secret.
     * @param payload The request body as a string.
     * @param appSecret The secret key used for signature generation.
     * @return The generated hexadecimal signature string.
     */
    @testVisible
    private static String createExpectedSignature(String payload, String appSecret) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(appSecret));
        
        return EncodingUtil.convertToHex(mac);
    }
    
    /**
     * @description Sends an email containing the raw JSON payload for debugging or logging purposes.
     * @param toEmailAddress The destination email address for debugging.
     * @param orgWideEmailAddress The Org-Wide Email Address to use as the sender.
     * @param body The email body content containing the JSON payload.
     */
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
    
    /**
     * @description Configures and returns a standardized REST response object.
     * @param response The RestResponse instance to modify.
     * @param statusCode The HTTP status code to assign.
     * @param body The response body to include (JSON or text).
     * @return The modified RestResponse object.
     */
    private static RestResponse setResponse(RestResponse response, Integer statusCode, String body) {
        response.statusCode = statusCode;
        response.responseBody = Blob.valueOf(body);
        
        return response;
    }
    
    /**
     * @description Gets a WhatsApp record using the wamId.
     * @param whatsAppMessageId The Id given to a single message on the WhatSapp platform.
     * @return Relevant WhatsAppReceipt__c record if found, otherwise, an empty object.
     */
    private static WhatsAppReceipt__c getWhatsAppReceipt(String whatsAppMessageId) {
        WhatsAppReceipt__c whatsAppReceipt = new WhatsAppReceipt__c();
        
        List<WhatsAppReceipt__c> whatsAppReceiptsList = [
            SELECT Id, SentDate__c, DeliveredDate__c, ReadDate__c, SendFailed__c, MessagingSession__c 
            FROM WhatsAppReceipt__c
            WHERE Name = :whatsAppMessageId
            LIMIT 1
        ];
        system.debug(whatsAppMessageId);
        
        if (whatsAppReceiptsList.size() > 0) {
            whatsAppReceipt = whatsAppReceiptsList[0];
        }
        
        return whatsAppReceipt;
    }
    
    /**
     * @description Upsert a WhatsAppReceipt__c record in relation to a MessagingSession.
     * @param whatsAppMessageId The Id given to a single message on the WhatSapp platform.
     * @param messagingSessionId The Id for a MessagingSession record.
     * @param status An instance of the WhatsAppWebhookWrapper.Status class.
     */
    private static void upsertWhatsAppReceipts(WhatsAppWebhookWrapper.Status status, Id messagingSessionId) {
        WhatsAppReceipt__c whatsAppReceiptRecord = getWhatsAppReceipt(status.id);
        upsertRecord(whatsAppReceiptRecord, status, messagingSessionId);
    }
    
    /**
     * @description Updates the specified sObject record fields based on the
     * WhatsApp message delivery status. Handles 'sent', 'delivered', 'read', and 'failed' states.
     * @param sObjectToUpdate The sObject record to update.
     * @param status An instance of the WhatsAppWebhookWrapper.Status class.
     * @param messagingSessionId The Id for a MessagingSession record.
     */
    private static void upsertRecord(sObject sObjectToUpdate, WhatsAppWebhookWrapper.Status statusObject, Id messagingSessionId) { 
        Datetime dateTimeStamp = createDateTimeValue(statusObject.timestamp);
        
        Boolean needsUpdate = false;
        
		Datetime sentDate = (Datetime) sObjectToUpdate.get('SentDate__c');
        Datetime deliveredDate = (Datetime) sObjectToUpdate.get('DeliveredDate__c');
        Datetime readDate = (Datetime) sObjectToUpdate.get('ReadDate__c');
        Boolean sendFailed = (Boolean) sObjectToUpdate.get('SendFailed__c');
        
        //Get metadata object name and details
        String sObjectname = sObjectToUpdate.getSObjectType().getDescribe().getName();
        
        //Get all object type
        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(sObjectname);
        
        // Get all fields
        Map<String, Schema.sObjectField> sObjectFields = sobjType.getDescribe().fields.getMap();
        
        if (messagingSessionId != null) {
            Id relationShipId = (Id) sObjectToUpdate.get('MessagingSession__c');
            
            if (relationShipId == null) {
                sObjectToUpdate.put(sObjectFields.get('MessagingSession__c'), messagingSessionId);
            }
            
        } 
        
        switch on statusObject.status.toLowerCase().trim() {
            when 'sent' {
                
                if (sentDate == null) {
                    sObjectToUpdate.put(sObjectFields.get('SentDate__c'), dateTimeStamp);
                    needsUpdate = true;
                }
                
            }
            
            when 'delivered' {
                
                if (deliveredDate == null) {
                    sObjectToUpdate.put(sObjectFields.get('DeliveredDate__c'), dateTimeStamp);
                    
                    if (sentDate == null) {
                        sObjectToUpdate.put(sObjectFields.get('SentDate__c'), dateTimeStamp);
                    }
                    
                    needsUpdate = true;
                }
                
            }
            
            when 'read' {
                
                if (readDate == null) {
                    sObjectToUpdate.put(sObjectFields.get('ReadDate__c'), dateTimeStamp);
                    
                    if (sentDate == null) {
                        sObjectToUpdate.put(sObjectFields.get('SentDate__c'), dateTimeStamp);
                    }
                    
                    if (deliveredDate == null) {
                        sObjectToUpdate.put(sObjectFields.get('DeliveredDate__c'), dateTimeStamp);
                    }
                    
                    needsUpdate = true;
                }
                
            }
            
            when 'failed' {
                
                if (sendFailed == false & deliveredDate == null) {
                    sObjectToUpdate.put(sObjectFields.get('SendFailed__c'), true);
                    
                    if (sentDate == null) {
                        sObjectToUpdate.put(sObjectFields.get('SentDate__c'), dateTimeStamp);
                    }
                    
                    needsUpdate = true;
                }
                
            }
        }
        
        if (needsUpdate) {
            upsert sObjectToUpdate;
        }

    }
}
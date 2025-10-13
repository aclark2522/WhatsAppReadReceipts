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
 *  - setConstants(): Loads configuration values from custom metadata.
 *  - getMessagingSession(String): Retrieves the corresponding MessagingSession record by recipient number.
 *  - getStatus(String): Parses the JSON body to extract message status data.
 *  - createDateTimeValue(String): Converts a timestamp string into a Datetime value.
 *  - updateMessagingSession(MessagingSession, String, Datetime): Updates a session record based on message status.
 *  - verifySignature(String, String, String): Verifies the request authenticity using HMAC-SHA256.
 *  - createExpectedSignature(String, String): Generates the expected HMAC-SHA256 signature.
 *  - sendJsonPackageToEmail(String, String, String): Sends a JSON payload to an email address for debugging.
 *  - setResponse(RestResponse, Integer, String): Standardizes REST responses.
 */
@RestResource(urlMapping='/webhooks/whatsapp')
global class WhatsappReceiver {
    
    private static String TO_ADDRESS;
    private static String ORG_WIDE_EMAIL_ADDRESS;
    private static String VERIFY_TOKEN;
    private static Integer ERROR_CODE;
    private static Boolean SEND_EMAIL;
    private static Integer SUCCESS_CODE;
    private static String APP_SECRET;
    
    /**
     * @description Loads constant values from the WhatsappWebhook__mdt metadata record.
     * These include email settings, verification tokens, status codes, and app secret.
     */
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
    
    /**
     * @description Handles incoming webhook POST requests from WhatsApp Cloud API.
     * Validates the signature, updates related MessagingSession records,
     * and optionally sends debug email notifications.
     */
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
    
    /**
     * @description Handles webhook verification (GET) requests from WhatsApp.
     * Verifies the `hub.verify_token` against stored metadata and returns
     * the `hub.challenge` value if successful.
     */
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
    
    /**
     * @description Retrieves the active MessagingSession record associated
     * with the provided WhatsApp recipient number.
     * @param recipientNumber The WhatsApp recipient's phone number.
     * @return The related MessagingSession record.
     */
    private static MessagingSession getMessagingSession(String recipientNumber) {
        return [
            SELECT Id, ConversationId, SentDate__c, ReadDate__c, DeliveredDate__c, SendFailed__c
            FROM MessagingSession
            WHERE MessagingEndUserId IN (SELECT Id FROM MessagingEndUser WHERE MessagingPlatformKey = :recipientNumber)
            LIMIT 1
        ];
    }
    
    /**
     * @description Parses a WhatsApp webhook JSON body into a strongly-typed wrapper
     * and extracts the status object for processing.
     * @param jsonBody The raw JSON payload from the webhook request.
     * @return The Status object containing message state and timestamp data.
     */
    private static WhatsAppWebhookWrapper.Status getStatus(String jsonBody) {
        WhatsAppWebhookWrapper data = WhatsAppWebhookWrapper.parse(jsonBody);
        
        WhatsAppWebhookWrapper.Status status = new WhatsAppWebhookWrapper.Status();
		return data.entry[0].changes[0].value.statuses[0];
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
     * @description Updates the specified MessagingSession record fields based on the
     * WhatsApp message delivery status. Handles 'sent', 'delivered', 'read', and 'failed' states.
     * @param session The MessagingSession record to update.
     * @param status The status string from the webhook payload.
     * @param updatedTimestamp The Datetime value corresponding to the status update.
     */
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
                    if (session.DeliveredDate__c == null) {
                        session.DeliveredDate__c = updatedTimestamp;
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
}

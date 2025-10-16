@isTest
private class WhatsappReceiverTest {
    private final static String REQUEST_URL = '/services/apexrest/webhooks/whatsapp';
    private final static String CHANNEL_KEY = '097616747092986';
    private final static Datetime NOW = Datetime.now();

    // Initialize basic map easier maintainability
    private static Map<String, Object> JSON_MAP = new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
            new Map<String, Object>{
                'changes' => new List<Object>{
                    new Map<String, Object>{
                        'value' => new Map<String, Object>{
                            'statuses' => new List<Object>{
                                new Map<String, Object>{
                                    'id' => '1234567890',
                                    'status' => 'sent',
                                    'timestamp' => '1759910419',
                                    'recipient_id' => '440000000000'
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    // Create metadata 
    @TestSetup
    static void setupTestData() {        
        MessagingChannel channel = new MessagingChannel(
            ConsentType = 'ImplicitOptIn',
            IsActive = true,
            IsoCountryCode = 'US',
            IsRequireDoubleOptIn = false,
            IsRestrictedToBusinessHours = false,
            Language = 'en_US',
            MasterLabel = 'TestMessageChannel',
            MessageType = 'WhatsApp',
            MessagingPlatformKey = CHANNEL_KEY,
            PlatformType = 'Enhanced',
            ConversationEndResponse = 'An agent has left the conversation.',
            DeveloperName = 'TestMessageChannel',
            InitialResponse = 'Thanks for messaging us. An agent will be with you shortly...',
            EngagedResponse = 'An agent has joined the conversation'
        );
        insert channel;
    }
    
    /**
     * @description test to confirm a POST request is succesful with a valid WhatsAppReceipt__c record.
     */
    @isTest
    static void testHandlePostSuccessWithWhatsAppReceipt() {
        Id sessionId = addObjects();
        insert new WhatsAppReceipt__c(
            MessagingSession__c = sessionId,
            SentDate__c = Datetime.now(),
            Name = '1234567890'
        );
        
		WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        String jsonString = JSON.serialize(JSON_MAP);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }

    /**
     * @description test to confirm a POST request is succesful with the 'sent' status.
     */
    @isTest
    static void testHandlePostSuccessSent() {
        addObjects();
		WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        String jsonString = JSON.serialize(JSON_MAP);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }
    
    /**
     * @description test to confirm a POST request is succesful with the 'delivered' status.
     */
    @isTest
    static void testHandlePostSuccessDelivered() {
        addObjects();
		WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        String jsonString = updateStatus('status', 'delivered');
        
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }
    
    /**
     * @description test to confirm a POST request is succesful with the 'read' status.
     */
    @isTest
    static void testHandlePostSuccessRead() {
        addObjects();
		WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        String jsonString = updateStatus('status', 'read');
        
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }
    
    /**
     * @description test to confirm a POST request is succesful with the 'failed' status.
     */
    @isTest
    static void testHandlePostSuccessSendFailed() {
        addObjects();
		WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        String jsonString = updateStatus('status', 'failed');
        
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }
    
    /**
     * @description test to confirm a POST request is unsuccesful with an invalid 'X-Hub-Signature-256' header.
     */
    @isTest
    static void testHandlePostinvalidHeader() {
        addObjects();
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        String jsonString = JSON.serialize(JSON_MAP);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', '123');

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('{"Success":false}', response.responseBody.toString(), 'Response Body should be {"Success":false}');
    }
    
    /**
     * @description test to confirm a POST request is unsuccesful with an invalid 'value' object.
     */
    @isTest
    static void testHandlePostinvalidValue() {
        addObjects();
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        Map<String, Object> body = new Map<String, Object>{
            'object' => 'whatsapp_business_account',
                'entry' => new List<Object>{
                    new Map<String, Object>{
                        'id' => '1234567890',
                            'changes' => new List<Object>{
                                new Map<String, Object>{
                                    'value' => new Map<String, Object>()
                                        }
                            }
                    }
                }
        };
        String jsonString = JSON.serialize(body);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('{"Success":false}', response.responseBody.toString(), 'Response Body should be {"Success":false}');
    }
    
    /**
     * @description test to confirm a POST request is unsuccesful with an invalid 'changes' object.
     */
    @isTest
    static void testHandlePostinvalidChanges() {
        addObjects();
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        Map<String, Object> body = new Map<String, Object>{
            'object' => 'whatsapp_business_account',
                'entry' => new List<Object>{
                    new Map<String, Object>{
                        'id' => '1234567890',
                            'changes' => new List<Object>()
                    }
                }
        };
        String jsonString = JSON.serialize(body);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('{"Success":false}', response.responseBody.toString(), 'Response Body should be {"Success":false}');
    }
    
    /**
     * @description test to confirm a POST request is unsuccesful with an invalid 'entry' object.
     */
    @isTest
    static void testHandlePostinvalidEntry() {
        addObjects();
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        Map<String, Object> body = new Map<String, Object>{
            'object' => 'whatsapp_business_account',
                'entry' => new List<Object>()
        };
        String jsonString = JSON.serialize(body);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('{"Success":false}', response.responseBody.toString(), 'Response Body should be {"Success":false}');
    }
    
    /**
     * @description test to confirm a POST request is unsuccesful with no MessagingSession found.
     */
    @isTest
    static void testHandlePostinvalidMessagingSession() {
        addObjects();
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        String jsonString = updateStatus('recipient_id', '440000000001');

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(jsonString);
        request.addHeader('X-Hub-Signature-256', WhatsappReceiver.createExpectedSignature(jsonString, WhatsappReceiver.config.APP_SECRET));

        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();

        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('{"Success":false}', response.responseBody.toString(), 'Response Body should be {"Success":false}');
    }

    /**
     * @description test to confirm a GET request is succesful.
     */
    @isTest
    static void testHandleGetSuccess() {
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = REQUEST_URL;
        request.httpMethod = 'GET';

        request.addParameter('hub.mode', 'subscribe');
        request.addParameter('hub.verify_token', WhatsappReceiver.config.VERIFY_TOKEN);
        request.addParameter('hub.challenge', '123456');
        
        RestContext.request = request;
        RestContext.response = response;
        
        WhatsappReceiver.handleGet();
        
        System.assertEquals(WhatsappReceiver.config.SUCCESS_CODE, response.statusCode, 'Status Code should be 200');
        System.assertEquals('123456', response.responseBody.toString(), 'Response Body should be 123456');
    }

    /**
     * @description test to confirm a GET request is unsuccesful with incorrect 'hub.verify_token' value.
     */
    @isTest
    static void testHandleGetInvalidVerifyToken() {
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'GET';

        request.addParameter('hub.mode', 'subscribe');
        request.addParameter('hub.verify_token', '123');
        request.addParameter('hub.challenge', '123456');
        
        RestContext.request = request;
        RestContext.response = response;
        
        WhatsappReceiver.handleGet();
        
        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('Incorrect verification Token', response.responseBody.toString(), 'Response Body should be Incorrect verification Token');
    }
    
    /**
     * @description test to confirm a GET request is unsuccesful with incorrect 'hub.mode' value.
     */
    @isTest
    static void testHandleGetInvalidMode() {
        WhatsappReceiver.initializeConfig();
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'GET';

        request.addParameter('hub.mode', 'fail');
        request.addParameter('hub.verify_token', WhatsappReceiver.config.VERIFY_TOKEN);
        request.addParameter('hub.challenge', '123456');
        
        RestContext.request = request;
        RestContext.response = response;
        
        WhatsappReceiver.handleGet();
        
        System.assertEquals(WhatsappReceiver.config.ERROR_CODE, response.statusCode, 'Status Code should be 400');
        System.assertEquals('Incorrect mode', response.responseBody.toString(), 'Response Body should be Incorrect mode');
    }
    
    /**
     * @description create custom objects to avoid mixed DML exceptions.
     * @return created MessagingSession Id.
     */
    private static Id addObjects() {
        Id channelId = [
            SELECT Id
            FROM MessagingChannel
            WHERE DeveloperName = 'TestMessageChannel'
            LIMIT 1
        ].Id;
        
        MessagingEndUser messagingUser = new MessagingEndUser(
            MessageType = 'WhatsApp',
            MessagingChannelId = channelId,
            MessagingConsentStatus = 'ImplicitlyOptedIn',
            Name = 'Test MessagingUser',
            MessagingPlatformKey = '440000000000',
            HasInitialResponseSent = false
        );
        
        insert messagingUser;
        
		MessagingSession session = new MessagingSession(
            AgentType = 'Bot',
            MessagingEndUserId = messagingUser.Id,
            MessagingChannelId = channelId,
            Origin = 'TriggeredOutbound',
            Status = 'Ended'
        );
        insert session;
        
        return session.Id;
    }
    
    /**
     * @description Retrieves the status value from the JSON_MAP for updates.
     * @param fieldName The name of the field within the status object that needs updating.
     * @param value The value of the field within the status object that needs updating.
     * @return Updated JSON_MAP as a String.
     */
    private static String updateStatus(String fieldName, String value) {
        Map<String, Object> jsonMap = JSON_MAP.clone();
        List<Object> entryList = (List<Object>) jsonMap.get('entry');
        Map<String, Object> entryMap = (Map<String, Object>) entryList[0];
        List<Object> changesList = (List<Object>) entryMap.get('changes');
        Map<String, Object> changesMap = (Map<String, Object>) changesList[0];
        Map<String, Object> valueMap = (Map<String, Object>) changesMap.get('value');
        List<Object> statusesList = (List<Object>) valueMap.get('statuses');
        Map<String, Object> statusMap = (Map<String, Object>) statusesList[0];
        
        statusMap.put(fieldName, value);
        return JSON.serialize(jsonMap);
    }
}
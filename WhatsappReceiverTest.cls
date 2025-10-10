@isTest
private class WhatsappReceiverTest {
    private final static String REQUEST_URL = '/services/apexrest/webhooks/whatsapp';
    private final static String CHANNEL_KEY = '097616747092986';
    private final static Datetime NOW = Datetime.now();
    private static String VERIFY_TOKEN;
    private static String APP_SECRET;
    private static Map<String, Object> JSON_MAP = new Map<String, Object>{
        'object' => 'whatsapp_business_account',
        'entry' => new List<Object>{
            new Map<String, Object>{
                'id' => '1234567890',
                'changes' => new List<Object>{
                    new Map<String, Object>{
                        'value' => new Map<String, Object>{
                            'statuses' => new List<Object>{
                                new Map<String, Object>{
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

    @TestSetup
    static void setupTestData() {
        MessagingChannel channel = new MessagingChannel(
            ConsentType = 'ImplicitOptIn',
            IsActive = true,
            IsoCountryCode = 'US',
            IsRequireDoubleOptIn = false,
            IsRestrictedToBusinessHours = false,
            Language = 'en_US',
            MasterLabel = '07526277094 (NEW)',
            MessageType = 'WhatsApp',
            MessagingPlatformKey = CHANNEL_KEY,
            PlatformType = 'Enhanced',
            ConversationEndResponse = 'An agent has left the conversation.',
            DeveloperName = 'TestMessageChannel',
            InitialResponse = 'Thanks for messaging us. An agent will be with you shortly...',
            EngagedResponse = 'An agent has joined the conversation'
        );
        insert channel;

        MessagingEndUser messagingUser = new MessagingEndUser(
            MessageType = 'WhatsApp',
            MessagingChannelId = channel.Id,
            MessagingConsentStatus = 'ImplicitlyOptedIn',
            Name = 'Test MessagingUser',
            MessagingPlatformKey = '440000000000',
            HasInitialResponseSent = false
        );
        insert messagingUser;

        MessagingSession session = new MessagingSession(
            AgentType = 'Bot',
            MessagingEndUserId = messagingUser.Id,
            MessagingChannelId = channel.Id,
            Origin = 'TriggeredOutbound',
            Status = 'Ended'
        );
        insert session;
    }

    @isTest
    static void testHandlePost() {
        setConstants();

        Test.startTest();
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        String jsonString = JSON.serialize(JSON_MAP);

        request.requestURI = REQUEST_URL;
        request.httpMethod = 'POST';
        String sig = WhatsappReceiver.createExpectedSignature(jsonString, APP_SECRET);
        request.addHeader('X-Hub-Signature-256', sig);

        request.requestBody = Blob.valueOf(jsonString);
        RestContext.request = request;
        RestContext.response = response;

        WhatsappReceiver.handlePost();
        Test.stopTest();

        System.assertEquals(200, response.statusCode, 'Status Code should be 200');
        System.assertEquals('{"Success":true}', response.responseBody.toString(), 'Response Body should be {"Success":true}');
    }

    @isTest
    static void testHandleGetSuccess() {
        setConstants();
        
        Test.startTest();
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestURI = REQUEST_URL;
        request.httpMethod = 'GET';

        request.addParameter('hub.mode', 'subscribe');
        request.addParameter('hub.verify_token', VERIFY_TOKEN);
        request.addParameter('hub.challenge', '123456');
        
        RestContext.request = request;
        RestContext.response = response;
        
        WhatsappReceiver.handleGet();
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status Code should be 200');
        System.assertEquals('123456', response.responseBody.toString(), 'Response Body should be 123456');
    }

    @isTest
    static void testHandleGetInvalidVerifyToken() {
        setConstants();
        
        Test.startTest();
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
        Test.stopTest();
        
        System.assertEquals(400, response.statusCode, 'Status Code should be 400');
        System.assertEquals('Incorrect verification Token', response.responseBody.toString(), 'Response Body should be Incorrect verification Token');
    }

    private static void setConstants() {
        WhatsappWebhook__mdt constants = WhatsappWebhook__mdt.getInstance('Constants');
            
        if (constants != null) {
            VERIFY_TOKEN = constants.VerifyToken__c;
            APP_SECRET = constants.AppSecret__c;
        }
    }
}
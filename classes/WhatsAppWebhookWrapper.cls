/**
 * Wrapper class for received WhatsApp webhooks 
 * Enforces strict typing
 */
public class WhatsAppWebhookWrapper {
    @JsonName('object')
    public String objectType { get; set; }
    public List<Entry> entry { get; set; }

    public class Entry {
        public String id { get; set; }
        public List<Change> changes { get; set; }
    }

    public class Change {
        public Value value { get; set; }
        public String field { get; set; }
    }

    public class Value {
        public String messaging_product { get; set; }
        public Metadata metadata { get; set; }
        public List<Status> statuses { get; set; }
    }

    public class Metadata {
        public String display_phone_number { get; set; }
        public String phone_number_id { get; set; }
    }

    public class Status {
        public String id { get; set; }
        public String status { get; set; }
        public String timestamp { get; set; }
        public String recipient_id { get; set; }
        public Conversation conversation { get; set; }
        public Pricing pricing { get; set; }
    }

    public class Conversation {
        public String id { get; set; }
        public Origin origin { get; set; }
    }

    public class Origin {
        public String type { get; set; }
    }

    public class Pricing {
        public Boolean billable { get; set; }
        public String pricing_model { get; set; }
        public String category { get; set; }
        public String type { get; set; }
    }
    
    public static WhatsAppWebhookWrapper parse(String jsonString) {
        return (WhatsAppWebhookWrapper) System.JSON.deserialize(jsonString, WhatsAppWebhookWrapper.class);
    }
}

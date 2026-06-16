/**
 * BedrockKBData
 * Data structures for AWS Bedrock Knowledge Base API requests and responses.
 *
 * Contains inner classes that represent the JSON structures used when
 * communicating with the Bedrock Retrieve and RetrieveAndGenerate APIs.
 *
 * CONFIGURATION REQUIRED:
 *   Update the modelArn in KnowledgeBaseConfig with the inference profile ARN
 *   for your AWS account. See README.md for instructions.
 */
public class BedrockKBData {

    // ========================================
    // RETRIEVE API STRUCTURES
    // ========================================

    public class RetrieveRequest {
        public RetrievalQuery retrievalQuery;
        public RetrievalConfiguration retrievalConfiguration;

        public RetrieveRequest(String queryText, Integer numResults) {
            this.retrievalQuery = new RetrievalQuery(queryText);
            this.retrievalConfiguration = new RetrievalConfiguration(numResults);
        }
    }

    public class RetrievalQuery {
        public String text;
        public RetrievalQuery(String text) { this.text = text; }
    }

    public class RetrievalConfiguration {
        public VectorSearchConfiguration vectorSearchConfiguration;
        public RetrievalConfiguration(Integer numResults) {
            this.vectorSearchConfiguration = new VectorSearchConfiguration(numResults);
        }
    }

    public class VectorSearchConfiguration {
        public Integer numberOfResults;
        public VectorSearchConfiguration(Integer numberOfResults) {
            this.numberOfResults = numberOfResults;
        }
    }

    public class RetrieveResponse {
        public List<RetrievalResult> retrievalResults;
        public String nextToken;
    }

    public class RetrievalResult {
        public Content content;
        public RetrievalLocation location;
        public Double score;
    }

    public class Content {
        public String text;
    }

    public class RetrievalLocation {
        public String type;
        public S3Location s3Location;
    }

    public class S3Location {
        public String uri;
    }

    // ========================================
    // RETRIEVE AND GENERATE API STRUCTURES
    // ========================================

    public class RetrieveAndGenerateRequest {
        public InputData input;
        public RetrieveAndGenerateConfiguration retrieveAndGenerateConfiguration;

        public RetrieveAndGenerateRequest(String queryText, String knowledgeBaseId) {
            this.input = new InputData(queryText);
            this.retrieveAndGenerateConfiguration = new RetrieveAndGenerateConfiguration(knowledgeBaseId);
        }
    }

    public class InputData {
        public String text;
        public InputData(String text) { this.text = text; }
    }

    public class RetrieveAndGenerateConfiguration {
        public String type;
        public KnowledgeBaseConfig knowledgeBaseConfiguration;

        public RetrieveAndGenerateConfiguration(String knowledgeBaseId) {
            this.type = 'KNOWLEDGE_BASE';
            this.knowledgeBaseConfiguration = new KnowledgeBaseConfig(knowledgeBaseId);
        }
    }

    public class KnowledgeBaseConfig {
        public String knowledgeBaseId;
        public String modelArn;

        public KnowledgeBaseConfig(String knowledgeBaseId) {
            this.knowledgeBaseId = knowledgeBaseId;
            // REPLACE with your inference profile ARN.
            // Format: arn:aws:bedrock:<REGION>:<ACCOUNT_ID>:inference-profile/<PROFILE_ID>
            // See README.md — Step 4: Update Apex Configuration.
            this.modelArn = 'arn:aws:bedrock:YOUR_REGION:YOUR_ACCOUNT_ID:inference-profile/YOUR_INFERENCE_PROFILE_ID';
        }
    }

    public class RetrieveAndGenerateResponse {
        public String sessionId;
        public OutputData output;
        public List<Citation> citations;
    }

    public class OutputData {
        public String text;
    }

    public class Citation {
        public List<RetrievedReference> retrievedReferences;
    }

    public class RetrievedReference {
        public Content content;
        public RetrievalLocation location;
    }
}

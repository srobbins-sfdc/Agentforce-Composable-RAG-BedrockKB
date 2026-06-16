/**
 * BedrockKBService
 * Service class for AWS Bedrock Knowledge Base API interactions.
 *
 * Handles HTTP callouts to the Bedrock Knowledge Base APIs:
 *   - Retrieve: fetches relevant text chunks for RAG context
 *   - RetrieveAndGenerate: returns a complete generated answer with citations
 *
 * Prerequisites:
 *   - AWS IAM user with bedrock:Retrieve (and optionally bedrock:RetrieveAndGenerate) permissions
 *   - Salesforce Named Credential configured with AWS Signature Version 4 authentication
 *
 * CONFIGURATION REQUIRED:
 *   Update KNOWLEDGE_BASE_ID below with your Bedrock Knowledge Base ID.
 *   See README.md — Step 4: Update Apex Configuration.
 */
public class BedrockKBService {

    // ── REPLACE this value with your Knowledge Base ID ──────────────────────
    private static final String KNOWLEDGE_BASE_ID = 'YOUR_KNOWLEDGE_BASE_ID';
    // ────────────────────────────────────────────────────────────────────────

    private static final String NAMED_CREDENTIAL = 'AWS_Bedrock_API';
    private static final Integer DEFAULT_NUM_RESULTS = 5;
    private static final Integer TIMEOUT_MS = 60000;

    /**
     * Retrieve relevant text chunks from the Knowledge Base.
     *
     * @param question   The user's question or query
     * @param numResults Number of results to retrieve (defaults to 5)
     * @return RetrieveResponse containing relevant text chunks with scores
     */
    public static BedrockKBData.RetrieveResponse retrieve(String question, Integer numResults) {
        if (String.isBlank(question)) {
            throw new IllegalArgumentException('Question cannot be blank');
        }
        if (numResults == null || numResults < 1) {
            numResults = DEFAULT_NUM_RESULTS;
        }

        BedrockKBData.RetrieveRequest requestBody = new BedrockKBData.RetrieveRequest(question, numResults);

        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + NAMED_CREDENTIAL + '/knowledgebases/' + KNOWLEDGE_BASE_ID + '/retrieve');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse response;
        try {
            response = http.send(request);
        } catch (Exception e) {
            throw new CalloutException('Failed to connect to AWS Bedrock: ' + e.getMessage());
        }

        if (response.getStatusCode() == 200) {
            return (BedrockKBData.RetrieveResponse) JSON.deserialize(
                response.getBody(), BedrockKBData.RetrieveResponse.class);
        }
        throw new CalloutException(
            'AWS Bedrock API Error: ' + response.getStatus() +
            ' (Status Code: ' + response.getStatusCode() + ')' +
            '\nResponse: ' + response.getBody());
    }

    /**
     * Retrieve and generate a complete answer from the Knowledge Base.
     *
     * @param question The user's question or query
     * @return RetrieveAndGenerateResponse containing the generated answer and citations
     */
    public static BedrockKBData.RetrieveAndGenerateResponse retrieveAndGenerate(String question) {
        if (String.isBlank(question)) {
            throw new IllegalArgumentException('Question cannot be blank');
        }

        BedrockKBData.RetrieveAndGenerateRequest requestBody =
            new BedrockKBData.RetrieveAndGenerateRequest(question, KNOWLEDGE_BASE_ID);

        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + NAMED_CREDENTIAL + '/retrieveAndGenerate');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse response;
        try {
            response = http.send(request);
        } catch (Exception e) {
            throw new CalloutException('Failed to connect to AWS Bedrock: ' + e.getMessage());
        }

        if (response.getStatusCode() == 200) {
            return (BedrockKBData.RetrieveAndGenerateResponse) JSON.deserialize(
                response.getBody(), BedrockKBData.RetrieveAndGenerateResponse.class);
        }
        throw new CalloutException(
            'AWS Bedrock API Error: ' + response.getStatus() +
            ' (Status Code: ' + response.getStatusCode() + ')' +
            '\nResponse: ' + response.getBody());
    }
}

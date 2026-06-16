/**
 * BedrockKBAgentAction
 * Invocable method for Agentforce and Flow integration with AWS Bedrock Knowledge Base.
 *
 * Uses the RetrieveAndGenerate API to return a complete, conversational answer
 * with citations from the Knowledge Base. Designed for use as an Agentforce
 * agent action or inside a Salesforce Flow.
 *
 * USAGE:
 *   Add "Get Knowledge Base Answer" as an action in your Agentforce agent or Flow.
 *   The action accepts a question and returns a generated answer with source citations.
 */
public class BedrockKBAgentAction {

    @InvocableMethod(
        label='Get Knowledge Base Answer'
        description='Get a complete AI-generated answer from AWS Bedrock Knowledge Base with citations.'
        category='AI and Predictions'
    )
    public static List<ActionResponse> getGeneratedAnswer(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();

        for (ActionRequest request : requests) {
            ActionResponse response = new ActionResponse();

            try {
                if (String.isBlank(request.question)) {
                    throw new IllegalArgumentException('Question cannot be blank');
                }

                BedrockKBData.RetrieveAndGenerateResponse ragResponse =
                    BedrockKBService.retrieveAndGenerate(request.question);

                response.answer = (ragResponse.output != null && String.isNotBlank(ragResponse.output.text))
                    ? ragResponse.output.text.trim()
                    : 'No answer could be generated from the available knowledge base content.';

                response.sessionId = ragResponse.sessionId;

                Set<String> uniqueSources = new Set<String>();
                List<String> citationList = new List<String>();

                if (ragResponse.citations != null) {
                    for (BedrockKBData.Citation citation : ragResponse.citations) {
                        if (citation.retrievedReferences != null) {
                            for (BedrockKBData.RetrievedReference ref : citation.retrievedReferences) {
                                if (ref.location != null &&
                                    ref.location.s3Location != null &&
                                    String.isNotBlank(ref.location.s3Location.uri)) {
                                    String uri = ref.location.s3Location.uri;
                                    if (!uniqueSources.contains(uri)) {
                                        uniqueSources.add(uri);
                                        citationList.add(uri);
                                    }
                                }
                            }
                        }
                    }
                }

                if (!citationList.isEmpty()) {
                    response.citations = String.join(citationList, '\n');
                    response.numberOfCitations = citationList.size();
                    response.hasCitations = true;
                    List<String> formatted = new List<String>();
                    Integer n = 1;
                    for (String src : citationList) {
                        formatted.add('[' + n++ + '] ' + src);
                    }
                    response.formattedCitations = String.join(formatted, '\n');
                } else {
                    response.citations = '';
                    response.numberOfCitations = 0;
                    response.hasCitations = false;
                    response.formattedCitations = '';
                }

                response.success = true;
                response.hasAnswer = String.isNotBlank(response.answer);

            } catch (Exception e) {
                response.success = false;
                response.hasAnswer = false;
                response.hasCitations = false;
                response.errorMessage = e.getMessage();
                response.errorType = e.getTypeName();
                response.answer = 'An error occurred while accessing the knowledge base. Please try again or contact your administrator.';
                response.technicalError = e.getMessage() + '\n' + e.getStackTraceString();
                System.debug(LoggingLevel.ERROR, 'BedrockKBAgentAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, e.getStackTraceString());
            }

            responses.add(response);
        }

        return responses;
    }

    public class ActionRequest {
        @InvocableVariable(label='Question' required=true)
        public String question;

        @InvocableVariable(label='Session ID (Optional)')
        public String sessionId;
    }

    public class ActionResponse {
        @InvocableVariable(label='Answer')
        public String answer;

        @InvocableVariable(label='Session ID')
        public String sessionId;

        @InvocableVariable(label='Citations')
        public String citations;

        @InvocableVariable(label='Formatted Citations')
        public String formattedCitations;

        @InvocableVariable(label='Number of Citations')
        public Integer numberOfCitations;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Has Answer')
        public Boolean hasAnswer;

        @InvocableVariable(label='Has Citations')
        public Boolean hasCitations;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Error Type')
        public String errorType;

        @InvocableVariable(label='Technical Error Details')
        public String technicalError;
    }
}

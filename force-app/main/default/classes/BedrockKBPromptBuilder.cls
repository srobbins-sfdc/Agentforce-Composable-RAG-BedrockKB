/**
 * BedrockKBPromptBuilder
 * Invocable method for Salesforce Prompt Template integration with AWS Bedrock Knowledge Base.
 *
 * Designed for use in Prompt Templates as part of an Agentforce agent action.
 * Retrieves relevant text chunks from the Knowledge Base and formats them for
 * RAG (Retrieval-Augmented Generation) prompt grounding.
 *
 * USAGE IN PROMPT TEMPLATE:
 *   Add the "Get Bedrock KB Context" action to your prompt template, then
 *   reference the output as: {!$Apex.Get_Bedrock_KB_Context.Prompt}
 *
 * EXAMPLE PROMPT:
 *   Context from our knowledge base:
 *   {!$Apex.Get_Bedrock_KB_Context.Prompt}
 *
 *   Based on the context above, please answer: {!$Input.question}
 */
public class BedrockKBPromptBuilder {

    @InvocableMethod(
        label='Get Bedrock KB Context'
        description='Retrieve relevant text chunks from AWS Bedrock Knowledge Base for prompt grounding.'
    )
    public static List<Response> getContextForPrompt(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request request : requests) {
            Response response = new Response();

            try {
                if (String.isBlank(request.question)) {
                    throw new IllegalArgumentException('Question cannot be blank');
                }

                BedrockKBData.RetrieveResponse retrieveResponse =
                    BedrockKBService.retrieve(request.question, 8);

                List<String> formattedChunks = new List<String>();

                if (retrieveResponse.retrievalResults != null && !retrieveResponse.retrievalResults.isEmpty()) {
                    Integer chunkNumber = 1;
                    for (BedrockKBData.RetrievalResult result : retrieveResponse.retrievalResults) {
                        if (result.content != null && String.isNotBlank(result.content.text)) {
                            String chunk = 'DOCUMENT ' + chunkNumber + ':\n';
                            if (result.score != null) {
                                Decimal scorePercent = Decimal.valueOf(result.score * 100).setScale(1);
                                chunk += '[Relevance: ' + scorePercent + '%]\n';
                            }
                            chunk += result.content.text.trim();
                            if (result.location != null &&
                                result.location.s3Location != null &&
                                String.isNotBlank(result.location.s3Location.uri)) {
                                chunk += '\n[Source: ' + result.location.s3Location.uri + ']';
                            }
                            formattedChunks.add(chunk);
                            chunkNumber++;
                        }
                    }
                }

                response.Prompt = !formattedChunks.isEmpty()
                    ? String.join(formattedChunks, '\n\n' + '='.repeat(50) + '\n\n')
                    : 'No relevant information found in the knowledge base for this query.';

            } catch (Exception e) {
                response.Prompt = '[Error retrieving context: ' + e.getMessage() + ']';
                System.debug(LoggingLevel.ERROR, 'BedrockKBPromptBuilder error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, e.getStackTraceString());
            }

            responses.add(response);
        }

        return responses;
    }

    public class Request {
        @InvocableVariable(required=true)
        public String question;
    }

    /** Output variable MUST be named "Prompt" (capital P) for Prompt Builder discovery. */
    public class Response {
        @InvocableVariable
        public String Prompt;
    }
}

/**
 * BedrockKBPromptBuilderSimple
 * Minimal Prompt Builder integration for quick testing and validation.
 *
 * Use this class to verify the end-to-end connection to the Knowledge Base
 * before using the full BedrockKBPromptBuilder in production prompt templates.
 */
public class BedrockKBPromptBuilderSimple {

    @InvocableMethod(
        label='Get Bedrock Context (Simple)'
        description='Simplified Knowledge Base context retrieval — use for testing.'
    )
    public static List<Response> getContext(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request input : requests) {
            Response output = new Response();

            try {
                BedrockKBData.RetrieveResponse retrieveResponse =
                    BedrockKBService.retrieve(input.question, 8);

                String formattedContext = '';
                if (retrieveResponse.retrievalResults != null) {
                    for (BedrockKBData.RetrievalResult result : retrieveResponse.retrievalResults) {
                        formattedContext += '\n---\n' + result.content.text + '\n';
                    }
                } else {
                    formattedContext = 'No relevant context found.';
                }

                output.Prompt = formattedContext;

            } catch (Exception e) {
                output.Prompt = 'Error: ' + e.getMessage();
            }

            responses.add(output);
        }

        return responses;
    }

    public class Request {
        @InvocableVariable(required=true)
        public String question;
    }

    public class Response {
        @InvocableVariable
        public String Prompt;
    }
}

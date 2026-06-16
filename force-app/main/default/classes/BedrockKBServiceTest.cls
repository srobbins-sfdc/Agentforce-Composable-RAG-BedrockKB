@isTest
private class BedrockKBServiceTest {

    private class RetrieveMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(
                req.getEndpoint().contains('/knowledgebases/') && req.getEndpoint().endsWith('/retrieve'),
                'Expected a /retrieve endpoint, got: ' + req.getEndpoint()
            );

            String body = '{'
                + '"retrievalResults": ['
                + '  {"content": {"text": "Sample retrieved chunk one."}, "score": 0.92,'
                + '   "location": {"type": "S3", "s3Location": {"uri": "s3://my-bucket/doc1.pdf"}}},'
                + '  {"content": {"text": "Sample retrieved chunk two."}, "score": 0.87,'
                + '   "location": {"type": "S3", "s3Location": {"uri": "s3://my-bucket/doc2.pdf"}}}'
                + ']'
                + '}';

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"message": "Access denied"}');
            return res;
        }
    }

    @isTest
    static void retrieve_returnsResults() {
        Test.setMock(HttpCalloutMock.class, new RetrieveMock());
        Test.startTest();
        BedrockKBData.RetrieveResponse response = BedrockKBService.retrieve('What is this knowledge base about?', 5);
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertNotEquals(null, response.retrievalResults);
        System.assertEquals(2, response.retrievalResults.size());

        BedrockKBData.RetrievalResult first = response.retrievalResults[0];
        System.assertNotEquals(null, first.content.text);
        System.assert(first.score > 0);
        System.assertEquals('s3://my-bucket/doc1.pdf', first.location.s3Location.uri);
    }

    @isTest
    static void retrieve_blankQuestion_throwsException() {
        Test.setMock(HttpCalloutMock.class, new RetrieveMock());
        Test.startTest();
        try {
            BedrockKBService.retrieve('', 5);
            System.assert(false, 'Expected IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('blank'));
        }
        Test.stopTest();
    }

    @isTest
    static void retrieve_nullNumResults_usesDefault() {
        Test.setMock(HttpCalloutMock.class, new RetrieveMock());
        Test.startTest();
        BedrockKBData.RetrieveResponse response = BedrockKBService.retrieve('Test question', null);
        Test.stopTest();
        System.assertNotEquals(null, response.retrievalResults);
    }

    @isTest
    static void retrieve_errorResponse_throwsCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            BedrockKBService.retrieve('test query', 3);
            System.assert(false, 'Expected CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('403'));
        }
        Test.stopTest();
    }
}
